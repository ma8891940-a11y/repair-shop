// 50.3 (0089): صور خلفية القوالب: كل محل صوره، والرفع بصلاحية قوالب الطباعة بس، وإزاحة الطابعة بحدود
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string | null, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [uid ? JSON.stringify({ sub: uid, role: 'authenticated' }) : '']);
    await db.query(`set local role ${uid ? 'authenticated' : 'anon'}`);
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
const DENIED = /row-level security|permission denied/;

d('صور خلفية القوالب', () => {
  let O = '';
  let R = '';
  let T = '';
  let X = '';
  let shop = '';
  let other = '';
  const upload = (u: string | null, name: string) => as(u, `insert into storage.objects(bucket_id, name) values ('print-backgrounds', $1)`, [name]);
  const seen = async (u: string | null, name: string) => (await as(u, `select name from storage.objects where bucket_id = 'print-backgrounds' and name = $1`, [name]).catch(() => ({ rowCount: 0 }))).rowCount;
  const grant = (u: string, v: boolean | null) => as(O, `select set_staff_override($1, 'print_templates', 'edit', $2)`, [u, v]);
  const fresh = (ext = 'png') => `${shop}/${randomUUID()}.${ext}`;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`bg-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الخلفيات')).shop_id s`)).rows[0].s;
    for (const role of ['reception', 'technician']) {
      const em = `bg-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    X = await user(`bg-x-${tag}@p.test`);
    other = (await as(X, `select (bootstrap_account('تاني', 'محل تاني')).shop_id s`)).rows[0].s;
  }, 60_000);
  afterAll(async () => db?.end());

  it('المكان خاص، و2 ميجا، وPNG وJPG بس', async () => {
    const b = (await admin(`select public, file_size_limit::int s, allowed_mime_types m from storage.buckets where id = 'print-backgrounds'`)).rows[0];
    expect(b).toEqual({ public: false, s: 2097152, m: ['image/png', 'image/jpeg'] });
  });

  it('الرفع: صاحب المحل أو بالصلاحية، ومحل تاني وزائر وفني لأ، والقراية للمحل بس', async () => {
    const a = fresh();
    await upload(O, a);
    expect([await seen(O, a), await seen(R, a), await seen(T, a), await seen(X, a), await seen(null, a)]).toEqual([1, 1, 1, 0, 0]);
    for (const u of [R, T, X, null]) await expect(upload(u, fresh())).rejects.toThrow(DENIED);
    await grant(R, true);
    await upload(R, fresh('jpg'));
    await grant(T, true);
    await expect(upload(T, fresh())).rejects.toThrow(DENIED);
    await expect(upload(R, `${other}/${randomUUID()}.png`)).rejects.toThrow(DENIED);
    await grant(R, null);
    await expect(upload(R, fresh())).rejects.toThrow(DENIED);
  });

  it('الاسم: فولدر المحل ثم uuid وامتداد png أو jpg بس', async () => {
    for (const n of [fresh('svg'), fresh('html'), `${shop}/logo.png`, `${shop}/x/${randomUUID()}.png`, `${randomUUID()}.png`, `${fresh()}.html`, `${shop}/../${other}/${randomUUID()}.png`])
      await expect(upload(O, n), n).rejects.toThrow(DENIED);
  });

  it('إزاحة الطابعة: بالمللي بحدود 10، والافتراضي فاضي', async () => {
    const add = (x: number | null, y: number | null) =>
      as(O, `insert into printers(shop_id, name, kind, width_mm, offset_x, offset_y) values (gen_random_uuid(), 'ط', 'label', 40, $1, $2) returning offset_x::float x, offset_y::float y`, [x, y]);
    expect((await add(null, null)).rows[0]).toEqual({ x: null, y: null });
    expect((await add(-10, 1.5)).rows[0]).toEqual({ x: -10, y: 1.5 });
    for (const [x, y] of [[10.1, 0], [0, -10.1], [99, 0]]) await expect(add(x, y)).rejects.toThrow(/check constraint|overflow/);
  });
});
