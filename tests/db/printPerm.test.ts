// 50.1 (0083): صلاحية "قوالب الطباعة": موظف الاستقبال بالصلاحية يعدّل قوالب وطابعات فروعه بس، وقالب المحل كله لصاحب المحل أو اللي معاه كل الفروع
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

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
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const DENIED = /row-level security/;

d('صلاحية قوالب الطباعة', () => {
  let O = '';
  let R = '';
  let T = '';
  let X = '';
  let shop = '';
  let main = '';
  const B2 = id();
  const tpl = async (u: string, branch: string | null, doc = 'receipt') => {
    const x = id();
    await as(u, `insert into print_templates(id, shop_id, doc, branch_id, name, blocks) values ($1, gen_random_uuid(), $2, $3, 'قالب', '[]')`, [x, doc, branch]);
    return x;
  };
  const printer = async (u: string, branch: string | null) => {
    const x = id();
    await as(u, `insert into printers(id, shop_id, branch_id, name, kind, width_mm) values ($1, gen_random_uuid(), $2, 'طابعة', 'a4', 210)`, [x, branch]);
    return x;
  };
  /** عدد الصفوف اللي اتعدّلت فعلًا (RLS بيخبّي اللي مش مسموح من غير خطأ) */
  const rename = async (u: string, table: 'printers' | 'print_templates', x: string) => (await as(u, `update ${table} set name = 'اتغيّر' where id = $1`, [x])).rowCount;
  const grant = (u: string, v: boolean | null) => as(O, `select set_staff_override($1, 'print_templates', 'edit', $2)`, [u, v]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pp-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الطباعة')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'PP2')`, [B2]);
    for (const role of ['reception', 'technician']) {
      const em = `pp-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, role, role, [main]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    X = await user(`pp-x-${tag}@p.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
  }, 60_000);
  afterAll(async () => db?.end());

  it('مقفولة لكل الأدوار الجاهزة، والموظف من غيرها ما يضيفش ولا يعدّل', async () => {
    expect((await admin(`select count(*)::int n from roles where shop_id = $1 and perms ? 'print_templates'`, [shop])).rows[0].n).toBe(0);
    const t = await tpl(O, main);
    const p = await printer(O, main);
    for (const u of [R, T]) {
      for (const b of [null, main, B2]) {
        await expect(tpl(u, b)).rejects.toThrow(DENIED);
        await expect(printer(u, b)).rejects.toThrow(DENIED);
      }
      expect(await rename(u, 'print_templates', t)).toBe(0);
      expect(await rename(u, 'printers', p)).toBe(0);
      // القراية لكل اللي بيطبع
      expect((await as(u, `select count(*)::int n from print_templates where id = $1`, [t])).rows[0].n).toBe(1);
    }
  });

  it('بالصلاحية: فروعه بس، مش فرع تاني ولا قالب المحل كله، وما ينقلش قالبه لفرع تاني', async () => {
    await grant(R, true);
    const t = await tpl(R, main);
    const p = await printer(R, main);
    expect(await rename(R, 'print_templates', t)).toBe(1);
    expect(await rename(R, 'printers', p)).toBe(1);
    expect((await as(R, `update print_templates set deleted_at = now() where id = $1`, [t])).rowCount).toBe(1);
    for (const b of [null, B2]) {
      await expect(tpl(R, b)).rejects.toThrow(DENIED);
      await expect(printer(R, b)).rejects.toThrow(DENIED);
      expect(await rename(R, 'print_templates', await tpl(O, b, 'invoice'))).toBe(0);
      expect(await rename(R, 'printers', await printer(O, b))).toBe(0);
      await expect(as(R, `update print_templates set branch_id = $2 where id = $1`, [t, b])).rejects.toThrow(DENIED);
      await expect(as(R, `update printers set branch_id = $2 where id = $1`, [p, b])).rejects.toThrow(DENIED);
    }
    // معاه كل الفروع: قالب المحل كله كمان
    await as(O, `select set_staff_branches($1, $2)`, [R, [main, B2]]);
    expect(await rename(R, 'print_templates', await tpl(R, null))).toBe(1);
    expect(await rename(R, 'printers', await printer(R, null))).toBe(1);
    await as(O, `select set_staff_branches($1, $2)`, [R, [main]]);
    // الصلاحية اتشالت: قفل على طول
    await grant(R, null);
    expect(await rename(R, 'printers', p)).toBe(0);
  });

  it('الفني عمره ما ياخدها حتى باستثناء، ومحل تاني ما يشوفش ولا يعدّل', async () => {
    await grant(T, true);
    await expect(tpl(T, main)).rejects.toThrow(DENIED);
    await expect(printer(T, main)).rejects.toThrow(DENIED);
    const t = await tpl(O, main);
    expect(await rename(T, 'print_templates', t)).toBe(0);
    expect(await rename(X, 'print_templates', t)).toBe(0);
    expect((await as(X, `select count(*)::int n from print_templates where id = $1`, [t])).rows[0].n).toBe(0);
  });

  it('صاحب المحل زي ما هو: كل الفروع وقالب المحل كله', async () => {
    for (const b of [null, main, B2]) {
      expect(await rename(O, 'print_templates', await tpl(O, b, 'voucher'))).toBe(1);
      expect(await rename(O, 'printers', await printer(O, b))).toBe(1);
    }
    expect((await as(O, `select my_perms() p`)).rows[0].p.print_templates).toContain('edit');
  });
});
