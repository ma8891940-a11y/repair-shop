// R1 (0061): الحضور والانصراف: كل واحد لنفسه وفي فرعه، ومفتوح واحد بس، والتقرير بالصلاحية والفرع، والتأخير، وصاحب المحل بس بيصلّح بسبب
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string | null, sql: string, params: unknown[] = [], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
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
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const FROM = () => new Date(Date.now() - 2 * 86400_000).toISOString();
const TO = () => new Date(Date.now() + 86400_000).toISOString();

d('الحضور والانصراف', () => {
  let O = '';
  let R1 = ''; // استقبال الرئيسي
  let R2 = ''; // استقبال الفرع التاني
  let T = ''; // فني الرئيسي
  let shop = '';
  let main = '';
  const B2 = id();
  const report = (uid: string, branch: string | null = null) => as(uid, `select * from attendance_report($1, $2, $3)`, [FROM(), TO(), branch]).then((r) => r.rows);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`at-o-${tag}@a.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الحضور')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'A2', null, null)`, [B2]);
    for (const [role, name, br] of [['reception', 'استقبال 1', main], ['reception', 'استقبال 2', B2], ['technician', 'فني', main]] as const) {
      const em = `at-${role}-${br.slice(0, 6)}-${tag}@a.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, name, role, [br]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (name === 'استقبال 1') R1 = u;
      else if (name === 'استقبال 2') R2 = u;
      else T = u;
    }
  }, 60_000);
  afterAll(async () => db?.end());

  it('حضور وانصراف لنفسه: مفتوح واحد بس، ونفس الطلب مرتين = سجل واحد، والانصراف من غير حضور مرفوض', async () => {
    const a = id();
    await as(T, `select clock_in($1, 'وصلت')`, [a]);
    await as(T, `select clock_in($1)`, [a]);
    await expect(as(T, `select clock_in($1)`, [id()])).rejects.toThrow(/E_ALREADY_IN/);
    expect((await admin(`select count(*)::int n, max(branch_id::text) b from attendance where profile_id = $1`, [T])).rows[0]).toEqual({ n: 1, b: main });
    await as(T, `select clock_out()`);
    await expect(as(T, `select clock_out()`)).rejects.toThrow(/E_NOT_IN/);
    // تاني يوم (أو وردية تانية): سجل جديد
    await as(T, `select clock_in($1)`, [id()]);
    await as(T, `select clock_out()`);
    const mine = (await as(T, `select * from my_attendance($1, $2)`, [FROM(), TO()])).rows;
    expect(mine).toHaveLength(2);
    expect(mine.every((r) => r.full_name === 'فني' && Number.isInteger(r.minutes) && r.minutes >= 0)).toBe(true);
    // الزائر ما يقدرش
    await expect(as(null, `select clock_in($1)`, [id()])).rejects.toThrow(/permission denied/);
  });

  it('الفرع: الحضور في الفرع الشغال، والموظف ما يشوفش سجلات غيره، والتقرير لصاحب المحل (أو الفريق) في فروعه بس', async () => {
    await as(R2, `select clock_in($1)`, [id()], B2);
    await as(R1, `select clock_in($1)`, [id()], main);
    expect((await admin(`select branch_id from attendance where profile_id = $1`, [R2])).rows[0].branch_id).toBe(B2);
    // الاستقبال من غير صلاحية الفريق: ما يشوفش غير نفسه، والتقرير مرفوض
    expect((await as(R1, `select profile_id from attendance`)).rows.every((r) => r.profile_id === R1)).toBe(true);
    await expect(report(R1)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(report(T)).rejects.toThrow(/E_FORBIDDEN/);
    // صاحب المحل: الكل، وبفلتر الفرع
    const all = await report(O);
    expect(new Set(all.map((r) => r.profile_id))).toEqual(new Set([T, R1, R2]));
    expect((await report(O, B2)).map((r) => r.profile_id)).toEqual([R2]);
    // استقبال الرئيسي بصلاحية "الفريق ← يشوف": الرئيسي بس، حتى لو طلب الفرع التاني
    await as(O, `select set_staff_override($1, 'staff', 'view', true)`, [R1]);
    const r1 = await report(R1);
    expect(r1.some((r) => r.profile_id === R2)).toBe(false);
    expect(r1.some((r) => r.profile_id === T)).toBe(true);
    expect(await report(R1, B2)).toEqual([]);
    await as(O, `select set_staff_override($1, 'staff', 'view', null)`, [R1]);
    for (const u of [R1, R2]) await as(u, `select clock_out()`);
  });

  it('التأخير: من ميعاد البداية والسماح في الإعدادات، والدقايق أعداد صحيحة', async () => {
    const a = id();
    // حضور 10:40 بتوقيت القاهرة وانصراف 18:10، والبداية 10:00 بسماح 15 دقيقة ← تأخير 25 دقيقة، و450 دقيقة شغل
    await admin(`update shops set extras = jsonb_set(coalesce(extras, '{}'), '{attendance}', '{"start": "10:00", "grace_min": 15}') where id = $1`, [shop]);
    const day = new Date(Date.now() - 86400_000).toISOString().slice(0, 10);
    await as(O, `select attendance_add($1, $2, ($3 || ' 10:40')::timestamp at time zone 'Africa/Cairo', ($3 || ' 18:10')::timestamp at time zone 'Africa/Cairo', 'نسي يسجّل')`, [a, R1, day]);
    const row = (await report(O)).find((r) => r.id === a)!;
    expect(row).toMatchObject({ minutes: 450, late_minutes: 25, fix_reason: 'نسي يسجّل' });
    // من غير ميعاد بداية: مفيش تأخير
    await admin(`update shops set extras = extras - 'attendance' where id = $1`, [shop]);
    expect((await report(O)).find((r) => r.id === a)!.late_minutes).toBe(0);
  });

  it('صاحب المحل بس بيصلّح أو يضيف أو يلغي، وبسبب، وفي سجل النشاط. ومفيش حذف فعلي', async () => {
    const a = id();
    await as(T, `select clock_in($1)`, [a]);
    const inAt = new Date(Date.now() - 3 * 3600_000).toISOString();
    const outAt = new Date(Date.now() - 3600_000).toISOString();
    await expect(as(T, `select attendance_fix($1, $2, $3, 'عايز أزوّد')`, [a, inAt, outAt])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await expect(as(R1, `select attendance_void($1, 'غلط')`, [a])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await expect(as(O, `select attendance_fix($1, $2, $3, '  ')`, [a, inAt, outAt])).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(as(O, `select attendance_fix($1, $2, $3, 'غلط')`, [a, outAt, inAt])).rejects.toThrow(/E_BAD_INPUT/);
    await as(O, `select attendance_fix($1, $2, $3, 'نسي ينصرف')`, [a, inAt, outAt]);
    const row = (await report(O)).find((r) => r.id === a)!;
    expect(row).toMatchObject({ minutes: 120, fix_reason: 'نسي ينصرف' });
    const audit = (await admin(`select count(*)::int n from audit_log where entity = 'attendance' and entity_id = $1 and action = 'update'`, [a])).rows[0].n;
    expect(audit).toBeGreaterThanOrEqual(1);
    // الموظف ما يقدرش يعدّل الجدول مباشرة
    expect((await as(T, `update attendance set clock_out = now() where id = $1 returning id`, [a]).catch(() => ({ rowCount: 0 }))).rowCount).toBe(0);
    // الإلغاء soft delete
    await as(O, `select attendance_void($1, 'سجل غلط')`, [a]);
    expect((await report(O)).some((r) => r.id === a)).toBe(false);
    expect((await admin(`select deleted_at is not null d from attendance where id = $1`, [a])).rows[0].d).toBe(true);
    await expect(admin(`delete from attendance where id = $1`, [a])).rejects.toThrow();
  });

  it('محل تاني ما يشوفش أي حاجة', async () => {
    const X = await user(`at-x-${tag}@a.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    expect((await as(X, `select count(*)::int n from attendance where shop_id = $1`, [shop])).rows[0].n).toBe(0);
    expect(await as(X, `select * from attendance_report($1, $2)`, [FROM(), TO()]).then((r) => r.rows)).toEqual([]);
  });
});
