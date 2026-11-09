// تنضيف قاعدة الاختبار المحلية (للاختبارات بس، ومش جزء من البرنامج):
// البرنامج نفسه ما بيمسحش حاجة أبدًا (soft delete بس، والدفتر وسجل النشاط ما بيتمسحوش)، فالتنضيف هنا
// بيقفل الـ triggers مؤقتًا (session_replication_role = replica) جوه transaction واحدة.
//
// حماية: بيرفض يشتغل على أي قاعدة بيانات مش على نفس الجهاز (127.0.0.1 أو localhost). ما بيلمسش أي قاعدة حقيقية.
//
// - purgeAll: قبل كل تشغيل كامل: كل المحلات والمستخدمين (الخطط ومشرفين المنصة بيفضلوا).
// - cleanupAfterFile: كل ملف اختبار بيمسح المحلات والمستخدمين اللي اتعملوا وهو شغال.
//   الملفات بتاخد قفل (advisory lock) واحدة ورا التانية، عشان تنضيف ملف ما يمسحش بيانات ملف تاني شغال معاه.
import pg from 'pg';

export const LOCK = 7_260_011;

export function isLocalDb(url: string | undefined): url is string {
  if (!url) return false;
  try {
    const h = new URL(url).hostname;
    return h === '127.0.0.1' || h === 'localhost' || h === '::1' || h === '[::1]';
  } catch {
    return false;
  }
}

/** بيمسح محلات (وكل بياناتها) ومستخدمين. shops/users = شرط SQL على الجدولين */
async function purge(db: pg.Client, shopsWhere: string, usersWhere: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query('set local session_replication_role = replica');
    await db.query(`create temp table _purge_shops on commit drop as select id from public.shops where ${shopsWhere}`, params);
    await db.query(`create temp table _purge_users on commit drop as select id from auth.users where ${usersWhere}
                    union select id from public.profiles where shop_id in (select id from _purge_shops)`, params);
    const tables = (
      await db.query<{ t: string }>(`select distinct c.table_name t from information_schema.columns c join pg_tables p on p.tablename = c.table_name and p.schemaname = 'public'
                                    where c.table_schema = 'public' and c.column_name = 'shop_id' and c.table_name <> 'shops'`)
    ).rows.map((r) => r.t);
    await db.query(`delete from vault.secrets where id in (select secret_id from public.device_passcodes where shop_id in (select id from _purge_shops))`).catch(() => undefined);
    await db.query(`delete from public.community_reports where post_id in (select id from public.community_posts where shop_id in (select id from _purge_shops))`).catch(() => undefined);
    for (const t of tables) await db.query(`delete from public.${t} where shop_id in (select id from _purge_shops)`);
    await db.query(`delete from public.profiles where id in (select id from _purge_users)`);
    await db.query(`delete from public.staff_invites where lower(email) in (select lower(email) from auth.users where id in (select id from _purge_users))`);
    await db.query(`delete from public.shops where id in (select id from _purge_shops)`);
    await db.query(`delete from storage.objects where (storage.foldername(name))[1] in (select id::text from _purge_shops)`);
    // جداول auth بتتمسح بالـ cascade العادي (من غير replica) عشان الجلسات والهويات تتمسح معاها
    await db.query('set local session_replication_role = origin');
    await db.query(`delete from public.platform_admins where user_id in (select id from _purge_users)`).catch(() => undefined);
    await db.query(`delete from auth.users where id in (select id from _purge_users)`);
    await db.query('commit');
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}

/** قبل التشغيل الكامل: قاعدة الاختبار المحلية بترجع فاضية (من غير محلات ولا مستخدمين) */
export async function purgeAll(url: string) {
  if (!isLocalDb(url)) throw new Error(`purgeAll: refusing non-local database`);
  const db = new pg.Client({ connectionString: url });
  await db.connect();
  try {
    await db.query('select pg_advisory_lock($1)', [LOCK]);
    await purge(db, 'true', 'true');
  } finally {
    await db.end();
  }
}

/** بيمسح كل اللي اتعمل من وقت معيّن (محلات ومستخدمين) */
export async function purgeSince(db: pg.Client, since: Date) {
  // بعض الاختبارات بتضيف مستخدمين من غير تاريخ (created_at فاضي): دول كمان بيتمسحوا
  await purge(db, 'created_at >= $1', 'coalesce(created_at, now()) >= $1', [since]);
}

