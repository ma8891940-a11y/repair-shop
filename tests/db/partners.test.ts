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
});
