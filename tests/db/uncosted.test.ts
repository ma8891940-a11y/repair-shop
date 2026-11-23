// البيع لصنف مالوش رصيد أو تكلفة، والتسوية التلقائية لما الكمية والتكلفة تتسجل. كل رقم متحسب باليد
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

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

d('البيع من غير رصيد والتسوية', () => {
  let O = '';
  let R = '';
  let shop = '';
  let sup = '';
  const acc: Record<string, string> = {};
  const bal = async (code: string) => Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1`, [acc[code]])).rows[0].b);
  const stock = async (item: string) => (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1`, [item])).rows[0];
  const pend = async (item: string) => Number((await as(O, `select unsettled from items_stock() where id = $1`, [item])).rows[0].unsettled);
  const clean = async () => expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  const sell = (uid: string, item: string, qty: number, price: number) => as(uid, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item, qty, price }]), acc.cash_cash]).then((r) => r.rows[0].e as string);
  const newItem = async (name: string) => {
    const it = id();
    await as(O, `insert into items(id, shop_id, kind, name, item_type, brand, model, quality, color) values ($1, gen_random_uuid(), 'part', $2, 'شاشة', 'Apple', 'iPhone 13 Pro', 'OLED', 'أسود')`, [it, name]);
    return it;
  };
  const allow = (on: boolean) => as(O, `update shops set extras = coalesce(extras, '{}'::jsonb) || jsonb_build_object('allow_negative_stock', $2::boolean) where id = $1`, [shop, on]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`un-o-${tag}@u.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل التسوية')).shop_id s`)).rows[0].s;
    const em = `un-r-${tag}@u.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الإعداد مقفول (الافتراضي): البيع من غير رصيد مرفوض، وتسجيل الكمية والتكلفة من نفس المكان وبعدين البيع', async () => {
    const it = await newItem('شاشة iPhone 13 Pro - OLED - أسود');
    await expect(sell(R, it, 1, 300000)).rejects.toThrow(/E_STOCK/);
    // بند 14 (0068): الاستقبال ما تقدرش تزوّد المخزون من شاشة البيع، والتسوية محتاجة سبب، وبتتسجل في سجل النشاط
    await expect(as(R, `select stock_in($1, $2, 2, 180000, 'جرد')`, [id(), it])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O, `select stock_in($1, $2, 2, 180000)`, [id(), it])).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(as(O, `select stock_in($1, $2, 2, 180000, '   ')`, [id(), it])).rejects.toThrow(/E_REASON_REQUIRED/);
    expect(await stock(it)).toEqual({ q: 0, v: 0 });
    const op = id();
    await as(O, `select stock_in($1, $2, 2, 180000, 'لقيت كرتونة في المخزن')`, [op, it]);
    await as(O, `select stock_in($1, $2, 2, 180000, 'لقيت كرتونة في المخزن')`, [op, it]); // نفس الطلب مرتين = مرة
    const log = (await admin(`select actor_id, after from audit_log where action = 'stock_adjust' and entity_id = $1`, [it])).rows;
    expect(log).toHaveLength(1);
    expect(log[0].actor_id).toBe(O);
    expect(log[0].after).toMatchObject({ qty: 2, unit_cost: 180000, value: 360000, reason: 'لقيت كرتونة في المخزن' });
    expect(await stock(it)).toEqual({ q: 2, v: 360000 });
    await sell(R, it, 1, 300000);
    expect(await stock(it)).toEqual({ q: 1, v: 180000 });
    await clean();
    // تفاصيل الصنف رجعت في المخزون
    expect((await as(O, `select item_type, brand, model, quality, color from items_stock() where id = $1`, [it])).rows[0]).toEqual({ item_type: 'شاشة', brand: 'Apple', model: 'iPhone 13 Pro', quality: 'OLED', color: 'أسود' });
  });

  it('مفتوح: البيع بيكمّل والصنف "محتاج تسوية"، ولما الكمية والتكلفة تيجي الحسابات بتتسوى لوحدها بقيد متوازن', async () => {
    await allow(true);
    const it = await newItem('بطارية');
    const rev0 = await bal('rev_parts');
    const cogs0 = await bal('cogs');
    // باع 2 بـ 100 والرصيد صفر
    await sell(R, it, 2, 10000);
    expect(await bal('rev_parts')).toBe(rev0 - 20000);
    expect(await bal('cogs')).toBe(cogs0); // التكلفة لسه مش معروفة
    expect(await stock(it)).toEqual({ q: -2, v: 0 });
    expect(await pend(it)).toBe(2);
    await clean();
    // اشترى 5 بـ 30: الاتنين اللي اتباعوا بياخدوا تكلفتهم (60)، والـ 3 الباقيين في المخزون بـ 90
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: it, qty: 5, unit_cost: 3000 }])]);
    expect(await stock(it)).toEqual({ q: 3, v: 9000 });
    expect(await bal('cogs')).toBe(cogs0 + 6000);
    expect(await pend(it)).toBe(0);
    await clean();
    expect((await admin(`select count(*)::int n from journal_entries where source_type = 'cost_adjust' and source_id = $1 and memo = 'تسوية بيع بدون رصيد'`, [it])).rows[0].n).toBe(1);
  });

  it('تسوية على مراحل: موجود 1 بـ 40 واتباع 3، وبعدين دخل 1 بـ 50 ← اتسوّى 1 وفاضل 1', async () => {
    const it = await newItem('سوكت شحن');
    await as(O, `select stock_in($1, $2, 1, 4000, 'رصيد')`, [id(), it]);
    const cogs0 = await bal('cogs');
    await sell(R, it, 3, 9000);
    expect(await bal('cogs')).toBe(cogs0 + 4000); // الواحدة اللي كانت موجودة بتكلفتها
    expect(await pend(it)).toBe(2);
    expect(await stock(it)).toEqual({ q: -2, v: 0 });
    await as(O, `select stock_in($1, $2, 1, 5000, 'رصيد')`, [id(), it]);
    expect(await pend(it)).toBe(1);
    expect(await bal('cogs')).toBe(cogs0 + 9000);
    expect(await stock(it)).toEqual({ q: -1, v: 0 });
    await clean();
  });

  it('عكس البيع: قبل التسوية الكمية بترجع والتسوية بتتلغي، وبعد التسوية مرفوض برسالة واضحة', async () => {
    const it = await newItem('جرس');
    const e1 = await sell(R, it, 1, 5000);
    expect(await pend(it)).toBe(1);
    await as(O, `select reverse_entry($1, 'غلط')`, [e1]);
    expect(await pend(it)).toBe(0);
    expect(await stock(it)).toEqual({ q: 0, v: 0 });
    await clean();
    const e2 = await sell(R, it, 1, 5000);
    await as(O, `select stock_in($1, $2, 2, 2000)`, [id(), it]);
    expect(await pend(it)).toBe(0);
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [e2])).rejects.toThrow(/E_SETTLED/);
    await clean();
    await allow(false);
  });

  it('مقفول تاني: مرفوض زي الأول، والهالك والقطع على الأجهزة عمرها ما بتخرج من غير رصيد', async () => {
    const it = await newItem('مايك');
    await expect(sell(R, it, 1, 1000)).rejects.toThrow(/E_STOCK/);
    await allow(true);
    await expect(as(O, `select write_off($1, $2, 1, 'اتكسر')`, [id(), it])).rejects.toThrow(/E_STOCK/);
    await allow(false);
  });

  it('صنف جديد من نافذة البيع: بالتفاصيل والكمية والتكلفة في عملية واحدة، وبيتباع على طول، والحسابات صح', async () => {
    const it = id();
    // "إضافة صنف جديد" مقفولة افتراضيًا للموظف: مرفوضة لحد ما صاحب المحل يفتحها
    await expect(as(R, `select create_item($1, 'part', 'x')`, [id()])).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'item_create', 'add', true)`, [R]);
    await as(R, `select create_item($1, 'part', 'شاشة A52 - Incell', 'شاشة', 'Samsung', 'A52', 'Incell', null, 45000, 3, 25000)`, [it]);
    expect(await stock(it)).toEqual({ q: 3, v: 75000 });
    expect((await as(R, `select sale_price, quality from items_stock() where id = $1`, [it])).rows[0]).toEqual({ sale_price: 45000, quality: 'Incell' });
    const cogs0 = await bal('cogs');
    await sell(R, it, 1, 45000);
    expect(await bal('cogs')).toBe(cogs0 + 25000);
    expect(await stock(it)).toEqual({ q: 2, v: 50000 });
    // نفس العملية مرتين (النت قطع ورجع): صنف واحد
    await as(R, `select create_item($1, 'part', 'تاني', null, null, null, null, null, null, 0, null)`, [it]);
    expect((await admin(`select name from items where id = $1`, [it])).rows[0].name).toBe('شاشة A52 - Incell');
    // من غير صلاحية "يضيف" في المخزون: مرفوض
    await as(O, `select set_staff_override($1, 'item_create', 'add', null)`, [R]);
    await expect(as(R, `select create_item($1, 'part', 'x')`, [id()])).rejects.toThrow(/E_FORBIDDEN/);
    await clean();
  });

  it('تقرير المخزون بفلتر النوع والماركة والموديل والجودة: الأصناف اللي في الفلتر بس', async () => {
    const a = id();
    const b = id();
    await as(O, `select create_item($1, 'part', 'بطارية A52', 'بطارية', 'Samsung', 'A52', 'أصلي', null, 30000, 4, 10000)`, [a]);
    await as(O, `select create_item($1, 'part', 'بطارية iPhone 11', 'بطارية', 'Apple', 'iPhone 11', 'كوبي', null, 30000, 2, 8000)`, [b]);
    await sell(R, a, 1, 30000);
    await sell(R, b, 1, 30000);
    const sum = async (f: object | null) => (await as(O, `select inventory_summary(now() - interval '1 day', now() + interval '1 day', null, $1::jsonb) s`, [f ? JSON.stringify(f) : null])).rows[0].s;
    const s1 = await sum({ item_type: 'بطارية', brand: 'Samsung' });
    expect(s1.top.map((x: { id: string }) => x.id)).toEqual([a]);
    expect(s1.filtered).toEqual({ items: 1, stock_qty: 3, stock_value: 30000 });
    const s2 = await sum({ quality: 'كوبي' });
    expect(s2.top.map((x: { id: string }) => x.id)).toEqual([b]);
    expect(s2.filtered).toEqual({ items: 1, stock_qty: 1, stock_value: 8000 });
    // من غير فلتر: زي الأول (أرقام المحل كله، ومفيش "filtered")
    const s0 = await sum(null);
    expect(s0.filtered).toBeNull();
    expect(s0.top.map((x: { id: string }) => x.id)).toEqual(expect.arrayContaining([a, b]));
  });
});

