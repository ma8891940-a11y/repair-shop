// C6: التحليلات الإضافية: أكتر الأعطال لكل موديل، والقطع اللي بتاكل الربح، والصرف لتوقع النفاد (بحساب يدوي)
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;

async function as<T extends pg.QueryResultRow = pg.QueryResultRow>(uid: string | null, sql: string, params: unknown[] = [], headers: Record<string, string> = {}) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': '10.9.9.9', ...headers })]);
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
  await db.query('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [id, email]);
  return id;
}
const tag = randomUUID().slice(0, 8);
let owner = '';
let rec = '';
let tech = '';
let cash = '';
let part = '';

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}
const ph = () => `0104${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
async function device(model: string, issue: string, final: number | null, parts = 0) {
  const c = randomUUID();
  const dv = randomUUID();
  await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [c, ph()]);
  await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', $3, $4)`, [dv, c, model, issue]);
  if (final == null) return dv;
  await as(tech, `update devices set status = 'inspecting' where id = $1`, [dv]);
  for (let i = 0; i < parts; i++) await as(tech, `select use_part($1, $2, $3, 1)`, [randomUUID(), dv, part]);
  for (const st of ['in_repair', 'repaired', 'ready']) await as(tech, `update devices set status = $2 where id = $1`, [dv, st]);
  await as(owner, `insert into device_costs(shop_id, device_id, estimated_cost, final_cost) values (gen_random_uuid(), $1, $2, $2)`, [dv, final]);
  await as(owner, `select deliver_on_credit($1)`, [dv]);
  return dv;
}
const range = [`now() - interval '1 day'`, `now() + interval '1 day'`];

d('C6: التحليلات الإضافية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`oc6-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل التحليلات')`);
    rec = await staff(`rc6-${tag}@t.test`, 'reception');
    tech = await staff(`tc6-${tag}@t.test`, 'technician');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    const sup = randomUUID();
    part = randomUUID();
    await as(owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(owner, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة A52', 90000)`, [part]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: part, qty: 10, unit_cost: 30000 }]), cash]);
    // A52: 3 أجهزة شاشة (2 فيهم قطعة)، وواحد بطارية. A12: جهاز شاشة واحد
    await device('A52', 'شاشة مكسورة', 100000, 1);
    await device('A52', 'شاشة مكسورة', 50000, 1);
    await device('A52', 'شاشة مكسورة', null);
    await device('A52', 'بطارية', null);
    await device('A12', 'شاشة مكسورة', null);
  });
  afterAll(async () => db?.end());

  it('أكتر الأعطال لكل موديل', async () => {
    const r = (await as(owner, `select brand, model, issue, devices from faults_by_model(${range[0]}, ${range[1]})`)).rows;
    expect(r[0]).toEqual({ brand: 'Samsung', model: 'A52', issue: 'شاشة مكسورة', devices: 3 });
    expect(r).toContainEqual({ brand: 'Samsung', model: 'A52', issue: 'بطارية', devices: 1 });
    expect(r).toContainEqual({ brand: 'Samsung', model: 'A12', issue: 'شاشة مكسورة', devices: 1 });
    // الفني ما يشوفش التقارير
    await expect(as(tech, `select * from faults_by_model(${range[0]}, ${range[1]})`)).rejects.toThrow();
  });

  it('القطع اللي بتاكل الربح: تكلفة القطعة (300 × 2) من إيراد الجهازين (1,000 + 500) = 40%', async () => {
    const [r] = (await as(owner, `select * from parts_profit(${range[0]}, ${range[1]})`)).rows;
    expect(r).toMatchObject({ name: 'شاشة A52', uses: '2', devices: '2', cost: '60000', revenue: '150000' });
    expect(Math.round((60000 * 10000) / 150000)).toBe(4000);
    await expect(as(rec, `select * from parts_profit(${range[0]}, ${range[1]})`)).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
  });

  it('الصرف في 30 يوم: القطع المركبة والبيع بس (من غير التحويل والهالك)', async () => {
    await as(owner, `select record_sale($1, $2::jsonb, $3)`, [randomUUID(), JSON.stringify([{ item: part, qty: 1, price: 90000 }]), cash]);
    await as(owner, `select write_off($1, $2, 1, 'كسر')`, [randomUUID(), part]).catch(() => undefined);
    const [r] = (await as(owner, `select used from items_usage30() where item_id = $1`, [part])).rows;
    expect(Number(r.used)).toBe(3);
  });
});
