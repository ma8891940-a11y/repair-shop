// (27) 0079: أوامر الشراء: استلام جزئي لحد ما يكمل من غير تضاعف، ومرتجع مورد مربوط بسطر الاستلام
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function on(c: pg.Client, uid: string, sql: string, params: unknown[] = [], branch?: string) {
  await c.query('begin');
  try {
    await c.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
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
const as = (uid: string, sql: string, params: unknown[] = [], branch?: string) => on(db, uid, sql, params, branch);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
interface OLine {
  id: string;
  item: string;
  qty: number;
  received: number;
  receipts: { move: string; entry: string; qty: number; value: number; returned: number }[];
}
interface Order {
  id: string;
  status: string;
  lines: OLine[];
}

d('أوامر الشراء', () => {
  let O = '';
  let M = ''; // مدير فرع الرئيسي
  let R = '';
  let T = '';
  let M2 = ''; // مدير فرع المعادي
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cash2 = '';
  let sup = '';
  const a = id();
  const b = id();
  const stock = async (i: string) => (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1`, [i])).rows[0];
  const ap = async () => Number((await admin(`select coalesce(sum(l.credit - l.debit), 0) n from journal_lines l join accounts c on c.id = l.account_id where c.code = 'ap' and l.party_id = $1`, [sup])).rows[0].n);
  const lines = async (e: string): Promise<Record<string, number>> =>
    Object.fromEntries((await admin(`select coalesce(c.code, c.kind) k, sum(l.debit - l.credit)::bigint n from journal_lines l join accounts c on c.id = l.account_id where l.entry_id = $1 group by 1`, [e])).rows.map((r) => [r.k, Number(r.n)]));
  const order = async (u: string, ls: unknown, op = id(), branch = main) => (await as(u, `select save_purchase_order($1, $2, $3::jsonb, '2026-12-20', 'مستعجل') r`, [op, sup, JSON.stringify(ls)], branch)).rows[0].r as string;
  const list = async (u = O, st: string | null = null, br: string | null = null) => (await as(u, `select purchase_orders_list($1, $2) j`, [st, br])).rows[0].j as Order[];
  const get = async (o: string) => (await list()).find((x) => x.id === o)!;
  const receive = async (u: string, o: string, ls: unknown, box: string | null = null, op = id(), branch = main) => (await as(u, `select receive_purchase_order($1, $2, $3::jsonb, $4) e`, [op, o, JSON.stringify(ls), box], branch)).rows[0].e as string;
  const giveBack = async (u: string, mv: string, q: number | null, box: string | null = null, reason: string | null = 'عيب', op = id()) => (await as(u, `select purchase_move_return($1, $2, $3, $4, $5) e`, [op, mv, q, box, reason], main)).rows[0].e as string;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`po-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الأوامر')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'O2', null, null)`, [B2]);
    const box = async (x: string) => (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, x])).rows[0].id;
    cash = await box(main);
    cash2 = await box(B2);
    const invite = async (k: string, preset: string, br: string) => {
      const role = (await admin(`select id from roles where shop_id = $1 and preset = $2`, [shop, preset])).rows[0].id;
      const em = `po-${k}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4, $5)`, [em, k, preset === 'technician' ? 'technician' : 'reception', [role], [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [k]);
      return u;
    };
    M = await invite('m', 'branch_manager', main);
    R = await invite('r', 'reception', main);
    T = await invite('t', 'technician', main);
    M2 = await invite('m2', 'branch_manager', B2);
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الأوامر')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة'), ($2, gen_random_uuid(), 'accessory', 'جراب')`, [a, b]);
    await as(O, `select owner_capital($1, $2, 90000000)`, [id(), cash]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الأمر من غير قيد، واستلام جزئي وبعدين الباقي: من غير تضاعف، والحالة بتتغيّر، والأمر المستلم ما يستلمش تاني', async () => {
    const n0 = Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [shop])).rows[0].n);
    const o = await order(M, [{ item: a, qty: 10, unit_cost: 60000 }, { item: b, qty: 4, unit_cost: 2500 }]);
    expect(Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [shop])).rows[0].n)).toBe(n0);
    expect(await get(o)).toMatchObject({ status: 'open' });
    const [la, lb] = (await get(o)).lines.map((l) => l.id);
    const e1 = await receive(M, o, [{ line: la, qty: 3 }]);
    expect(await lines(e1)).toEqual({ inventory: 180000, ap: -180000 });
    expect((await get(o)).status).toBe('partial');
    // نفس الطلب مرتين = مرة
    const op = id();
    const e2 = await receive(M, o, [{ line: la, qty: 5, unit_cost: 61000 }, { line: lb, qty: 4 }], cash, op);
    expect(await receive(M, o, [{ line: la, qty: 5, unit_cost: 61000 }, { line: lb, qty: 4 }], cash, op)).toBe(e2);
    expect(await lines(e2)).toEqual({ inventory: 315000, cash_cash: -315000 });
    for (const q of [3, 100]) await expect(receive(M, o, [{ line: la, qty: q }])).rejects.toThrow(/E_ORDER_QTY/);
    await receive(M, o, [{ line: la, qty: 2 }]);
    const g = await get(o);
    expect(g.status).toBe('received');
    expect(g.lines.map((l) => [l.qty, l.received])).toEqual([[10, 10], [4, 4]]);
    await expect(receive(M, o, [{ line: lb, qty: 1 }])).rejects.toThrow(/E_ORDER_QTY/);
    expect(await stock(a)).toEqual({ q: 10, v: 180000 + 305000 + 120000 });
    expect(await stock(b)).toEqual({ q: 4, v: 10000 });
    expect(await ap()).toBe(180000 + 120000);
    // تعديل قيد الاستلام كان هيفك ربطه بالأمر فيتستلم تاني
    const args = (await as(O, `select entry_args($1) a`, [e1])).rows[0].a;
    await expect(as(O, `select edit_entry($1, 'تعديل', $2::jsonb)`, [e1, JSON.stringify({ ...args, id: id() })])).rejects.toThrow(/E_ORDER_EDIT/);
    // إلغاء استلام بقيد عكسي: الكمية ترجع باقية
    await as(O, `select reverse_entry($1, 'غلط')`, [e1]);
    expect((await get(o)).lines[0].received).toBe(7);
    expect((await get(o)).status).toBe('partial');
    await receive(M, o, [{ line: la, qty: 3 }]);
    expect((await get(o)).status).toBe('received');
  });

  it('استلامين في نفس اللحظة: ما يعدّوش المطلوب', async () => {
    const o = await order(O, [{ item: b, qty: 5, unit_cost: 100 }]);
    const l = (await get(o)).lines[0].id;
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      const q = `select receive_purchase_order($1, $2, $3::jsonb)`;
      const r = await Promise.allSettled([on(db, O, q, [id(), o, JSON.stringify([{ line: l, qty: 4 }])], main), on(c2, O, q, [id(), o, JSON.stringify([{ line: l, qty: 4 }])], main)]);
      expect(r.map((x) => x.status).sort()).toEqual(['fulfilled', 'rejected']);
      expect(String((r.find((x) => x.status === 'rejected') as PromiseRejectedResult).reason)).toMatch(/E_ORDER_QTY/);
    } finally {
      await c2.end();
    }
    expect((await get(o)).lines[0].received).toBe(4);
  });

  it('مرتجع من سطر الاستلام: بسعره هو، وما يزيدش عن اللي وصل فيه، وآخر مرتجع بيقفله بالقرش، والشرا ما يتلغيش قبله', async () => {
    const i = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'بطارية')`, [i]);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: i, qty: 10, unit_cost: 1000 }])], main);
    const o = await order(M, [{ item: i, qty: 3, unit_cost: 5000 }]);
    const e = await receive(M, o, [{ line: (await get(o)).lines[0].id, qty: 3 }]);
    const mv = (await get(o)).lines[0].receipts[0].move;
    const ap0 = await ap();
    for (const q of [0, -1, 4, null]) await expect(giveBack(M, mv, q)).rejects.toThrow(/E_RETURN_QTY/);
    await expect(giveBack(M, mv, 1, null, ' ')).rejects.toThrow(/E_REASON_REQUIRED/);
    // المتوسط 25000 / 13 = 1923: المورد بيخصم سعر الشرا 5000، والفرق تكلفة
    const op = id();
    const r1 = await giveBack(M, mv, 1, null, 'عيب', op);
    expect(await giveBack(M, mv, 1, null, 'عيب', op)).toBe(r1);
    const l1 = await lines(r1);
    expect(l1.ap).toBe(5000);
    expect(l1.inventory + l1.ap + l1.cogs).toBe(0);
    await giveBack(M, mv, 2, cash);
    await expect(giveBack(M, mv, 1)).rejects.toThrow(/E_RETURN_QTY/);
    expect(await ap()).toBe(ap0 - 5000);
    expect((await stock(i)).q).toBe(10);
    expect((await get(o)).lines[0].receipts[0].returned).toBe(3);
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_HAS_RETURNS/);
    await as(O, `select reverse_entry($1, 'المرتجع غلط')`, [r1]);
    expect((await get(o)).lines[0].receipts[0].returned).toBe(2);
    await giveBack(M, mv, 1);
    // المباع ما يترجعش للمورد
    const o2 = await order(O, [{ item: i, qty: 1, unit_cost: 700 }]);
    await receive(O, o2, [{ line: (await get(o2)).lines[0].id, qty: 1 }]);
    const mv2 = (await get(o2)).lines[0].receipts[0].move;
    await as(O, `select write_off($1, $2, 11, 'اتكسر')`, [id(), i], main);
    await expect(giveBack(O, mv2, 1)).rejects.toThrow(/E_STOCK/);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('مرتجع من شرا عادي (من غير أمر) بنفس الطريقة', async () => {
    const e = (await as(O, `select record_purchase($1, $2, $3::jsonb) e`, [id(), sup, JSON.stringify([{ item: b, qty: 2, unit_cost: 333 }])], main)).rows[0].e;
    const mv = (await admin(`select id from stock_moves where entry_id = $1`, [e])).rows[0].id;
    expect((await lines(await giveBack(O, mv, 2))).ap).toBe(666);
    const ret = (await admin(`select id from stock_moves where return_of = $1`, [mv])).rows[0].id;
    await expect(giveBack(O, ret, 1)).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('إلغاء الأمر بسبب، والمستلم بيفضل، والاستلام بعده مرفوض', async () => {
    const o = await order(M, [{ item: b, qty: 6, unit_cost: 100 }]);
    const l = (await get(o)).lines[0].id;
    await receive(M, o, [{ line: l, qty: 2 }]);
    await expect(as(M, `select cancel_purchase_order($1, '')`, [o])).rejects.toThrow(/E_REASON_REQUIRED/);
    await as(M, `select cancel_purchase_order($1, 'المورد ما عندوش')`, [o]);
    expect(await get(o)).toMatchObject({ status: 'cancelled' });
    expect((await get(o)).lines[0].received).toBe(2);
    await expect(receive(M, o, [{ line: l, qty: 1 }])).rejects.toThrow(/E_ORDER_CANCELLED/);
  });

  it('المدخلات الغلط، ونفس رقم الأمر مرتين = أمر واحد', async () => {
    const op = id();
    expect(await order(O, [{ item: a, qty: 1, unit_cost: 5 }], op)).toBe(op);
    expect(await order(O, [{ item: a, qty: 9, unit_cost: 5 }], op)).toBe(op);
    expect((await get(op)).lines[0].qty).toBe(1);
    for (const [ls, err] of [
      [[], /E_BAD_INPUT/], [null, /E_BAD_INPUT/], [[{ item: a, qty: 0, unit_cost: 1 }], /E_BAD_QTY/], [[{ item: a, qty: 1.5, unit_cost: 1 }], /E_BAD_QTY/], [[{ item: a, qty: 1, unit_cost: -1 }], /E_BAD_PRICE/],
      [[{ item: a, qty: 1, unit_cost: 1 }, { item: a, qty: 2, unit_cost: 1 }], /E_BAD_INPUT/], [[{ item: id(), qty: 1, unit_cost: 1 }], /E_NOT_FOUND/], [[{ item: a, qty: 100000, unit_cost: 999999999999 }], /E_BAD_AMOUNT/], [[{ item: a, qty: 1, unit_cost: 0 }], /E_BAD_AMOUNT/],
    ] as [unknown, RegExp][])
      await expect(order(O, ls), JSON.stringify(ls)).rejects.toThrow(err);
    const l = (await get(op)).lines[0].id;
    for (const [ls, err] of [[[], /E_BAD_INPUT/], [[{ line: l, qty: 0 }], /E_BAD_QTY/], [[{ line: l, qty: 1 }, { line: l, qty: 1 }], /E_BAD_INPUT/], [[{ line: id(), qty: 1 }], /E_NOT_FOUND/], [[{ line: l, qty: 1, unit_cost: 'x' }], /E_BAD_PRICE/]] as [unknown, RegExp][])
      await expect(receive(O, op, ls), JSON.stringify(ls)).rejects.toThrow(err);
    await expect(receive(O, op, [{ line: l, qty: 1 }], cash2)).rejects.toThrow(/E_BAD_BRANCH/);
    await expect(admin(`update purchase_order_lines set qty = 50 where id = $1`, [l])).rejects.toThrow();
    await expect(admin(`delete from purchase_orders where id = $1`, [op])).rejects.toThrow();
  });

  it('الصلاحيات والفرع والمحل', async () => {
    const o = await order(M, [{ item: b, qty: 3, unit_cost: 100 }]);
    const l = (await get(o)).lines[0].id;
    for (const u of [R, T]) {
      await expect(order(u, [{ item: b, qty: 1, unit_cost: 1 }])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(receive(u, o, [{ line: l, qty: 1 }])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(list(u)).rejects.toThrow(/E_FORBIDDEN/);
      for (const t of ['purchase_orders', 'purchase_order_lines']) expect((await as(u, `select count(*)::int n from ${t}`)).rows[0].n).toBe(0);
    }
    await expect(receive(M2, o, [{ line: l, qty: 1 }], null, id(), B2)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(M2, `select cancel_purchase_order($1, 'x')`, [o])).rejects.toThrow(/E_NOT_FOUND/);
    expect(await list(M2)).toEqual([]);
    expect((await as(M2, `select count(*)::int n from purchase_order_lines`)).rows[0].n).toBe(0);
    await receive(M, o, [{ line: l, qty: 1 }]);
    const mv = (await get(o)).lines[0].receipts[0].move;
    await expect(as(M2, `select purchase_move_return($1, $2, 1, null, 'x')`, [id(), mv])).rejects.toThrow(/E_FORBIDDEN/);
    const X = await user(`po-x-${tag}@p.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    await expect(receive(X, o, [{ line: l, qty: 1 }], null, id(), undefined)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(X, `select purchase_move_return($1, $2, 1, null, 'x')`, [id(), mv])).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(X, `select save_purchase_order($1, $2, $3::jsonb)`, [o, sup, '[]'])).rejects.toThrow(/E_NOT_FOUND/);
    expect(await list(X)).toEqual([]);
  });

  it('النسخة الاحتياطية والاسترجاع: الأوامر والمستلم والمرتجع زي ما هم', async () => {
    const backup = (await as(O, `select export_backup() b`)).rows[0].b;
    const N = await user(`po-n-${tag}@p.test`);
    await as(N, `select bootstrap_account('جديد', 'محل جديد')`);
    await as(N, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const shape = (x: Order[]) => x.map((o) => [o.status, ...o.lines.map((l) => `${l.qty}/${l.received}/${l.receipts.map((r) => `${r.qty}-${r.returned}`).sort().join(',')}`)].join(' ')).sort();
    expect(shape(await list(N))).toEqual(shape(await list(O)));
  });
});
