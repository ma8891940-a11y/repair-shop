// اختبارات الأمان والقواعد على قاعدة بيانات حقيقية (Postgres محلي مؤقت).
// بتشتغل بـ: npm run test:db
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { STATUSES, canTransition } from '../../src/lib/status';

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;

let db: pg.Client;

async function admin(sql: string, params: unknown[] = []) {
  return db.query(sql, params);
}

/** ينفّذ SQL كأنه مستخدم مسجّل دخول في Supabase */
async function as<T extends pg.QueryResultRow = pg.QueryResultRow>(
  uid: string,
  sql: string,
  params: unknown[] = [],
): Promise<pg.QueryResult<T>> {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    const r = await db.query<T>(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}

async function newUser(email: string, confirmed = true) {
  const id = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, $3)', [id, email, confirmed ? new Date() : null]);
  return id;
}

const ownerA = { id: '', shop: '' };
const ownerB = { id: '', shop: '' };
let recA = '';
let techA = '';
let customerA = '';
let deviceA = '';
let deviceA2 = '';
let year = 0;

async function addDevice(uid: string, customerId: string, imei: string | null = null) {
  const id = randomUUID();
  const r = await as<{ order_no: string }>(
    uid,
    `insert into devices(id, customer_id, brand, model, imei, issue)
     values ($1, $2, 'Samsung', 'A52', $3, 'الشاشة مكسورة') returning order_no`,
    [id, customerId, imei],
  );
  return { id, orderNo: r.rows[0].order_no };
}

