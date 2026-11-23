// بند 2 من qa-37: اختبارات تكامل مالية. كل عملية بتغيّر المخزون والخزنة والإيراد والتكلفة مرة واحدة، أو بتفشل كلها.
// وضغطتين متزامنتين (اتصالين منفصلين بنفس رقم العملية) = قيد واحد وحركة مخزون واحدة، من غير خطأ (0067).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
let db2: pg.Client;
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
/**
 * ضغطتين متزامنتين بجد: الطلب الأول بيفضل جوه الـ transaction (لسه ما اتحفظش) لحد ما القاعدة تقول
 * إن الطلب التاني (اتصال تاني) واقف مستنيه. بعدين الأول بيتحفظ والتاني بيكمّل. من غير ده Promise.all ممكن ما يتداخلش.
 */
async function twice(uid: string, sql: string, params: unknown[], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    const r1 = await db.query(sql, params);
    const p2 = on(db2, uid, sql, params, branch);
    let waited = false;
    for (let i = 0; i < 250 && !waited; i++) {
      waited = (await db.query(`select exists (select 1 from pg_locks where pid = $1 and not granted) w`, [pid2])).rows[0].w;
      if (!waited) await new Promise((r) => setTimeout(r, 20));
    }
    await db.query('commit');
    const r2 = await p2;
    expect(waited, 'الطلب التاني ما استناش الأول (مفيش تداخل)').toBe(true);
    return [r1, r2] as const;
  } catch (e) {
    await db.query('rollback').catch(() => {});
    throw e;
  }
}
let pid2 = 0;
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);

