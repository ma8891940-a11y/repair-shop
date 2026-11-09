// S3: المساعد الذكي — الإعدادات والصلاحيات والحد اليومي بتتأكد في قاعدة البيانات نفسها
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
const tag = randomUUID().slice(0, 6);
const setAssistant = (O: string, a: unknown) => as(O, `update shops set extras = coalesce(extras, '{}'::jsonb) || jsonb_build_object('assistant', $1::jsonb)`, [JSON.stringify(a)]);

d('المساعد الذكي: الإعدادات والصلاحيات والحد اليومي', () => {
  let O = '';
  let R = '';
  let T = '';
  let O2 = '';
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`as-o-${tag}@a.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل المساعد')`);
    for (const role of ['reception', 'technician'] as const) {
      const em = `as-${role}-${tag}@a.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    O2 = await user(`as-o2-${tag}@a.test`);
    await as(O2, `select bootstrap_account('تاني', 'محل تاني')`);
  }, 60_000);
  afterAll(async () => {
    await db?.end();
  });

  it('الافتراضي: كله شغال إلا المالية، والأماكن حسب الدور', async () => {
    const o = (await as(O, `select assistant_info() i`)).rows[0].i;
    expect(o.settings.areas).toEqual({ tech: true, intake: true, inventory: true, finance: false, customers: true, reports: true, screen: true });
    expect(o.allowed).toMatchObject({ tech: true, intake: true, inventory: true, finance: false, reports: true });
    const t = (await as(T, `select assistant_info() i`)).rows[0].i;
    expect(t.allowed).toEqual({ tech: true, intake: false, inventory: false, finance: false, customers: false, reports: false, screen: true });
    const r = (await as(R, `select assistant_info() i`)).rows[0].i;
    expect(r.allowed).toMatchObject({ intake: true, customers: true, inventory: false, reports: false, finance: false });
    // المالية مقفولة افتراضيًا حتى لصاحب المحل
    await expect(as(O, `select ai_take_area('finance')`)).rejects.toThrow(/E_AI_OFF/);
    // الفني ما يقدرش يسأل في المالية ولا التقارير ولا الشراء، حتى لو صاحب المحل فتحهم
    await setAssistant(O, { areas: { finance: true } });
    for (const a of ['finance', 'reports', 'inventory', 'customers', 'intake']) await expect(as(T, `select ai_take_area($1)`, [a])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select ai_take_area('finance')`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O, `select ai_take_area('nope')`)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await as(O, `select ai_take_area('finance') r`)).rows[0].r.left).toBeGreaterThan(0);
  });

  it('صاحب المحل بيقفل مكان أو موظف أو المساعد كله، والقفل بيتطبق في القاعدة', async () => {
    await setAssistant(O, { areas: { tech: false } });
    await expect(as(T, `select ai_take_area('tech')`)).rejects.toThrow(/E_AI_OFF/);
    await expect(as(T, `select ai_take()`)).rejects.toThrow(/E_AI_OFF/);
    await setAssistant(O, { staff: { technician: false } });
    await expect(as(T, `select ai_take_area('screen')`)).rejects.toThrow(/E_AI_OFF/);
    expect((await as(R, `select ai_take_area('screen') r`)).rows[0].r.left).toBeGreaterThanOrEqual(0);
    await setAssistant(O, { enabled: false });
    await expect(as(O, `select ai_take_area('screen')`)).rejects.toThrow(/E_AI_OFF/);
    // الموظف ما يقدرش يغيّر الإعدادات بنفسه
    const before = (await as(O, `select extras from shops`)).rows[0].extras;
    await as(R, `update shops set extras = jsonb_build_object('assistant', '{"enabled": true}'::jsonb)`);
    expect((await as(O, `select extras from shops`)).rows[0].extras).toEqual(before);
    await setAssistant(O, {});
  });

  it('الحد اليومي للمحل: أقل من حد الخطة، وبيترفض بعد ما يخلص، ومحل تاني مش متأثر', async () => {
    const used = (await as(O, `select assistant_info() i`)).rows[0].i.used as number;
    await setAssistant(O, { daily: used + 2 });
    expect((await as(O, `select assistant_info() i`)).rows[0].i.limit).toBe(used + 2);
    expect((await as(T, `select ai_take_area('tech') r`)).rows[0].r).toEqual({ left: 1, limit: used + 2 });
    expect((await as(O, `select ai_take() r`)).rows[0].r).toEqual({ left: 0 });
    await expect(as(R, `select ai_take_area('intake')`)).rejects.toThrow(/E_PLAN_LIMIT/);
    // حد أكبر من الخطة بيتقص لحد الخطة
    await setAssistant(O, { daily: 100000 });
    const i = (await as(O, `select assistant_info() i`)).rows[0].i;
    expect(i.limit).toBe(i.plan_limit);
    // المحل التاني ليه حده لوحده
    expect((await as(O2, `select ai_take_area('tech') r`)).rows[0].r.left).toBeGreaterThan(0);
    // اللي بيتسجل: المكان والوقت بس (من غير السؤال)
    const cols = (await admin(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'ai_usage'`)).rows.map((r) => r.column_name);
    expect(cols.sort()).toEqual(['area', 'created_at', 'deleted_at', 'id', 'shop_id', 'updated_at', 'user_id']);
    // الإعدادات نفسها مش متاحة لحد بره (security definer من غير صلاحية مباشرة)
    await expect(as(O, `select assistant_settings(gen_random_uuid())`)).rejects.toThrow(/permission denied/);
  });
});
