// البند 7: القوائم اللي بيديرها صاحب المحل، والحالات الفرعية
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

// كل اللي الملف ده بيعمله في قاعدة الاختبار بيتمسح في الآخر
cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);

d('القوائم والحالات الفرعية', () => {
  let O = '';
  let R = '';
  let T = '';
  let O2 = '';
  let dev = '';
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ls-o-${tag}@l.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل القوائم')`);
    for (const role of ['reception', 'technician'] as const) {
      const em = `ls-${role}-${tag}@l.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    O2 = await user(`ls-o2-${tag}@l.test`);
    await as(O2, `select bootstrap_account('تاني', 'محل تاني')`);
    const cust = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [cust, `0106${String(Date.now()).slice(-7)}`]);
    dev = id();
    await as(R, `insert into devices(id, customer_id, brand, model, issue, accessories) values ($1, $2, 'Nothing', 'Phone 2', 'شاشة', '{"شاحن أصلي"}')`, [dev, cust]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('صاحب المحل بس اللي بيضيف، والكل بيشوف، ومفيش تكرار، والمحل التاني ما يشوفش', async () => {
    await as(O, `insert into shop_lists(id, shop_id, list, value, sort) values ($1, gen_random_uuid(), 'brands', 'Nothing', 1)`, [id()]);
    await expect(as(O, `insert into shop_lists(id, shop_id, list, value) values ($1, gen_random_uuid(), 'brands', ' nothing ')`, [id()])).rejects.toThrow(/shop_lists_unique|duplicate/);
    await expect(as(R, `insert into shop_lists(id, shop_id, list, value) values ($1, gen_random_uuid(), 'brands', 'Nokia')`, [id()])).rejects.toThrow();
    expect((await as(R, `select value from shop_lists where list = 'brands'`)).rows.map((r) => r.value)).toEqual(['Nothing']);
    expect((await as(T, `select value from shop_lists where list = 'brands'`)).rowCount).toBe(1);
    expect((await as(O2, `select * from shop_lists`)).rowCount).toBe(0);
    // الحالة الفرعية لازم يبقى ليها حالة أساسية صح
    await expect(as(O, `insert into shop_lists(id, shop_id, list, value) values ($1, gen_random_uuid(), 'sub_statuses', 'اتطلبت')`, [id()])).rejects.toThrow();
    await expect(as(O, `insert into shop_lists(id, shop_id, list, value, parent) values ($1, gen_random_uuid(), 'sub_statuses', 'اتطلبت', 'flying')`, [id()])).rejects.toThrow();
  });

  it('حذف بند من القايمة بيخفيه من الاختيار بس: الأجهزة القديمة زي ما هي، وينفع يتضاف تاني', async () => {
    const b = (await as(O, `select id from shop_lists where list = 'brands' and value = 'Nothing'`)).rows[0].id;
    await as(O, `update shop_lists set deleted_at = now() where id = $1`, [b]);
    expect((await as(R, `select value from shop_lists where list = 'brands' and deleted_at is null`)).rowCount).toBe(0);
    const dv = (await as(R, `select brand, accessories from devices where id = $1`, [dev])).rows[0];
    expect(dv).toEqual({ brand: 'Nothing', accessories: ['شاحن أصلي'] });
    await as(O, `insert into shop_lists(id, shop_id, list, value) values ($1, gen_random_uuid(), 'brands', 'Nothing')`, [id()]);
    await expect(admin(`delete from shop_lists where id = $1`, [b])).rejects.toThrow();
  });

  it('الحالة الفرعية: الفني بيغيّرها (والحالة بس، مش أي حاجة تانية)، ولما الحالة الأساسية تتغير بتتشال', async () => {
    await as(O, `insert into shop_lists(id, shop_id, list, value, parent) values ($1, gen_random_uuid(), 'sub_statuses', 'اتطلبت من المورد', 'awaiting_part')`, [id()]);
    await as(T, `update devices set status = 'inspecting' where id = $1`, [dev]);
    await as(T, `update devices set status = 'awaiting_part' where id = $1`, [dev]);
    await as(T, `update devices set sub_status = 'اتطلبت من المورد' where id = $1`, [dev]);
    expect((await admin(`select sub_status from devices where id = $1`, [dev])).rows[0].sub_status).toBe('اتطلبت من المورد');
    await expect(as(T, `update devices set issue = 'تغيير' where id = $1`, [dev])).rejects.toThrow(/E_TECH_STATUS_ONLY/);
    await as(T, `update devices set status = 'in_repair' where id = $1`, [dev]);
    expect((await admin(`select status, sub_status from devices where id = $1`, [dev])).rows[0]).toEqual({ status: 'in_repair', sub_status: null });
    // السجل بيحفظ التغيير
    expect(Number((await admin(`select count(*) n from audit_log where entity = 'devices' and entity_id = $1 and after->>'sub_status' = 'اتطلبت من المورد'`, [dev])).rows[0].n)).toBeGreaterThanOrEqual(1);
  });
});