d('تكامل مالي (بند 2)', () => {
  let O = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cust = '';
  const acc = id(); // جراب بكمية
  const acc2 = id();
  const srv = id();

  /** لقطة: رصيد الخزنة، والمخزون (كمية وقيمة)، والإيراد، والتكلفة، وعدد القيود، وتوازن الدفتر */
  async function snap() {
    const q = async (sql: string, p: unknown[] = []) => Number((await admin(sql, p)).rows[0].v ?? 0);
    return {
      cash: await q(`select sum(debit - credit) v from journal_lines where account_id = $1`, [cash]),
      qty: await q(`select sum(qty) v from stock_moves where shop_id = $1 and item_id = $2`, [shop, acc]),
      stock: await q(`select sum(value) v from stock_moves where shop_id = $1`, [shop]),
      revenue: await q(`select sum(l.credit - l.debit) v from journal_lines l join accounts a on a.id = l.account_id where l.shop_id = $1 and a.type = 'revenue'`, [shop]),
      cogs: await q(`select sum(l.debit - l.credit) v from journal_lines l join accounts a on a.id = l.account_id where l.shop_id = $1 and a.kind = 'cogs'`, [shop]),
      entries: await q(`select count(*) v from journal_entries where shop_id = $1`, [shop]),
      unbalanced: await q(`select count(*) v from (select entry_id from journal_lines where shop_id = $1 group by entry_id having sum(debit) <> sum(credit)) x`, [shop]),
    };
  }

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    db2 = new pg.Client({ connectionString: url });
    await Promise.all([db.connect(), db2.connect()]);
    pid2 = (await db2.query('select pg_backend_pid() p')).rows[0].p;
    O = randomUUID();
    await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [O, `fi-o-${tag}@f.test`]);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل التكامل')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'FI2', null, null)`, [B2]);
    cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل التكامل', '01066667777')`, [cust]);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'accessory', 'جراب', 15025), ($2, gen_random_uuid(), 'accessory', 'سماعة', 30000), ($3, gen_random_uuid(), 'service', 'تنظيف', 5000)`, [acc, acc2, srv]);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash], main);
    // 18 جراب × 50 جنيه، و5 سماعات × 120
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: acc, qty: 18, unit_cost: 5000 }, { item: acc2, qty: 5, unit_cost: 12000 }]), cash], main);
  }, 60_000);
  afterAll(async () => {
    await Promise.all([db?.end(), db2?.end()]);
  });

  it('بيع بكسور وأكتر من صنف: 150.25 دقيق في الخزنة والإيراد، والمخزون والتكلفة بيتغيروا مرة واحدة، والقيد متوازن', async () => {
    const a = await snap();
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 15025 }, { item: acc2, qty: 2, price: 30000 }, { item: srv, qty: 1, price: 5000 }]), cash], main);
    const b = await snap();
    expect(b.cash - a.cash).toBe(15025 + 60000 + 5000);
    expect(b.revenue - a.revenue).toBe(80025);
    expect(b.qty - a.qty).toBe(-1);
    expect(b.cogs - a.cogs).toBe(5000 + 2 * 12000);
    expect(b.stock - a.stock).toBe(-(5000 + 2 * 12000));
    expect(b.entries - a.entries).toBe(1);
    expect(b.unbalanced).toBe(0);
  });

  it('فشل في نص العملية (السطر التاني صنف مش موجود): ولا حاجة بتتغير', async () => {
    const a = await snap();
    await expect(as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 15025 }, { item: id(), qty: 1, price: 100 }]), cash], main)).rejects.toThrow(/E_NOT_FOUND/);
    expect(await snap()).toEqual(a);
  });

  it('ضغطتين متزامنتين على "سجّل" (نفس رقم العملية من اتصالين): قيد واحد وحركة مخزون واحدة، والاتنين بيرجعوا نفس القيد', async () => {
    const a = await snap();
    const op = id();
    const lines = JSON.stringify([{ item: acc, qty: 2, price: 15025 }]);
    const sql = `select record_sale($1, $2::jsonb, $3) e`;
    const [r1, r2] = await twice(O, sql, [op, lines, cash], main);
    expect(r1.rows[0].e).toBe(r2.rows[0].e);
    const b = await snap();
    expect(b.entries - a.entries).toBe(1);
    expect(b.qty - a.qty).toBe(-2);
    expect(b.cash - a.cash).toBe(30050);
    expect((await admin(`select count(*)::int n from stock_moves where entry_id = $1`, [r1.rows[0].e])).rows[0].n).toBe(1);
    // إعادة الطلب بعد timeout (نفس الرقم تاني): نفس القيد من غير تغيير
    const r3 = await as(O, sql, [op, lines, cash], main);
    expect(r3.rows[0].e).toBe(r1.rows[0].e);
    expect(await snap()).toEqual(b);
  });

  it('دفعة (عربون) ومصروف متزامنين بنفس الرقم: مرة واحدة', async () => {
    const a = await snap();
    const pay = id();
    const exp = id();
    const rent = (await admin(`select id from accounts where shop_id = $1 and code = 'exp_rent'`, [shop])).rows[0].id;
    await twice(O, `select record_payment($1, $2, $3, 20000)`, [pay, cust, cash], main);
    await twice(O, `select record_expense($1, $2, $3, 7000)`, [exp, rent, cash], main);
    const b = await snap();
    expect(b.cash - a.cash).toBe(20000 - 7000);
    expect(b.entries - a.entries).toBe(2);
    expect((await admin(`select count(*)::int n from payments where id = $1 or entry_id in (select id from journal_entries where idem_key = $1)`, [pay])).rows[0].n).toBe(1);
  });

  it('(22ب) شيك مستلم وشيك صادر وخطة أقساط متزامنين بنفس الرقم: مرة واحدة من غير خطأ', async () => {
    const sup2 = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الشيك')`, [sup2]);
    const a = await snap();
    const [c1, c2, pl] = [id(), id(), id()];
    const rows = JSON.stringify([{ due: '2026-12-30', amount: 1000 }, { due: '2027-01-30', amount: 2500 }]);
    for (const [op, sql, params] of [
      [c1, `select cheque_receive($1, $2, 'T-1', null, '2026-12-31', 1000) r`, [c1, cust]],
      [c2, `select cheque_issue($1, $2, 'T-2', null, '2026-12-31', 1000) r`, [c2, sup2]],
      [pl, `select save_plan($1, 'customer', $2, $3::jsonb) r`, [pl, cust, rows]],
    ] as [string, string, unknown[]][]) {
      const [r1, r2] = await twice(O, sql, params, main);
      expect([r1.rows[0].r, r2.rows[0].r]).toEqual([op, op]);
    }
    const b = await snap();
    expect(b.entries - a.entries).toBe(1); // الشيك الصادر بس ليه قيد وقت الإصدار
    expect((await admin(`select count(*)::int n from cheques where id in ($1, $2)`, [c1, c2])).rows[0].n).toBe(2);
    expect((await admin(`select amount::int a from plan_installments where plan_id = $1 order by seq`, [pl])).rows.map((x) => x.a)).toEqual([1000, 2500]);
  });

  it('إلغاء البيع: بيرجّع الخزنة والمخزون والإيراد والتكلفة بالظبط، ومرة واحدة بس', async () => {
    const a = await snap();
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 3, price: 15025 }]), cash], main)).rows[0].e;
    await as(O, `select reverse_entry($1, 'غلط')`, [e], main);
    await expect(as(O, `select reverse_entry($1, 'تاني')`, [e], main)).rejects.toThrow();
    const b = await snap();
    expect({ ...b, entries: 0 }).toEqual({ ...a, entries: 0 });
    expect(b.entries - a.entries).toBe(2);
  });

  it('مرتجع جزئي: بيرجّع كمية المرتجع وقيمتها بس', async () => {
    const a = await snap();
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: acc, qty: 4, price: 15025 }]), cash], main);
    await as(O, `select sale_return($1, $2, 1, 15025, $3, $4, true, 'مرتجع')`, [id(), acc, cash, cust], main);
    const b = await snap();
    expect(b.qty - a.qty).toBe(-3);
    expect(b.cash - a.cash).toBe(3 * 15025);
    expect(b.unbalanced).toBe(0);
  });

  it('تحويل بين الفروع (مرتين بنفس الرقم في نفس اللحظة): الكمية بتنقل مرة واحدة، وقيمة المخزون الكلية ما بتتغيرش', async () => {
    const a = await snap();
    const op = id();
    const sql = `select transfer_stock($1, $2, 2, $3, $4) e`;
    await twice(O, sql, [op, acc, main, B2], main);
    const b = await snap();
    expect(b.stock).toBe(a.stock);
    expect(b.entries - a.entries).toBe(1);
    const q = async (br: string) => Number((await admin(`select coalesce(sum(qty), 0) v from stock_moves where item_id = $1 and branch_id = $2`, [acc, br])).rows[0].v);
    expect(await q(B2)).toBe(2);
  });

  it('التسليم بعربون: الإيراد بيتسجل مرة واحدة، والتسليم قبل السداد الكامل ممنوع، وبعد الدفع بيعدّي', async () => {
    const dv = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A35', 'شاشة')`, [dv, cust], main);
    await as(O, `insert into device_costs(shop_id, device_id, final_cost) values (gen_random_uuid(), $1, 100050)`, [dv], main);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [dv, st], main);
    await as(O, `select record_payment($1, $2, $3, 30000, $4)`, [id(), cust, cash, dv], main);
    await expect(as(O, `update devices set status = 'delivered' where id = $1`, [dv], main)).rejects.toThrow(/E_UNPAID/);
    await as(O, `select record_payment($1, $2, $3, 70050, $4)`, [id(), cust, cash, dv], main);
    const a = await snap();
    await as(O, `update devices set status = 'delivered' where id = $1`, [dv], main);
    const b = await snap();
    expect(b.revenue - a.revenue).toBe(100050);
    expect(b.cash).toBe(a.cash);
    expect((await admin(`select count(*)::int n from journal_entries where source_type = 'delivery' and source_id = $1`, [dv])).rows[0].n).toBe(1);
    expect(b.unbalanced).toBe(0);
  });
});
