// استكمال المراحل 1-3 حسب docs/spec.pdf (migration 0012)
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
async function as(uid: string | null, sql: string, params: unknown[] = [], ip = '10.77.0.1') {
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
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const tag = randomUUID().slice(0, 8);
const PHONE = `0109${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
const id = () => randomUUID();
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@s.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}

let owner = '';
let rec = '';
let tech = '';
let cash = '';
let cust = '';
let dev = '';
let token = '';
let order = '';
let sup1 = '';
let sup2 = '';
let part = '';

d('استكمال المواصفات', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`spec-o-${tag}@s.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل المواصفات')`);
    rec = await staff(owner, 'استقبال', 'reception');
    tech = await staff(owner, 'فني', 'technician');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    [cust, dev, sup1, sup2, part] = [id(), id(), id(), id(), id()];
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل المواصفات', $2)`, [cust, PHONE]);
    const r = await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'شاشة مكسورة وبطارية') returning order_no, tracking_token`, [dev, cust]);
    order = r.rows[0].order_no;
    token = r.rows[0].tracking_token;
    await as(owner, `insert into device_costs(id, shop_id, device_id) values ($1, gen_random_uuid(), $2)`, [id(), dev]);
    await as(owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد أ'), ($2, gen_random_uuid(), 'مورد ب')`, [sup1, sup2]);
    await as(owner, `insert into items(id, shop_id, kind, name, min_qty) values ($1, gen_random_uuid(), 'part', 'شاشة A54', 2)`, [part]);
    await as(owner, `select owner_capital($1, $2, 1000000)`, [id(), cash]);
  });
  afterAll(async () => db?.end());

  it('كل قطعة بمصدرها حتى في الشراء النقدي، ومقارنة أسعار الموردين لصاحب المحل بس', async () => {
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup1, JSON.stringify([{ item: part, qty: 2, unit_cost: 30000 }]), cash]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup2, JSON.stringify([{ item: part, qty: 1, unit_cost: 27000 }])]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup1, JSON.stringify([{ item: part, qty: 1, unit_cost: 28000 }]), cash]);
    const r = (await as(owner, `select supplier, last_cost, min_cost, total_qty from item_suppliers($1)`, [part])).rows;
    expect(r).toEqual([
      { supplier: 'مورد ب', last_cost: '27000', min_cost: '27000', total_qty: '1' },
      { supplier: 'مورد أ', last_cost: '28000', min_cost: '28000', total_qty: '3' },
    ]);
    const p = (await as(owner, `select on_credit from purchases order by created_at`)).rows.map((x) => x.on_credit);
    expect(p).toEqual([false, true, false]);
    await expect(as(rec, `select * from item_suppliers($1)`, [part])).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(rec, `select * from purchases`)).rowCount).toBe(0);
  });

  it('الحد الأدنى: الصنف بيدخل النواقص لما الكمية توصل للحد', async () => {
    const q = async () => (await as(owner, `select qty, short from items_stock() where id = $1`, [part])).rows[0];
    expect(await q()).toEqual({ qty: '4', short: false });
    await as(tech, `select use_part($1, $2, $3, 2)`, [id(), dev, part]);
    expect(await q()).toEqual({ qty: '2', short: true });
  });

  it('القطع المستبدلة بتظهر للفاتورة من غير أي تكلفة، والسعر المقترح من الإعدادات', async () => {
    const parts = (await as(rec, `select * from device_parts($1)`, [dev])).rows;
    expect(parts).toEqual([{ item_id: part, name: 'شاشة A54', qty: '2' }]);
    // أجرة الشاشة 150 والبطارية 50، والهامش 20% على القطع
    await as(owner, `insert into labor_rates(id, shop_id, issue, amount) values ($1, gen_random_uuid(), 'شاشة', 15000), ($2, gen_random_uuid(), 'بطارية', 5000), ($3, gen_random_uuid(), 'سوفت', 9000)`, [id(), id(), id()]);
    // تكلفة القطعتين بالمتوسط المرجّح: (60000 + 27000 + 28000) / 4 × 2 = 57500
    const o = (await as(owner, `select suggest_device_price($1) as s`, [dev])).rows[0].s;
    expect(o).toEqual({ parts: 57500, labor: 20000, margin: 20, markup: 11500, price: 89000 });
    const r = (await as(rec, `select suggest_device_price($1) as s`, [dev])).rows[0].s;
    expect(r).toEqual({ price: 89000, labor: 20000 }); // من غير تكلفة القطع
    await expect(as(tech, `select suggest_device_price($1)`, [dev])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(rec, `insert into labor_rates(id, shop_id, issue, amount) values ($1, gen_random_uuid(), 'x', 1)`, [id()])).rejects.toThrow();
    expect((await as(tech, `select * from labor_rates`)).rowCount).toBe(0);
  });

  it('صفحة التتبع بتعرض المتبقي بعد الدفعات', async () => {
    await as(owner, `update device_costs set final_cost = 89000 where device_id = $1`, [dev]);
    await as(rec, `select record_payment($1, $2, $3, 30000, $4)`, [id(), cust, cash, dev]);
    const t = (await as(null, `select due, final_cost from get_tracking(p_token => $1)`, [token])).rows[0];
    expect(t).toEqual({ due: '59000', final_cost: 89000 });
    const t2 = (await as(null, `select order_no, due from get_tracking($1, $2)`, [order, PHONE.slice(-4)], '10.77.9.9')).rows[0];
    expect(t2).toEqual({ order_no: order, due: '59000' });
  });

  it('التسليم بالآجل بيتسجل في السجل باسم صاحب المحل والمبلغ المتبقي', async () => {
    for (const s of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(tech, `update devices set status = $2 where id = $1`, [dev, s]);
    await as(owner, `select deliver_on_credit($1)`, [dev]);
    const a = (await admin(`select actor_id, after ->> 'due' as due from audit_log where action = 'deliver_on_credit' and entity_id = $1`, [dev])).rows[0];
    expect(a).toEqual({ actor_id: owner, due: '59000' });
  });

  it('المدينين بأقدم دين: السداد بيقفل الأقدم الأول', async () => {
    // دين التسليم 590 (بعد الدفعة)، وبعدين بيع آجل 100، ودفعة 600 بتقفل الأول كله وجزء من التاني
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup1, JSON.stringify([{ item: part, qty: 3, unit_cost: 20000 }]), cash]);
    const sale = (await as(owner, `select record_sale($1, $2::jsonb, null, $3) as e`, [id(), JSON.stringify([{ item: part, qty: 1, price: 10000 }]), cust])).rows[0].e;
    let r = (await as(owner, `select balance, oldest from party_balances('customers') where party_id = $1`, [cust])).rows[0];
    const delivery = (await admin(`select occurred_at from journal_entries where source_type = 'delivery' and source_id = $1`, [dev])).rows[0].occurred_at;
    expect(r.balance).toBe('69000');
    expect(r.oldest).toEqual(delivery);
    await as(rec, `select record_payment($1, $2, $3, 60000)`, [id(), cust, cash]);
    r = (await as(owner, `select balance, oldest from party_balances('customers') where party_id = $1`, [cust])).rows[0];
    const saleAt = (await admin(`select occurred_at from journal_entries where id = $1`, [sale])).rows[0].occurred_at;
    expect(r.balance).toBe('9000');
    expect(r.oldest).toEqual(saleAt);
  });

  it('توقيع العميل: صورة PNG بس وبحجم محدود', async () => {
    const x = id();
    await expect(as(rec, `insert into devices(id, customer_id, brand, model, issue, intake_signature) values ($1, $2, 'a', 'b', 'c', 'javascript:alert(1)')`, [x, cust])).rejects.toThrow(/check/);
    await as(rec, `insert into devices(id, customer_id, brand, model, issue, intake_signature) values ($1, $2, 'a', 'b', 'c', 'data:image/png;base64,iVBORw0KGgo=')`, [x, cust]);
    expect((await as(rec, `select intake_signature from devices where id = $1`, [x])).rows[0].intake_signature).toMatch(/^data:image\/png/);
  });
});
