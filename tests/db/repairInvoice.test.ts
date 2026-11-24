// (19) 0081: فاتورة صيانة ثابتة: رقم مستقل متسلسل لكل فرع، وتاريخ إصدار ما بيتغيرش، والبيانات زي ما كانت وقت الإصدار
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
interface Inv {
  id: string;
  invoice_no: string;
  issued_at: string;
  order_no: string;
  customer: string;
  model: string;
  total: number;
  vat: number;
  net: number;
  vat_no: string | null;
  parts: { name: string; qty: number }[];
  reversed?: boolean;
}

d('فاتورة الصيانة الثابتة', () => {
  let O = '';
  let R = '';
  let R2 = '';
  let C = '';
  let T = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cust = '';
  const part = id();
  let late = '';
  const year = () => admin(`select extract(year from (now() at time zone 'Africa/Cairo'))::int y`).then((r) => r.rows[0].y as number);
  const invoice = async (u: string, dv: string, issue = true) => (await as(u, `select repair_invoice($1, $2) j`, [dv, issue])).rows[0].j as Inv | null;
  const vat = (on_: boolean) => admin(`update shops set extras = case when $2 then jsonb_set(coalesce(extras, '{}'), '{vat}', '{"enabled":true,"rate_bp":1400,"reg_no":"99-1"}') else extras - 'vat' end where id = $1`, [shop, on_]);
  const device = async (cost: number | null, deliver = true, br = main, withPart = false) => {
    const x = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'شاشة')`, [x, cust], br);
    if (cost != null) {
      await as(O, `insert into device_costs(shop_id, device_id, final_cost) values (gen_random_uuid(), $1, $2)`, [x, cost], br);
    }
    if (withPart) await as(O, `select use_part($1, $2, $3, 1)`, [id(), x, part], br);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [x, st], br);
    if (deliver) await as(O, `select deliver_on_credit($1)`, [x], br);
    return x;
  };

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ri-o-${tag}@r.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الفواتير الثابتة')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'R2', null, null)`, [B2]);
    const invite = async (k: string, preset: string, br: string) => {
      const role = (await admin(`select id from roles where shop_id = $1 and preset = $2`, [shop, preset])).rows[0].id;
      const em = `ri-${k}-${tag}@r.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4, $5)`, [em, k, preset === 'technician' ? 'technician' : 'reception', [role], [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [k]);
      return u;
    };
    R = await invite('r', 'reception', main);
    R2 = await invite('r2', 'reception', B2);
    C = await invite('c', 'cashier', main);
    T = await invite('t', 'technician', main);
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الفاتورة', '01033344455')`, [cust]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة A54')`, [part]);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: part, qty: 5, unit_cost: 60000 }])], main);
  }, 60_000);
  afterAll(async () => db?.end());

  it('قبل التسليم أو من غير تكلفة: مفيش فاتورة. وبعد التسليم رقم متسلسل بالفرع', async () => {
    const y = await year();
    const a = await device(50000, false);
    await expect(invoice(R, a)).rejects.toThrow(/E_NO_INVOICE/);
    expect(await invoice(R, a, false)).toBeNull();
    const free = await device(0);
    await expect(invoice(R, free)).rejects.toThrow(/E_NO_INVOICE/);
    await as(O, `select deliver_on_credit($1)`, [a]);
    expect(await invoice(R, a, false)).toBeNull();
    expect((await invoice(R, a))!.invoice_no).toBe(`F-${y}-0001`);
    const b = await device(60000);
    expect((await invoice(R, b))!.invoice_no).toBe(`F-${y}-0002`);
    const c = await device(70000, true, B2);
    expect((await invoice(R2, c))!.invoice_no).toBe(`R2-F-${y}-0001`);
    // بادئة اتنقلت لفرع تاني: الترقيم بيكمّل من غير تكرار
    const B3 = id();
    await as(O, `select save_branch($1, 'فرع تاني', 'RX', null, null)`, [B2]);
    await as(O, `select save_branch($1, 'فرع تالت', 'R2', null, null)`, [B3]);
    expect((await invoice(O, await device(1500, true, B3)))!.invoice_no).toBe(`R2-F-${y}-0002`);
    expect((await invoice(O, await device(1600, true, B2)))!.invoice_no).toBe(`RX-F-${y}-0001`);
    // راجع ضمان من غير ما فاتورته تصدر: تستنى لحد ما يتسلّم
    await as(O, `update devices set status = 'warranty_return' where id = $1`, [await (async () => (late = await device(2500)))()]);
    await expect(invoice(R, late)).rejects.toThrow(/E_NO_INVOICE/);
    // سجل النشاط فيه الرقم بس
    const log = (await admin(`select after from audit_log where shop_id = $1 and entity = 'repair_invoices'`, [shop])).rows;
    expect(log.length).toBeGreaterThan(0);
    expect(JSON.stringify(log)).not.toContain('عميل');
  });

  it('ثابتة: تغيير العميل أو الموديل أو الضريبة بعدها ما بيغيّرش حاجة، وإعادة الطباعة نفس الرقم والتاريخ، والمبلغ من القيد', async () => {
    await vat(true);
    const x = await device(114000, true, main, true);
    const first = (await invoice(R, x))!;
    expect(first).toMatchObject({ customer: 'عميل الفاتورة', model: 'A54', total: 114000, vat: 14000, net: 100000, vat_no: '99-1', parts: [{ name: 'شاشة A54', qty: 1 }] });
    await vat(false);
    await as(O, `update customers set name = 'اسم جديد' where id = $1`, [cust]);
    await as(O, `update items set name = 'اسم قطعة جديد' where id = $1`, [part]);
    await new Promise((r) => setTimeout(r, 20));
    expect(await invoice(O, x)).toEqual(first);
    expect(await invoice(R, x, false)).toEqual(first);
    await as(O, `update customers set name = 'عميل الفاتورة' where id = $1`, [cust]);
    await expect(admin(`update repair_invoices set invoice_no = 'x' where id = $1`, [first.id])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    await expect(admin(`delete from repair_invoices where id = $1`, [first.id])).rejects.toThrow();
    await expect(as(O, `insert into repair_invoices(shop_id) values (gen_random_uuid())`)).rejects.toThrow(/permission denied/);
  });

  it('إلغاء التسليم: الفاتورة القديمة ملغية، والجديد ليه رقم جديد. ومرتجع الضمان بنفس فاتورته', async () => {
    const x = await device(40000);
    const a = (await invoice(R, x))!;
    const e = (await admin(`select entry_id from repair_invoices where id = $1`, [a.id])).rows[0].entry_id;
    await as(O, `update devices set status = 'warranty_return' where id = $1`, [x]);
    for (const st of ['in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [x, st]);
    await as(O, `select deliver_on_credit($1)`, [x]);
    expect((await invoice(R, x))!.id).toBe(a.id);
    await as(O, `update devices set status = 'warranty_return' where id = $1`, [x]);
    await as(O, `select reverse_entry($1, 'غلط')`, [e]);
    for (const st of ['in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [x, st]);
    await as(O, `select deliver_on_credit($1)`, [x]);
    const b = (await invoice(R, x))!;
    expect(b.id).not.toBe(a.id);
    const all = (await as(R, `select repair_invoices_of($1) j`, [x])).rows[0].j as Inv[];
    expect(all.map((v) => [v.invoice_no, v.reversed])).toEqual([[a.invoice_no, true], [b.invoice_no, false]]);
  });

  it('طلبين في نفس اللحظة: لجهاز واحد فاتورة واحدة، ولجهازين رقمين ورا بعض من غير تكرار', async () => {
    const [x, y, z] = [await device(1000), await device(2000), await device(3000)];
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      const q = `select repair_invoice($1) j`;
      const [a, b] = await Promise.all([on(db, O, q, [x]), on(c2, R, q, [x])]);
      expect(a.rows[0].j.id).toBe(b.rows[0].j.id);
      const [m, n] = await Promise.all([on(db, O, q, [y]), on(c2, R, q, [z])]);
      const nums = [m, n].map((r) => Number((r.rows[0].j.invoice_no as string).split('-').at(-1))).sort((p, q2) => p - q2);
      expect(nums[1] - nums[0]).toBe(1);
    } finally {
      await c2.end();
    }
    const seqs = (await admin(`select seq from repair_invoices where shop_id = $1 and prefix = '' order by seq`, [shop])).rows.map((r) => r.seq);
    expect(seqs).toEqual(seqs.map((_, i) => i + 1));
  });

  it('الصلاحيات والفرع والمحل، والنسخة الاحتياطية والترقيم بعد الاسترجاع', async () => {
    const x = await device(9000);
    for (const u of [C, T, R2]) {
      await expect(invoice(u, x)).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select repair_invoices_of($1)`, [x])).rejects.toThrow(/E_FORBIDDEN/);
      expect((await as(u, `select count(*)::int n from repair_invoices where branch_id = $1`, [main])).rows[0].n).toBe(0);
    }
    expect((await as(R, `select count(*)::int n from repair_invoices where branch_id = $1`, [main])).rows[0].n).toBeGreaterThan(0);
    const X = await user(`ri-x-${tag}@r.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    await expect(invoice(X, x)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(X, `select repair_invoices_of($1)`, [x])).rejects.toThrow(/E_NOT_FOUND/);
    expect((await admin(`select has_function_privilege('anon', 'public.repair_invoice(uuid,boolean)', 'execute') x`)).rows[0].x).toBe(false);
    const backup = (await as(O, `select export_backup() b`)).rows[0].b;
    await as(X, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const s2 = (await admin(`select shop_id from profiles where id = $1`, [X])).rows[0].shop_id;
    const list = async (s: string) => (await admin(`select invoice_no, issued_at, data from repair_invoices where shop_id = $1 order by invoice_no, issued_at`, [s])).rows;
    expect(await list(s2)).toEqual(await list(shop));
  });
});
