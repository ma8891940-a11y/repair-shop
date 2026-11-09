// البند 5: الشركاء. كل رقم متحسب باليد
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

// كل اللي الملف ده بيعمله في قاعدة الاختبار بيتمسح في الآخر
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

d('الشركاء: النسب، ورأس المال، والسحب (مش مصروف)، وتوزيع الأرباح', () => {
  let O = '';
  let R = '';
  const acc: Record<string, string> = {};
  const A = id();
  const B = id();
  // فترة التوزيع: من ساعة فاتت لساعة جاية (كل العمليات جواها)
  const F1 = new Date(Date.now() - 3600_000).toISOString();
  const T1 = new Date(Date.now() + 3600_000).toISOString();
  const bal = async (code: string) => Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1`, [acc[code]])).rows[0].b);
  const partners = async () => Object.fromEntries((await as(O, `select * from partner_balances()`)).rows.map((r) => [r.id, { capital: Number(r.capital), current: Number(r.current), total: Number(r.total) }]));
  const pos = async () => (await as(O, `select financial_position($1, $2) p`, [F1, T1])).rows[0].p;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pt-o-${tag}@p.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل الشركاء')`);
    const em = `pt-r-${tag}@p.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
  }, 60_000);
  afterAll(async () => db?.end());

  it('النسب: مجموعها ما يعديش 100%، والاستقبال ما يشوفش الشركاء خالص', async () => {
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'أحمد', 6000), ($2, gen_random_uuid(), 'سامي', 3000)`, [A, B]);
    await expect(as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'زيادة', 2000)`, [id()])).rejects.toThrow(/E_SHARE_OVER_100/);
    await expect(as(O, `update partners set share_bp = 7500 where id = $1`, [B])).rejects.toThrow(/E_SHARE_OVER_100/);
    expect((await as(R, `select * from partners`)).rowCount).toBe(0);
    await expect(as(R, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'x', 100)`, [id()])).rejects.toThrow();
    await expect(as(R, `select * from partner_balances()`)).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('رأس المال: إيداع كاش ورصيد افتتاحي، وده مش ربح', async () => {
    await as(O, `select partner_deposit($1, $2, $3, 1000000)`, [id(), A, acc.cash_cash]);
    await as(O, `select opening_balance($1, 'partner', $2, 500000)`, [id(), B]);
    const p = await partners();
    expect(p[A]).toEqual({ capital: 1000000, current: 0, total: 1000000 });
    expect(p[B]).toEqual({ capital: 500000, current: 0, total: 500000 });
    expect(Number((await pos()).profit)).toBe(0);
  });

  it('توزيع الربح: 1000 ج ← أحمد 600 وسامي 300 والـ 100 الباقيين للمحل، والربح وقيمة المحل ما بيتغيروش', async () => {
    // شراء 10 × 100 كاش، وبيع 10 × 250، ومصروف إيجار 500 ← ربح 2500 − 1000 − 500 = 1000 ج
    const it = id();
    const sup = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'جراب')`, [it]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: it, qty: 10, unit_cost: 10000 }]), acc.cash_cash]);
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: it, qty: 10, price: 25000 }]), acc.cash_cash]);
    await as(O, `select record_expense($1, $2, $3, 50000)`, [id(), acc.exp_rent, acc.cash_cash]);
    const before = await pos();
    expect(Number(before.profit)).toBe(100000);
    const prev = (await as(O, `select profit_split($1, $2) s`, [F1, T1])).rows[0].s;
    expect(Number(prev.profit)).toBe(100000);
    expect(prev.shares.map((x: { amount: number }) => Number(x.amount))).toEqual([60000, 30000]);
    const k = id();
    const e = (await as(O, `select distribute_profit($1, $2, $3) e`, [k, F1, T1])).rows[0].e;
    // نفس الطلب مرتين (المزامنة) = نفس القيد
    expect((await as(O, `select distribute_profit($1, $2, $3) e`, [k, F1, T1])).rows[0].e).toBe(e);
    const p = await partners();
    expect(p[A].current).toBe(60000);
    expect(p[B].current).toBe(30000);
    expect(await bal('retained')).toBe(90000);
    const after = await pos();
    expect(Number(after.profit)).toBe(100000);
    expect(Number(after.net_worth)).toBe(Number(before.net_worth));
    expect(after.balanced).toBe(true);
    // نفس الفترة تاني ممنوع
    await expect(as(O, `select distribute_profit($1, $2, $3)`, [id(), F1, T1])).rejects.toThrow(/E_PERIOD_DISTRIBUTED/);
    expect((await as(O, `select profit_split($1, $2) s`, [F1, T1])).rows[0].s.overlap).toBe(true);
    // ولو التوزيع اتلغى بقيد عكسي، الفترة بتتفتح تاني
    await as(O, `select reverse_entry($1, 'النسب كانت غلط')`, [e]);
    expect((await partners())[A].current).toBe(0);
    await as(O, `select distribute_profit($1, $2, $3)`, [id(), F1, T1]);
    expect((await partners())[A].current).toBe(60000);
  });

  it('سحب الشريك مش مصروف: الخزنة بتقل وجاريه بيقل، والربح زي ما هو', async () => {
    const cash0 = await bal('cash_cash');
    const profit0 = Number((await pos()).profit);
    await as(O, `select partner_withdraw($1, $2, $3, 20000)`, [id(), A, acc.cash_cash]);
    expect(await bal('cash_cash')).toBe(cash0 - 20000);
    expect((await partners())[A]).toEqual({ capital: 1000000, current: 40000, total: 1040000 });
    expect(Number((await pos()).profit)).toBe(profit0);
    // سحب من رأس المال
    await as(O, `select partner_withdraw($1, $2, $3, 100000, 'سحب جزء من رأس المال', true)`, [id(), B, acc.cash_cash]);
    expect((await partners())[B]).toEqual({ capital: 400000, current: 30000, total: 430000 });
    // كشف حساب الشريك: كل الحركات والرصيد في الآخر
    const st = (await as(O, `select statement('partner', $1, $2, $3) s`, [A, F1, T1])).rows[0].s;
    expect(st.moves.at(-1).balance).toBe(1040000);
    expect(st.moves.map((m: { source_type: string }) => m.source_type)).toContain('partner_withdrawal');
    // الشريك اللي ليه فلوس ما بيتحذفش
    await expect(as(O, `update partners set deleted_at = now() where id = $1`, [A])).rejects.toThrow(/E_HAS_BALANCE/);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('فترة خسارة: الخسارة بتتوزع بنفس النسب (جاري الشريك بيقل)', async () => {
    // فترة جديدة بعد الأولى: مصروف 200 ج بس ← خسارة 200
    const F2 = new Date(Date.now() + 3600_000 + 1000).toISOString();
    const T2 = new Date(Date.now() + 7200_000).toISOString();
    const e = (await as(O, `select record_expense($1, $2, $3, 20000) e`, [id(), acc.exp_electricity, acc.cash_cash])).rows[0].e;
    await admin(`alter table journal_entries disable trigger user`);
    await admin(`update journal_entries set occurred_at = now() + interval '90 minutes' where id = $1`, [e]);
    await admin(`alter table journal_entries enable trigger user`);
    await as(O, `select distribute_profit($1, $2, $3)`, [id(), F2, T2]);
    const p = await partners();
    expect(p[A].current).toBe(40000 - 12000);
    expect(p[B].current).toBe(30000 - 6000);
    // شريك دخل بعد نهاية الفترة ما بياخدش منها
    const late = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp, joined_on) values ($1, gen_random_uuid(), 'متأخر', 500, (now() at time zone 'Africa/Cairo')::date + 3)`, [late]);
    const sp = (await as(O, `select profit_split($1, $2) s`, [F1, T1])).rows[0].s;
    expect(sp.shares.map((x: { partner: string }) => x.partner)).not.toContain(late);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('شريك دخل بـ 50,000 كاش: الخزنة +50,000، والربح ما اتغيرش، و"عليا للناس" ما اتغيرش، والمعادلة متوازنة، وقيمة المحل ما نزلتش', async () => {
    const C = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'كريم', 500)`, [C]);
    const before = await pos();
    const cash0 = await bal('cash_cash');
    await as(O, `select partner_capital_in($1, $2, 'cash', 5000000, null, $3)`, [id(), C, acc.cash_cash]);
    const after = await pos();
    expect(await bal('cash_cash')).toBe(cash0 + 5000000);
    expect(Number(after.profit)).toBe(Number(before.profit));
    expect(Number(after.payables)).toBe(Number(before.payables));
    // قيمة المحل (الأصول − اللي لناس من بره) بتزيد بالفلوس اللي دخلت، ما بتنزلش
    expect(Number(after.net_worth)).toBe(Number(before.net_worth) + 5000000);
    expect(after.balanced).toBe(true);
    const e = after.equation;
    expect(Number(e.assets)).toBe(Number(e.liabilities) + Number(e.equity) + Number(e.earnings));
    const pc = after.equity_parts.partners.find((x: { id: string }) => x.id === C);
    expect(Number(pc.capital)).toBe(5000000);
  });

  it('شريك دخل ببضاعة: المخزون بيزيد بنفس الطريقة (والحركة في المخزون بالكمية والتكلفة)، وبمعدات: الأصول الثابتة، وبرأس مال قديم: من غير ما الخزن تتلمس', async () => {
    const C = id();
    const it = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'منير', 0)`, [C]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشات من الشريك')`, [it]);
    const before = await pos();
    // 20 شاشة × 400 ج = 8,000، بتاريخ قديم
    await as(O, `select partner_capital_in($1, $2, 'goods', null, (now() at time zone 'Africa/Cairo')::date - 10, null, $3::jsonb)`, [id(), C, JSON.stringify([{ item: it, qty: 20, unit_cost: 40000 }])]);
    let after = await pos();
    expect(Number(after.inventory)).toBe(Number(before.inventory) + 800000);
    expect(Number(after.profit)).toBe(Number(before.profit));
    expect(Number(after.payables)).toBe(Number(before.payables));
    expect(Number((await admin(`select sum(qty) q from stock_moves where item_id = $1`, [it])).rows[0].q)).toBe(20);
    // معدات بـ 3,000 (مكنة فصل شاشات): الأصول الثابتة وقيمة المحل
    await as(O, `select partner_capital_in($1, $2, 'equipment', 300000, null, null, null, 'مكنة فصل شاشات')`, [id(), C]);
    after = await pos();
    expect(Number(after.fixed_assets)).toBe(300000);
    expect(Number(after.net_worth)).toBe(Number(before.net_worth) + 1100000);
    // رأس مال قديم 2,000: الخزن ما اتلمستش، ورأس مال صاحب المحل بيقل بنفس المبلغ
    const cash0 = Number(after.cash);
    const own0 = Number(after.equity_parts.owner_capital);
    await as(O, `select partner_capital_in($1, $2, 'old', 200000, '2025-12-31')`, [id(), C]);
    after = await pos();
    expect(Number(after.cash)).toBe(cash0);
    expect(Number(after.equity_parts.owner_capital)).toBe(own0 - 200000);
    const pm = after.equity_parts.partners.find((x: { id: string }) => x.id === C);
    expect(Number(pm.capital)).toBe(1300000);
    expect(after.balanced).toBe(true);
    // التاريخ في كشف الشريك زي ما اتكتب، وتاريخ في المستقبل ممنوع
    const st = (await as(O, `select statement('partner', $1, '2025-01-01', now() + interval '1 day') s`, [C])).rows[0].s;
    expect(st.moves[0].at.slice(0, 10)).toBe('2025-12-31');
    await expect(as(O, `select partner_capital_in($1, $2, 'cash', 100, (now() at time zone 'Africa/Cairo')::date + 2, $3)`, [id(), C, acc.cash_cash])).rejects.toThrow(/E_BAD_DATE/);
    // سحب جزء من رأس المال بتاريخ
    await as(O, `select partner_capital_out($1, $2, $3, 100000, (now() at time zone 'Africa/Cairo')::date - 1)`, [id(), C, acc.cash_cash]);
    expect(Number((await pos()).equity_parts.partners.find((x: { id: string }) => x.id === C).capital)).toBe(1200000);
    await expect(as(R, `select partner_capital_in($1, $2, 'cash', 100, null, $3)`, [id(), C, acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('أرباح الشركاء اللي اتوزعت ولسه ما اتسحبتش: سطر لوحدها، ومش جوه "عليا للناس"', async () => {
    const p = await pos();
    // من الاختبارات اللي فوق: أحمد 28,000 + سامي 24,000 قرش ليهم في الجاري
    expect(Number(p.partners_due)).toBe(28000 + 24000);
    // "عليا للناس" = الموردين والمرتبات (وعربون العملاء) بس: نفس الرقم من القيود مباشرة، من غير حسابات الشركاء
    const ext = Number((await admin(`select coalesce(sum(greatest(b, 0)), 0) n from (select sum(l.credit - l.debit) b from journal_lines l join accounts a on a.id = l.account_id
                                      where a.shop_id = (select shop_id from accounts where id = $1) and a.kind in ('payable', 'salaries') group by l.account_id, l.party_id) x`, [acc.ap])).rows[0].n);
    const custCredit = Number((await admin(`select coalesce(sum(greatest(b, 0)), 0) n from (select sum(l.credit - l.debit) b from journal_lines l join accounts a on a.id = l.account_id
                                      where a.shop_id = (select shop_id from accounts where id = $1) and a.kind in ('receivable', 'advances') group by l.account_id, l.party_id) x`, [acc.ap])).rows[0].n);
    expect(Number(p.payables)).toBe(ext + custCredit);
  });
});

