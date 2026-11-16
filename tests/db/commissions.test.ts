// C5: عمولات الفنيين والمكافآت والجزاءات
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;

async function as<T extends pg.QueryResultRow = pg.QueryResultRow>(uid: string | null, sql: string, params: unknown[] = [], headers: Record<string, string> = {}) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': '10.9.9.9', ...headers })]);
    if (uid) {
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
    } else {
      await db.query(`select set_config('request.jwt.claims', '', true)`);
      await db.query('set local role anon');
    }
    const r = await db.query<T>(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
async function user(email: string) {
  const id = randomUUID();
  await db.query('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [id, email]);
  return id;
}
const tag = randomUUID().slice(0, 8);
let owner = '';
let rec = '';
let t1 = '';
let t2 = '';
let cash = '';
let part = '';

async function staff(email: string, role: string, name = 'موظف') {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [email, name, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}
const ph = () => `0103${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
/** جهاز بيمر بكل الحالات: الفني بيبدأ الفحص، ويركّب قطعة لو مطلوب، وصاحب المحل بيسلّم بالآجل */
async function repair(tech: string, final: number, withPart = false) {
  const c = randomUUID();
  const dv = randomUUID();
  await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [c, ph()]);
  await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Xiaomi', 'Note 12', 'شاشة')`, [dv, c]);
  await as(tech, `update devices set status = 'inspecting' where id = $1`, [dv]);
  if (withPart) await as(tech, `select use_part($1, $2, $3, 1)`, [randomUUID(), dv, part]);
  for (const st of ['in_repair', 'repaired', 'ready']) await as(tech, `update devices set status = $2 where id = $1`, [dv, st]);
  await as(owner, `insert into device_costs(shop_id, device_id, estimated_cost, final_cost) values (gen_random_uuid(), $1, $2, $2)`, [dv, final]);
  await as(owner, `select deliver_on_credit($1)`, [dv]);
  return dv;
}
const report = async () =>
  Object.fromEntries((await as(owner, `select * from commissions_report(now() - interval '1 day', now() + interval '1 day')`)).rows.map((r) => [r.technician_id, r]));
const owed = async (tech: string) =>
  Number((await as(owner, `select coalesce(sum(l.credit - l.debit), 0)::bigint b from journal_lines l join accounts a on a.id = l.account_id where a.code = 'salaries_payable' and l.party_id = $1`, [tech])).rows[0].b);
const clean = async () => expect((await as(owner, `select integrity_report() r`)).rows[0].r).toEqual([]);

d('C5: عمولات الفنيين', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`oc5-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل العمولات')`);
    rec = await staff(`rc5-${tag}@t.test`, 'reception');
    t1 = await staff(`t1c5-${tag}@t.test`, 'technician', 'كريم');
    t2 = await staff(`t2c5-${tag}@t.test`, 'technician', 'سامح');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    const sup = randomUUID();
    part = randomUUID();
    await as(owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(owner, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة Note 12', 50000)`, [part]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: part, qty: 5, unit_cost: 20000 }]), cash]);
  });
  afterAll(async () => db?.end());

  it('من غير قواعد: مفيش عمولة', async () => {
    await repair(t1, 100000);
    expect(await owed(t1)).toBe(0);
  });

  it('نسبة من المصنعية (التكلفة − القطع)، وقاعدة الفني بتكسب العامة، والقيد متوازن، ومرة واحدة لكل جهاز', async () => {
    // الاستقبال ما تشوفش القواعد ولا تكتبها
    await expect(as(rec, `insert into commission_rules(shop_id, mode, value) values (gen_random_uuid(), 'percent', 3000)`)).rejects.toThrow();
    await as(owner, `insert into commission_rules(shop_id, mode, value) values (gen_random_uuid(), 'percent', 3000)`);
    await as(owner, `insert into commission_rules(shop_id, technician_id, mode, value) values (gen_random_uuid(), $1, 'fixed', 15000)`, [t2]);
    expect((await as(rec, `select * from commission_rules`)).rows).toHaveLength(0);
    await expect(as(owner, `insert into commission_rules(shop_id, mode, value) values (gen_random_uuid(), 'percent', 10001)`)).rejects.toThrow(/check/);
    // (100,000 − قطعة 20,000) × 30% = 24,000
    const dv = await repair(t1, 100000, true);
    expect(await owed(t1)).toBe(24000);
    // الفني التاني: مبلغ ثابت 15,000
    await repair(t2, 300000);
    expect(await owed(t2)).toBe(15000);
    await clean();
    // الجهاز رجع ضمان واتسلّم تاني: مفيش عمولة تانية
    await as(owner, `update devices set status = 'warranty_return' where id = $1`, [dv]);
    for (const st of ['in_repair', 'repaired', 'ready']) await as(t1, `update devices set status = $2 where id = $1`, [dv, st]);
    await as(owner, `update devices set status = 'delivered' where id = $1`, [dv]);
    expect(await owed(t1)).toBe(24000);
  });

  it('مكافأة وجزاء (بسبب) من صاحب المحل بس، والصرف بيقلل المستحق، والتقرير مطابق للقيود', async () => {
    await expect(as(rec, `select staff_bonus($1, $2, 5000)`, [randomUUID(), t1])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await as(owner, `select staff_bonus($1, $2, 5000, 'شغل ممتاز')`, [randomUUID(), t1]);
    await expect(as(owner, `select staff_penalty($1, $2, 2000)`, [randomUUID(), t1])).rejects.toThrow(/E_REASON_REQUIRED/);
    await as(owner, `select staff_penalty($1, $2, 2000, 'تأخير')`, [randomUUID(), t1]);
    expect(await owed(t1)).toBe(24000 + 5000 - 2000);
    await as(owner, `select owner_capital($1, $2, 1000000)`, [randomUUID(), cash]);
    await as(owner, `select pay_salary($1, $2, $3, 10000)`, [randomUUID(), t1, cash]);
    const r = (await report())[t1];
    expect(r).toMatchObject({ full_name: 'كريم', devices: '1', commission: '24000', bonus: '5000', penalty: '2000', paid: '10000', balance: String(24000 + 5000 - 2000 - 10000) });
    expect(Number(r.balance)).toBe(await owed(t1));
    // عكس العمولة بيتحسب على العمولة نفسها
    const e = (await as(owner, `select id from journal_entries where source_type = 'commission' and memo is not null order by created_at limit 1`)).rows[0].id;
    await as(owner, `select reverse_entry($1, 'غلط في النسبة')`, [e]);
    expect((await report())[t1].commission).toBe('0');
    await clean();
  });
});
