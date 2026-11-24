// (5) 0076: أعمار المديونية: 0–29 و30–59 و60+، الشرايح ما تتداخلش ومجموعها = الرصيد، لحد تاريخ معيّن
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
const AS_OF = '2026-09-30';

d('أعمار المديونية', () => {
  let O = '';
  let R = '';
  let T = '';
  let X = '';
  let shop = '';
  let main = '';
  let cash = '';
  let sup = '';
  const B2 = id();
  const srv = id();
  const part = id();
  let n = 0;
  const customer = async () => {
    const c = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), $2, $3)`, [c, `عميل ${++n}`, `0105555${String(1000 + n)}`]);
    return c;
  };
  /** القيد اتعمل وقت معيّن (بتوقيت القاهرة): القيود ما بتتعدلش، فالتاريخ بيتظبط والتريجرات مقفولة في قاعدة الاختبار */
  const at = async (e: string, when: string) => {
    await admin(`set session_replication_role = replica`);
    await admin(`update journal_entries set occurred_at = ($2::timestamp at time zone 'Africa/Cairo') where id = $1`, [e, when]);
    await admin(`set session_replication_role = origin`);
    return e;
  };
  const before = (days: number, time = '12:00') => `${new Date(Date.parse(`${AS_OF}T00:00:00Z`) - days * 86400_000).toISOString().slice(0, 10)} ${time}`;
  const sell = async (c: string, amount: number, when: string, b = main) => at((await as(O, `select record_sale($1, $2::jsonb, null, $3) e`, [id(), JSON.stringify([{ item: srv, qty: 1, price: amount }]), c], b)).rows[0].e, when);
  const pay = async (c: string, amount: number, when: string) => at((await as(O, `select record_payment($1, $2, $3, $4) e`, [id(), c, cash, amount], main)).rows[0].e, when);
  const aging = async (u = O, kind = 'customers', asOf: string | null = AS_OF, b: string | null = null) =>
    (await as(u, `select party_id, balance::bigint, d0, d30, d60, oldest::text, as_of::text from debt_aging($1, $2, $3)`, [kind, asOf, b])).rows.map((r) => ({ ...r, balance: Number(r.balance), d0: Number(r.d0), d30: Number(r.d30), d60: Number(r.d60) }));
  const one = async (c: string, asOf = AS_OF) => (await aging(O, 'customers', asOf)).find((r) => r.party_id === c);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ag-o-${tag}@a.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الأعمار')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'G2', null, null)`, [B2]);
    cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    for (const role of ['reception', 'technician'] as const) {
      const em = `ag-${role}-${tag}@a.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, role, role, [main]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    X = await user(`ag-x-${tag}@a.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'service', 'خدمة'), ($2, gen_random_uuid(), 'part', 'قطعة')`, [srv, part]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('النهارده و29 و30 و59 و60 يوم: كل واحد في شريحته، ومجموع الشرايح = الرصيد', async () => {
    const c = await customer();
    for (const [days, amount] of [[0, 1], [29, 20], [30, 300], [59, 4000], [60, 50000]] as const) await sell(c, amount, before(days));
    expect(await one(c)).toEqual({ party_id: c, balance: 54321, d0: 21, d30: 4300, d60: 50000, oldest: before(60).slice(0, 10), as_of: AS_OF });
  });

  it('حدود اليوم بتوقيت القاهرة، والعملية بعد التاريخ مش داخلة', async () => {
    const c = await customer();
    await sell(c, 100, before(30, '00:00'));
    await sell(c, 7, before(29, '23:59:59'));
    await sell(c, 900, before(-1, '00:00'));
    expect(await one(c)).toMatchObject({ balance: 107, d0: 7, d30: 100, d60: 0 });
  });

  it('دفعة جزئية بتغطي الأقدم الأول بالقرش، واللي خلّص أو ليه رصيد مش في الكشف', async () => {
    const c = await customer();
    await sell(c, 10001, before(70));
    await sell(c, 5000, before(40));
    await sell(c, 333, before(5));
    await pay(c, 12002, before(1));
    expect(await one(c)).toMatchObject({ balance: 3332, d0: 333, d30: 2999, d60: 0, oldest: before(40).slice(0, 10) });
    // التقرير القديم زي ما كان يومها (قبل الدفعة)
    expect(await one(c, before(2).slice(0, 10))).toMatchObject({ balance: 15334, d60: 10001 });
    await pay(c, 3332, before(0));
    expect(await one(c)).toBeUndefined();
    await pay(c, 500, before(0));
    expect(await one(c)).toBeUndefined();
  });

  it('إلغاء بيع جديد ما يغطيش الدين القديم، والإلغاء بعد التاريخ ما يغيّرش تقرير قديم', async () => {
    const c = await customer();
    await sell(c, 1000, before(80));
    const e = await sell(c, 1000, before(10));
    await at((await as(O, `select reverse_entry($1, 'غلط') r`, [e])).rows[0].r, before(3));
    expect(await one(c)).toMatchObject({ balance: 1000, d0: 0, d60: 1000 });
    expect(await one(c, before(4).slice(0, 10))).toMatchObject({ balance: 2000, d0: 1000, d60: 1000 });
  });

  it('مرتجع بفاتورة من بيع جديد بيقلّله هو مش الدين القديم، وإلغاء دفعة بيرجّع الدين بعمره', async () => {
    const c = await customer();
    await sell(c, 1000, before(80));
    const e = await sell(c, 5000, before(10));
    const line = (await admin(`select id from sale_lines where entry_id = $1`, [e])).rows[0].id;
    await at((await as(O, `select sale_line_return($1, $2, 1, null, false, 'رجع') e`, [id(), line], main)).rows[0].e, before(2));
    expect(await one(c)).toMatchObject({ balance: 1000, d0: 0, d60: 1000 });
    expect(await one(c, before(3).slice(0, 10))).toMatchObject({ balance: 6000, d0: 5000, d60: 1000 });
    const p = await pay(c, 400, before(1));
    expect(await one(c)).toMatchObject({ balance: 600, d60: 600 });
    await at((await as(O, `select reverse_entry($1, 'غلط') r`, [p])).rows[0].r, before(0));
    expect(await one(c)).toMatchObject({ balance: 1000, d60: 1000 });
  });

  it('الموردين: الشرا الآجل، والسداد بيغطي الأقدم', async () => {
    const buy = async (q: number, when: string) => at((await as(O, `select record_purchase($1, $2, $3::jsonb, null) e`, [id(), sup, JSON.stringify([{ item: part, qty: q, unit_cost: 1000 }])], main)).rows[0].e, when);
    await buy(5, before(65));
    await buy(2, before(31));
    await at((await as(O, `select pay_supplier($1, $2, $3, 5500) e`, [id(), sup, cash], main)).rows[0].e, before(0));
    expect((await aging(O, 'suppliers')).find((r) => r.party_id === sup)).toMatchObject({ balance: 1500, d0: 0, d30: 1500, d60: 0 });
  });

  it('الإجمالي لكل العملاء = الأرصدة الموجبة في party_balances (التاريخ النهارده)', async () => {
    const c = await customer();
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item: srv, qty: 1, price: 777 }]), c], main);
    const rows = await aging(O, 'customers', null);
    const pb = (await as(O, `select balance from party_balances('customers')`)).rows.map((r) => Number(r.balance)).filter((b) => b > 0);
    expect(rows.reduce((a, r) => a + r.balance, 0)).toBe(pb.reduce((a, b) => a + b, 0));
    for (const r of rows) expect(r.d0 + r.d30 + r.d60).toBe(r.balance);
    expect(rows.find((r) => r.party_id === c)).toMatchObject({ d0: 777 });
  });

  it('الصلاحيات والفرع والمحل: من غير الوضع المالي لأ، والموظف فرعه بس، ومحل تاني فاضي', async () => {
    const c = await customer();
    await sell(c, 4000, before(5), B2);
    await sell(c, 600, before(5), main);
    for (const u of [R, T]) await expect(aging(u)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [R]);
    for (const b of [null, B2, main]) expect((await aging(R, 'customers', AS_OF, b)).find((r) => r.party_id === c)).toMatchObject({ balance: 600 });
    await as(O, `select set_staff_override($1, 'finance', 'view', null)`, [R]);
    expect((await aging(O, 'customers', AS_OF, B2)).map((r) => r.party_id)).toEqual([c]);
    expect((await aging(O)).find((r) => r.party_id === c)).toMatchObject({ balance: 4600 });
    expect(await aging(X)).toEqual([]);
    await expect(aging(O, 'customers', '2999-01-01')).rejects.toThrow(/E_BAD_INPUT/);
    for (const k of ['employees', '', null]) await expect(aging(O, k as string)).rejects.toThrow(/E_BAD_INPUT/);
  });
});
