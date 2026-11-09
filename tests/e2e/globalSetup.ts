// قبل تشغيل اختبارات المتصفح: قاعدة Supabase المحلية بتتنضف (من غير محلات ولا مستخدمين)،
// وفي الآخر كل اللي التشغيل عمله بيتمسح. على أي قاعدة مش محلية ما بيعملش حاجة خالص.
// تقدر تقفله بـ E2E_DB_RESET=0 (مثلًا لو عايز تبص على الداتا بعد الاختبار).
import pg from 'pg';
import { isLocalDb, LOCK, purgeAll, purgeSince } from '../db/purgeCore';

export default async function globalSetup() {
  const url = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
  if (!isLocalDb(url) || process.env.E2E_DB_RESET === '0') return;
  try {
    await purgeAll(url);
  } catch (e) {
    // Supabase المحلي مش شغال: الاختبارات نفسها هتقول كده بوضوح
    console.warn('e2e: test database not reachable, skipping reset:', (e as Error).message);
    return;
  }
  const db = new pg.Client({ connectionString: url });
  await db.connect();
  await db.query('select pg_advisory_lock($1)', [LOCK]);
  const since = (await db.query<{ n: Date }>('select clock_timestamp() n')).rows[0].n;
  return async () => {
    try {
      await purgeSince(db, since);
    } finally {
      await db.query('select pg_advisory_unlock($1)', [LOCK]).catch(() => undefined);
      await db.end();
    }
  };
}
