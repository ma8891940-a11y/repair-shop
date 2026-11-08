// البند 3: المخزون قسم مستقل بحساباته. كل رقم هنا متحسب باليد
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

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
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();

d('المخزون بحساباته: هالك، ومرتجع مورد، ومرتجع عميل، وقطعة يدوية، وحركة صنف، وربح المخزون', () => {
  let O = '';
  let R = '';
  let T = '';
  const acc: Record<string, string> = {};
  let sup = '';
  let cust = '';
  let dev = '';
  let glass = '';
  let cover = '';
  const bal = async (code: string, party?: string) =>
    Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1 and ($2::uuid is null or party_id = $2)`, [acc[code], party ?? null])).rows[0].b);
  const stock = async (item: string) => (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1`, [item])).rows[0];
  const clean = async () => expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`inv-o-${tag}@i.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل المخزون')`);
    for (const role of ['reception', 'technician'] as const) {
      const em = `inv-${role}-${tag}@i.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد القطع')`, [sup]);
    cust = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [cust, `0105${String(Date.now()).slice(-7)}`]);
    dev = id();
    await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Honor', 'X8', 'شاشة')`, [dev, cust]);
    glass = id();
    cover = id();
    await as(O, `insert into items(id, shop_id, kind, name, category, barcode) values ($1, gen_random_uuid(), 'part', 'شاشة X8', 'شاشات', '2000000000017')`, [glass]);
    await as(O, `insert into items(id, shop_id, kind, name, category) values ($1, gen_random_uuid(), 'accessory', 'جراب', 'جرابات')`, [cover]);
    // شراء آجل: 4 شاشات × 300 ج، و10 جرابات × 20 ج
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: glass, qty: 4, unit_cost: 30000 }, { item: cover, qty: 10, unit_cost: 2000 }])]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الهالك: شاشة اتكسرت ← المخزون 3 بـ 900 ج، ومصروف الهالك 300 ج، والسبب إجباري، وللمالك بس', async () => {
    await expect(as(O, `select write_off($1, $2, 1, ' ')`, [id(), glass])).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(as(R, `select write_off($1, $2, 1, 'كسر')`, [id(), glass])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O, `select write_off($1, $2, 99, 'كسر')`, [id(), glass])).rejects.toThrow(/E_STOCK/);
    await as(O, `select write_off($1, $2, 1, 'اتكسرت وهي بتتركب')`, [id(), glass]);
    expect(await stock(glass)).toEqual({ q: 3, v: 90000 });
    expect(await bal('wastage')).toBe(30000);
    await clean();
  });

  it('مرتجع للمورد: شاشة بـ 300 والمورد خصم 250 بس ← المورد 1450 بدل 1700، والفرق 50 تكلفة', async () => {
    const cogs0 = await bal('cogs');
    expect(await bal('ap', sup)).toBe(-140000);
    await as(O, `select supplier_return($1, $2, $3, 1, 25000, null, 'عيب صناعة')`, [id(), sup, glass]);
    expect(await stock(glass)).toEqual({ q: 2, v: 60000 });
    expect(await bal('ap', sup)).toBe(-115000);
    expect(await bal('cogs')).toBe(cogs0 + 5000);
    // ومرتجع بكاش: المورد رجّع 25 ج كاش لجراب تكلفته 20 ← مكسب 5 ج بيقلل التكلفة
    const cash0 = await bal('cash_cash');
    await as(O, `select supplier_return($1, $2, $3, 1, 2500, $4, 'لون غلط')`, [id(), sup, cover, acc.cash_cash]);
    expect(await bal('cash_cash')).toBe(cash0 + 2500);
    expect(await bal('cogs')).toBe(cogs0 + 5000 - 500);
    expect(await stock(cover)).toEqual({ q: 9, v: 18000 });
    await clean();
  });

  it('بيع ثم مرتجع من العميل: السليم بيرجع المخزون بتكلفته، والبايظ بيتسجل هالك، والإيراد بيقل', async () => {
    await as(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: cover, qty: 3, price: 5000 }]), acc.cash_cash]);
    expect(await stock(cover)).toEqual({ q: 6, v: 12000 });
    const rev0 = await bal('rev_accessories');
    const cash0 = await bal('cash_cash');
    await expect(as(R, `select sale_return($1, $2, 1, 5000, $3, null, true, '')`, [id(), cover, acc.cash_cash])).rejects.toThrow(/E_REASON_REQUIRED/);
    await as(R, `select sale_return($1, $2, 1, 5000, $3, null, true, 'العميل غيّر رأيه')`, [id(), cover, acc.cash_cash]);
    expect(await stock(cover)).toEqual({ q: 7, v: 14000 });
    expect(await bal('rev_accessories')).toBe(rev0 + 5000); // الإيراد دائن، فالمرتجع بيقرّبه للصفر
    expect(await bal('cash_cash')).toBe(cash0 - 5000);
    // البايظ: رصيد للعميل (من غير خزنة)، وما بيرجعش المخزون
    await as(R, `select sale_return($1, $2, 1, 4000, null, $3, false, 'مقطوع')`, [id(), cover, cust]);
    expect(await stock(cover)).toEqual({ q: 7, v: 14000 });
    expect(await bal('ar', cust)).toBe(-4000);
    await clean();
  });

  it('ربط المخزون بالصيانة مقفول: قطعة يدوية بتكلفتها على الجهاز من غير ما المخزون يتأثر، والفني ما يسجلش تكلفة', async () => {
    const st0 = await stock(glass);
    await expect(as(T, `select device_manual_part($1, $2, 'فلاتة', 15000, $3)`, [id(), dev, acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select device_manual_part($1, $2, 'فلاتة', 15000)`, [id(), dev])).rejects.toThrow(/E_BAD_INPUT/);
    await as(R, `select device_manual_part($1, $2, 'فلاتة شحن', 15000, $3)`, [id(), dev, acc.cash_cash]);
    await as(O, `select device_manual_part($1, $2, 'سماعة', 8000, null, $3)`, [id(), dev, sup]);
    expect(await stock(glass)).toEqual(st0);
    const m = (await as(O, `select device_money($1) m`, [dev])).rows[0].m;
    expect(Number(m.parts_cost)).toBe(23000);
    expect(await bal('ap', sup)).toBe(-115000 - 8000);
    await clean();
  });

  it('حركة الصنف بالترتيب والرصيد بعد كل حركة، وربح المخزون للفترة = المبيعات - التكلفة - الهالك - فرق المرتجعات', async () => {
    const mv = (await as(O, `select * from item_moves($1)`, [cover])).rows;
    expect(mv.map((r) => r.source_type)).toEqual(['purchase', 'supplier_return', 'sale', 'sale_return']);
    expect(mv.map((r) => Number(r.balance_qty))).toEqual([10, 9, 6, 7]);
    expect(Number(mv.at(-1).balance_value)).toBe(14000);
    await expect(as(R, `select * from item_moves($1)`, [cover])).rejects.toThrow(/E_FORBIDDEN/);
    const s = (await as(O, `select inventory_summary($1, $2) s`, [FROM(), TO()])).rows[0].s;
    // المبيعات: 3×50 = 150 - مرتجع 50 - مرتجع 40 = 60 ج. التكلفة: 3×20 = 60 - 20 (رجع المخزون) = 40 ج
    expect(Number(s.sales)).toBe(6000);
    expect(Number(s.sales_cost)).toBe(4000);
    expect(Number(s.wastage)).toBe(30000);
    expect(Number(s.return_diff)).toBe(5000 - 500);
    expect(Number(s.profit)).toBe(6000 - 4000 - 30000 - 4500);
    expect(Number(s.stock_value)).toBe(60000 + 14000);
    expect(Number(s.parts_used)).toBe(23000);
    // الباركود ما يتكررش في نفس المحل
    await expect(as(O, `insert into items(id, shop_id, kind, name, barcode) values ($1, gen_random_uuid(), 'part', 'تاني', '2000000000017')`, [id()])).rejects.toThrow(/items_barcode_unique|duplicate/);
    const row = (await as(T, `select * from items_stock() where id = $1`, [glass])).rows[0];
    expect(row).toMatchObject({ category: 'شاشات', barcode: '2000000000017', sale_price: null, avg_cost: null, value: null });
  });

  it('إلغاء أي عملية مخزون بقيد عكسي بيرجّع كل حاجة زي ما كانت', async () => {
    const e = (await as(O, `select write_off($1, $2, 2, 'جرد') e`, [id(), cover])).rows[0].e;
    expect(await stock(cover)).toEqual({ q: 5, v: 10000 });
    await as(O, `select reverse_entry($1, 'الجرد كان غلط')`, [e]);
    expect(await stock(cover)).toEqual({ q: 7, v: 14000 });
    await clean();
  });
});
