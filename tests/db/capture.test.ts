// C1: صور الاستلام من موبايل الفني بالـ QR، وصور الاستلام في صفحة التتبع
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
async function device(uid: string) {
  const c = randomUUID();
  const id = randomUUID();
  await as(uid, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'سارة علي', $2)`, [c, `0101${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`]);
  const r = await as<{ tracking_token: string; shop_id: string }>(uid, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A52', 'شاشة') returning tracking_token, shop_id`, [id, c]);
  return { id, ...r.rows[0] };
}
const upload = (tok: string, name: string) =>
  as(null, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [name], { 'x-upload-token': tok });

const tag = randomUUID().slice(0, 8);
let owner = '';
let tech = '';
let other = '';

d('C1: صور الاستلام بالـ QR', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`oc-${tag}@t.test`);
    other = await user(`xc-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل الصور')`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'فني', 'technician')`, [`tc-${tag}@t.test`]);
    tech = await user(`tc-${tag}@t.test`);
    await as(tech, `select bootstrap_account('فني')`);
  });
  afterAll(async () => db?.end());

  it('الاستقبال بيفتح جلسة، والموبايل من غير دخول بيرفع جوه فولدر الجهاز بس وبيسجل الصورة، والجلسة القديمة بتتقفل', async () => {
    const dev = await device(owner);
    // الفني ومحل تاني ما يقدروش يفتحوا جلسة
    await expect(as(tech, `select * from start_photo_upload($1)`, [dev.id])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(other, `select * from start_photo_upload($1)`, [dev.id])).rejects.toThrow(/E_NOT_FOUND/);
    const tok = (await as<{ token: string }>(owner, `select token from start_photo_upload($1)`, [dev.id])).rows[0].token;
    expect(tok).toMatch(/^[0-9a-f]{32}$/);
    // الموبايل بيشوف المحل والجهاز من غير بيانات العميل
    const info = (await as(null, `select * from photo_session($1)`, [tok])).rows[0];
    expect(info).toMatchObject({ shop_name: 'محل الصور', model: 'A52', photos: 0, max_photos: 6, folder: `${dev.shop_id}/${dev.id}` });
    expect(JSON.stringify(info)).not.toContain('سارة');
    expect(JSON.stringify(info)).not.toContain('"0101');
    const good = `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`;
    // من غير token أو بـ token غلط أو برا فولدر الجهاز: مرفوض
    await expect(as(null, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [good])).rejects.toThrow();
    await expect(upload('0'.repeat(32), good)).rejects.toThrow();
    await expect(upload(tok, `${dev.shop_id}/${randomUUID()}/${randomUUID()}.jpg`)).rejects.toThrow();
    await expect(upload(tok, `${dev.shop_id}/${dev.id}/../x.jpg`)).rejects.toThrow();
    await upload(tok, good);
    // تسجيل صورة مش مرفوعة أو برا الفولدر مرفوض، والمرفوعة بتتسجل مرة واحدة باسم اللي فتح الجلسة
    await expect(as(null, `select add_session_photo($1, $2)`, [tok, `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`])).rejects.toThrow(/E_NOT_FOUND/);
    const p1 = (await as<{ id: string }>(null, `select add_session_photo($1, $2) id`, [tok, good])).rows[0].id;
    const p2 = (await as<{ id: string }>(null, `select add_session_photo($1, $2) id`, [tok, good])).rows[0].id;
    expect(p2).toBe(p1);
    const row = (await as(owner, `select device_id, uploaded_by from device_photos where storage_path = $1`, [good])).rows[0];
    expect(row).toEqual({ device_id: dev.id, uploaded_by: owner });
    // جلسة جديدة بتقفل القديمة
    const tok2 = (await as<{ token: string }>(owner, `select token from start_photo_upload($1)`, [dev.id])).rows[0].token;
    expect((await as(null, `select * from photo_session($1)`, [tok])).rows).toHaveLength(0);
    expect((await as(null, `select photos from photo_session($1)`, [tok2])).rows[0].photos).toBe(1);
    // الحد 6 صور
    for (let i = 0; i < 5; i++) {
      const n = `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`;
      await upload(tok2, n);
      await as(null, `select add_session_photo($1, $2)`, [tok2, n]);
    }
    await expect(upload(tok2, `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`)).rejects.toThrow();
  });

  it('الجلسة بتنتهي بعد وقتها وبعد التسليم', async () => {
    const dev = await device(owner);
    const tok = (await as<{ token: string }>(owner, `select token from start_photo_upload($1)`, [dev.id])).rows[0].token;
    await db.query(`update photo_upload_sessions set expires_at = now() - interval '1 minute' where token = $1`, [tok]);
    expect((await as(null, `select * from photo_session($1)`, [tok])).rows).toHaveLength(0);
    await expect(upload(tok, `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`)).rejects.toThrow();
    await expect(as(null, `select add_session_photo($1, $2)`, [tok, `${dev.shop_id}/${dev.id}/x.jpg`])).rejects.toThrow(/E_UPLOAD_EXPIRED/);
  });

  it('صفحة التتبع: صور الجهاز لصاحب رابط التتبع بس، ومش لجهاز تاني', async () => {
    const dev = await device(owner);
    const dev2 = await device(owner);
    const tok = (await as<{ token: string }>(owner, `select token from start_photo_upload($1)`, [dev.id])).rows[0].token;
    const name = `${dev.shop_id}/${dev.id}/${randomUUID()}.jpg`;
    await upload(tok, name);
    await as(null, `select add_session_photo($1, $2)`, [tok, name]);
    expect((await as<{ p: string }>(null, `select p from tracking_photos($1) p`, [dev.tracking_token])).rows.map((r) => r.p)).toEqual([name]);
    expect((await as(null, `select * from tracking_photos($1)`, [dev2.tracking_token])).rows).toHaveLength(0);
    expect((await as(null, `select * from tracking_photos($1)`, [''])).rows).toHaveLength(0);
    // سياسة القراية في Storage: بالـ header الصح بس
    const read = (h: Record<string, string>) => as(null, `select name from storage.objects where bucket_id = 'device-photos' and name like $1`, [`${dev.shop_id}/%`], h);
    expect((await read({ 'x-track-token': dev.tracking_token })).rows.map((r) => r.name)).toEqual([name]);
    expect((await read({ 'x-track-token': dev2.tracking_token })).rows).toHaveLength(0);
    expect((await read({})).rows).toHaveLength(0);
  });
});
