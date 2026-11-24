// (29) 0080: الجرد الدوري: العد لوحده ما يعملش تسوية، والفرق من رصيد لحظة العد، والاعتماد بصلاحية وقيد واحد متوازن
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
interface Sheet {
  status: string;
  entry: string | null;
  lines: { item: string; name: string; opening: number; system: number | null; counted: number | null; diff: number | null; value: number | null }[];
}

d('الجرد الدوري', () => {
  let O = '';
  let M = '';
  let R = '';
  let C = '';
  let T = '';
  let M2 = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  const [a, b, c, fresh] = [id(), id(), id(), id()];
  const stock = async (i: string, br = main) => (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1 and branch_id = $2`, [i, br])).rows[0];
  const lines = async (e: string) => (await admin(`select a.code c, l.debit::int d, l.credit::int cr from journal_lines l join accounts a on a.id = l.account_id where l.entry_id = $1 order by a.code, l.debit`, [e])).rows.map((x) => [x.c, x.d, x.cr]);
  const entries = async () => Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [shop])).rows[0].n);
  const start = async (u: string, op = id(), br = main) => (await as(u, `select start_stock_count($1, 'جرد الشهر') r`, [op], br)).rows[0].r as string;
  const count = (u: string, k: string, i: string, q: number | null) => as(u, `select save_stock_count($1, $2, $3)`, [k, i, q], main);
  const post = async (u: string, k: string, reason: string | null = 'جرد', op = id()) => (await as(u, `select post_stock_count($1, $2, $3) e`, [op, k, reason], main)).rows[0].e as string | null;
  const sheet = async (u: string, k: string) => (await as(u, `select stock_count_sheet($1) j`, [k])).rows[0].j as Sheet;
  const row = async (k: string, i: string, u = O) => (await sheet(u, k)).lines.find((x) => x.item === i)!;
  const sell = (i: string, q: number) => as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: i, qty: q, price: 9000 }]), cash], main);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`sc-o-${tag}@s.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الجرد')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'C2', null, null)`, [B2]);
    cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    // خطة من غير حد موظفين
    await admin(`set session_replication_role = replica`);
    await admin(`update shops set plan_code = (select code from plans where max_staff is null limit 1) where id = $1`, [shop]);
    await admin(`set session_replication_role = origin`);
    const invite = async (k: string, preset: string, br: string) => {
      const role = (await admin(`select id from roles where shop_id = $1 and preset = $2`, [shop, preset])).rows[0].id;
      const em = `sc-${k}-${tag}@s.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4, $5)`, [em, k, preset === 'technician' ? 'technician' : 'reception', [role], [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [k]);
      return u;
    };
    M = await invite('m', 'branch_manager', main);
    R = await invite('r', 'reception', main);
    C = await invite('c', 'cashier', main);
    T = await invite('t', 'technician', main);
    M2 = await invite('m2', 'branch_manager', B2);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'أ شاشة'), ($2, gen_random_uuid(), 'accessory', 'ب جراب'), ($3, gen_random_uuid(), 'accessory', 'ج شاحن'), ($4, gen_random_uuid(), 'part', 'د جديد')`, [a, b, c, fresh]);
    await as(O, `insert into items(id, shop_id, kind, name) values (gen_random_uuid(), gen_random_uuid(), 'service', 'خدمة')`);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: a, qty: 10, unit_cost: 1000 }, { item: b, qty: 20, unit_cost: 300 }, { item: c, qty: 5, unit_cost: 700 }])], main);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: a, qty: 4, unit_cost: 1000 }])], B2);
  }, 60_000);
  afterAll(async () => db?.end());

  it('العد لوحده ما بيعملش تسوية، وكشف الفروق برصيد البداية ولحظة العد، والبيع بعد العد ما يلخبطش الفرق', async () => {
    const n0 = await entries();
    const k = await start(R);
    expect((await sheet(O, k)).lines.map((l) => [l.name, l.opening, l.counted])).toEqual([['أ شاشة', 10, null], ['ب جراب', 20, null], ['ج شاحن', 5, null], ['د جديد', 0, null]]);
    await sell(a, 1); // قبل العد: رصيد النظام 9
    await count(R, k, a, 7);
    await sell(a, 2); // بعد العد
    await count(R, k, b, 23);
    expect(await entries()).toBe(n0 + 2);
    expect(await row(k, a)).toMatchObject({ opening: 10, system: 9, counted: 7, diff: -2, value: -2000 });
    expect(await row(k, b)).toMatchObject({ system: 20, counted: 23, diff: 3, value: 900 });
    expect(await row(k, c)).toMatchObject({ counted: null, diff: null, value: null });
    // الاستقبال بتعدّ ومن غير ما تشوف التكلفة، وما تعتمدش
    expect((await row(k, b, R)).value).toBeNull();
    await expect(post(R, k)).rejects.toThrow(/E_FORBIDDEN/);
    for (const x of [null, ' ']) await expect(post(M, k, x)).rejects.toThrow(/E_REASON_REQUIRED/);
    const op = id();
    const e = (await post(M, k, 'جرد الشهر', op))!;
    expect(await post(M, k, 'جرد الشهر', op)).toBe(e);
    expect(await post(M, k)).toBe(e); // ضغطة تانية برقم تاني: نفس القيد
    expect(await lines(e)).toEqual([['inventory', 0, 2000], ['inventory', 900, 0], ['wastage', 0, 900], ['wastage', 2000, 0]]);
    expect(await stock(a)).toEqual({ q: 5, v: 5000 });
    expect(await stock(b)).toEqual({ q: 23, v: 6900 });
    expect(await stock(c)).toEqual({ q: 5, v: 3500 }); // ما اتعدّش
    expect(await stock(a, B2)).toEqual({ q: 4, v: 4000 }); // الفرع التاني
    expect(await sheet(O, k)).toMatchObject({ status: 'posted', entry: e });
    await expect(count(R, k, c, 1)).rejects.toThrow(/E_COUNT_CLOSED/);
    const log = (await admin(`select after from audit_log where action = 'stock_count_post' and entity_id = $1`, [k])).rows;
    expect(log.map((x) => x.after)).toEqual([expect.objectContaining({ items: 2, shortage: 2000, surplus: 900, reason: 'جرد الشهر' })]);
    // الإلغاء بقيد عكسي بيرجّع المخزون
    await as(O, `select reverse_entry($1, 'غلط')`, [e]);
    expect(await stock(a)).toEqual({ q: 7, v: 7000 });
    expect(await stock(b)).toEqual({ q: 20, v: 6000 });
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('من غير فروق: بيتقفل من غير قيد، ومن غير عد مرفوض، وجرد مفتوح واحد للفرع، والإلغاء ما بيعملش حاجة', async () => {
    const n0 = await entries();
    const op = id();
    const k = await start(M, op);
    expect(await start(M, op)).toBe(k);
    await expect(start(R)).rejects.toThrow(/E_COUNT_OPEN/);
    const other = await start(M2, id(), B2); // فرع تاني عادي
    await expect(post(M, k)).rejects.toThrow(/E_COUNT_EMPTY/);
    await count(M, k, c, 9);
    await count(M, k, c, null); // مسح العد
    await expect(post(M, k)).rejects.toThrow(/E_COUNT_EMPTY/);
    await count(M, k, c, 4);
    await count(M, k, c, 5); // إعادة عد
    expect(await post(M, k)).toBeNull();
    expect(await sheet(O, k)).toMatchObject({ status: 'posted', entry: null });
    expect(await entries()).toBe(n0);
    const k2 = await start(M);
    await count(M, k2, c, 0);
    await as(M, `select cancel_stock_count($1)`, [k2]);
    await expect(post(M, k2)).rejects.toThrow(/E_COUNT_CLOSED/);
    expect(await stock(c)).toEqual({ q: 5, v: 3500 });
    await as(O, `select cancel_stock_count($1)`, [other]);
  });

  it('الحالات الصعبة: زيادة من غير تكلفة، ونقص اتباع بعد العد، وصنف اتضاف بعد البداية، ومدخلات غلط', async () => {
    const k = await start(M);
    await count(M, k, fresh, 2);
    await expect(post(M, k)).rejects.toThrow(/E_COUNT_COST/);
    await count(M, k, fresh, null);
    await count(M, k, c, 1); // فرق −4
    await sell(c, 3); // فضل 2
    await expect(post(M, k)).rejects.toThrow(/E_STOCK/);
    expect(await sheet(O, k)).toMatchObject({ status: 'open' });
    const late = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'هـ متأخر')`, [late]);
    await count(M, k, late, 0);
    expect(await row(k, late)).toMatchObject({ opening: 0, diff: 0 });
    for (const q of [-1, 1000001]) await expect(count(M, k, c, q)).rejects.toThrow(/E_BAD_QTY/);
    await expect(count(M, k, id(), 1)).rejects.toThrow(/E_NOT_FOUND/);
    const srv = (await admin(`select id from items where shop_id = $1 and kind = 'service'`, [shop])).rows[0].id;
    await expect(count(M, k, srv, 1)).rejects.toThrow(/E_NOT_FOUND/);
    await count(M, k, c, 2);
    await post(M, k);
  });

  it('اعتمادين في نفس اللحظة: قيد واحد', async () => {
    const k = await start(O);
    await count(O, k, b, 19);
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      const q = `select post_stock_count($1, $2, 'جرد') e`;
      const [x, y] = await Promise.all([on(db, O, q, [id(), k], main), on(c2, M, q, [id(), k], main)]);
      expect(x.rows[0].e).toBe(y.rows[0].e);
    } finally {
      await c2.end();
    }
    expect((await stock(b)).q).toBe(19);
    expect((await admin(`select count(*)::int n from journal_entries where source_type = 'stock_count' and source_id = $1`, [k])).rows[0].n).toBe(1);
  });

  it('الصلاحيات والفرع والمحل، والنسخة الاحتياطية', async () => {
    const k = await start(M);
    await count(M, k, a, 7);
    for (const u of [C, T]) {
      await expect(start(u)).rejects.toThrow(/E_FORBIDDEN/);
      await expect(count(u, k, a, 1)).rejects.toThrow(/E_FORBIDDEN/);
      await expect(sheet(u, k)).rejects.toThrow(/E_FORBIDDEN/);
      for (const t of ['stock_counts', 'stock_count_lines']) expect((await as(u, `select count(*)::int n from ${t}`)).rows[0].n).toBe(0);
    }
    for (const q of [() => count(M2, k, a, 1), () => sheet(M2, k), () => post(M2, k), () => as(M2, `select cancel_stock_count($1)`, [k])]) await expect(q()).rejects.toThrow(/E_NOT_FOUND/);
    expect((await as(M2, `select count(*)::int n from stock_counts where branch_id = $1`, [main])).rows[0].n).toBe(0);
    const X = await user(`sc-x-${tag}@s.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    for (const q of [() => sheet(X, k), () => post(X, k), () => start(X, k)]) await expect(q()).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(O, `update stock_count_lines set counted_qty = 1 where count_id = $1`, [k])).rejects.toThrow(/permission denied/);
    const backup = (await as(O, `select export_backup() b`)).rows[0].b;
    await as(X, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const n = async (s: string) => (await admin(`select c.status, count(l.id)::int n, count(l.counted_qty)::int k from stock_counts c join stock_count_lines l on l.count_id = c.id where c.shop_id = $1 group by c.id, c.status order by 1, 2, 3`, [s])).rows;
    const s2 = (await admin(`select shop_id from profiles where id = $1`, [X])).rows[0].shop_id;
    expect(await n(s2)).toEqual(await n(shop));
  });
});
