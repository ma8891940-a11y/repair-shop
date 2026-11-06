// المرحلة 3: اختبارات القبول الإلزامية للدفتر (docs/phase-3-ledger.md)
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;

const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as<T extends pg.QueryResultRow = pg.QueryResultRow>(uid: string, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    const r = await db.query<T>(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
/** بصلاحيات قاعدة البيانات الكاملة بس باسم مستخدم (عشان نجرب الدوال الداخلية ونكسر الحماية عن قصد) */
async function asSuper(uid: string, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
async function user(email: string) {
  const id = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [id, email]);
  return id;
}
const tag = randomUUID().slice(0, 8);
const id = () => randomUUID();
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();

interface Position {
  cash: number;
  receivables: number;
  payables: number;
  inventory: number;
  revenue: number;
  expenses: number;
  profit: number;
  net_worth: number;
  balanced: boolean;
  debits: number;
  credits: number;
  unbalanced_entries: number;
  equation: { assets: number; liabilities: number; equity: number; earnings: number };
  cashboxes: { id: string; code: string; balance: number }[];
  top_customers: { id: string; balance: number }[];
  top_suppliers: { id: string; balance: number }[];
  by_method: Record<string, number>;
}

async function newShop(name: string) {
  const owner = await user(`${name}-o-${tag}@l.test`);
  const shop = (await as(owner, `select (bootstrap_account('صاحب', $1)).shop_id as s`, [name])).rows[0].s as string;
  return { owner, shop };
}
async function staff(owner: string, name: string, role: 'reception' | 'technician') {
  const em = `${name}-${tag}@l.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}
const acc = async (u: string, code: string) => (await as(u, `select id from accounts where code = $1`, [code])).rows[0].id as string;
const pos = async (u: string) => (await as(u, `select financial_position($1, $2) as p`, [FROM(), TO()])).rows[0].p as Position;
const balanceOf = async (u: string, code: string) => (await pos(u)).cashboxes.find((c) => c.code === code)!.balance;

let A = { owner: '', shop: '' };
let rec = '';
let tech = '';
let cash = '';
let wallet = '';
let c1 = '';
let c2 = '';
let s1 = '';
let part = '';
let accessory = '';
let d1 = '';
let d2 = '';

d('المرحلة 3: الدفتر المحاسبي', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    A = await newShop('محل الدفتر');
    await as(A.owner, `update shops set payment_methods = array['cash', 'wallet']`);
    rec = await staff(A.owner, 'سارة', 'reception');
    tech = await staff(A.owner, 'كريم', 'technician');
    cash = await acc(A.owner, 'cash_cash');
    wallet = await acc(A.owner, 'cash_wallet');
    [c1, c2, s1, part, accessory, d1, d2] = [id(), id(), id(), id(), id(), id(), id()];
    await as(A.owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل واحد', '01011111111'), ($2, gen_random_uuid(), 'عميل اتنين', '01022222222')`, [c1, c2]);
    await as(A.owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد القطع')`, [s1]);
    await as(A.owner, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة', 45000), ($2, gen_random_uuid(), 'accessory', 'جراب', 7500)`, [part, accessory]);
    await as(A.owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'شاشة'), ($3, $4, 'Oppo', 'A78', 'شحن')`, [d1, c1, d2, c2]);
    await as(A.owner, `insert into device_costs(shop_id, device_id) values (gen_random_uuid(), $1), (gen_random_uuid(), $2)`, [d1, d2]);
    // الاستقبال مسؤولة عن الدرج
    await as(A.owner, `select update_account($1, p_holder => $2)`, [cash, rec]);
  });
  afterAll(async () => db?.end());

  it('المحل الجديد بياخد الحسابات الأساسية وخزنة لكل طريقة دفع', async () => {
    const r = await as(A.owner, `select code from accounts where code is not null order by code`);
    const codes = r.rows.map((x) => x.code);
    for (const c of ['ar', 'ap', 'inventory', 'capital', 'drawings', 'rev_repair', 'cogs', 'exp_rent']) expect(codes).toContain(c);
    // الخزن الخمسة الأساسية: الدرج، فودافون كاش، InstaPay، البنك، الكارت
    for (const c of ['cash_cash', 'cash_wallet', 'cash_instapay', 'cash_bank_transfer', 'cash_card']) expect(codes).toContain(c);
  });

  it('قبول 3: يوم كامل فيه 22 عملية، وكل أرقام الوضع المالي مطابقة لحساب يدوي، والمعادلة متوازنة', async () => {
    const O = A.owner;
    // 1-2) رأس مال
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash]);
    await as(O, `select owner_capital($1, $2, 500000)`, [id(), wallet]);
    // 3) شراء آجل: 4 شاشات × 250 + 10 جراب × 30
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), s1, JSON.stringify([{ item: part, qty: 4, unit_cost: 25000 }, { item: accessory, qty: 10, unit_cost: 3000 }])]);
    // 4) شراء نقدي: 2 شاشة × 310 ← المتوسط المرجّح يبقى (100000 + 62000) / 6 = 27000
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), s1, JSON.stringify([{ item: part, qty: 2, unit_cost: 31000 }]), cash]);
    // 5) الفني ركّب شاشة في الجهاز الأول (من غير ما يشوف السعر)
    await as(tech, `select use_part($1, $2, $3, 1)`, [id(), d1, part]);
    const techView = await as(tech, `select name, qty, avg_cost, value, sale_price from items_stock() where id = $1`, [part]);
    expect(techView.rows[0]).toEqual({ name: 'شاشة', qty: '5', avg_cost: null, value: null, sale_price: null });
    // 6) عربون من العميل الأول
    await as(rec, `select record_payment($1, $2, $3, 50000, $4)`, [id(), c1, cash, d1]);
    // 7) التكلفة النهائية 1500، والتسليم ممنوع قبل السداد، وبعدين باقي المبلغ على المحفظة
    await as(O, `update device_costs set final_cost = 150000 where device_id = $1`, [d1]);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [d1, st]);
    await expect(as(rec, `update devices set status = 'delivered' where id = $1`, [d1])).rejects.toThrow(/E_UNPAID/);
    await as(rec, `select record_payment($1, $2, $3, 100000, $4)`, [id(), c1, wallet, d1]);
    // 8) التسليم بيسجل الإيراد
    await as(rec, `update devices set status = 'delivered' where id = $1`, [d1]);
    // 9) الجهاز التاني اتسلّم بالآجل (صاحب المحل بس)
    await as(O, `update device_costs set final_cost = 80000 where device_id = $1`, [d2]);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [d2, st]);
    await expect(as(rec, `select deliver_on_credit($1)`, [d2])).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select deliver_on_credit($1)`, [d2]);
    // 10) بيع 3 جراب نقدي (التكلفة 3 × 3000)
    await as(rec, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: accessory, qty: 3, price: 7500 }]), cash]);
    // 11) بيع شاشة بالآجل للعميل التاني (التكلفة 135000 / 5 = 27000)
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item: part, qty: 1, price: 45000 }]), c2]);
    // 12-13) مصروفات
    await as(O, `select record_expense($1, $2, $3, 300000, 'إيجار الشهر')`, [id(), await acc(O, 'exp_rent'), cash]);
    await as(O, `select record_expense($1, $2, $3, 45050)`, [id(), await acc(O, 'exp_electricity'), wallet]);
    // 14) سداد جزء من المورد
    await as(O, `select pay_supplier($1, $2, $3, 80000)`, [id(), s1, cash]);
    // 15) تحويل من المحفظة للدرج
    await as(O, `select transfer_cash($1, $2, $3, 100000)`, [id(), wallet, cash]);
    // 16-19) مرتب الفني: مستحق 4000، سلفة 500، خصم السلفة، صرف 2000
    await as(O, `select accrue_salary($1, $2, 400000)`, [id(), tech]);
    await as(O, `select give_advance($1, $2, $3, 50000)`, [id(), tech, cash]);
    await as(O, `select settle_advance($1, $2, 50000)`, [id(), tech]);
    await as(O, `select pay_salary($1, $2, $3, 200000)`, [id(), tech, cash]);
    // 20) سحب صاحب المحل
    await as(O, `select owner_drawing($1, $2, 100000)`, [id(), wallet]);
    // 21) دفعة من العميل التاني من غير جهاز
    await as(rec, `select record_payment($1, $2, $3, 30000)`, [id(), c2, cash]);
    // 22) تقفيل الدرج: المتوقع 5105 والمعدود 5100 ← عجز 5 جنيه باسم الموظفة
    const close = await as(rec, `select close_drawer($1, $2, 510000, 'آخر اليوم') as r`, [id(), cash]);
    expect(close.rows[0].r).toEqual({ expected: 510500, counted: 510000, diff: -500 });

    // الحساب اليدوي
    const cashBox = 510000;
    const walletBox = 500000 + 100000 - 45050 - 100000 - 100000; // 354950
    const ar = 0 + (80000 + 45000 - 30000); // العميل الأول صفر، والتاني 95000
    const payables = 130000 - 80000 + (400000 - 50000 - 200000); // مورد 50000 + مرتبات 150000
    const inventory = 4 * 27000 + 7 * 3000; // 108000 + 21000
    const revenue = 150000 + 80000 + 22500 + 45000;
    const expenses = 27000 + 9000 + 27000 + 300000 + 45050 + 400000 + 500;
    const p = await pos(O);
    expect(p.cash).toBe(cashBox + walletBox);
    expect(p.cashboxes.find((c) => c.code === 'cash_cash')!.balance).toBe(cashBox);
    expect(p.cashboxes.find((c) => c.code === 'cash_wallet')!.balance).toBe(walletBox);
    expect(p.receivables).toBe(ar);
    expect(p.payables).toBe(payables);
    expect(p.inventory).toBe(inventory);
    expect(p.revenue).toBe(revenue);
    expect(p.expenses).toBe(expenses);
    expect(p.profit).toBe(revenue - expenses);
    expect(p.net_worth).toBe(cashBox + walletBox + ar + inventory - payables);
    // المعادلة: الأصول = الالتزامات + رأس المال والأرباح
    expect(p.equation).toEqual({ assets: cashBox + walletBox + ar + inventory, liabilities: payables, equity: 1500000 - 100000, earnings: revenue - expenses });
    expect(p.balanced).toBe(true);
    expect(p.debits).toBe(p.credits);
    expect(p.top_customers).toEqual([{ id: c2, name: 'عميل اتنين', balance: 95000 }]);
    expect(p.top_suppliers).toEqual([{ id: s1, name: 'مورد القطع', balance: 50000 }]);
    expect(p.by_method).toEqual({ cash: 80000, wallet: 100000 });
    // الجهاز الأول: اتدفع بالكامل، وتكلفة القطع عليه 270
    const m = (await as(O, `select device_money($1) as m`, [d1])).rows[0].m;
    expect(m).toMatchObject({ final: 150000, paid: 150000, due: 0, parts_cost: 27000 });
  });

  it('تفاصيل الأرقام: كل الأرصدة، والإيرادات والمصروفات لكل بند، وحركة الخزن يوم بيوم، لصاحب المحل بس', async () => {
    const cust = (await as(A.owner, `select party_id, balance from party_balances('customers')`)).rows;
    expect(cust).toEqual([{ party_id: c2, balance: '95000' }]);
    const sup = (await as(A.owner, `select party_id, balance from party_balances('suppliers')`)).rows;
    expect(sup).toEqual([{ party_id: s1, balance: '50000' }]);
    const emp = (await as(A.owner, `select account, balance from party_balances('employees')`)).rows;
    expect(emp).toEqual([{ account: 'salaries_payable', balance: '150000' }]);
    const pl = (await as(A.owner, `select code, amount from pl_breakdown($1, $2)`, [FROM(), TO()])).rows;
    const byCode = Object.fromEntries(pl.map((r) => [r.code, Number(r.amount)]));
    expect(byCode).toMatchObject({ rev_repair: 230000, rev_parts: 45000, rev_accessories: 22500, cogs: 63000, exp_rent: 300000, exp_salaries: 400000, shortage: 500 });
    const p = await pos(A.owner);
    const daily = (await as(A.owner, `select cashbox, sum(net)::bigint as n from cashbox_daily($1, $2) group by cashbox`, [FROM(), TO()])).rows;
    for (const cb of p.cashboxes) expect(Number(daily.find((r) => r.cashbox === cb.id)?.n ?? 0)).toBe(cb.balance);
    for (const u of [rec, tech]) {
      await expect(as(u, `select * from party_balances('customers')`)).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select * from pl_breakdown($1, $2)`, [FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select * from cashbox_daily($1, $2)`, [FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
    }
  });

  it('قبول 1: كل قيد متوازن، والدفتر كله متوازن', async () => {
    const r = await admin(
      `select e.id, sum(l.debit) d, sum(l.credit) c, count(*) n from journal_entries e join journal_lines l on l.entry_id = e.id where e.shop_id = $1 group by e.id`,
      [A.shop],
    );
    expect(r.rowCount).toBeGreaterThanOrEqual(20);
    for (const x of r.rows) {
      expect(x.d).toBe(x.c);
      expect(Number(x.n)).toBeGreaterThanOrEqual(2);
    }
    const t = await admin(`select sum(debit) d, sum(credit) c from journal_lines where shop_id = $1`, [A.shop]);
    expect(t.rows[0].d).toBe(t.rows[0].c);
  });

  it('قبول 2: رصيد كل خزنة = مجموع حركاتها بالظبط، وكشف الخزنة بيوصل لنفس الرصيد', async () => {
    const p = await pos(A.owner);
    for (const cb of p.cashboxes) {
      const r = await admin(`select coalesce(sum(debit - credit), 0)::bigint s from journal_lines where account_id = $1`, [cb.id]);
      expect(Number(r.rows[0].s)).toBe(cb.balance);
      const st = (await as(A.owner, `select statement('cashbox', $1, $2, $3) as s`, [cb.id, '2000-01-01', TO()])).rows[0].s;
      expect(st.opening).toBe(0);
      const last = st.moves.at(-1);
      expect(last ? last.balance : 0).toBe(cb.balance);
    }
    // كشف حساب العميل التاني: 800 تسليم + 450 بيع − 300 دفعة
    const cs = (await as(A.owner, `select statement('customer', $1, $2, $3) as s`, [c2, '2000-01-01', TO()])).rows[0].s;
    expect(cs.moves.map((x: { amount: number }) => x.amount)).toEqual([80000, 45000, -30000]);
    expect(cs.moves.at(-1).balance).toBe(95000);
  });

  it('قبول 4: القيد ما بيتعدلش ولا بيتحذف (من الـ API ولا من SQL)، والقيد العكسي بيرجّع الرصيد صح', async () => {
    const e = (await admin(`select id from journal_entries where shop_id = $1 and source_type = 'expense' and memo = 'إيجار الشهر'`, [A.shop])).rows[0].id;
    // من الـ API: مفيش صلاحية كتابة أصلًا
    await expect(as(A.owner, `update journal_lines set debit = 1 where entry_id = $1`, [e])).rejects.toThrow(/permission denied/);
    await expect(as(A.owner, `delete from journal_entries where id = $1`, [e])).rejects.toThrow(/permission denied/);
    await expect(as(A.owner, `insert into journal_lines(shop_id, entry_id, account_id, debit) values ($1, $2, $3, 5)`, [A.shop, e, cash])).rejects.toThrow(/permission denied/);
    // من SQL بصلاحيات كاملة: الحماية جوه قاعدة البيانات نفسها
    await expect(admin(`update journal_lines set debit = debit + 1 where entry_id = $1`, [e])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    await expect(admin(`update journal_entries set memo = 'x' where id = $1`, [e])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    await expect(admin(`delete from journal_lines where entry_id = $1`, [e])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    await expect(admin(`delete from payments`)).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    await expect(admin(`truncate journal_lines cascade`)).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
    // القيد العكسي
    const before = await balanceOf(A.owner, 'cash_cash');
    const exp0 = (await pos(A.owner)).expenses;
    await expect(as(rec, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(A.owner, `select reverse_entry($1, '')`, [e])).rejects.toThrow(/E_BAD_INPUT/);
    const rev = (await as(A.owner, `select reverse_entry($1, 'الإيجار اتسجل مرتين') as r`, [e])).rows[0].r;
    expect(await balanceOf(A.owner, 'cash_cash')).toBe(before + 300000);
    expect((await pos(A.owner)).expenses).toBe(exp0 - 300000);
    const link = await admin(`select reverses_id, source_type from journal_entries where id = $1`, [rev]);
    expect(link.rows[0]).toEqual({ reverses_id: e, source_type: 'reversal' });
    await expect(as(A.owner, `select reverse_entry($1, 'تاني')`, [e])).rejects.toThrow(/E_ALREADY_REVERSED/);
    await expect(as(A.owner, `select reverse_entry($1, 'عكس العكس')`, [rev])).rejects.toThrow(/E_ALREADY_REVERSED/);
    const log = await admin(`select actor_id, after ->> 'reason' as reason from audit_log where action = 'reverse_entry' and entity_id = $1`, [e]);
    expect(log.rows[0]).toEqual({ actor_id: A.owner, reason: 'الإيجار اتسجل مرتين' });
    expect((await pos(A.owner)).balanced).toBe(true);
  });

  it('قبول 4ب: عكس دفعة بيرجّع الجهاز "مش مدفوع"، وعكس شراء بيرجّع المخزون', async () => {
    const pay = (await admin(`select entry_id from payments where device_id = $1 and amount = 100000`, [d1])).rows[0].entry_id;
    await as(A.owner, `select reverse_entry($1, 'الدفعة اترجعت للعميل')`, [pay]);
    const m = (await as(rec, `select device_money($1) as m`, [d1])).rows[0].m;
    expect(m).toMatchObject({ paid: 50000, due: 100000 });
    expect(m.payments.filter((x: { reversed: boolean }) => x.reversed)).toHaveLength(1);
    // شراء جديد وبعدين عكسه: الكمية والقيمة يرجعوا زي ما كانوا
    const st0 = (await as(A.owner, `select qty, value from items_stock() where id = $1`, [accessory])).rows[0];
    const pe = (await as(A.owner, `select record_purchase($1, $2, $3::jsonb, $4) as e`, [id(), s1, JSON.stringify([{ item: accessory, qty: 5, unit_cost: 4000 }]), cash])).rows[0].e;
    await as(A.owner, `select reverse_entry($1, 'الشحنة اترجعت')`, [pe]);
    expect((await as(A.owner, `select qty, value from items_stock() where id = $1`, [accessory])).rows[0]).toEqual(st0);
    expect((await pos(A.owner)).balanced).toBe(true);
  });

  it('قبول 5: التحويل بين خزنتين ما بيغيرش إجمالي الفلوس، ومينفعش يحوّل أكتر من الموجود', async () => {
    const p0 = await pos(A.owner);
    await as(A.owner, `select transfer_cash($1, $2, $3, 12345)`, [id(), cash, wallet]);
    const p1 = await pos(A.owner);
    expect(p1.cash).toBe(p0.cash);
    expect(p1.net_worth).toBe(p0.net_worth);
    expect(p1.cashboxes.find((c) => c.code === 'cash_wallet')!.balance).toBe(p0.cashboxes.find((c) => c.code === 'cash_wallet')!.balance + 12345);
    await expect(as(A.owner, `select transfer_cash($1, $2, $2, 100)`, [id(), cash])).rejects.toThrow(/E_SAME_CASHBOX/);
    await expect(as(A.owner, `select transfer_cash($1, $2, $3, 999999999)`, [id(), cash, wallet])).rejects.toThrow(/E_INSUFFICIENT/);
  });

  it('قبول 6: عملية فشلت في النص ما بيتسجلش منها أي حاجة', async () => {
    const count = async () => (await admin(`select (select count(*) from journal_entries where shop_id = $1) e, (select count(*) from journal_lines where shop_id = $1) l, (select count(*) from stock_moves where shop_id = $1) m`, [A.shop])).rows[0];
    const c0 = await count();
    // الصنف التاني مش موجود: الأول ما يتسجلش
    await expect(as(A.owner, `select record_purchase($1, $2, $3::jsonb)`, [id(), s1, JSON.stringify([{ item: part, qty: 1, unit_cost: 100 }, { item: randomUUID(), qty: 1, unit_cost: 100 }])])).rejects.toThrow(/E_NOT_FOUND/);
    // البيع: السطر التاني أكتر من المخزون، فالأول بيترجع
    await expect(as(rec, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: accessory, qty: 1, price: 7500 }, { item: part, qty: 999, price: 1 }]), cash])).rejects.toThrow(/E_STOCK/);
    // قيد مش متوازن مكتوب مباشرة بصلاحيات كاملة: بيتلغي كله عند الحفظ
    await expect(
      asSuper(A.owner, `with e as (insert into journal_entries(shop_id, source_type) values ($1, 'expense') returning id)
                        insert into journal_lines(shop_id, entry_id, account_id, debit) select $1, id, $2, 100 from e`, [A.shop, cash]),
    ).rejects.toThrow(/E_UNBALANCED/);
    // نفس العملية لو اتبعتت مرتين (من الطابور بدون نت) بتتسجل مرة واحدة
    const pid = id();
    await as(rec, `select record_payment($1, $2, $3, 1000)`, [pid, c1, cash]);
    await as(rec, `select record_payment($1, $2, $3, 1000)`, [pid, c1, cash]);
    expect((await admin(`select count(*)::int n from payments where id = $1`, [pid])).rows[0].n).toBe(1);
    const c1n = await count();
    expect(Number(c1n.e)).toBe(Number(c0.e) + 1);
    expect(Number(c1n.l)).toBe(Number(c0.l) + 2);
    expect(c1n.m).toBe(c0.m);
    // مبالغ غلط
    for (const amt of [0, -5]) await expect(as(rec, `select record_payment($1, $2, $3, $4)`, [id(), c1, cash, amt])).rejects.toThrow(/E_BAD_AMOUNT/);
  });

  it('قبول 7: الأرقام الكبيرة (ملايين) ما بيضيعش منها ولا قرش', async () => {
    const B = await newShop('محل الملايين');
    const cb = await acc(B.owner, 'cash_cash');
    const big = 1234567891; // 12,345,678.91
    for (let i = 0; i < 3; i++) await as(B.owner, `select owner_capital($1, $2, $3)`, [id(), cb, big]);
    await as(B.owner, `select record_expense($1, $2, $3, 1)`, [id(), await acc(B.owner, 'exp_rent'), cb]);
    const p = await pos(B.owner);
    expect(p.cash).toBe(3 * big - 1);
    expect(p.cash).toBe(3703703672);
    expect(p.equation.equity).toBe(3703703673);
    expect(p.balanced).toBe(true);
    // المتوسط المرجّح بكسور: 3 قطع × 33 + قطعة × 1 = 4 قطع بقيمة 100 قرش (متوسط 25)،
    // وبعدين 3 قطع × 1 = 7 قطع بقيمة 103 (متوسط 14.71...). خروجهم واحدة واحدة لازم يطلّع 103 بالظبط
    const it3 = id();
    const sup = id();
    await as(B.owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(B.owner, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'كابل')`, [it3]);
    await as(B.owner, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: it3, qty: 3, unit_cost: 33 }, { item: it3, qty: 1, unit_cost: 1 }])]);
    await as(B.owner, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: it3, qty: 3, unit_cost: 1 }])]);
    for (let i = 0; i < 7; i++) await as(B.owner, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: it3, qty: 1, price: 50 }]), cb]);
    const left = (await as(B.owner, `select qty, value from items_stock() where id = $1`, [it3])).rows[0];
    expect(left).toEqual({ qty: '0', value: '0' });
    const cogs = await admin(`select sum(-value)::int s from stock_moves where item_id = $1 and qty < 0`, [it3]);
    expect(cogs.rows[0].s).toBe(103);
    expect((await pos(B.owner)).balanced).toBe(true);
  });

  it('قبول 8: الاستقبال والفني ما يقدروش يقروا الأرصدة حتى من الـ API مباشرة، ومحل تاني ما يشوفش حاجة', async () => {
    for (const u of [rec, tech]) {
      expect((await as(u, `select * from journal_lines`)).rowCount).toBe(0);
      expect((await as(u, `select * from journal_entries`)).rowCount).toBe(0);
      expect((await as(u, `select * from stock_moves`)).rowCount).toBe(0);
      await expect(as(u, `select financial_position($1, $2)`, [FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select statement('cashbox', $1, $2, $3)`, [cash, FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select statement('customer', $1, $2, $3)`, [c2, FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
      await expect(as(u, `select ledger_balance($1)`, [cash])).rejects.toThrow(/permission denied/);
      await expect(as(u, `select ledger_post('expense', null, null, '[]'::jsonb)`)).rejects.toThrow(/permission denied/);
      await expect(as(u, `select transfer_cash($1, $2, $3, 1)`, [id(), cash, wallet])).rejects.toThrow(/E_FORBIDDEN/);
    }
    // الفني ما يشوفش الدفعات ولا الخزن
    expect((await as(tech, `select * from payments`)).rowCount).toBe(0);
    expect((await as(tech, `select * from accounts`)).rowCount).toBe(0);
    await expect(as(tech, `select device_money($1)`, [d1])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(tech, `select * from my_drawers()`)).rejects.toThrow(/E_FORBIDDEN/);
    // الاستقبال: الدرج بتاعها بس، ومن غير أرصدة الخزن التانية ولا تكلفة القطع
    const mine = await as(rec, `select id from my_drawers()`);
    expect(mine.rows.map((r) => r.id)).toEqual([cash]);
    await expect(as(rec, `select close_drawer($1, $2, 0)`, [id(), wallet])).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(rec, `select avg_cost, value from items_stock() where id = $1`, [part])).rows[0]).toEqual({ avg_cost: null, value: null });
    expect((await as(rec, `select device_money($1) as m`, [d1])).rows[0].m.parts_cost).toBeNull();
    // محل تاني
    const X = await newShop('محل غريب');
    expect((await as(X.owner, `select * from journal_lines`)).rowCount).toBe(0);
    expect((await as(X.owner, `select * from payments`)).rowCount).toBe(0);
    await expect(as(X.owner, `select record_payment($1, $2, $3, 100)`, [id(), c1, cash])).rejects.toThrow(/E_BAD_ACCOUNT/);
    await expect(as(X.owner, `select statement('cashbox', $1, $2, $3) as s`, [cash, FROM(), TO()])).rejects.toThrow(/E_NOT_FOUND/);
    expect((await pos(X.owner)).cash).toBe(0);
  });

  it('قبول 9: توازن مكسور عن قصد بيتمسك: الدالة بترفضه، ولو اتكسر من ورا كل الحماية الوضع المالي بيقول "مش متوازن"', async () => {
    const C = await newShop('محل الكسر');
    const cb = await acc(C.owner, 'cash_cash');
    // الدالة الداخلية نفسها بترفض قيد مش متوازن
    await expect(
      asSuper(C.owner, `select ledger_post('expense', null, null, $1::jsonb)`, [JSON.stringify([{ account: cb, debit: 100 }, { account: cb, credit: 99 }])]),
    ).rejects.toThrow(/E_UNBALANCED/);
    await as(C.owner, `select owner_capital($1, $2, 1000)`, [id(), cb]);
    expect((await pos(C.owner)).balanced).toBe(true);
    // كسر متعمد: بنقفل الحماية ونزوّد سطر (ده بيحاكي عطل أو تلاعب في قاعدة البيانات)
    const e = (await admin(`select id from journal_entries where shop_id = $1`, [C.shop])).rows[0].id;
    await admin('begin');
    await admin(`alter table journal_lines disable trigger entry_balanced`);
    await admin(`insert into journal_lines(shop_id, entry_id, account_id, debit) values ($1, $2, $3, 1)`, [C.shop, e, cb]);
    await admin(`alter table journal_lines enable trigger entry_balanced`);
    await admin('commit');
    const p = await pos(C.owner);
    expect(p.balanced).toBe(false);
    expect(p.unbalanced_entries).toBe(1);
    expect(p.debits).toBe(p.credits + 1);
  });
});
