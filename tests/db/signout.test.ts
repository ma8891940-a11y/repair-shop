// الخروج: end_my_session بتلغي الجلسة الحالية بس على السيرفر، ومن غير أي خطأ لو الجلسة أو المستخدم مش موجودين
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

// كل اللي الملف ده بيعمله في قاعدة الاختبار بيتمسح في الآخر
cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
async function as(uid: string, sid: string, sql: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated', session_id: sid })]);
    await db.query('set local role authenticated');
    const r = await db.query(sql);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const hasSessions = async () => Number((await db.query(`select count(*) n from information_schema.tables where table_schema = 'auth' and table_name = 'sessions'`)).rows[0].n) > 0;

d('الخروج من غير أخطاء', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
  });
  afterAll(async () => db?.end());

  it('بتلغي الجلسة الحالية بس (والتانية بتفضل)، ومرة تانية أو لمستخدم اتحذف: من غير خطأ', async () => {
    const u = randomUUID();
    await db.query('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, `so-${u.slice(0, 8)}@s.test`]);
    const [s1, s2] = [randomUUID(), randomUUID()];
    if (await hasSessions()) {
      await db.query('insert into auth.sessions(id, user_id) values ($1, $2), ($3, $2)', [s1, u, s2]);
      await as(u, s1, 'select end_my_session()');
      const left = (await db.query('select id from auth.sessions where user_id = $1', [u])).rows.map((r) => r.id);
      expect(left).toEqual([s2]);
    }
    // تاني مرة (الجلسة اتلغت خلاص): من غير خطأ
    await as(u, s1, 'select end_my_session()');
    // المستخدم اتحذف: من غير خطأ
    await db.query('delete from auth.users where id = $1', [u]);
    await as(u, s2, 'select end_my_session()');
    // من غير دخول: مرفوض
    await db.query('begin');
    await db.query('set local role anon');
    await expect(db.query('select end_my_session()')).rejects.toThrow();
    await db.query('rollback');
  });
});
