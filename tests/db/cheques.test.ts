// R7 (0063): الشيكات: استلام من عميل وإصدار لمورد، والصرف والرفض، والأرصدة والقيود متوازنة، والصلاحيات والفروع
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
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();
const DUE = '2026-12-31';

d('الشيكات', () => {
  let O = '';
  let R1 = ''; // استقبال الرئيسي
  let R2 = ''; // استقبال الفرع التاني
  let shop = '';
  let main = '';
  const B2 = id();
  let bank = '';
  let cust = '';
  let sup = '';
  /** رصيد طرف (عميل أو مورد) من الدفتر: موجب = ليّا */
  const partyBal = async (party: string, code: 'ar' | 'ap') =>
    Number((await admin(`select coalesce(sum(l.debit - l.credit), 0)::bigint b from journal_lines l join accounts a on a.id = l.account_id where a.code = $2 and a.shop_id = $3 and l.party_id = $1`, [party, code, shop])).rows[0].b);
  const accBal = async (code: string) =>
    Number((await admin(`select coalesce(sum(l.debit - l.credit), 0)::bigint b from journal_lines l join accounts a on a.id = l.account_id where a.code = $1 and a.shop_id = $2`, [code, shop])).rows[0].b);
  const pos = async () => (await as(O, `select financial_position($1, $2) p`, [FROM(), TO()])).rows[0].p;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`chq-o-${tag}@c.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الشيكات')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'C2', null, null)`, [B2]);
    bank = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'bank_transfer'`, [shop, main])).rows[0].id;
    for (const [name, br] of [['استقبال 1', main], ['استقبال 2', B2]] as const) {
      const em = `chq-${br.slice(0, 6)}-${tag}@c.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, 'reception', $3)`, [em, name, [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (br === main) R1 = u;
      else R2 = u;
    }
    cust = id();
    sup = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الشيك', '01033334444')`, [cust]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الشيك')`, [sup]);
    // العميل عليه 5000، وللمورد 8000 (من بيع وشرا آجل)
    const item = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة')`, [item]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, null)`, [id(), sup, JSON.stringify([{ item, qty: 4, unit_cost: 200000 }])], main);
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 500000 }]), cust], main);
  }, 60_000);
  afterAll(async () => db?.end());

  // قرار صاحب المشروع (0065): الشيك "تحت التحصيل" ما بيقللش الدين غير لما يتصرف
  it('شيك من عميل: الدين ما بيقلش وقت الاستلام، وبيقل وقت الصرف والفلوس في البنك', async () => {
    expect(await partyBal(cust, 'ar')).toBe(500000);
    const c = id();
    await as(O, `select cheque_receive($1, $2, '000123', 'البنك الأهلي', $3, 300000, 'دفعة')`, [c, cust, DUE], main);
    await as(O, `select cheque_receive($1, $2, '000123', 'البنك الأهلي', $3, 300000, 'دفعة')`, [c, cust, DUE], main); // نفس الطلب مرتين = مرة
    expect(await partyBal(cust, 'ar')).toBe(500000);
    expect(await accBal('cheques_in')).toBe(0);
    expect((await admin(`select status, branch_id, entry_id from cheques where id = $1`, [c])).rows[0]).toEqual({ status: 'pending', branch_id: main, entry_id: null });
    expect((await pos()).balanced).toBe(true);
    const op = id();
    await as(O, `select cheque_clear($1, $2, $3)`, [op, c, bank], main);
    await as(O, `select cheque_clear($1, $2, $3)`, [op, c, bank], main);
    expect(await partyBal(cust, 'ar')).toBe(200000);
    expect(await accBal('cheques_in')).toBe(0);
    // الصرف بيتسجل دفعة من العميل (مرة واحدة)
    expect((await admin(`select count(*)::int n, sum(amount)::bigint a from payments where customer_id = $1`, [cust])).rows[0]).toEqual({ n: 1, a: '300000' });
    expect((await admin(`select status from cheques where id = $1`, [c])).rows[0].status).toBe('cleared');
    expect((await pos()).cashboxes.find((x: { id: string }) => x.id === bank).balance).toBe(300000);
    await expect(as(O, `select cheque_bounce($1, $2, 'متأخر')`, [id(), c], main)).rejects.toThrow(/E_CHEQUE_DONE/);
    // صرف تاني بعملية جديدة (مش نفس الطلب) مرفوض: الفلوس ما تدخلش مرتين
    await expect(as(O, `select cheque_clear($1, $2, $3)`, [id(), c, bank], main)).rejects.toThrow(/E_CHEQUE_DONE/);
    expect(await accBal('cheques_in')).toBe(0);
  });

  it('شيك مرفوض: الدين فضل زي ما هو من غير قيد، والسبب متسجل، ومن غير سبب مرفوض، ونفس الطلب مرتين = مرة', async () => {
    const c = id();
    await as(O, `select cheque_receive($1, $2, '000124', null, $3, 200000)`, [c, cust, DUE], main);
    expect(await partyBal(cust, 'ar')).toBe(200000);
    await expect(as(O, `select cheque_bounce($1, $2, '  ')`, [id(), c], main)).rejects.toThrow(/E_REASON_REQUIRED/);
    const op = id();
    await as(O, `select cheque_bounce($1, $2, 'رصيد غير كافي')`, [op, c], main);
    await as(O, `select cheque_bounce($1, $2, 'رصيد غير كافي')`, [op, c], main);
    await expect(as(O, `select cheque_bounce($1, $2, 'تاني')`, [id(), c], main)).rejects.toThrow(/E_CHEQUE_DONE/);
    expect(await partyBal(cust, 'ar')).toBe(200000);
    expect(await accBal('cheques_in')).toBe(0);
    const row = (await admin(`select status, note, settle_entry_id from cheques where id = $1`, [c])).rows[0];
    expect(row).toMatchObject({ status: 'bounced', settle_entry_id: null });
    expect(row.note).toContain('رصيد غير كافي');
    // كشف حساب العميل: البيع وصرف الشيك الأول بس (الشيك المرفوض ما عملش قيد)
    const st = (await admin(`select e.source_type from journal_lines l join journal_entries e on e.id = l.entry_id join accounts a on a.id = l.account_id where a.code = 'ar' and l.party_id = $1 order by e.entry_no`, [cust])).rows.map((r) => r.source_type);
    expect(st).toEqual(['sale', 'cheque_clear']);
  });

  it('شيك لمورد: اللي له بيقل، والشيك مستحق الدفع، وبعد الصرف بيخرج من البنك. والمرفوض بيرجّع الدين', async () => {
    expect(await partyBal(sup, 'ap')).toBe(-800000);
    const c = id();
    await as(O, `select cheque_issue($1, $2, '777', 'بنك مصر', $3, 500000)`, [c, sup, DUE], main);
    expect(await partyBal(sup, 'ap')).toBe(-300000);
    expect(await accBal('cheques_out')).toBe(-500000);
    expect((await pos()).cheques_out).toBe(500000);
    await as(O, `select cheque_clear($1, $2, $3)`, [id(), c, bank], main);
    expect(await accBal('cheques_out')).toBe(0);
    expect((await pos()).cashboxes.find((x: { id: string }) => x.id === bank).balance).toBe(-200000);
    const c2 = id();
    await as(O, `select cheque_issue($1, $2, '778', null, $3, 100000)`, [c2, sup, DUE], main);
    await as(O, `select cheque_bounce($1, $2, 'اتلغى قبل الصرف')`, [id(), c2], main);
    expect(await partyBal(sup, 'ap')).toBe(-300000);
    const p = await pos();
    expect(p.balanced).toBe(true);
    expect(p.cheques_out).toBe(0);
  });

  it('قيود الشيكات ما بتتلغيش بقيد عكسي (الرفض بس)، وما حدش يكتب في الجدول مباشرة، ومفيش حذف', async () => {
    const c = id();
    await as(O, `select cheque_receive($1, $2, '9001', null, $3, 1000)`, [c, cust, DUE], main);
    const e = (await as(O, `select cheque_clear($1, $2, $3) e`, [id(), c, bank], main)).rows[0].e;
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_CHEQUE_REVERSAL/);
    expect((await as(O, `update cheques set amount = 1 where id = $1 returning id`, [c]).catch(() => ({ rowCount: 0 }))).rowCount).toBe(0);
    await expect(admin(`delete from cheques where id = $1`, [c])).rejects.toThrow();
    await expect(as(O, `select cheque_receive($1, $2, '', null, $3, 1000)`, [id(), cust, DUE])).rejects.toThrow(/E_BAD_INPUT/);
    await expect(as(O, `select cheque_receive($1, $2, '1', null, $3, 0)`, [id(), cust, DUE])).rejects.toThrow(/E_BAD_AMOUNT/);
    await expect(as(O, `select cheque_receive($1, $2, '1', null, $3, 1000)`, [id(), id(), DUE])).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('الصلاحيات والفروع: الاستقبال من غير صلاحية لأ، وبصلاحية المالية في فرعه بس', async () => {
    await expect(as(R1, `select cheque_receive($1, $2, '55', null, $3, 1000)`, [id(), cust, DUE], main)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R1, `select * from cheques_list()`)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(R1, `select count(*)::int n from cheques`)).rows[0].n).toBe(0);
    for (const u of [R1, R2]) for (const op of ['view', 'add']) await as(O, `select set_staff_override($1, 'finance', $2, true)`, [u, op]);
    const c = id();
    await as(R2, `select cheque_receive($1, $2, '56', null, $3, 1000)`, [c, cust, DUE], B2);
    expect((await admin(`select branch_id from cheques where id = $1`, [c])).rows[0].branch_id).toBe(B2);
    // استقبال الرئيسي ما يشوفش ولا يصرف شيك الفرع التاني
    expect((await as(R1, `select id from cheques_list()`)).rows.some((r) => r.id === c)).toBe(false);
    await expect(as(R1, `select cheque_bounce($1, $2, 'x')`, [id(), c], main)).rejects.toThrow(/E_NOT_FOUND|E_FORBIDDEN/);
    const mine = (await as(R2, `select id, party_name, status from cheques_list('pending')`, [], B2)).rows;
    expect(mine.find((r) => r.id === c)).toMatchObject({ party_name: 'عميل الشيك', status: 'pending' });
    // الصرف بخزنة فرع تاني مرفوض، والرفض من صاحب المحل وهو فاتح فرع تاني بيتسجل في فرع الشيك نفسه
    const mainBank = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    await expect(as(O, `select cheque_clear($1, $2, $3)`, [id(), c, mainBank], main)).rejects.toThrow(/E_BRANCH/);
    const b2Cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, B2])).rows[0].id;
    const be = (await as(O, `select cheque_clear($1, $2, $3) e`, [id(), c, b2Cash], main)).rows[0].e;
    expect((await admin(`select branch_id from journal_entries where id = $1`, [be])).rows[0].branch_id).toBe(B2);
    for (const u of [R1, R2]) for (const op of ['view', 'add']) await as(O, `select set_staff_override($1, 'finance', $2, null)`, [u, op]);
  });

  it('التسليم قبل صرف الشيك: ممنوع (الشيك مش دفعة)، وصاحب المحل بس يسلّم بالآجل، وبعد الصرف الجهاز مدفوع', async () => {
    const [d1, d2] = [id(), id()];
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $3, 'Samsung', 'A54', 'شاشة'), ($2, $3, 'Oppo', 'A78', 'شحن')`, [d1, d2, cust], main);
    await as(O, `insert into device_costs(shop_id, device_id, final_cost) values (gen_random_uuid(), $1, 50000), (gen_random_uuid(), $2, 70000)`, [d1, d2], main);
    for (const d of [d1, d2]) for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [d, st], main);
    const c1 = id();
    await as(O, `select cheque_receive($1, $2, 'D-1', null, $3, 50000, null, $4)`, [c1, cust, DUE, d1], main);
    await expect(as(O, `update devices set status = 'delivered' where id = $1`, [d1], main)).rejects.toThrow(/E_UNPAID/);
    await as(O, `select cheque_clear($1, $2, $3)`, [id(), c1, bank], main);
    await as(O, `update devices set status = 'delivered' where id = $1`, [d1], main);
    // شيك على جهاز تاني لسه ما اتصرفش: الاستقبال ما تقدرش تسلّم، وصاحب المحل يقدر بالآجل
    await as(O, `select cheque_receive($1, $2, 'D-2', null, $3, 70000, null, $4)`, [id(), cust, DUE, d2], main);
    await expect(as(R1, `update devices set status = 'delivered' where id = $1`, [d2], main)).rejects.toThrow(/E_UNPAID/);
    await expect(as(R1, `select deliver_on_credit($1)`, [d2], main)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select deliver_on_credit($1)`, [d2], main);
    expect((await admin(`select status from devices where id = $1`, [d2])).rows[0].status).toBe('delivered');
    // الجهاز لازم يكون بتاع نفس العميل
    await expect(as(O, `select cheque_receive($1, $2, 'D-3', null, $3, 1000, null, $4)`, [id(), cust, DUE, id()], main)).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('محل تاني ما يشوفش شيكات المحل ده', async () => {
    const X = await user(`chq-x-${tag}@c.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    expect((await as(X, `select count(*)::int n from cheques`)).rows[0].n).toBe(0);
    expect((await as(X, `select count(*)::int n from cheques_list()`)).rows[0].n).toBe(0);
  });
});
