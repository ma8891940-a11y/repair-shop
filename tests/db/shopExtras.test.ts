// (26) 0073: حفظ مفاتيح من shops.extras بس، وفحص "المحل فاضي" في الاسترجاع يشمل الحضور
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
const login = async (c: pg.Client, uid: string) => {
  await c.query('begin');
  await c.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
  await c.query('set local role authenticated');
};
async function as(uid: string, sql: string, params: unknown[] = []) {
  await login(db, uid);
  try {
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

d('إعدادات المحل مفتاح بمفتاح', () => {
  let O = '';
  let R = '';
  let X = '';
  let shop = '';
  const save = (u: string, patch: unknown, merge = false) => as(u, `select set_shop_extras($1::jsonb, $2)`, [patch === null ? null : JSON.stringify(patch), merge]);
  const extras = async (s = shop) => (await admin(`select extras from shops where id = $1`, [s])).rows[0].extras;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ex-o-${tag}@x.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الإعدادات')).shop_id s`)).rows[0].s;
    const em = `ex-r-${tag}@x.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    X = await user(`ex-x-${tag}@x.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
  }, 60_000);
  afterAll(async () => db?.end());

  it('المفتاح المبعوت بس بيتغيّر، والباقي زي ما هو', async () => {
    const before = await extras();
    await save(O, { vat: { enabled: true, rate_bp: 1400, reg_no: '123' } });
    await save(O, { public_url: null, attendance: { start: '10:00', grace_min: 5 } });
    expect(await extras()).toEqual({ ...before, vat: { enabled: true, rate_bp: 1400, reg_no: '123' }, public_url: null, attendance: { start: '10:00', grace_min: 5 } });
  });

  it('من غير دمج القيمة بتتبدّل كلها (عشان مسح اختصار)، وبالدمج بتتحط فوق القديمة، والمصفوفة بتتبدّل', async () => {
    await save(O, { shortcuts: { a: 'F2', b: 'F3' }, reminders: { days: 5 }, lists_edit: ['reception'] });
    await save(O, { shortcuts: { a: 'F2' } });
    await save(O, { reminders: { push_from: 9 }, lists_edit: [], opening_steps: { cash: true } }, true);
    await save(O, { opening_steps: { stock: true } }, true);
    expect(await extras()).toMatchObject({ reminders: { days: 5, push_from: 9 }, lists_edit: [], opening_steps: { cash: true, stock: true } });
    expect((await extras()).shortcuts).toEqual({ a: 'F2' });
  });

  it('تعديلين في نفس اللحظة: الاتنين بيفضلوا', async () => {
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      await login(db, O);
      await login(c2, O);
      await db.query(`select set_shop_extras('{"reminders":{"days":7}}', true)`);
      const second = c2.query(`select set_shop_extras('{"reminders":{"push_to":20},"allow_negative_stock":true}', true)`);
      await new Promise((r) => setTimeout(r, 200));
      await db.query('commit');
      await second;
      await c2.query('commit');
    } finally {
      await c2.end();
    }
    expect(await extras()).toMatchObject({ reminders: { days: 7, push_from: 9, push_to: 20 }, allow_negative_stock: true, vat: { enabled: true } });
  });

  it('صاحب المحل بس، ومحله هو بس، والمدخلات الغلط مرفوضة', async () => {
    await expect(save(R, { vat: { enabled: false } })).rejects.toThrow(/E_FORBIDDEN/);
    const mine = await extras();
    await save(X, { vat: { enabled: false } });
    expect(await extras()).toEqual(mine);
    for (const bad of [null, [], 'x', 5, {}]) await expect(save(O, bad)).rejects.toThrow(/E_BAD_INPUT/);
    expect((await admin(`select has_function_privilege('anon', 'public.set_shop_extras(jsonb,boolean)', 'execute') x`)).rows[0].x).toBe(false);
  });

  it('الاسترجاع: محل فيه حضور مش فاضي، والحضور الملغي ما بيمنعش', async () => {
    const backup = (await as(O, `select export_backup() b`)).rows[0].b;
    const N = await user(`ex-n-${tag}@x.test`);
    await as(N, `select bootstrap_account('جديد', 'محل جديد')`);
    const a = randomUUID();
    await as(N, `select clock_in($1)`, [a]);
    await expect(as(N, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow(/E_RESTORE_NOT_EMPTY/);
    await as(N, `select attendance_void($1, 'تجربة')`, [a]);
    await as(N, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const s2 = (await admin(`select shop_id from profiles where id = $1`, [N])).rows[0].shop_id;
    expect((await extras(s2)).vat).toEqual((await extras()).vat);
  });
});
