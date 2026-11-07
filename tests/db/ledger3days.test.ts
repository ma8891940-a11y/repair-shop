// مراجعة الحسابات: سيناريو 3 أيام فيه 50 عملية متنوعة، وكل رقم مطابق لحساب يدوي مكتوب في التعليقات.
// كل المبالغ بالقروش (100 = جنيه). العمليات بتتسجل بوقت النهارده، وبعد كل يوم بنرجّع وقت قيوده (occurred_at) لليوم بتاعه
// عشان نقيس كل يوم لوحده (بيانات اختبار: من ورا الحماية بصلاحيات قاعدة البيانات الكاملة، مش من الـ API).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string | null, sql: string, params: unknown[] = [], ip = '10.77.0.1') {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': ip })]);
    if (uid) {
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
    } else {
      await db.query(`select set_config('request.jwt.claims', '', true)`);
      await db.query('set local role anon');
    }
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const tag = randomUUID().slice(0, 8);
const id = () => randomUUID();
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@s.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}

let O = '';
let R = '';
let T = '';
let S = '';
const acc: Record<string, string> = {};

/** بداية يوم بتوقيت القاهرة (0 = النهارده، 1 = امبارح...) + ساعات */
const dayAt = (back: number, hours: number) => `((date_trunc('day', now() at time zone 'Africa/Cairo') - interval '${back} days' + interval '${hours} hours') at time zone 'Africa/Cairo')`;
async function moveDay(since: Date, back: number) {
  await admin('begin');
  await admin('set local session_replication_role = replica');
  await admin(`update journal_entries set occurred_at = ${dayAt(back, 10)} where shop_id = $1 and created_at >= $2`, [S, since]);
  await admin('commit');
}
async function pos(from: string, to: string) {
  return (await as(O, `select financial_position(${from}, ${to}) as p`)).rows[0].p as {
    cash: number; receivables: number; payables: number; inventory: number; revenue: number; expenses: number; profit: number; net_worth: number;
    equation: { assets: number; liabilities: number; equity: number; earnings: number }; balanced: boolean; debits: number; credits: number;
    cashboxes: { code: string; balance: number }[];
  };
}
/** رصيد الحساب من القيود مباشرة (مدين − دائن)، من غير أي دالة من دوال البرنامج */
async function raw(code: string) {
  return Number((await admin(`select coalesce(sum(l.debit - l.credit), 0)::bigint s from journal_lines l join accounts a on a.id = l.account_id where a.shop_id = $1 and a.code = $2`, [S, code])).rows[0].s);
}
async function walk(dev: string) {
  for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [dev, st]);
}

