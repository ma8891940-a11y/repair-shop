// 0087: "المرتبات ورأس المال" صلاحية لوحدها (مقفولة): من غيرها الموظف ما يشوفش التفاصيل من أي دالة ولا من الجداول، والخزنة بتقفل صح
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
const FROM = '2000-01-01';
const TO = '2999-01-01';
const SECRET = 'سر-المرتب';
interface Mv {
  entry_id: string;
  source_type: string;
  memo: string | null;
  by: string | null;
  amount: number;
  balance: number;
}

d('المرتبات ورأس المال', () => {
  let O = '';
  let R = '';
  let T = '';
  let shop = '';
  let cash = '';
  const ac: Record<string, string> = {};
  const priv: string[] = [];
  const grant = (op: string, v: boolean | null, sec = 'finance', u = R) => as(O, `select set_staff_override($1, $2, $3, $4)`, [u, sec, op, v]);
  const val = async (u: string, sql: string, p: unknown[] = []) => (await as(u, sql, p)).rows[0].v;
  const box = async (u: string) => (await val(u, `select statement('cashbox', $1, '${FROM}', '${TO}') v`, [cash])) as { opening: number; moves: Mv[] };
  const PRIVATE = ['advances', 'salaries_payable', 'capital', 'drawings', 'partners_capital', 'partners_current', 'retained', 'exp_salaries'];
  const reports = async (u: string) => ({
    tb: (await as(u, `select code, balance::bigint from trial_balance()`)).rows as { code: string; balance: string }[],
    pl: (await as(u, `select code, amount::bigint from pl_breakdown('${FROM}', '${TO}')`)).rows as { code: string; amount: string }[],
  });

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pf-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل السرية')).shop_id s`)).rows[0].s;
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) ac[r.code] = r.id;
    cash = ac.cash_cash;
    for (const role of ['reception', 'technician']) {
      const em = `pf-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    const e = async (sql: string, p: unknown[]) => {
      const x = (await as(O, sql, p)).rows[0].e as string;
      priv.push(x);
      return x;
    };
    await e(`select owner_capital($1, $2, 1000000, $3) e`, [id(), cash, SECRET]);
    await e(`select accrue_salary($1, $2, 300000, $3) e`, [id(), T, SECRET]);
    await e(`select pay_salary($1, $2, $3, 250000, $4) e`, [id(), T, cash, SECRET]);
    await e(`select give_advance($1, $2, $3, 10000, $4) e`, [id(), T, cash, SECRET]);
    await e(`select owner_drawing($1, $2, 20000, $3) e`, [id(), cash, SECRET]);
    // مرتب اتسجل كمصروف مباشر، وقيد مرتب اتلغى
    await e(`select record_expense($1, $2, $3, 7000, $4) e`, [id(), ac.exp_salaries, cash, SECRET]);
    const adv = await e(`select give_advance($1, $2, $3, 500, $4) e`, [id(), T, cash, SECRET]);
    await e(`select reverse_entry($1, $2) e`, [adv, SECRET]);
    // عادي: إيجار وبيع
    await as(O, `select record_expense($1, $2, $3, 40000, 'إيجار المحل')`, [id(), ac.exp_rent, cash]);
    const srv = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'service', 'خدمة')`, [srv]);
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: srv, qty: 1, price: 90000 }]), cash]);
    for (const op of ['view', 'export']) await grant(op, true);
    await grant('view', true, 'audit');
    await grant('view', true, 'cashbox');
  }, 60_000);
  afterAll(async () => db?.end());

  it('الصلاحية مقفولة لكل الأدوار الجاهزة، والأقسام 18', async () => {
    expect((await admin(`select count(*)::int n from roles where shop_id = $1 and perms ? 'private_finance'`, [shop])).rows[0].n).toBe(0);
    expect(Object.keys(await val(O, `select my_perms() v`))).toHaveLength(18);
  });

  it('من غيرها: الميزان والأرباح من غير المرتبات ورأس المال، والأرقام متطابقة في كل مكان', async () => {
    const o = await reports(O);
    expect(o.tb.map((r) => r.code)).toEqual(expect.arrayContaining(['capital', 'drawings', 'advances', 'salaries_payable', 'exp_salaries']));
    const r = await reports(R);
    expect(r.tb.filter((x) => PRIVATE.includes(x.code))).toEqual([]);
    expect(r.tb).toEqual(o.tb.filter((x) => !PRIVATE.includes(x.code)));
    expect(r.pl).toEqual(o.pl.filter((x) => x.code !== 'exp_salaries'));
    const fp = await val(R, `select financial_position('${FROM}', '${TO}') v`);
    expect([fp.revenue, fp.expenses, fp.profit]).toEqual([90000, 40000, 50000]);
    expect(fp.daily.reduce((a: number, x: { expenses: number }) => a + x.expenses, 0)).toBe(40000);
    const fo = await val(O, `select financial_position('${FROM}', '${TO}') v`);
    expect([fo.expenses, fo.profit]).toEqual([347000, -257000]);
    // الخزنة نفسها زي ما هي
    expect(fp.cash).toBe(fo.cash);
    // مؤشرات الفروع (قسم التقارير): المصروفات من غير المرتبات
    await grant('view', true, 'reports');
    const opex = async (u: string) => Number((await as(u, `select opex from branch_kpis('${FROM}', '${TO}')`)).rows[0].opex);
    expect([await opex(R), await opex(O)]).toEqual([40000, 347000]);
  });

  it('كشف الخزنة: "حركة خاصة" بالمبلغ بس، والرصيد ونفس عدد السطور، وإقفال الدرج مظبوط', async () => {
    const o = await box(O);
    const r = await box(R);
    expect(r.opening).toBe(o.opening);
    expect(r.moves.map((m) => [m.entry_id, m.amount, m.balance])).toEqual(o.moves.map((m) => [m.entry_id, m.amount, m.balance]));
    const hidden = r.moves.filter((m) => priv.includes(m.entry_id));
    expect(hidden).toHaveLength(7);
    for (const m of hidden) expect(m).toMatchObject({ source_type: 'private', source_id: null, memo: null, by: null, device_id: null, order_no: null, reverses: null });
    expect(r.moves.filter((m) => m.source_type !== 'private').map((m) => m.source_type).sort()).toEqual(['expense', 'sale']);
    expect(JSON.stringify(r)).not.toContain(SECRET);
    // الرصيد = مجموع الحركات = اللي الدرج بيقفل عليه
    const bal = r.moves.reduce((a, m) => a + m.amount, r.opening);
    expect(r.moves.at(-1)!.balance).toBe(bal);
    await admin(`update accounts set holder_id = $2 where id = $1`, [cash, R]);
    const c = await val(R, `select close_drawer($1, $2, $3) v`, [id(), cash, bal]);
    expect(c).toEqual({ expected: bal, counted: bal, diff: 0 });
    // التقرير اليومي: نفس التسوية ومن غير تفاصيل
    const day = await val(R, `select day_cash_report('${FROM}', '${TO}') v`);
    const b = day.cashboxes.find((x: { id: string }) => x.id === cash);
    expect([b.opening + b.in - b.out, b.closing]).toEqual([bal, bal]);
    expect(b.entries.filter((x: { source_type: string }) => x.source_type === 'private')).toHaveLength(7);
    expect(JSON.stringify(day)).not.toContain(SECRET);
  });

  it('السيرفر: الجداول والدوال التانية ما بتسرّبش', async () => {
    for (const t of ['journal_entries', 'journal_lines']) {
      const col = t === 'journal_entries' ? 'id' : 'entry_id';
      expect((await as(R, `select count(*)::int n from ${t} where ${col} = any($1)`, [priv])).rows[0].n).toBe(0);
      expect((await as(R, `select count(*)::int n from ${t}`)).rows[0].n).toBeGreaterThan(0);
    }
    const audit = (await as(R, `select entity, entity_id, before, after from audit_log`)).rows;
    expect(audit.length).toBeGreaterThan(0);
    expect(JSON.stringify(audit)).not.toContain(SECRET);
    const bl = (await as(R, `select account_id from branch_lines()`)).rows.map((r) => r.account_id);
    for (const c of PRIVATE) if (ac[c]) expect(bl).not.toContain(ac[c]);
    expect(JSON.stringify(await val(R, `select accountant_export(current_date - 2, current_date + 2) v`))).not.toContain(SECRET);
    await expect(as(R, `select * from party_balances('employees')`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select statement('employee', $1, '${FROM}', '${TO}')`, [T])).rejects.toThrow(/E_FORBIDDEN/);
    // حتى بصلاحية التصحيح: ما يقراش القيد ولا يلغيه (ومعاه المصروف اللي على حساب المرتبات)
    for (const s of ['finance', 'cashbox', 'expenses', 'staff', 'settings']) await grant('delete', true, s);
    for (const e of priv) {
      await expect(as(R, `select entry_args($1)`, [e])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(R, `select reverse_entry($1, 'x')`, [e])).rejects.toThrow(/E_FORBIDDEN/);
    }
    for (const s of ['finance', 'cashbox', 'expenses', 'staff', 'settings']) await grant('delete', null, s);
  });

  it('بالصلاحية: المحاسب يشوف التفاصيل، وصافي القيمة والشركاء لسه لصاحب المحل، والفني لأ حتى باستثناء', async () => {
    await grant('view', true, 'private_finance');
    expect(await reports(R)).toEqual(await reports(O));
    const s = await box(R);
    expect(s.moves.map((m) => m.source_type)).toEqual((await box(O)).moves.map((m) => m.source_type));
    expect(JSON.stringify(s)).toContain(SECRET);
    expect((await as(R, `select count(*)::int n from journal_entries where id = any($1)`, [priv])).rows[0].n).toBe(priv.length);
    expect((await as(R, `select * from party_balances('employees')`)).rows.length).toBeGreaterThan(0);
    expect((await val(R, `select statement('employee', $1, '${FROM}', '${TO}') v`, [T])).moves.length).toBeGreaterThan(0);
    const fp = await val(R, `select financial_position('${FROM}', '${TO}') v`);
    expect(fp).toMatchObject({ expenses: 347000, net_worth: null, equity_parts: null });
    await expect(as(R, `select statement('partner', $1, '${FROM}', '${TO}')`, [T])).rejects.toThrow(/E_FORBIDDEN/);
    // شريك: حساباته وقيوده لصاحب المحل بس حتى بالصلاحية
    const pt = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'شريك', 1000)`, [pt]);
    const pe = (await as(O, `select partner_deposit($1, $2, $3, 5000, 'شراكة') e`, [id(), pt, cash])).rows[0].e;
    expect((await reports(O)).tb.map((x) => x.code)).toContain('partners_capital');
    expect((await reports(R)).tb.map((x) => x.code)).not.toContain('partners_capital');
    expect((await as(R, `select count(*)::int n from journal_lines where entry_id = $1`, [pe])).rows[0].n).toBe(0);
    expect((await box(R)).moves.find((m) => m.entry_id === pe)).toMatchObject({ source_type: 'private', memo: null, amount: 5000 });
    expect((await as(R, `select count(*)::int n from audit_log where entity = 'partners'`)).rows[0].n).toBe(0);
    // لسه ما يصرفش مرتبات
    await expect(as(R, `select give_advance($1, $2, $3, 100)`, [id(), T, cash])).rejects.toThrow(/E_FORBIDDEN/);
    for (const sec of ['finance', 'private_finance']) await grant('view', true, sec, T);
    await expect(as(T, `select * from trial_balance()`)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(T, `select count(*)::int n from journal_entries`)).rows[0].n).toBe(0);
    // اتشالت: قفل على طول
    await grant('view', null, 'private_finance');
    expect(JSON.stringify(await box(R))).not.toContain(SECRET);
  });
});
