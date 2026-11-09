// البند 4: جرد المحل أول مرة والأرصدة الافتتاحية. كل رقم متحسب باليد
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
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();

d('الأرصدة الافتتاحية: قيود متوازنة قصاد رأس المال', () => {
  let O = '';
  let R = '';
  let S = '';
  const acc: Record<string, string> = {};
  const it1 = id();
  const it2 = id();
  const c1 = id();
  const c2 = id();
  const s1 = id();
  const s2 = id();
  const sum = async () => (await as(O, `select opening_summary() s`)).rows[0].s;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`op-o-${tag}@o.test`);
    S = (await as(O, `select (bootstrap_account('صاحب', 'محل الافتتاح')).shop_id s`)).rows[0].s;
    const em = `op-r-${tag}@o.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة'), ($2, gen_random_uuid(), 'accessory', 'شاحن')`, [it1, it2]);
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل مديون', $3), ($2, gen_random_uuid(), 'عميل دافع عربون', $4)`, [c1, c2, `0101${String(Date.now()).slice(-7)}`, `0102${String(Date.now()).slice(-7)}`]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد ليه'), ($2, gen_random_uuid(), 'مورد عليه')`, [s1, s2]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('مخزون + خزن + ديون عملاء وموردين بالاتجاهين ← رأس المال = الأصول - الالتزامات، والدفتر متوازن', async () => {
    // المخزون: 5 شاشات × 100 ج + 3 شواحن × 250 ج = 1250 ج
    await as(O, `select opening_balance($1, 'stock', null, null, $2::jsonb)`, [id(), JSON.stringify([{ item: it1, qty: 5, unit_cost: 10000 }, { item: it2, qty: 3, unit_cost: 25000 }])]);
    await as(O, `select opening_balance($1, 'cash', $2, 200000)`, [id(), acc.cash_cash]);
    await as(O, `select opening_balance($1, 'customer', $2, 30000)`, [id(), c1]);
    await as(O, `select opening_balance($1, 'customer', $2, -5000)`, [id(), c2]);
    await as(O, `select opening_balance($1, 'supplier', $2, 40000)`, [id(), s1]);
    await as(O, `select opening_balance($1, 'supplier', $2, -2000)`, [id(), s2]);
    const s = await sum();
    expect(s).toMatchObject({ stock: 125000, stock_items: 2, cash: 200000, receivables: 25000, payables: 38000, entries: 6, balanced: true, done: false });
    // 1250 + 2000 + 300 - 50 - 400 + 20 = 3120 ج
    expect(Number(s.capital)).toBe(312000);
    const p = (await as(O, `select financial_position($1, $2) p`, [FROM(), TO()])).rows[0].p;
    expect(p.balanced).toBe(true);
    expect(Number(p.net_worth)).toBe(312000);
    expect(Number(p.inventory)).toBe(125000);
    expect(Number(p.cash)).toBe(200000);
    // الأرصدة الافتتاحية ما بتعملش ربح ولا خسارة
    expect(Number(p.profit)).toBe(0);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
    // المخزون بالمتوسط: الشاشة بـ 100
    const st = (await as(O, `select qty, avg_cost from items_stock() where id = $1`, [it1])).rows[0];
    expect([Number(st.qty), Number(st.avg_cost)]).toEqual([5, 10000]);
    // كشف العميل والمورد بيبدأ بالرصيد الافتتاحي
    const bal = (await as(O, `select party_id, balance from party_balances('customers')`)).rows;
    expect(Number(bal.find((b) => b.party_id === c1).balance)).toBe(30000);
    expect(Number(bal.find((b) => b.party_id === c2).balance)).toBe(-5000);
  });

  it('نفس الرصيد مرتين (النت قطع ورجع) بيتسجل مرة واحدة، والتصحيح بقيد عكسي، والاستقبال ما يقدرش', async () => {
    const k = id();
    await as(O, `select opening_balance($1, 'cash', $2, 10000)`, [k, acc.cash_wallet]);
    await as(O, `select opening_balance($1, 'cash', $2, 10000)`, [k, acc.cash_wallet]);
    expect(Number((await sum()).cash)).toBe(210000);
    const e = (await admin(`select id from journal_entries where idem_key = $1`, [k])).rows[0].id;
    await as(O, `select reverse_entry($1, 'الرقم غلط')`, [e]);
    expect(Number((await sum()).cash)).toBe(200000);
    expect(Number((await sum()).capital)).toBe(312000);
    await expect(as(R, `select opening_balance($1, 'cash', $2, 10000)`, [id(), acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select opening_summary()`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O, `select opening_balance($1, 'cash', $2, -10)`, [id(), acc.cash_cash])).rejects.toThrow(/E_BAD_AMOUNT/);
    await expect(as(O, `select opening_balance($1, 'stock', null, null, '[]'::jsonb)`, [id()])).rejects.toThrow(/E_BAD_INPUT/);
    await expect(as(O, `select opening_balance($1, 'other', null, 5)`, [id()])).rejects.toThrow(/E_BAD_INPUT/);
    // "خلّص" بيتحفظ في المحل
    await as(O, `update shops set extras = extras || '{"opening_done": true}'::jsonb where id = $1`, [S]);
    expect((await sum()).done).toBe(true);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });
});
