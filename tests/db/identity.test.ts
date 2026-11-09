// هوية كل محل: كل محل بيشوف هويته ولوجوه بس، وصفحة التتبع بتعرض لوجو المحل بتاع الجهاز (migration 0016)
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
async function as(uid: string | null, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': '10.88.0.1' })]);
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
const tag = randomUUID().slice(0, 8);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const PNG_A = 'data:image/png;base64,AAAA';
const PNG_B = 'data:image/png;base64,BBBB';
let A = '';
let B = '';
let shopA = '';
let shopB = '';
let recA = '';
let token = '';

d('هوية المحل', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    A = await user(`ida-${tag}@id.test`);
    B = await user(`idb-${tag}@id.test`);
    shopA = (await as(A, `select (bootstrap_account('أ', 'محل ألف')).shop_id as s`)).rows[0].s;
    shopB = (await as(B, `select (bootstrap_account('ب', 'محل باء')).shop_id as s`)).rows[0].s;
    await as(A, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'سارة', 'reception')`, [`idr-${tag}@id.test`]);
    recA = await user(`idr-${tag}@id.test`);
    await as(recA, `select bootstrap_account('سارة')`);
    const c = randomUUID();
    await as(A, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', '01066660000')`, [c]);
    const dv = await as(A, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'c') returning tracking_token`, [randomUUID(), c]);
    token = dv.rows[0].tracking_token;
  });
  afterAll(async () => db?.end());

  it('كل محل بيحفظ هويته، وما يشوفش هوية محل تاني', async () => {
    await as(A, `insert into shop_branding(id, shop_id, tagline, logo_color, logo_thermal) values ($1, gen_random_uuid(), 'صيانة بضمان', $2, $2)`, [randomUUID(), PNG_A]);
    await as(B, `insert into shop_branding(id, shop_id, tagline, logo_color) values ($1, gen_random_uuid(), 'محل باء', $2)`, [randomUUID(), PNG_B]);
    const a = (await as(A, `select shop_id, logo_color from shop_branding`)).rows;
    expect(a).toEqual([{ shop_id: shopA, logo_color: PNG_A }]);
    const b = (await as(B, `select shop_id, logo_color from shop_branding`)).rows;
    expect(b).toEqual([{ shop_id: shopB, logo_color: PNG_B }]);
    // الاستقبال بتشوف هوية محلها (للطباعة) بس ما تعدّلش
    expect((await as(recA, `select tagline from shop_branding`)).rows).toEqual([{ tagline: 'صيانة بضمان' }]);
    expect((await as(recA, `update shop_branding set tagline = 'x'`)).rowCount).toBe(0);
    // مينفعش لوجو مش صورة PNG جاهزة
    await expect(as(B, `update shop_branding set logo_color = 'javascript:alert(1)'`)).rejects.toThrow(/check/);
    // ومحدش يكتب في محل تاني
    await as(B, `update shop_branding set tagline = 'اختراق' where shop_id = $1`, [shopA]);
    expect((await admin(`select tagline from shop_branding where shop_id = $1`, [shopA])).rows[0].tagline).toBe('صيانة بضمان');
  });

  it('لوجو المحل في Storage: خاص، وكل محل بيرفع ويقرا في فولدره بس', async () => {
    expect((await admin(`select public from storage.buckets where id = 'shop-logos'`)).rows[0].public).toBe(false);
    await as(A, `insert into storage.objects(bucket_id, name) values ('shop-logos', $1)`, [`${shopA}/logo.png`]);
    await expect(as(A, `insert into storage.objects(bucket_id, name) values ('shop-logos', $1)`, [`${shopB}/logo.png`])).rejects.toThrow();
    await expect(as(recA, `insert into storage.objects(bucket_id, name) values ('shop-logos', $1)`, [`${shopA}/x.png`])).rejects.toThrow();
    expect((await as(B, `select name from storage.objects where bucket_id = 'shop-logos' and name like $1`, [`${shopA}/%`])).rowCount).toBe(0);
    expect((await as(A, `select name from storage.objects where bucket_id = 'shop-logos' and name like $1`, [`${shopA}/%`])).rowCount).toBe(1);
    expect((await as(null, `select name from storage.objects where bucket_id = 'shop-logos'`).catch(() => ({ rowCount: 0 }))).rowCount).toBe(0);
  });

  it('صفحة التتبع بتعرض لوجو المحل بتاع الجهاز بس (صورة جاهزة، مش مسار)', async () => {
    const t = (await as(null, `select shop_name, shop_logo from get_tracking(p_token => $1)`, [token])).rows[0];
    expect(t).toEqual({ shop_name: 'محل ألف', shop_logo: PNG_A });
  });

  it('النسخة الاحتياطية بتشمل هوية المحل', async () => {
    const b = (await as(A, `select export_backup() as b`)).rows[0].b;
    expect(b.shop_branding).toHaveLength(1);
    expect(b.shop_branding[0].shop_id).toBe(shopA);
  });
});
