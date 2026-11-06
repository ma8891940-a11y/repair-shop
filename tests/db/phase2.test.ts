// المرحلة 2: التتبع العام، والموافقة على التكلفة، والرسايل، والفحص، والضمان
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;

async function admin(sql: string, params: unknown[] = []) {
  return db.query(sql, params);
}
async function as<T extends pg.QueryResultRow = pg.QueryResultRow>(uid: string | null, sql: string, params: unknown[] = [], ip = '10.0.0.1') {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': ip })]);
    if (uid) {
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
    } else {
      await db.query(`select set_config('request.jwt.claims', '', true)`);
      await db.query('set local role anon');
    }
    const r = await db.query<T>(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
async function user(email: string) {
  const id = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [id, email]);
  return id;
}

const tag = randomUUID().slice(0, 8);
// عنوان شبكة مختلف لكل تشغيلة، عشان محاولات التشغيلات اللي فاتت ما تأثرش
const NET = `10.${Math.floor(Math.random() * 250) + 1}`;
let owner = '';
let tech = '';
let other = '';
let shop = '';
let customer = '';
let dev = '';
let order = '';
let token = '';

d('المرحلة 2: العميل', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`o2-${tag}@t.test`);
    other = await user(`x2-${tag}@t.test`);
    shop = (await as(owner, `select (bootstrap_account('صاحب', 'محل التتبع')).shop_id as s`)).rows[0].s;
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'كريم حسن', 'technician')`, [`t2-${tag}@t.test`]);
    tech = await user(`t2-${tag}@t.test`);
    await as(tech, `select bootstrap_account('كريم حسن')`);
    customer = randomUUID();
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'منى سمير', '01123456789')`, [customer]);
    dev = randomUUID();
    const r = await as<{ order_no: string; tracking_token: string }>(
      owner,
      `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'iPhone', '13 Pro', 'بطارية') returning order_no, tracking_token`,
      [dev, customer],
    );
    order = r.rows[0].order_no;
    token = r.rows[0].tracking_token;
    await as(owner, `insert into device_costs(shop_id, device_id, estimated_cost) values (gen_random_uuid(), $1, 160000)`, [dev]);
  });
  afterAll(async () => db?.end());

  it('كل جهاز ليه رمز تتبع عشوائي طويل ومختلف، وما بيتغيرش', async () => {
    expect(token).toMatch(/^[0-9a-f]{24}$/);
    await expect(as(owner, `update devices set tracking_token = 'x' where id = $1`, [dev])).rejects.toThrow(/E_RECEIPT_IMMUTABLE/);
  });

  it('الزائر بيتتبع بالرمز (QR) أو برقم الطلب وآخر 4 أرقام، ومن غير أي بيانات شخصية', async () => {
    const a = await as(null, `select * from get_tracking(p_token => $1)`, [token]);
    expect(a.rows[0]).toMatchObject({ order_no: order, status: 'received', brand: 'iPhone', estimated_cost: 160000, shop_name: 'محل التتبع' });
    const keys = Object.keys(a.rows[0]);
    for (const k of ['name', 'phone', 'customer_name', 'customer_phone', 'imei', 'issue']) expect(keys).not.toContain(k);
    expect(JSON.stringify(a.rows[0])).not.toContain('منى');
    expect(JSON.stringify(a.rows[0])).not.toContain('01123456789');
    const b = await as(null, `select order_no from get_tracking($1, '6789')`, [order]);
    expect(b.rows[0].order_no).toBe(order);
  });

  it('اسم الفني بيظهر (الاسم الأول بس) بعد ما يشتغل على الجهاز', async () => {
    await as(tech, `update devices set status = 'inspecting' where id = $1`, [dev]);
    const r = await as(null, `select technician, status from get_tracking(p_token => $1)`, [token]);
    expect(r.rows[0]).toEqual({ technician: 'كريم', status: 'inspecting' });
  });

  it('بيانات غلط = مفيش نتيجة، والزائر ما يقدرش يقرا الجداول مباشرة', async () => {
    expect((await as(null, `select * from get_tracking($1, '0000')`, [order], `${NET}.9.1`)).rowCount).toBe(0);
    expect((await as(null, `select * from get_tracking(p_token => 'ffffffffffffffffffffffff')`, [], `${NET}.9.1`)).rowCount).toBe(0);
    for (const tbl of ['devices', 'customers', 'device_costs', 'tracking_attempts', 'quote_decisions']) {
      await expect(as(null, `select * from ${tbl}`)).rejects.toThrow(/permission denied/);
    }
  });

  it('حد المحاولات: بعد 5 تخمينات مختلفة لنفس رقم الطلب بيقفل، حتى بالبيانات الصح', async () => {
    const victim = randomUUID();
    const r = await as<{ order_no: string }>(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A78', 'x') returning order_no`, [victim, customer]);
    const o = r.rows[0].order_no;
    // رقم الطلب مش فريد بين المحلات، فممكن يكون عليه تخمينات من تشغيلات قبل كده: بنكمّل لحد 5 مختلفين
    const seen = new Set((await admin(`select distinct guess from tracking_attempts where order_no = $1 and not success and guess is not null and created_at > now() - interval '15 minutes'`, [o])).rows.map((x) => x.guess));
    for (let v = 1000; seen.size < 5; v++) {
      const h = (await admin(`select tracking_guess($1, $2) as h`, [o, String(v)])).rows[0].h;
      if (seen.has(h)) continue;
      expect((await as(null, `select * from get_tracking($1, $2)`, [o, String(v)], `${NET}.1.${v % 250}`)).rowCount).toBe(0);
      seen.add(h);
    }
    await expect(as(null, `select * from get_tracking($1, '6789')`, [o], `${NET}.1.251`)).rejects.toThrow(/E_RATE_LIMIT/);
    // التخمين نفسه ما بيتخزنش، بيتخزن hash بس
    const stored = await admin(`select guess from tracking_attempts where order_no = $1 and guess is not null limit 1`, [o]);
    expect(stored.rows[0].guess).toMatch(/^[0-9a-f]{64}$/);
  });

  it('حد المحاولات: تكرار نفس الغلطة ما بيقفلش رقم الطلب (عشان عميل محل تاني بنفس الرقم ما يتأثرش)', async () => {
    const x = randomUUID();
    const r = await as<{ order_no: string }>(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A16', 'x') returning order_no`, [x, customer]);
    const o = r.rows[0].order_no;
    const wrong = '1234'; // ثابت عشان التشغيلات المتكررة تبقى نفس الغلطة
    for (let i = 0; i < 8; i++) await as(null, `select * from get_tracking($1, $2)`, [o, wrong], `${NET}.5.${i}`);
    expect((await as(null, `select order_no from get_tracking($1, '6789')`, [o], `${NET}.5.99`)).rows[0].order_no).toBe(o);
  });

  it('حد المحاولات: بعد 10 محاولات غلط من نفس الجهاز بيقفل', async () => {
    const ip = `${NET}.2.2`;
    for (let i = 0; i < 10; i++) await as(null, `select * from get_tracking($1, '1111')`, [`2099-${String(i).padStart(4, '0')}`], ip);
    await expect(as(null, `select * from get_tracking(p_token => $1)`, [token], ip)).rejects.toThrow(/E_RATE_LIMIT/);
    // جهاز تاني لسه يقدر
    expect((await as(null, `select order_no from get_tracking(p_token => $1)`, [token], `${NET}.2.3`)).rowCount).toBe(1);
  });

  it('الموافقة على التكلفة: مسموحة بس وهو مستني موافقة، وبتنقله لجاري الصيانة وبتتسجل', async () => {
    await expect(as(null, `select decide_quote('approved', p_token => $1)`, [token], `${NET}.3.1`)).rejects.toThrow(/E_BAD_TRANSITION/);
    await as(owner, `update devices set status = 'awaiting_approval' where id = $1`, [dev]);
    let r = await as(null, `select can_decide from get_tracking(p_token => $1)`, [token], `${NET}.3.1`);
    expect(r.rows[0].can_decide).toBe(true);
    const s = await as(null, `select decide_quote('approved', p_token => $1) as s`, [token], `${NET}.3.1`);
    expect(s.rows[0].s).toBe('in_repair');
    r = await as(null, `select can_decide, decision, status from get_tracking(p_token => $1)`, [token], `${NET}.3.1`);
    expect(r.rows[0]).toEqual({ can_decide: false, decision: 'approved', status: 'in_repair' });
    const q = await as(owner, `select decision, amount from quote_decisions where device_id = $1`, [dev]);
    expect(q.rows[0]).toEqual({ decision: 'approved', amount: 160000 });
    const log = await as(owner, `select old_status::text, new_status::text, changed_by from status_log where device_id = $1 order by created_at desc limit 1`, [dev]);
    expect(log.rows[0]).toEqual({ old_status: 'awaiting_approval', new_status: 'in_repair', changed_by: null });
    // مرة واحدة بس
    await expect(as(null, `select decide_quote('rejected', p_token => $1)`, [token], `${NET}.3.1`)).rejects.toThrow(/E_BAD_TRANSITION/);
    await expect(as(owner, `update quote_decisions set decision = 'rejected'`)).rejects.toThrow();
  });

  it('الرفض بينقل الجهاز لـ "لم يُصلَّح"', async () => {
    const x = randomUUID();
    const r = await as<{ tracking_token: string }>(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Vivo', 'Y36', 'x') returning tracking_token`, [x, customer]);
    await as(owner, `update devices set status = 'inspecting' where id = $1`, [x]);
    await as(owner, `update devices set status = 'awaiting_approval' where id = $1`, [x]);
    const s = await as(null, `select decide_quote('rejected', p_token => $1) as s`, [r.rows[0].tracking_token], `${NET}.4.1`);
    expect(s.rows[0].s).toBe('unrepairable');
  });

  it('الضمان: بيتحسب عند التسليم من مدة ضمان المحل', async () => {
    await as(owner, `update shops set warranty_days = 45`);
    for (const st of ['repaired', 'ready']) await as(owner, `update devices set status = $2 where id = $1`, [dev, st]);
    await as(owner, `update device_costs set final_cost = 160000 where device_id = $1`, [dev]);
    await as(owner, `select record_payment($1, $2, (select id from accounts where code = 'cash_cash'), 160000, $3)`, [randomUUID(), customer, dev]);
    await as(owner, `update devices set status = 'delivered' where id = $1`, [dev]);
    const r = await as(owner, `select warranty_days, extract(day from warranty_until - delivered_at)::int as days from devices where id = $1`, [dev]);
    expect(r.rows[0]).toEqual({ warranty_days: 45, days: 45 });
  });

  it('القوالب: صاحب المحل بس يعدّلها، والرسايل والفحص معزولين بين المحلات', async () => {
    await as(owner, `insert into message_templates(shop_id, key, body) values (gen_random_uuid(), 'ready', 'جهازك جاهز {order}')`);
    await expect(as(tech, `insert into message_templates(shop_id, key, body) values (gen_random_uuid(), 'status', 'x')`)).rejects.toThrow();
    expect((await as(other, `select * from message_templates`)).rowCount).toBe(0);
    await as(owner, `insert into message_log(shop_id, device_id, customer_id, template_key, body) values (gen_random_uuid(), $1, $2, 'ready', 'x')`, [dev, customer]);
    expect((await as(tech, `select * from message_log`)).rowCount).toBe(0); // الفني ما يشوفش رسايل العملاء
    expect((await as(other, `select * from message_log`)).rowCount).toBe(0);
    await as(tech, `insert into device_checks(shop_id, device_id, stage, items) values (gen_random_uuid(), $1, 'intake', '{"wifi":"ok","camera":"fail"}')`, [dev]);
    const c = await as(owner, `select checked_by, items->>'camera' as cam from device_checks where device_id = $1`, [dev]);
    expect(c.rows[0]).toEqual({ checked_by: tech, cam: 'fail' });
    expect((await as(other, `select * from device_checks`)).rowCount).toBe(0);
    await expect(as(other, `insert into device_checks(shop_id, device_id, stage, items) values (gen_random_uuid(), $1, 'delivery', '{}')`, [dev])).rejects.toThrow(/E_CROSS_SHOP/);
  });

  it('الزائر (anon) ملوش أي صلاحية على أي جدول أو عرض في قاعدة البيانات كلها', async () => {
    const r = await admin(`select table_name, privilege_type from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public'`);
    expect(r.rows).toEqual([]);
    const f = await admin(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute') and p.prokind = 'f'
      and p.proname not in ('get_tracking', 'decide_quote') and p.prorettype <> 'trigger'::regtype`);
    // الدوال المساعدة (اللي بترجّع قيم بس من غير ما تكشف بيانات) مسموحة؛ المهم إن مفيش دالة بتغيّر أو بتقرا بيانات المحلات
    const risky = f.rows.map((x) => x.proname).filter((n) => /bootstrap|passcode|pending_invite|tracking_find|tracking_guard/.test(n));
    expect(risky).toEqual([]);
  });

  it('محاولة تعديل من غير مستخدم برّه الدوال الموثوقة مرفوضة', async () => {
    await expect(as(null, `update devices set status = 'ready' where id = $1`, [dev])).rejects.toThrow(/permission denied/);
    void shop;
  });
});
