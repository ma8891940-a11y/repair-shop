// المرحلة 5: آخر تعديل يكسب مع تسجيل التعارض، والنسخ الاحتياطي (migration 0015)
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
let owner = '';
let rec = '';
let other = '';
let shop = '';
let dev = '';

d('المرحلة 5: بدون إنترنت والنسخ الاحتياطي', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`o5-${tag}@t5.test`);
    shop = (await as(owner, `select (bootstrap_account('صاحب', 'محل النسخ')).shop_id as s`)).rows[0].s;
    await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'سارة', 'reception')`, [`r5-${tag}@t5.test`]);
    rec = await user(`r5-${tag}@t5.test`);
    await as(rec, `select bootstrap_account('سارة')`);
    other = await user(`x5-${tag}@t5.test`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    const c = randomUUID();
    await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', '01055550000')`, [c]);
    dev = randomUUID();
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'c')`, [dev, c]);
    await as(rec, `select set_device_passcode($1, 'pin', 'pin-zq-8817-sekret')`, [dev]);
  });
  afterAll(async () => db?.end());

  it('آخر تعديل يكسب: التعديل الأحدث من الجهاز بيتطبق، والأقدم من السيرفر بيترفض ويتسجل تعارض', async () => {
    const future = new Date(Date.now() + 60_000).toISOString();
    const r1 = (await as(rec, `select apply_status_lww($1, 'inspecting', $2) as r`, [dev, future])).rows[0].r;
    expect(r1).toEqual({ applied: true });
    // تعديل اتعمل بدون نت من ساعة، بعد كده الجهاز اتعدّل على السيرفر
    const past = new Date(Date.now() - 3600_000).toISOString();
    const r2 = (await as(rec, `select apply_status_lww($1, 'unrepairable', $2) as r`, [dev, past])).rows[0].r;
    expect(r2).toMatchObject({ applied: false, reason: 'newer_on_server', server_status: 'inspecting' });
    expect((await admin(`select status::text from devices where id = $1`, [dev])).rows[0].status).toBe('inspecting');
    const log = (await admin(`select actor_id, after ->> 'status' as s, after ->> 'kept' as k from audit_log where action = 'sync_conflict' and entity_id = $1`, [dev])).rows;
    expect(log).toEqual([{ actor_id: rec, s: 'unrepairable', k: 'server' }]);
    // انتقال مش مسموح: ما بيتطبقش وبيتسجل تعارض (مش خطأ بيوقف الطابور)
    const r3 = (await as(rec, `select apply_status_lww($1, 'delivered', $2) as r`, [dev, future])).rows[0].r;
    expect(r3).toMatchObject({ applied: false, reason: 'rejected' });
    // نفس الحالة: مفيش حاجة تتعمل
    expect((await as(rec, `select apply_status_lww($1, 'inspecting', $2) as r`, [dev, past])).rows[0].r).toMatchObject({ applied: true, same: true });
    // محل تاني ما يقدرش
    await expect(as(other, `select apply_status_lww($1, 'in_repair', $2)`, [dev, future])).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('تصدير نسخة كاملة: صاحب المحل بس، وفيها كل الجداول، ومن غير أسرار الأقفال، ومتسجل في السجل', async () => {
    await expect(as(rec, `select export_backup()`)).rejects.toThrow(/E_FORBIDDEN/);
    const b = (await as(owner, `select export_backup() as b`)).rows[0].b;
    expect(b.format).toBe('warsha-backup');
    expect(b.shop_id).toBe(shop);
    for (const t of ['devices', 'customers', 'journal_entries', 'journal_lines', 'accounts', 'repair_steps', 'audit_log']) expect(Array.isArray(b[t])).toBe(true);
    expect(b.devices.map((x: { id: string }) => x.id)).toContain(dev);
    expect(b.device_passcodes).toEqual([{ device_id: dev, kind: 'pin', erased_at: null }]);
    expect(JSON.stringify(b)).not.toContain('pin-zq-8817-sekret');
    expect(JSON.stringify(b)).not.toContain('secret_id');
    // ما فيهاش بيانات محل تاني
    expect(b.shops.map((s: { id: string }) => s.id)).toEqual([shop]);
    const a = (await admin(`select count(*)::int n from audit_log where action = 'backup_export' and shop_id = $1`, [shop])).rows[0].n;
    expect(a).toBe(1);
  });

  it('النسخة اليومية على السيرفر: لكل محل، وصاحب المحل بس يشوفها وينزّلها، والأقدم من 7 أيام بتتعلّم محذوفة', async () => {
    await admin(`select daily_backups()`);
    const list = (await as(owner, `select id, size_kb from list_backups()`)).rows;
    expect(list.length).toBeGreaterThanOrEqual(1);
    const b = (await as(owner, `select get_backup($1) as b`, [list[0].id])).rows[0].b;
    expect(b.shop_id).toBe(shop);
    await expect(as(rec, `select * from list_backups()`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(other, `select get_backup($1)`, [list[0].id])).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(owner, `select * from shop_backups`)).rejects.toThrow(/permission denied/); // مفيش قراءة مباشرة
    await expect(admin(`delete from shop_backups where id = $1`, [list[0].id])).rejects.toThrow();
    // نسخة قديمة
    await admin(`update shop_backups set created_at = now() - interval '8 days' where id = $1`, [list[0].id]);
    await admin(`select daily_backups()`);
    const old = (await admin(`select deleted_at, data from shop_backups where id = $1`, [list[0].id])).rows[0];
    expect(old.deleted_at).toBeInstanceOf(Date);
    expect(old.data).toEqual({});
    expect((await as(owner, `select id from list_backups()`)).rows.map((r) => r.id)).not.toContain(list[0].id);
  }, 60_000); // بيعمل نسخة لكل المحلات في القاعدة (القاعدة بتتنضف قبل كل تشغيل، وكل ملف بيمسح اللي عمله)
});
