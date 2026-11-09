// بيربط التنضيف بكل ملف اختبار (المنطق نفسه في purgeCore.ts، عشان globalSetup يستخدمه من غير vitest)
import pg from 'pg';
import { afterAll, beforeAll } from 'vitest';
import { isLocalDb, LOCK, purgeSince } from './purgeCore';

export { isLocalDb, purgeAll } from './purgeCore';

/**
 * لكل ملف اختبار قاعدة بيانات: بياخد القفل (عشان الملفات تشتغل واحدة ورا التانية)، ويسجل الوقت،
 * وفي الآخر بيمسح كل المحلات والمستخدمين اللي الملف عملهم.
 */
export function cleanupAfterFile() {
  const url = process.env.TEST_DATABASE_URL;
  if (!isLocalDb(url)) return;
  let db: pg.Client | null = null;
  let since: Date | null = null;
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    await db.query('select pg_advisory_lock($1)', [LOCK]);
    since = (await db.query<{ n: Date }>('select clock_timestamp() n')).rows[0].n;
  }, 20 * 60_000);
  afterAll(async () => {
    if (!db) return;
    try {
      if (since) await purgeSince(db, since);
    } finally {
      await db.query('select pg_advisory_unlock($1)', [LOCK]).catch(() => undefined);
      await db.end();
    }
  }, 120_000);
}