d('مراجعة الحسابات: 3 أيام و50 عملية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`l3-o-${tag}@s.test`);
    S = (await as(O, `select (bootstrap_account('صاحب', 'محل الـ 3 أيام')).shop_id as s`)).rows[0].s;
    R = await staff(O, 'استقبال', 'reception');
    T = await staff(O, 'فني', 'technician');
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    // الاستقبال مسؤولة عن كاش الدرج (من الإعدادات)، فهي اللي بتقفله
    await as(O, `select update_account($1, p_holder => $2)`, [acc.cash_cash, R]);
  });
  afterAll(async () => db?.end());

  it('كل الأرقام مطابقة لحساب يدوي يوم بيوم وفي الآخر، والمعادلة متوازنة، والدرج والقيود صح', async () => {
    const [cash, wallet, insta, bank] = [acc.cash_cash, acc.cash_wallet, acc.cash_instapay, acc.cash_bank_transfer];
    const [s1, s2, screen, battery, cases] = [id(), id(), id(), id(), id()];
    const [c1, c2, c3, c4] = [id(), id(), id(), id()];
    const [d1, d2, d3, d4] = [id(), id(), id(), id()];
    const ph = () => `012${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الشاشات'), ($2, gen_random_uuid(), 'مورد البطاريات')`, [s1, s2]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة'), ($2, gen_random_uuid(), 'part', 'بطارية'), ($3, gen_random_uuid(), 'accessory', 'جراب')`, [screen, battery, cases]);
    for (const [c, n] of [[c1, 'عميل 1'], [c2, 'عميل 2'], [c3, 'عميل 3'], [c4, 'عميل 4']]) await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), $2, $3)`, [c, n, ph()]);
    for (const [dv, c] of [[d1, c1], [d2, c2], [d3, c3], [d4, c4]]) {
      await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'عطل')`, [dv, c]);
      await as(O, `insert into device_costs(id, shop_id, device_id) values ($1, gen_random_uuid(), $2)`, [id(), dv]);
    }
    let ops = 0;
    const op = async (who: string, sql: string, params: unknown[] = []) => {
      ops++;
      return as(who, sql, params);
    };

    // ===================== اليوم الأول (17 عملية) =====================
    const t1 = new Date();
    await op(O, `select owner_capital($1, $2, 2000000)`, [id(), cash]); //  1) كاش 20,000
    await op(O, `select owner_capital($1, $2, 1000000)`, [id(), bank]); //  2) بنك 10,000
    await op(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), s1, JSON.stringify([{ item: screen, qty: 6, unit_cost: 25000 }])]); //  3) آجل 1,500
    await op(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), s2, JSON.stringify([{ item: battery, qty: 10, unit_cost: 8000 }]), cash]); //  4) نقدي 800
    await op(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), s2, JSON.stringify([{ item: cases, qty: 20, unit_cost: 3000 }])]); //  5) آجل 600
    await op(O, `select record_expense($1, $2, $3, 300000, 'إيجار')`, [id(), acc.exp_rent, cash]); //  6) إيجار 3,000
    await op(R, `select record_payment($1, $2, $3, 50000, $4)`, [id(), c1, cash, d1]); //  7) عربون 500
    await op(T, `select use_part($1, $2, $3, 1)`, [id(), d1, screen]); //  8) شاشة في d1 (250)
    await op(R, `select record_payment($1, $2, $3, 20000, $4)`, [id(), c2, wallet, d2]); //  9) عربون 200 محفظة
    await op(T, `select use_part($1, $2, $3, 1)`, [id(), d2, battery]); // 10) بطارية في d2 (80)
    await op(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: cases, qty: 2, price: 7500 }]), cash]); // 11) بيع 150 (تكلفة 60)
    await op(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: cases, qty: 1, price: 8000 }]), wallet]); // 12) بيع 80 محفظة (تكلفة 30)
    await op(O, `select transfer_cash($1, $2, $3, 200000)`, [id(), bank, cash]); // 13) بنك ← درج 2,000
    await op(O, `select record_expense($1, $2, $3, 45050)`, [id(), acc.exp_electricity, cash]); // 14) كهربا 450.50
    await op(O, `select give_advance($1, $2, $3, 30000)`, [id(), T, cash]); // 15) سلفة للفني 300
    await op(O, `select accrue_salary($1, $2, 300000)`, [id(), R]); // 16) مرتب الاستقبال مستحق 3,000
    // درج آخر اليوم الأول: 20,000 − 800 − 3,000 + 500 + 150 + 2,000 − 450.50 − 300 = 18,099.50
    const close1 = (await op(R, `select close_drawer($1, $2, 1809950) as r`, [id(), cash])).rows[0].r; // 17)
    expect(close1).toEqual({ expected: 1809950, counted: 1809950, diff: 0 });
    await moveDay(t1, 2);

    // ===================== اليوم التاني (17 عملية) =====================
    const t2 = new Date();
    await as(O, `update device_costs set final_cost = 150000 where device_id = $1`, [d1]);
    await op(R, `select record_payment($1, $2, $3, 100000, $4)`, [id(), c1, insta, d1]); // 18) باقي d1 على InstaPay 1,000
    await walk(d1);
    await op(R, `update devices set status = 'delivered' where id = $1`, [d1]); // 19) تسليم d1: إيراد 1,500
    await as(O, `update device_costs set final_cost = 80000 where device_id = $1`, [d2]);
    await walk(d2);
    await op(O, `select deliver_on_credit($1)`, [d2]); // 20) تسليم d2 بالآجل: إيراد 800، والعميل عليه 600
    await op(R, `select record_payment($1, $2, $3, 30000)`, [id(), c2, cash]); // 21) العميل 2 دفع 300
    await op(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), s1, JSON.stringify([{ item: screen, qty: 5, unit_cost: 31000 }]), cash]); // 22) 5 × 310 نقدي ← المتوسط (1,250 + 1,550) / 10 = 280
    await op(T, `select use_part($1, $2, $3, 1)`, [id(), d3, screen]); // 23) شاشة في d3 (280)
    await op(O, `select pay_supplier($1, $2, $3, 100000)`, [id(), s1, cash]); // 24) سداد مورد الشاشات 1,000
    await op(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item: screen, qty: 1, price: 45000 }]), c3]); // 25) بيع شاشة آجل للعميل 3 (تكلفة 280)
    await op(O, `select record_expense($1, $2, $3, 20000)`, [id(), acc.exp_internet, insta]); // 26) نت 200
    await op(O, `select accrue_salary($1, $2, 250000)`, [id(), T]); // 27) مرتب الفني مستحق 2,500
    await op(O, `select settle_advance($1, $2, 30000)`, [id(), T]); // 28) خصم السلفة 300 من المرتب
    await op(O, `select pay_salary($1, $2, $3, 300000)`, [id(), R, cash]); // 29) صرف مرتب الاستقبال 3,000
    await op(O, `select owner_drawing($1, $2, 20000)`, [id(), wallet]); // 30) سحب صاحب المحل 200 من المحفظة
    const wrong = (await op(O, `select record_expense($1, $2, $3, 12345) as e`, [id(), acc.exp_electricity, cash])).rows[0].e; // 31) مصروف غلط 123.45
    await op(O, `select reverse_entry($1, 'اتكتب غلط')`, [wrong]); // 32) قيد عكسي
    await op(R, `select record_payment($1, $2, $3, 45000)`, [id(), c3, bank]); // 33) العميل 3 سدد 450 تحويل
    // درج اليوم التاني: 18,099.50 + 300 − 1,550 − 1,000 − 3,000 = 12,849.50، والمعدود أقل بـ 10 جنيه
    const close2 = (await op(R, `select close_drawer($1, $2, 1283950) as r`, [id(), cash])).rows[0].r; // 34)
    expect(close2).toEqual({ expected: 1284950, counted: 1283950, diff: -1000 });
    await moveDay(t2, 1);

    // ===================== اليوم التالت (16 عملية) =====================
    await as(O, `update device_costs set final_cost = 120000 where device_id = $1`, [d3]);
    await op(R, `select record_payment($1, $2, $3, 120000, $4)`, [id(), c3, cash, d3]); // 35) d3 اتدفع كله 1,200
    await walk(d3);
    await op(R, `update devices set status = 'delivered' where id = $1`, [d3]); // 36) تسليم d3: إيراد 1,200
    await op(R, `select record_payment($1, $2, $3, 10000, $4)`, [id(), c4, wallet, d4]); // 37) عربون d4 100 محفظة
    await op(T, `select use_part($1, $2, $3, 1)`, [id(), d4, battery]); // 38) بطارية في d4 (80)
    await as(O, `update device_costs set final_cost = 60000 where device_id = $1`, [d4]);
    await op(R, `select record_payment($1, $2, $3, 50000, $4)`, [id(), c4, cash, d4]); // 39) باقي d4 500
    await walk(d4);
    await op(R, `update devices set status = 'delivered' where id = $1`, [d4]); // 40) تسليم d4: إيراد 600
    await op(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), s2, JSON.stringify([{ item: battery, qty: 5, unit_cost: 8000 }])]); // 41) بطاريات آجل 400
    await op(O, `select pay_supplier($1, $2, $3, 60000)`, [id(), s2, bank]); // 42) سداد مورد البطاريات 600 تحويل
    await op(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: cases, qty: 3, price: 7000 }]), cash]); // 43) بيع 210 (تكلفة 90)
    await op(O, `select transfer_cash($1, $2, $3, 300000)`, [id(), cash, bank]); // 44) درج ← بنك 3,000
    await op(O, `select record_expense($1, $2, $3, 45050)`, [id(), acc.exp_electricity, cash]); // 45) كهربا 450.50
    await op(O, `select pay_salary($1, $2, $3, 220000)`, [id(), T, cash]); // 46) صرف باقي مرتب الفني 2,200
    await op(O, `select owner_capital($1, $2, 100000)`, [id(), insta]); // 47) رأس مال 1,000 على InstaPay
    const wrongPay = (await op(R, `select record_payment($1, $2, $3, 5000) as e`, [id(), c1, cash])).rows[0].e; // 48) دفعة غلط 50
    await op(O, `select reverse_entry($1, 'دفعة مكررة')`, [wrongPay]); // 49) قيد عكسي
    // درج اليوم التالت: 12,839.50 + 1,200 + 500 + 210 − 3,000 − 450.50 − 2,200 = 9,099، والمعدود زيادة 20 جنيه
    const close3 = (await op(R, `select close_drawer($1, $2, 911900) as r`, [id(), cash])).rows[0].r; // 50)
    expect(close3).toEqual({ expected: 909900, counted: 911900, diff: 2000 });
    expect(ops).toBe(50);

    // ===================== الحساب اليدوي =====================
    const day = [
      // اليوم الأول: إيراد 150 + 80. ومصروف إيجار 3,000 + قطع 250 + 80 + تكلفة مبيعات 60 + 30 + كهربا 450.50 + مرتب 3,000
      { back: 2, revenue: 15000 + 8000, expenses: 300000 + 25000 + 8000 + 6000 + 3000 + 45050 + 300000 },
      // اليوم التاني: إيراد 1,500 + 800 + 450. ومصروف قطعة 280 + تكلفة بيع 280 + نت 200 + مرتب 2,500 + عجز 10 (والغلط اتعكس = صفر)
      { back: 1, revenue: 150000 + 80000 + 45000, expenses: 28000 + 28000 + 20000 + 250000 + 1000 },
      // اليوم التالت: إيراد 1,200 + 600 + 210 + زيادة الدرج 20. ومصروف قطعة 80 + تكلفة بيع 90 + كهربا 450.50
      { back: 0, revenue: 120000 + 60000 + 21000 + 2000, expenses: 8000 + 9000 + 45050 },
    ];
    for (const x of day) {
      const p = await pos(dayAt(x.back, 0), x.back === 0 ? `now() + interval '1 hour'` : dayAt(x.back - 1, 0));
      expect({ revenue: p.revenue, expenses: p.expenses, profit: p.profit, balanced: p.balanced }, `يوم ${3 - x.back}`).toEqual({ revenue: x.revenue, expenses: x.expenses, profit: x.revenue - x.expenses, balanced: true });
    }
    const revenue = day.reduce((s, x) => s + x.revenue, 0); // 5,010
    const expenses = day.reduce((s, x) => s + x.expenses, 0); // 10,761
    expect(revenue).toBe(501000);
    expect(expenses).toBe(1076100);

    const boxes = { cash_cash: 911900, cash_wallet: 20000 + 8000 - 20000 + 10000, cash_instapay: 100000 - 20000 + 100000, cash_bank_transfer: 1000000 - 200000 + 45000 - 60000 + 300000 };
    expect(boxes).toEqual({ cash_cash: 911900, cash_wallet: 18000, cash_instapay: 180000, cash_bank_transfer: 1085000 });
    const cashTotal = Object.values(boxes).reduce((s, v) => s + v, 0); // 21,949
    const receivables = 80000 - 20000 - 30000; // العميل 2 بس عليه 300، والباقيين صفر
    const inventory = 8 * 28000 + 13 * 8000 + 14 * 3000; // شاشات 8 × 280، وبطاريات 13 × 80، وجراب 14 × 30
    const payables = 150000 - 100000 + (60000 + 40000 - 60000); // مورد الشاشات 500 + البطاريات 400، والمرتبات صفر
    const equity = 2000000 + 1000000 + 100000 - 20000; // رأس المال ناقص السحب

    const p = await pos(dayAt(3, 0), `now() + interval '1 hour'`);
    expect(p.revenue).toBe(revenue);
    expect(p.expenses).toBe(expenses);
    expect(p.profit).toBe(revenue - expenses);
    expect(p.cash).toBe(cashTotal);
    for (const [code, v] of Object.entries(boxes)) {
      expect(p.cashboxes.find((c) => c.code === code)!.balance, code).toBe(v);
      // رصيد كل خزنة = مجموع حركاتها في القيود بالظبط
      expect(await raw(code), `${code} من القيود`).toBe(v);
    }
    expect(p.receivables).toBe(receivables);
    expect(p.inventory).toBe(inventory);
    expect(p.payables).toBe(payables);
    expect(p.net_worth).toBe(cashTotal + receivables + inventory - payables);
    // المعادلة: الأصول = الالتزامات + رأس المال + الأرباح
    expect(p.equation).toEqual({ assets: cashTotal + receivables + inventory, liabilities: payables, equity, earnings: revenue - expenses });
    expect(cashTotal + receivables + inventory).toBe(payables + equity + revenue - expenses);
    expect(p.balanced).toBe(true);
    expect(p.debits).toBe(p.credits);
    // كل قيد لوحده متوازن
    const bad = (await admin(`select e.id from journal_entries e join journal_lines l on l.entry_id = e.id where e.shop_id = $1 group by e.id having sum(l.debit) <> sum(l.credit)`, [S])).rowCount;
    expect(bad).toBe(0);
    // القيد ما بيتعدلش ولا بيتحذف، حتى لصاحب المحل
    await expect(as(O, `update journal_lines set debit = debit + 1 where shop_id = $1`, [S])).rejects.toThrow();
    await expect(as(O, `delete from journal_entries where shop_id = $1`, [S])).rejects.toThrow();
    // الأرصدة ما بتتخزنش: مفيش عمود رصيد في الحسابات
    const cols = (await admin(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'accounts'`)).rows.map((r) => r.column_name);
    expect(cols.filter((c) => /balance/.test(c))).toEqual([]);
  });
});
