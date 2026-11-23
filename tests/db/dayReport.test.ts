// 0064 (بند 1 من qa-37): التقرير اليومي بيجمع التحصيل كله (صيانة + بيع)، وتسوية الخزنة بتطابق
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

type Cash = {
  collections: { method: string; payments: number; sales: number; refunds: number; total: number }[];
  cashboxes: { id: string; opening: number; in: number; out: number; closing: number; entries: { entry_id: string; source_type: string; in: number; out: number; cancelled: boolean }[] }[];
};

d('التقرير اليومي (day_cash_report)', () => {
  let O = '';
  let R2 = ''; // استقبال الفرع التاني
  let T = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cash2 = '';
  let cust = '';
  const acc = id();
  let from = '';
  let to = '';
  const report = async (uid: string, branch?: string | null, f = from, t = to) =>
    (await as(uid, `select day_cash_report($1, $2, $3) r`, [f, t, branch ?? null])).rows[0].r as Cash;
  const cashRow = (r: Cash) => r.collections.find((c) => c.method === 'cash');

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    // اليوم بتوقيت القاهرة
    const b = (await admin(`select (date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') f`)).rows[0].f as Date;
    from = b.toISOString();
    to = new Date(b.getTime() + 86_400_000).toISOString();
    O = await user(`dr-o-${tag}@s.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل التقرير')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'F2', null, null)`, [B2]);
    cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    cash2 = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, B2])).rows[0].id;
    for (const [role, name, br] of [['reception', 'استقبال التاني', B2], ['technician', 'فني', main]] as const) {
      const em = `dr-${role}-${tag}@s.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, name, role, [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (role === 'reception') {
        R2 = u;
        // الاستقبال افتراضيًا ما بيشوفش المالية: صاحب المحل بيديها "المالية ← يشوف"
        await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [u]);
      }
      else T = u;
    }
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل التقرير', '01055557777')`, [cust]);
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'خدمة', 1000)`, [acc]);
    // رصيد أول اليوم: رأس مال 1000 جنيه (قبل الفترة اللي هنقيسها)
    await as(O, `select owner_capital($1, $2, 100000)`, [id(), cash], main);
    const mid = (await admin(`select now() n`)).rows[0].n as Date;
    // افتتاحي = اللي قبل mid؛ نقيس من mid عشان رأس المال يبقى افتتاحي
    from = new Date(mid.getTime() + 1).toISOString();
    await new Promise((r) => setTimeout(r, 20));
    // نفس أرقام تجربة 22/11: صيانة 2500 + 500، وبيع كاش 600 + 150.25
    await as(O, `select record_payment($1, $2, $3, 250000)`, [id(), cust, cash], main);
    await as(O, `select record_payment($1, $2, $3, 50000)`, [id(), cust, cash], main);
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 60000 }]), cash], main);
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 15025 }]), cash], main);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الكاش = 3750.25 (صيانة 3000 + بيع 750.25)، مش 3000 بس', async () => {
    const r = await report(O);
    expect(cashRow(r)).toEqual({ method: 'cash', payments: 300000, sales: 75025, refunds: 0, total: 375025 });
  });

  it('تسوية الخزنة: افتتاحي + وارد − صادر = ختامي، وكل رقم ليه قيده', async () => {
    const box = (await report(O)).cashboxes.find((c) => c.id === cash)!;
    expect(box.opening).toBe(100000);
    expect(box.in).toBe(375025);
    expect(box.out).toBe(0);
    expect(box.closing).toBe(box.opening + box.in - box.out);
    expect(box.entries.map((e) => e.source_type).sort()).toEqual(['payment', 'payment', 'sale', 'sale']);
    expect(box.entries.reduce((a, e) => a + e.in - e.out, 0)).toBe(box.in - box.out);
    // الختامي = رصيد الخزنة في الدفتر
    const bal = (await admin(`select sum(debit - credit)::bigint b from journal_lines where account_id = $1`, [cash])).rows[0].b;
    expect(Number(bal)).toBe(box.closing);
  });

  it('حدود اليوم: فترة بعد الحركات فاضية، والختامي بيبقى الافتتاحي', async () => {
    const later = new Date(Date.now() + 60_000).toISOString();
    const r = await report(O, null, later, to);
    expect(r.collections).toEqual([]);
    expect(r.cashboxes.find((c) => c.id === cash)).toMatchObject({ opening: 475025, in: 0, out: 0, closing: 475025 });
  });

  it('الإلغاء: البيع الملغي ما يدخلش التحصيل، والتسوية لسه بتطابق', async () => {
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 9999 }]), cash], main)).rows[0].e;
    await as(O, `select reverse_entry($1, 'غلط')`, [e], main);
    const r = await report(O);
    expect(cashRow(r)!.total).toBe(375025);
    const box = r.cashboxes.find((c) => c.id === cash)!;
    expect(box.in - box.out).toBe(375025);
    expect(box.entries.filter((x) => x.cancelled)).toHaveLength(2);
  });

  it('المرتجع: بيظهر لوحده وبيتخصم من الإجمالي', async () => {
    await as(O, `select sale_return($1, $2, 1, 5000, $3, $4, false, 'مرتجع')`, [id(), acc, cash, cust], main);
    const c = cashRow(await report(O))!;
    expect(c).toMatchObject({ payments: 300000, sales: 75025, refunds: 5000, total: 370025 });
  });

  it('الفرع: بيع الفرع التاني ما يدخلش في تقرير الرئيسي، وموظف الفرع التاني يشوف فرعه بس', async () => {
    await as(O, `select owner_capital($1, $2, 1000)`, [id(), cash2], B2);
    await as(R2, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 20000 }]), cash2], B2);
    expect(cashRow(await report(O, main))!.sales).toBe(75025);
    expect(cashRow(await report(O, B2))!.sales).toBe(20000);
    expect(cashRow(await report(O))!.sales).toBe(95025);
    // حتى لو طلب الرئيسي أو كل الفروع، بيرجعله فرعه بس
    for (const b of [null, main]) {
      const r = await report(R2, b);
      expect(r.cashboxes.map((c) => c.id)).toEqual([cash2]);
      expect(cashRow(r)!.sales).toBe(20000);
    }
  });

  it('الفني، أو الاستقبال من غير "المالية ← يشوف"، ما يشوفوش التقرير', async () => {
    await as(O, `select set_staff_override($1, 'finance', 'view', null)`, [R2]);
    await expect(report(R2)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [R2]);
    await expect(report(T)).rejects.toThrow(/E_FORBIDDEN/);
  });
});
