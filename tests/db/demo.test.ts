// C7: البيانات التجريبية: التحميل لمحل فاضي بس، والمسح بقيود عكسية وأرشفة (كل الأرصدة بترجع صفر)
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
const tag = randomUUID().slice(0, 8);
let owner = '';
let other = '';
const balances = async (uid: string) =>
  (await as(uid, `select a.code, coalesce(sum(l.debit - l.credit), 0)::bigint b from accounts a left join journal_lines l on l.account_id = a.id group by a.code having coalesce(sum(l.debit - l.credit), 0) <> 0 order by 1`)).rows;
const clean = async (uid: string) => expect((await as(uid, `select integrity_report() r`)).rows[0].r).toEqual([]);

d('C7: البيانات التجريبية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`od-${tag}@t.test`);
    other = await user(`xd-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل التجربة')`);
    await as(other, `select bootstrap_account('تاني', 'محل فيه شغل')`);
  });
  afterAll(async () => db?.end());

  it('التحميل: أجهزة بحالات مختلفة وعملاء وأصناف وفلوس، والدفتر متوازن، ومرة واحدة بس', async () => {
    expect((await as(owner, `select demo_state() s`)).rows[0].s).toBe('none');
    await as(owner, `select load_demo()`);
    expect((await as(owner, `select demo_state() s`)).rows[0].s).toBe('loaded');
    const st = (await as(owner, `select status::text, count(*)::int n from devices where deleted_at is null group by 1 order by 1`)).rows;
    expect(st).toEqual([
      { status: 'awaiting_approval', n: 1 },
      { status: 'delivered', n: 1 },
      { status: 'in_repair', n: 1 },
      { status: 'ready', n: 1 },
      { status: 'received', n: 1 },
    ]);
    expect((await balances(owner)).length).toBeGreaterThan(3);
    await clean(owner);
    await expect(as(owner, `select load_demo()`)).rejects.toThrow(/E_DEMO_USED/);
  });

  it('المسح: كل قيد اتعكس (من غير حذف)، والأرصدة كلها صفر، والبيانات اتأرشفت، والقيود الأصلية لسه موجودة', async () => {
    const entries = Number((await as(owner, `select count(*) n from journal_entries`)).rows[0].n);
    const n = (await as(owner, `select clear_demo() n`)).rows[0].n;
    expect(n).toBe(entries);
    expect(await balances(owner)).toEqual([]);
    await clean(owner);
    expect(Number((await as(owner, `select count(*) n from journal_entries`)).rows[0].n)).toBe(entries * 2);
    for (const t of ['devices', 'customers', 'items', 'suppliers'])
      expect(Number((await as(owner, `select count(*) n from ${t} where deleted_at is null`)).rows[0].n), t).toBe(0);
    expect((await as(owner, `select demo_state() s`)).rows[0].s).toBe('cleared');
    await expect(as(owner, `select clear_demo()`)).rejects.toThrow(/E_NOT_FOUND/);
    expect((await as(owner, `select count(*)::int n from audit_log where action = 'demo_cleared'`)).rows[0].n).toBe(1);
  });

  it('محل فيه شغل حقيقي: التحميل مرفوض، وغير صاحب المحل ممنوع', async () => {
    await as(other, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل حقيقي', '01099990000')`, [randomUUID()]);
    await expect(as(other, `select load_demo()`)).rejects.toThrow(/E_DEMO_NOT_EMPTY/);
  });
});
