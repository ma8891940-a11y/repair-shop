// (4) 0078: تصدير للمحاسب: مطابق للقيود بالقرش، والفترة بتوقيت القاهرة، والفرع، والصلاحيات
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string, sql: string, params: unknown[] = [], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
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
const DAY = '2026-08-10';
interface Line {
  entry_no: number;
  source: string;
  memo: string | null;
  party: string | null;
  debit: number;
  credit: number;
}
interface Out {
  lines: Line[];
  payments: { amount: number; customer: string | null; order_no: string | null; reversed: boolean; method: string }[];
  sales: { item: string; qty: number; amount: number; return_of: number | null }[];
  debit: number;
  credit: number;
  restricted: boolean;
  branch: string | null;
}

d('تصدير للمحاسب', () => {
  let O = '';
  let A = '';
  let R = '';
  let X = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cash2 = '';
  let cust = '';
  const srv = id();
  let saleNo = 0;
  const E: Record<string, string> = {};
  const exp = async (u: string, from = DAY, to = DAY, b: string | null = null) => (await as(u, `select accountant_export($1, $2, $3) j`, [from, to, b])).rows[0].j as Out;
  const at = async (e: string, when: string) => {
    await admin(`set session_replication_role = replica`);
    await admin(`update journal_entries set occurred_at = ($2::timestamp at time zone 'Africa/Cairo') where id = $1`, [e, when]);
    await admin(`set session_replication_role = origin`);
    return e;
  };
  const totals = async (where: string, params: unknown[]) => {
    const r = (await admin(`select coalesce(sum(l.debit), 0)::bigint d, coalesce(sum(l.credit), 0)::bigint c from journal_lines l join journal_entries e on e.id = l.entry_id where ${where}`, params)).rows[0];
    return { d: Number(r.d), c: Number(r.c) };
  };

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ax-o-${tag}@a.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل التصدير')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'X2', null, null)`, [B2]);
    const box = async (b: string) => (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, b])).rows[0].id;
    cash = await box(main);
    cash2 = await box(B2);
    const rent = (await admin(`select id from accounts where shop_id = $1 and code = 'exp_rent'`, [shop])).rows[0].id;
    const invite = async (k: string, preset: string) => {
      const role = (await admin(`select id from roles where shop_id = $1 and preset = $2`, [shop, preset])).rows[0].id;
      const em = `ax-${k}-${tag}@a.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids, branch_ids) values (gen_random_uuid(), $1, $2, 'reception', $3, $4)`, [em, k, [role], [main]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [k]);
      return u;
    };
    A = await invite('acc', 'accountant');
    R = await invite('rec', 'reception');
    X = await user(`ax-x-${tag}@a.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), '=عميل "التصدير"', '01012340000')`, [cust]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'service', 'خدمة، بفاصلة')`, [srv]);
    E.cap = await at((await as(O, `select owner_capital($1, $2, 900000) e`, [id(), cash])).rows[0].e, `${DAY} 09:00`);
    E.sale = await at((await as(O, `select record_sale($1, $2::jsonb, $3, $4) e`, [id(), JSON.stringify([{ item: srv, qty: 3, price: 15025 }]), cash, cust])).rows[0].e, `${DAY} 10:00`);
    saleNo = Number((await admin(`select entry_no from journal_entries where id = $1`, [E.sale])).rows[0].entry_no);
    const line = (await admin(`select id from sale_lines where entry_id = $1`, [E.sale])).rows[0].id;
    E.ret = await at((await as(O, `select sale_line_return($1, $2, 1, $3, true, 'رجع') e`, [id(), line, cash])).rows[0].e, `${DAY} 11:00`);
    E.pay = await at((await as(O, `select record_payment($1, $2, $3, 20001) e`, [id(), cust, cash])).rows[0].e, `${DAY} 23:59:59`);
    E.next = await at((await as(O, `select record_expense($1, $2, $3, 777) e`, [id(), rent, cash])).rows[0].e, '2026-08-11 00:00');
    E.first = await at((await as(O, `select record_expense($1, $2, $3, 333) e`, [id(), rent, cash])).rows[0].e, `${DAY} 00:00`);
    E.b2 = await at((await as(O, `select record_payment($1, $2, $3, 5000) e`, [id(), cust, cash2], B2)).rows[0].e, `${DAY} 12:00`);
  }, 60_000);
  afterAll(async () => db?.end());

  it('مطابق للقيود بالقرش: الإجمالي، وسطر سطر، والفترة بتوقيت القاهرة (أول اليوم داخل، وأول بكرة بره)', async () => {
    const o = await exp(O);
    const t = await totals(`e.shop_id = $1 and e.id = any($2)`, [shop, [E.cap, E.sale, E.ret, E.pay, E.first, E.b2]]);
    expect([o.debit, o.credit]).toEqual([t.d, t.c]);
    expect(o.debit).toBe(o.credit);
    expect(o.lines.reduce((a, l) => a + l.debit, 0)).toBe(o.debit);
    expect(o.lines.some((l) => l.debit === 777)).toBe(false);
    expect(o.lines.some((l) => l.debit === 333)).toBe(true);
    expect(o.restricted).toBe(false);
    // بعد بكرة: المصروف بس
    expect((await exp(O, '2026-08-11', '2026-08-11')).debit).toBe(777);
    expect(await exp(O, '2025-01-01', '2025-01-31')).toMatchObject({ lines: [], payments: [], sales: [], debit: 0, credit: 0 });
  });

  it('المدفوعات والبيع والمرتجع بأسماء عربي وكسور، والنص زي ما هو (الحماية في ملف التصدير)', async () => {
    const o = await exp(O, DAY, DAY, main);
    expect(o.payments).toEqual([expect.objectContaining({ amount: 20001, customer: '=عميل "التصدير"', reversed: false, method: 'cash' })]);
    expect(o.sales.map((s) => [s.item, s.qty, s.amount, s.return_of])).toEqual([
      ['خدمة، بفاصلة', 3, 45075, null],
      ['خدمة، بفاصلة', 1, 15025, saleNo],
    ]);
  });

  it('الفرع: كل فرع قيوده بس', async () => {
    const o = await exp(O, DAY, DAY, B2);
    expect(o.debit).toBe(5000);
    expect((await exp(O, DAY, DAY, main)).debit + o.debit).toBe((await exp(O)).debit);
  });

  it('المحاسب فرعه بس ومن غير رأس المال والمرتبات، والاستقبال لأ، وسحب "يصدّر" بيمنع', async () => {
    for (const b of [null, B2, main]) {
      const o = await exp(A, DAY, DAY, b);
      expect(o.branch).toBe(main);
      expect(o.restricted).toBe(true);
      expect(o.debit).toBe(o.credit);
      expect(o.lines.some((l) => ['capital', 'salary', 'advance'].includes(l.source))).toBe(false);
      const t = await totals(`e.id = any($1)`, [[E.sale, E.ret, E.pay, E.first]]);
      expect(o.debit).toBe(t.d);
    }
    await expect(exp(R)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'export', false)`, [A]);
    await expect(exp(A)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'export', null)`, [A]);
    // من غير صلاحية العملاء: الاسم ما بيطلعش
    await as(O, `select set_staff_override($1, 'customers', 'view', false)`, [A]);
    const o = await exp(A);
    expect(JSON.stringify(o)).not.toContain('عميل');
    await as(O, `select set_staff_override($1, 'customers', 'view', null)`, [A]);
  });

  it('مدخلات غلط، ومحل تاني فاضي، والتصدير في سجل النشاط', async () => {
    for (const [f, t] of [['2026-08-11', '2026-08-10'], ['2024-01-01', '2026-01-01'], [null, DAY], [DAY, null]] as const) await expect(exp(O, f as string, t as string)).rejects.toThrow(/E_BAD_INPUT/);
    await expect(exp(O, DAY, DAY, id())).rejects.toThrow(/E_BAD_BRANCH/);
    await expect(exp(X, DAY, DAY, B2)).rejects.toThrow(/E_BAD_BRANCH/);
    expect((await exp(X)).lines).toEqual([]);
    expect((await admin(`select count(*)::int n from audit_log where shop_id = $1 and action = 'accountant_export' and actor_id = $2`, [shop, A])).rows[0].n).toBe(4);
    expect((await admin(`select has_function_privilege('anon', 'public.accountant_export(date,date,uuid)', 'execute') x`)).rows[0].x).toBe(false);
  });
});