d('قاعدة البيانات: العزل والصلاحيات', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    year = (await admin(`select extract(year from now() at time zone 'Africa/Cairo')::int as y`)).rows[0].y;

    ownerA.id = await newUser('a@shop.test');
    ownerB.id = await newUser('b@shop.test');
    ownerA.shop = (await as(ownerA.id, `select (bootstrap_account('أحمد', 'محل أ')).shop_id as s`)).rows[0].s;
    ownerB.shop = (await as(ownerB.id, `select (bootstrap_account('بسمة', 'محل ب')).shop_id as s`)).rows[0].s;

    await as(ownerA.id, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), 'rec@shop.test', 'سارة', 'reception')`);
    await as(ownerA.id, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), 'tech@shop.test', 'كريم', 'technician')`);
    recA = await newUser('rec@shop.test');
    const inv = await as(recA, `select * from my_pending_invite()`);
    expect(inv.rows[0]).toEqual({ shop_name: 'محل أ', role: 'reception' });
    expect((await as(ownerB.id, `select * from my_pending_invite()`)).rowCount).toBe(0);
    techA = await newUser('tech@shop.test');
    await as(recA, `select bootstrap_account('سارة')`);
    await as(techA, `select bootstrap_account('كريم')`);

    customerA = randomUUID();
    await as(recA, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'محمد', '01012345678')`, [customerA]);
    deviceA = (await addDevice(recA, customerA, '490154203237518')).id;
    await as(recA, `insert into device_costs(shop_id, device_id, estimated_cost) values (gen_random_uuid(), $1, 15000)`, [deviceA]);
    deviceA2 = (await addDevice(recA, customerA)).id;
  });

  afterAll(async () => {
    await db?.end();
  });

  it('أول تسجيل بيعمل محل وصاحب محل، والدعوة بتضيف الموظف بالدور الصح', async () => {
    const roles = await admin(`select email, role::text, shop_id from profiles order by email`);
    const byEmail = Object.fromEntries(roles.rows.map((r) => [r.email, r]));
    expect(byEmail['a@shop.test'].role).toBe('owner');
    expect(byEmail['b@shop.test'].role).toBe('owner');
    expect(byEmail['rec@shop.test']).toMatchObject({ role: 'reception', shop_id: ownerA.shop });
    expect(byEmail['tech@shop.test']).toMatchObject({ role: 'technician', shop_id: ownerA.shop });
    expect(ownerA.shop).not.toBe(ownerB.shop);
  });

  it('الدعوة ما تشتغلش لو الإيميل مش متأكَّد منه', async () => {
    await as(ownerA.id, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), 'fake@shop.test', 'x', 'reception')`);
    const fake = await newUser('fake@shop.test', false);
    await expect(as(fake, `select bootstrap_account('x')`)).rejects.toThrow(/تأكّد الإيميل/);
  });

  it('رقم الطلب تلقائي ومتسلسل لكل محل لوحده', async () => {
    const nums = (await as(ownerA.id, `select order_no from devices order by order_no`)).rows.map((r) => r.order_no);
    expect(nums).toEqual([`${year}-0001`, `${year}-0002`]);
    const custB = randomUUID();
    await as(ownerB.id, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'علي', '01112345678')`, [custB]);
    const b = await addDevice(ownerB.id, custB);
    expect(b.orderNo).toBe(`${year}-0001`);
  });

  it('محل ما يقدرش يشوف أي حاجة من بيانات محل تاني', async () => {
    for (const t of ['customers', 'device_costs', 'device_notes', 'device_photos', 'status_log', 'audit_log', 'staff_invites', 'devices_list']) {
      const r = await as(ownerB.id, `select count(*)::int as n from ${t} where shop_id = $1`, [ownerA.shop]);
      expect(r.rows[0].n, t).toBe(0);
    }
    const devs = await as(ownerB.id, `select id from devices where id = $1`, [deviceA]);
    expect(devs.rowCount).toBe(0);
    const shops = await as(ownerB.id, `select id from shops`);
    expect(shops.rows.map((r) => r.id)).toEqual([ownerB.shop]);
  });

  it('محل ما يقدرش يكتب أو يعدّل في محل تاني', async () => {
    // حتى لو بعت shop_id بتاع محل تاني، الـ trigger بيرجّعه لمحله هو
    const id = randomUUID();
    await as(ownerB.id, `insert into customers(id, shop_id, name, phone) values ($1, $2, 'دخيل', '01212345678')`, [id, ownerA.shop]);
    const row = await admin(`select shop_id from customers where id = $1`, [id]);
    expect(row.rows[0].shop_id).toBe(ownerB.shop);

    const upd = await as(ownerB.id, `update devices set model = 'hack' where id = $1`, [deviceA]);
    expect(upd.rowCount).toBe(0);
    // ربط جهاز بعميل من محل تاني ممنوع
    await expect(
      as(ownerB.id, `insert into devices(shop_id, customer_id, order_no, brand, model, issue) values (gen_random_uuid(), $1, 'x', 'a', 'b', 'c')`, [customerA]),
    ).rejects.toThrow(/نفس المحل/);
  });

  it('كل تغيير حالة يتسجّل بالقديمة والجديدة والموظف والوقت', async () => {
    await as(techA, `update devices set status = 'inspecting' where id = $1`, [deviceA]);
    const log = await as(ownerA.id, `select old_status::text, new_status::text, changed_by, created_at from status_log where device_id = $1 order by created_at`, [deviceA]);
    expect(log.rows.map((r) => [r.old_status, r.new_status])).toEqual([[null, 'received'], ['received', 'inspecting']]);
    expect(log.rows[0].changed_by).toBe(recA);
    expect(log.rows[1].changed_by).toBe(techA);
    expect(log.rows[1].created_at).toBeInstanceOf(Date);
  });

  it('الانتقالات الغلط مرفوضة من قاعدة البيانات نفسها', async () => {
    await expect(as(recA, `update devices set status = 'delivered' where id = $1`, [deviceA2])).rejects.toThrow(/انتقال غير مسموح/);
  });

  it('قواعد الانتقال في قاعدة البيانات مطابقة للي في التطبيق (100 حالة)', async () => {
    for (const from of STATUSES) {
      for (const to of STATUSES) {
        const r = await admin(`select is_valid_transition($1::device_status, $2::device_status) as ok`, [from, to]);
        expect(r.rows[0].ok, `${from} -> ${to}`).toBe(canTransition(from, to));
      }
    }
  });

  it('الفني: ما يشوفش أسعار ولا بيانات عملاء، ويغيّر الحالة بس، وما يسلّمش', async () => {
    expect((await as(techA, `select * from device_costs`)).rowCount).toBe(0);
    expect((await as(techA, `select * from customers`)).rowCount).toBe(0);
    const list = await as(techA, `select customer_name, customer_phone, estimated_cost from devices_list where id = $1`, [deviceA]);
    expect(list.rows[0]).toEqual({ customer_name: null, customer_phone: null, estimated_cost: null });
    await expect(as(techA, `update devices set model = 'X' where id = $1`, [deviceA])).rejects.toThrow(/الفني/);
    await as(techA, `update devices set status = 'in_repair' where id = $1`, [deviceA]);
    await as(techA, `update devices set status = 'repaired' where id = $1`, [deviceA]);
    await as(techA, `update devices set status = 'ready' where id = $1`, [deviceA]);
    await expect(as(techA, `update devices set status = 'delivered' where id = $1`, [deviceA])).rejects.toThrow();
  });

  it('التسليم محتاج تكلفة نهائية، وبيسجّل وقت التسليم تلقائيًا', async () => {
    await expect(as(recA, `update devices set status = 'delivered' where id = $1`, [deviceA])).rejects.toThrow(/التكلفة النهائية/);
    await as(recA, `update device_costs set final_cost = 17550 where device_id = $1`, [deviceA]);
    await as(recA, `update devices set status = 'delivered' where id = $1`, [deviceA]);
    const r = await as(recA, `select delivered_at, final_cost from devices_list where id = $1`, [deviceA]);
    expect(r.rows[0].delivered_at).toBeInstanceOf(Date);
    expect(r.rows[0].final_cost).toBe(17550);
  });

  it('تعديل السعر بيتسجّل في سجل النشاط بالقيمة قبل وبعد', async () => {
    const r = await as(ownerA.id, `select before->>'final_cost' as b, after->>'final_cost' as a, actor_id from audit_log where entity = 'device_costs' and action = 'update' order by created_at desc limit 1`);
    expect(r.rows[0]).toEqual({ b: null, a: '17550', actor_id: recA });
  });

  it('سجل النشاط: صاحب المحل بس يشوفه، ومحدش يقدر يعدّله أو يحذفه', async () => {
    expect((await as(ownerA.id, `select count(*)::int as n from audit_log`)).rows[0].n).toBeGreaterThan(5);
    expect((await as(recA, `select count(*)::int as n from audit_log`)).rows[0].n).toBe(0);
    expect((await as(techA, `select count(*)::int as n from audit_log`)).rows[0].n).toBe(0);
    await expect(as(ownerA.id, `update audit_log set action = 'x'`)).rejects.toThrow();
    await expect(as(ownerA.id, `delete from audit_log`)).rejects.toThrow();
    await expect(as(ownerA.id, `insert into audit_log(shop_id, action, entity) values ($1, 'fake', 'x')`, [ownerA.shop])).rejects.toThrow();
    // حتى مدير قاعدة البيانات نفسه
    await expect(admin(`update audit_log set action = 'x'`)).rejects.toThrow(/سجل النشاط/);
    await expect(admin(`delete from audit_log`)).rejects.toThrow();
  });

  it('الحذف الفعلي ممنوع في كل الجداول (soft delete بس)', async () => {
    await expect(as(ownerA.id, `delete from devices where id = $1`, [deviceA2])).rejects.toThrow();
    await expect(admin(`delete from devices where id = $1`, [deviceA2])).rejects.toThrow(/الحذف الفعلي ممنوع/);
    await as(ownerA.id, `update customers set deleted_at = now() where id = $1`, [randomUUID()]);
  });

  it('الملاحظات الداخلية: أي موظف يكتب، وما بتتعدلش', async () => {
    const id = randomUUID();
    await as(techA, `insert into device_notes(id, shop_id, device_id, body) values ($1, gen_random_uuid(), $2, 'الفلاتة اتغيرت قبل كده')`, [id, deviceA]);
    const n = await as(recA, `select author_id, body from device_notes where id = $1`, [id]);
    expect(n.rows[0].author_id).toBe(techA);
    await expect(as(techA, `update device_notes set body = 'تعديل' where id = $1`, [id])).rejects.toThrow();
  });

  it('حد أقصى 6 صور لكل جهاز، والمسار لازم يكون جوه فولدر المحل', async () => {
    for (let i = 0; i < 6; i++) {
      await as(recA, `insert into device_photos(shop_id, device_id, storage_path) values (gen_random_uuid(), $1, $2)`, [deviceA2, `${ownerA.shop}/${deviceA2}/${i}.jpg`]);
    }
    await expect(
      as(recA, `insert into device_photos(shop_id, device_id, storage_path) values (gen_random_uuid(), $1, $2)`, [deviceA2, `${ownerA.shop}/${deviceA2}/7.jpg`]),
    ).rejects.toThrow(/6 صور/);
    await expect(
      as(recA, `insert into device_photos(shop_id, device_id, storage_path) values (gen_random_uuid(), $1, $2)`, [deviceA, `${ownerB.shop}/${deviceA}/x.jpg`]),
    ).rejects.toThrow(/مسار/);
  });

  it('ملفات الصور: محل ما يقدرش يقرا أو يرفع في فولدر محل تاني، والفني ما يرفعش', async () => {
    await admin(`insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${ownerA.shop}/${deviceA}/a.jpg`]);
    expect((await as(ownerA.id, `select count(*)::int as n from storage.objects`)).rows[0].n).toBe(1);
    expect((await as(ownerB.id, `select count(*)::int as n from storage.objects`)).rows[0].n).toBe(0);
    await expect(as(ownerB.id, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${ownerA.shop}/x/b.jpg`])).rejects.toThrow();
    await expect(as(techA, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${ownerA.shop}/x/b.jpg`])).rejects.toThrow();
    await as(recA, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${ownerA.shop}/x/c.jpg`]);
  });

  it('تنبيه IMEI: البحث بيلاقي الجهاز في نفس المحل بس', async () => {
    const q = `select order_no from devices where imei = $1 and deleted_at is null`;
    expect((await as(recA, q, ['490154203237518'])).rowCount).toBe(1);
    expect((await as(ownerB.id, q, ['490154203237518'])).rowCount).toBe(0);
  });

  it('الموظف ما يقدرش يغيّر دوره، وغير صاحب المحل ما يعدّلش المستخدمين أو الإعدادات', async () => {
    expect((await as(recA, `update profiles set role = 'owner' where id = $1`, [recA])).rowCount).toBe(0);
    expect((await as(recA, `update shops set name = 'x'`)).rowCount).toBe(0);
    await expect(as(ownerA.id, `update profiles set role = 'owner' where id = $1`, [recA])).rejects.toThrow();
    await expect(as(ownerA.id, `update profiles set deleted_at = now() where id = $1`, [ownerA.id])).rejects.toThrow();
  });

  it('الموظف الموقوف ما يشوفش أي حاجة', async () => {
    await as(ownerA.id, `update profiles set deleted_at = now() where id = $1`, [techA]);
    expect((await as(techA, `select count(*)::int as n from devices`)).rows[0].n).toBe(0);
    await expect(as(techA, `select bootstrap_account('x')`)).rejects.toThrow(/موقوف/);
  });

  it('الزائر من غير تسجيل دخول (anon) ما يشوفش أي جدول', async () => {
    await db.query('begin');
    await db.query('set local role anon');
    await expect(db.query('select * from devices')).rejects.toThrow(/permission denied/);
    await db.query('rollback');
  });
});
