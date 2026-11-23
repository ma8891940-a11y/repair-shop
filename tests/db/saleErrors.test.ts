// بند 13 (0069): أخطاء البيع برسالة الحقل على السيرفر، والبيع المجاني بصلاحية وسبب وسجل
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID as id } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
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
const tag = id().slice(0, 6);

d('أخطاء البيع والبيع المجاني', () => {
  let O = '';
  let R = '';
  let cash = '';
  let shop = '';
  const srv = id();
  const gift = id();
  async function user(email: string) {
    const u = id();
    await db.query('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
    return u;
  }
  /** السطور كنص JSON، عشان نبعت قيم غلط زي ما أي حد يقدر يبعتها للـ API */
  const sell = (uid: string, lines: string, note: string | null = null) => as(uid, `select record_sale($1, $2::jsonb, $3, null, $4) e`, [id(), lines, cash, note]);
  const entries = async () => (await db.query(`select count(*)::int n from journal_entries where shop_id = $1`, [shop])).rows[0].n;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`se-o-${tag}@s.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل')).shop_id s`)).rows[0].s;
    cash = (await db.query(`select id from accounts where shop_id = $1 and method = 'cash' order by created_at limit 1`, [shop])).rows[0].id;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [`se-r-${tag}@s.test`]);
    R = await user(`se-r-${tag}@s.test`);
    await as(R, `select bootstrap_account('استقبال')`);
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'تنظيف', 5000), ($2, gen_random_uuid(), 'service', 'لزق اسكرينة', 1000)`, [srv, gift]);
  }, 60_000);
  afterAll(async () => db?.end());

  it.each([
    ['0', 'E_BAD_QTY'],
    ['-1', 'E_BAD_QTY'],
    ['1.5', 'E_BAD_QTY'],
    ['null', 'E_BAD_QTY'],
    ['""', 'E_BAD_QTY'],
    ['"NaN"', 'E_BAD_QTY'],
  ])('الكمية %s مرفوضة بـ %s من غير أي قيد', async (qty, code) => {
    const n = await entries();
    await expect(sell(O, `[{"item":"${srv}","qty":${qty},"price":5000}]`)).rejects.toThrow(code);
    expect(await entries()).toBe(n);
  });

  it.each(['-1', '10.5', 'null', '""', '"NaN"'])('السعر %s مرفوض بـ E_BAD_PRICE من غير أي قيد', async (price) => {
    const n = await entries();
    await expect(sell(O, `[{"item":"${srv}","qty":1,"price":${price}}]`)).rejects.toThrow('E_BAD_PRICE');
    expect(await entries()).toBe(n);
  });

  it('المجاني: الاستقبال ممنوعة، وصاحب المحل محتاج سبب، وبيتسجل، وبالصلاحية الاستقبال تقدر', async () => {
    const lines = `[{"item":"${srv}","qty":1,"price":5000},{"item":"${gift}","qty":1,"price":0}]`;
    const n = await entries();
    await expect(sell(R, lines, 'هدية')).rejects.toThrow('E_FREE_SALE');
    await expect(sell(O, lines)).rejects.toThrow('E_REASON_REQUIRED');
    await expect(sell(O, lines, '  ')).rejects.toThrow('E_REASON_REQUIRED');
    expect(await entries()).toBe(n);
    expect((await db.query(`select 1 from audit_log where shop_id = $1 and action = 'free_sale'`, [shop])).rowCount).toBe(0);
    const e = (await sell(O, lines, 'هدية لعميل دايم')).rows[0].e;
    const log = (await db.query(`select actor_id, entity_id, after from audit_log where shop_id = $1 and action = 'free_sale'`, [shop])).rows;
    expect(log).toHaveLength(1);
    expect(log[0]).toMatchObject({ actor_id: O, entity_id: gift, after: { qty: 1, reason: 'هدية لعميل دايم', entry: e } });
    await as(O, `select set_staff_override($1, 'inventory', 'amounts', true)`, [R]);
    await sell(R, lines, 'هدية');
    await as(O, `select set_staff_override($1, 'inventory', 'amounts', null)`, [R]);
  });

  it('فاتورة كلها مجانية مرفوضة، والبيع العادي من الاستقبال زي ما هو', async () => {
    await expect(sell(O, `[{"item":"${gift}","qty":1,"price":0}]`, 'هدية')).rejects.toThrow('E_BAD_AMOUNT');
    await sell(R, `[{"item":"${srv}","qty":1,"price":15025}]`);
  });
});
