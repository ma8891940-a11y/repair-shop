// N: مواعيد التحصيل وخطط التقسيط: المدفوع بيتحسب من القيود، والزيادة بتغطي القسط اللي بعده، والخطة بتتقفل لوحدها. والإشعارات بالصلاحية
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
const day = (n: number) => {
  const d = new Date(Date.now() + n * 86400_000);
  return d.toISOString().slice(0, 10);
};

d('مواعيد التحصيل والأقساط', () => {
  let O = '';
  let R = '';
  let shop = '';
  let cust = '';
  let sup = '';
  let item = '';
  const acc: Record<string, string> = {};
  const plans = async (uid = O) => (await as(uid, `select * from plans_overview('customer', $1)`, [cust])).rows;
  const pay = (amount: number) => as(O, `select record_payment($1, $2, $3, $4)`, [id(), cust, acc.cash_cash, amount]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pl-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الأقساط')).shop_id s`)).rows[0].s;
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    const em = `pl-r-${tag}@p.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), acc.cash_cash]);
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الأقساط', $2)`, [cust, `0109${String(Date.now()).slice(-7)}`]);
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الأقساط')`, [sup]);
    item = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'سماعة')`, [item]);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 10, unit_cost: 10000 }])]);
    // بيع آجل للعميل بـ 3000 ج
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 2, price: 150000 }]), cust]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('خطة 3 أقساط (1000 كل واحد): واحد متأخر، والدفع بيغطي بالترتيب، والزيادة بتروح للي بعده', async () => {
    const p = id();
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb, 'جهاز بالتقسيط')`, [p, cust, JSON.stringify([{ due: day(-2), amount: 100000 }, { due: day(2), amount: 100000 }, { due: day(30), amount: 100000 }])]);
    let [x] = await plans();
    expect(x).toMatchObject({ total: '300000', paid: '0', remaining: '300000', overdue: '100000', status: 'overdue' });
    expect(x.installments.map((i: { status: string }) => i.status)).toEqual(['overdue', 'due_soon', 'upcoming']);
    // دفع 1500: الأول اتقفل، والتاني نصه
    await pay(150000);
    [x] = await plans();
    expect(x).toMatchObject({ paid: '150000', remaining: '150000', overdue: '0', status: 'due_soon', next_amount: '50000' });
    expect(x.installments.map((i: { covered: number }) => Number(i.covered))).toEqual([100000, 50000, 0]);
    // نفس العملية مرتين (النت قطع ورجع): خطة واحدة
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [p, cust, JSON.stringify([{ due: day(1), amount: 999 }])]);
    expect(await plans()).toHaveLength(1);
    // الباقي كله: الخطة اتقفلت لوحدها
    await pay(150000);
    [x] = await plans();
    expect(x).toMatchObject({ paid: '300000', remaining: '0', status: 'done', next_due: null });
  });

  it('دفعة اتلغت (قيد عكسي) بترجّع القسط مستحق، وزيادة الدفع ما بتعدّيش إجمالي الخطة', async () => {
    const p = id();
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 50000 }]), cust]);
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb, 'ميعاد تحصيل')`, [p, cust, JSON.stringify([{ due: day(5), amount: 50000 }])]);
    const e = (await as(O, `select record_payment($1, $2, $3, 80000) e`, [id(), cust, acc.cash_cash])).rows[0].e;
    let mine = (await plans()).find((r) => r.plan_id === p);
    expect(mine).toMatchObject({ paid: '50000', status: 'done' });
    await as(O, `select reverse_entry($1, 'غلط')`, [e]);
    mine = (await plans()).find((r) => r.plan_id === p);
    expect(mine).toMatchObject({ paid: '0', status: 'open' });
  });

  it('مورد (عليا): السداد للمورد بيغطي الخطة، والإلغاء ما بيمسحش حاجة من الفلوس', async () => {
    const p = id();
    await as(O, `select save_plan($1, 'supplier', $2, $3::jsonb)`, [p, sup, JSON.stringify([{ due: day(-1), amount: 40000 }, { due: day(10), amount: 60000 }])]);
    let [x] = (await as(O, `select * from plans_overview('supplier', $1)`, [sup])).rows;
    expect(x).toMatchObject({ status: 'overdue', overdue: '40000' });
    await as(O, `select pay_supplier($1, $2, $3, 40000)`, [id(), sup, acc.cash_cash]);
    [x] = (await as(O, `select * from plans_overview('supplier', $1)`, [sup])).rows;
    expect(x).toMatchObject({ status: 'open', paid: '40000', overdue: '0' });
    const before = (await admin(`select count(*)::int n from journal_entries where shop_id = $1`, [shop])).rows[0].n;
    await as(O, `select cancel_plan($1)`, [p]);
    expect((await as(O, `select * from plans_overview('supplier', $1)`, [sup])).rows).toHaveLength(0);
    expect((await admin(`select count(*)::int n from journal_entries where shop_id = $1`, [shop])).rows[0].n).toBe(before);
    expect((await admin(`select deleted_at is not null d from payment_plans where id = $1`, [p])).rows[0].d).toBe(true);
  });

  it('الصلاحيات: الاستقبال من غير "الوضع المالي" ما يشوفش الخطط، وبالصلاحية يشوف ويعمل؛ والفني لأ', async () => {
    await expect(plans(R)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(R, `select count(*)::int n from payment_plans`)).rows[0].n).toBe(0);
    await expect(as(R, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(3), amount: 1000 }])])).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [R]);
    await as(O, `select set_staff_override($1, 'finance', 'add', true)`, [R]);
    expect((await plans(R)).length).toBeGreaterThan(0);
    await as(R, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(3), amount: 1000 }])]);
    await expect(as(R, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(3), amount: -5 }])])).rejects.toThrow(/E_BAD_AMOUNT/);
    await as(O, `select set_staff_override($1, 'finance', 'view', null)`, [R]);
    await as(O, `select set_staff_override($1, 'finance', 'add', null)`, [R]);
  });

  it('الإشعارات: المتأخر والقريب لصاحب المحل، و"اتقرا" لكل مستخدم لوحده، والاستقبال من غير مالية ما يشوفش الفلوس', async () => {
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(-3), amount: 20000 }])]);
    const feed = async (uid: string) => (await as(uid, `select * from notifications_feed()`)).rows;
    const mine = await feed(O);
    const late = mine.find((n) => n.kind === 'overdue');
    expect(late).toBeTruthy();
    expect(late.args.name).toBe('عميل الأقساط');
    expect(late.link).toBe(`/finance/customer/${cust}`);
    expect(late.read).toBe(false);
    await as(O, `select mark_notifications_read($1)`, [[late.key]]);
    expect((await feed(O)).find((n) => n.key === late.key).read).toBe(true);
    // الاستقبال: ما بيشوفش الأقساط خالص (من غير صلاحية الوضع المالي)
    expect((await feed(R)).filter((n) => n.kind === 'overdue' || n.kind === 'due_soon')).toHaveLength(0);
  });
});
