// الميزات الإضافية (migration 0019): الأعطال الجاهزة ومفاتيح التشغيل، والنسخة الاحتياطية فيها جداول المرحلة 6
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
const tag = randomUUID().slice(0, 8);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@ex.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}
let owner = '';
let rec = '';
let tech = '';
let other = '';
let shop = '';

d('الميزات الإضافية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`exo-${tag}@ex.test`);
    shop = (await as(owner, `select (bootstrap_account('صاحب', 'محل الإضافات')).shop_id as s`)).rows[0].s;
    rec = await staff(owner, 'استقبال', 'reception');
    tech = await staff(owner, 'فني', 'technician');
    other = await user(`exx-${tag}@ex.test`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
  });
  afterAll(async () => db?.end());

  it('مفاتيح التشغيل: افتراضيًا شغالة ماعدا الطباعة التلقائية، وصاحب المحل بس يغيّرها', async () => {
    const x = (await as(owner, `select extras from shops`)).rows[0].extras;
    expect(x).toEqual({ quick_issues: true, day_summary: true, auto_print: false });
    await as(owner, `update shops set extras = extras || '{"auto_print": true}'`);
    expect((await as(owner, `select extras->>'auto_print' v from shops`)).rows[0].v).toBe('true');
    const r = await as(rec, `update shops set extras = '{}' returning id`);
    expect(r.rowCount).toBe(0);
  });

  it('الأعطال الجاهزة: صاحب المحل بيكتب، والاستقبال بيقرا بس، والفني ما يشوفهاش (فيها أسعار)، ومحل تاني ما يشوفهاش', async () => {
    const id = randomUUID();
    await as(owner, `insert into issue_presets(id, shop_id, label, issue, est_cost) values ($1, gen_random_uuid(), 'شاشة', 'تغيير شاشة', 150000)`, [id]);
    const row = (await as(rec, `select shop_id, label, est_cost from issue_presets`)).rows;
    expect(row).toEqual([{ shop_id: shop, label: 'شاشة', est_cost: 150000 }]);
    await expect(as(rec, `insert into issue_presets(id, shop_id, label, issue) values ($1, gen_random_uuid(), 'x', 'y')`, [randomUUID()])).rejects.toThrow();
    expect((await as(rec, `update issue_presets set label = 'z' returning id`)).rowCount).toBe(0);
    expect((await as(tech, `select * from issue_presets`)).rowCount).toBe(0);
    expect((await as(other, `select * from issue_presets`)).rowCount).toBe(0);
    // المبلغ بالقروش كعدد صحيح، وممنوع الحذف الفعلي
    await expect(as(owner, `insert into issue_presets(id, shop_id, label, issue, est_cost) values ($1, gen_random_uuid(), 'a', 'b', '10.5')`, [randomUUID()])).rejects.toThrow();
    await expect(admin(`delete from issue_presets where id = $1`, [id])).rejects.toThrow(/E_HARD_DELETE/);
    await as(owner, `update issue_presets set deleted_at = now() where id = $1`, [id]);
  });

  it('النسخة الاحتياطية فيها الفيديوهات والتقييمات والأعطال الجاهزة', async () => {
    const b = (await as(owner, `select export_backup() as b`)).rows[0].b;
    for (const t of ['repair_videos', 'device_ratings', 'issue_presets']) expect(Array.isArray(b[t]), t).toBe(true);
    expect(b.issue_presets.length).toBe(1);
  });
});
