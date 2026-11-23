// (3) 0072: مرتجع مربوط بسطر البيع: الكمية والمبلغ والضريبة والتكلفة من البيع نفسه، وما يزيدش عن اللي اتباع
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function on(c: pg.Client, uid: string, sql: string, params: unknown[] = []) {
  await c.query('begin');
  try {
    await c.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await c.query('set local role authenticated');
    const r = await c.query(sql, params);
    await c.query('commit');
    return r;
  } catch (e) {
    await c.query('rollback');
    throw e;
  }
}
const as = (uid: string, sql: string, params: unknown[] = []) => on(db, uid, sql, params);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);

d('مرتجع بسطر البيع', () => {
  let O = '';
  let R = ''; // استقبال الرئيسي
  let R2 = ''; // استقبال الفرع التاني
  let T = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cash2 = '';
  let cust = '';
  let sup = '';
  const part = id();
  const acc = id();
  const acc2 = id();
  const srv = id();
  const vat = (bp: number | null) =>
    admin(`update shops set extras = case when $2::int is null then extras - 'vat' else jsonb_set(coalesce(extras, '{}'), '{vat}', jsonb_build_object('enabled', true, 'rate_bp', $2::int)) end where id = $1`, [shop, bp]);
  const lines = async (e: string): Promise<Record<string, number>> =>
    Object.fromEntries((await admin(`select coalesce(a.code, a.kind) c, sum(l.debit - l.credit)::bigint n from journal_lines l join accounts a on a.id = l.account_id where l.entry_id = $1 group by 1`, [e])).rows.map((r) => [r.c, Number(r.n)]));
  const bal = async (code: string) => Number((await admin(`select coalesce(sum(l.debit - l.credit), 0) n from journal_lines l join accounts a on a.id = l.account_id where a.shop_id = $1 and a.code = $2`, [shop, code])).rows[0].n);
  const stock = async (i: string) => (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1`, [i])).rows[0];
  const sell = async (u: string, ls: { item: string; qty: number; price: number }[], box: string | null = cash, c: string | null = null) => {
    const e = (await as(u, `select record_sale($1, $2::jsonb, $3, $4) e`, [id(), JSON.stringify(ls), box, c])).rows[0].e as string;
    const ln = (await admin(`select id from sale_lines where entry_id = $1 order by seq`, [e])).rows.map((x) => x.id as string);
    const no = Number((await admin(`select entry_no from journal_entries where id = $1`, [e])).rows[0].entry_no);
    return { e, ln, no };
  };
  const ret = async (u: string, line: string, qty: number | null, box: string | null = cash, restock = true, reason: string | null = 'العميل رجّعه', op = id()) =>
    (await as(u, `select sale_line_return($1, $2, $3, $4, $5, $6) e`, [op, line, qty, box, restock, reason])).rows[0].e as string;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`sr-o-${tag}@s.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل المرتجع')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'S2', null, null)`, [B2]);
    const box = async (b: string) => (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, b])).rows[0].id;
    cash = await box(main);
    cash2 = await box(B2);
    const invite = async (k: string, role: string, b: string) => {
      const em = `sr-${k}-${tag}@s.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, k, role, [b]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [k]);
      return u;
    };
    R = await invite('r1', 'reception', main);
    R2 = await invite('r2', 'reception', B2);
    T = await invite('t', 'technician', main);
    cust = id();
    sup = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل المرتجع', '01066667777')`, [cust]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    for (const [i, k, n] of [[part, 'part', 'شاشة'], [acc, 'accessory', 'جراب'], [acc2, 'accessory', 'شاحن'], [srv, 'service', 'سوفت']])
      await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), $2, $3)`, [i, k, n]);
    await as(O, `select owner_capital($1, $2, 50000000)`, [id(), cash]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: part, qty: 20, unit_cost: 60000 }, { item: acc, qty: 20, unit_cost: 3000 }, { item: acc2, qty: 20, unit_cost: 5000 }]), cash]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('بند من فاتورة متعددة البنود: بكميته وسعره هو بس، والباقي زي ما هو', async () => {
    const before = { p: await stock(part), a: await stock(acc), c: await bal('cash_cash') };
    const s = await sell(R, [{ item: part, qty: 2, price: 150000 }, { item: acc, qty: 3, price: 8050 }, { item: srv, qty: 1, price: 5000 }]);
    const e = await ret(R, s.ln[1], 2);
    expect(await lines(e)).toEqual({ cash_cash: -16100, rev_accessories: 16100, inventory: 6000, cogs: -6000 });
    expect(await stock(part)).toEqual({ q: before.p.q - 2, v: before.p.v - 120000 });
    expect(await stock(acc)).toEqual({ q: before.a.q - 1, v: before.a.v - 3000 });
    expect(await bal('cash_cash')).toBe(before.c + 329150 - 16100);
    const inv = (await as(R, `select sale_for_return($1) j`, [s.no])).rows[0].j;
    expect(inv.lines.map((l: { name: string; qty: number; returned: number; price: number; service: boolean }) => [l.name, l.qty, l.returned, l.price, l.service])).toEqual([
      ['شاشة', 2, 0, 150000, false],
      ['جراب', 3, 2, 8050, false],
      ['سوفت', 1, 0, 5000, true],
    ]);
    expect(inv).toMatchObject({ credit: false, cancelled: false });
    expect(JSON.stringify(inv)).not.toMatch(/cost|phone|عميل/);
  });

  it('ما يزيدش عن اللي اتباع، ولا على مرتين، ونفس الطلب مرتين = مرة', async () => {
    const s = await sell(R, [{ item: acc, qty: 3, price: 5000 }]);
    for (const q of [0, -1, 4, null]) await expect(ret(R, s.ln[0], q)).rejects.toThrow(/E_RETURN_QTY/);
    const op = id();
    const e = await ret(R, s.ln[0], 2, cash, true, 'سبب', op);
    expect(await ret(R, s.ln[0], 2, cash, true, 'سبب', op)).toBe(e);
    await expect(ret(R, s.ln[0], 2)).rejects.toThrow(/E_RETURN_QTY/);
    await ret(R, s.ln[0], 1);
    await expect(ret(R, s.ln[0], 1)).rejects.toThrow(/E_RETURN_QTY/);
    // سطر المرتجع نفسه ما يترجعش
    const rl = (await admin(`select id from sale_lines where return_of = $1 limit 1`, [s.ln[0]])).rows[0].id;
    await expect(ret(R, rl, 1)).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('مرتجعين متزامنين لآخر قطعة: واحد بس بيعدّي', async () => {
    const s = await sell(R, [{ item: acc, qty: 1, price: 5000 }]);
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      const q = `select sale_line_return($1, $2, 1, $3, true, 'متزامن')`;
      const r = await Promise.allSettled([on(db, R, q, [id(), s.ln[0], cash]), on(c2, O, q, [id(), s.ln[0], cash])]);
      expect(r.map((x) => x.status).sort()).toEqual(['fulfilled', 'rejected']);
      expect(String((r.find((x) => x.status === 'rejected') as PromiseRejectedResult).reason)).toMatch(/E_RETURN_QTY/);
    } finally {
      await c2.end();
    }
  });

  it('الضريبة والتكلفة من البيع نفسه حتى لو النسبة والمتوسط اتغيروا، وآخر مرتجع بيقفلهم بالقرش', async () => {
    await vat(1400);
    // 3 جراب × 33.33 + شاحن 17.77 = 117.76 شامل. الضريبة بالتقريب 14.46 (11776×1400/11400 ← 1446.175)
    const s = await sell(R, [{ item: acc, qty: 3, price: 3333 }, { item: acc2, qty: 1, price: 1777 }]);
    const sale = await lines(s.e);
    expect(sale).toMatchObject({ cash_cash: 11776, vat_payable: -1446, rev_accessories: -10330 });
    await vat(500);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: acc, qty: 10, unit_cost: 9000 }]), cash]);
    const sum: Record<string, number> = {};
    for (const [l, q] of [[s.ln[0], 1], [s.ln[1], 1], [s.ln[0], 1], [s.ln[0], 1]] as const) {
      for (const [k, n] of Object.entries<number>(await lines(await ret(R, l, q)))) sum[k] = (sum[k] ?? 0) + n;
    }
    for (const k of Object.keys(sale)) expect(sum[k], k).toBe(-sale[k]);
    await vat(null);
  });

  it('بيع قبل فتح الضريبة: مرتجعه من غير ضريبة', async () => {
    const s = await sell(R, [{ item: acc, qty: 1, price: 11400 }]);
    await vat(1400);
    expect((await lines(await ret(R, s.ln[0], 1))).vat_payable).toBeUndefined();
    await vat(null);
  });

  it('التالف: ما يرجعش المخزون وتكلفته تفضل مصروف. والخدمة: فلوس بس', async () => {
    const s = await sell(R, [{ item: part, qty: 1, price: 150000 }, { item: srv, qty: 1, price: 5000 }]);
    const before = await stock(part);
    expect(await lines(await ret(R, s.ln[0], 1, cash, false))).toEqual({ cash_cash: -150000, rev_parts: 150000 });
    expect(await stock(part)).toEqual(before);
    expect(await lines(await ret(R, s.ln[1], 1))).toEqual({ cash_cash: -5000, rev_repair: 5000 });
  });

  it('الآجل: بيتخصم من حساب العميل بس. والكاش لعميل معروف ممكن يبقى رصيد، ولعميل مش معروف لأ', async () => {
    const cr = await sell(O, [{ item: acc, qty: 2, price: 10000 }], null, cust);
    await expect(ret(R, cr.ln[0], 1, cash)).rejects.toThrow(/E_RETURN_CREDIT/);
    expect(await lines(await ret(R, cr.ln[0], 1, null))).toMatchObject({ ar: -10000, rev_accessories: 10000 });
    const party = Number((await admin(`select sum(l.debit - l.credit) n from journal_lines l where l.party_id = $1`, [cust])).rows[0].n);
    expect(party).toBe(10000);
    const k = await sell(R, [{ item: acc, qty: 1, price: 4000 }], cash, cust);
    expect(await lines(await ret(R, k.ln[0], 1, null))).toMatchObject({ ar: -4000 });
    const u = await sell(R, [{ item: acc, qty: 1, price: 4000 }]);
    await expect(ret(R, u.ln[0], 1, null)).rejects.toThrow(/E_BAD_INPUT/);
  });

  it('الإلغاء: بيع رجع منه حاجة ما يتلغيش، وإلغاء المرتجع بيرجّع الكمية متاحة، وبيع ملغي ما يترجعش', async () => {
    const s = await sell(R, [{ item: acc, qty: 1, price: 5000 }]);
    const e = await ret(R, s.ln[0], 1);
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [s.e])).rejects.toThrow(/E_HAS_RETURNS/);
    await as(O, `select reverse_entry($1, 'المرتجع غلط')`, [e]);
    const e2 = await ret(R, s.ln[0], 1);
    await as(O, `select reverse_entry($1, 'تاني')`, [e2]);
    await as(O, `select reverse_entry($1, 'البيع نفسه')`, [s.e]);
    await expect(ret(R, s.ln[0], 1)).rejects.toThrow(/E_ALREADY_REVERSED/);
    expect((await as(R, `select sale_for_return($1) j`, [s.no])).rows[0].j.cancelled).toBe(true);
  });

  it('الصلاحيات والفروع والسبب، والمستعمل بإلغاء البيع', async () => {
    const s = await sell(R, [{ item: acc, qty: 1, price: 5000 }]);
    await expect(ret(R, s.ln[0], 1, cash, true, '  ')).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(ret(T, s.ln[0], 1)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(T, `select sale_for_return($1)`, [s.no])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(ret(R2, s.ln[0], 1, cash2)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R2, `select sale_for_return($1)`, [s.no])).rejects.toThrow(/E_NOT_FOUND/);
    await expect(ret(O, s.ln[0], 1, cash2)).rejects.toThrow(/E_BAD_BRANCH/);
    await as(O, `select set_staff_override($1, 'sales', 'edit', false)`, [R]);
    await expect(ret(R, s.ln[0], 1)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'sales', 'edit', null)`, [R]);
    const X = await user(`sr-x-${tag}@s.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    await expect(ret(X, s.ln[0], 1)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(X, `select sale_for_return($1)`, [s.no])).rejects.toThrow(/E_NOT_FOUND/);
    // الزائر
    expect((await admin(`select has_function_privilege('anon', 'public.sale_line_return(uuid,uuid,integer,uuid,boolean,text)', 'execute') x`)).rows[0].x).toBe(false);
    const u = id();
    await as(O, `select buy_used_device($1, $2::jsonb, $3, $4::jsonb)`, [u, JSON.stringify({ imei: `35${String(Date.now()).padStart(13, '0').slice(-13)}`, brand: 'Apple', model: 'iPhone 12', buy_price: 500000, sale_price: 600000 }), cash, JSON.stringify({ name: 'بائع' })]);
    const used = (await admin(`select id from used_devices where shop_id = $1`, [shop])).rows[0].id;
    const ue = (await as(O, `select sell_used_device($1, $2, 600000, $3) e`, [id(), used, cash])).rows[0].e;
    const ul = (await admin(`select id from sale_lines where entry_id = $1`, [ue])).rows[0].id;
    await expect(ret(O, ul, 1)).rejects.toThrow(/E_USED_RETURN/);
  });

  it('مبالغ كبيرة ومن غير كسور، والدفتر سليم في الآخر', async () => {
    await vat(1400);
    const s = await sell(O, [{ item: srv, qty: 7, price: 1428571428 }]);
    const sale = await lines(s.e);
    let v = 0;
    for (const q of [3, 3, 1]) v += (await lines(await ret(O, s.ln[0], q))).vat_payable;
    expect(v).toBe(-sale.vat_payable);
    await vat(null);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('النسخة الاحتياطية فيها ربط المرتجع بسطره', async () => {
    const b = (await as(O, `select export_backup() b`)).rows[0].b;
    expect(JSON.stringify(b)).toContain('"return_of"');
  });
});
