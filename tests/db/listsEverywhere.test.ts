// قوائم الملء السريع في البرنامج كله: الإضافة والحذف بصلاحية من صاحب المحل، وسجل النشاط، والحذف ما بيغيّرش القديم
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

d('قوائم الملء السريع', () => {
  let O = '';
  let R = '';
  let T = '';
  let shop = '';
  const add = (uid: string, list: string, value: string, k = id()) =>
    as(uid, `insert into shop_lists(id, shop_id, list, value) values ($1, gen_random_uuid(), $2, $3)`, [k, list, value]).then(() => k);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`le-o-${tag}@l.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل القوايم')).shop_id s`)).rows[0].s;
    for (const role of ['reception', 'technician'] as const) {
      const em = `le-${role}-${tag}@l.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
  }, 60_000);
  afterAll(async () => db?.end());

  it('القوايم الجديدة (أنواع الأجهزة، والأعطال، وقطع الغيار، وأسباب المرتجع) مقبولة، وغيرها لأ', async () => {
    for (const l of ['device_types', 'issues', 'parts', 'return_reasons']) await add(O, l, `بند ${l}`);
    await expect(add(O, 'whatever', 'x')).rejects.toThrow(/shop_lists_list_check/);
  });

  it('الإضافة والحذف: صاحب المحل دايمًا، والأدوار اللي يختارها هو بس', async () => {
    await expect(add(R, 'brands', 'Nokia')).rejects.toThrow(/row-level security|policy/);
    await expect(as(R, `insert into issue_presets(id, shop_id, label, issue) values ($1, gen_random_uuid(), 'x', 'y')`, [id()])).rejects.toThrow(/row-level security|policy/);
    expect((await as(R, `select can_edit_lists() c`)).rows[0].c).toBe(false);
    await as(O, `update shops set extras = coalesce(extras, '{}'::jsonb) || '{"lists_edit": ["reception"]}'::jsonb where id = $1`, [shop]);
    expect((await as(R, `select can_edit_lists() c`)).rows[0].c).toBe(true);
    const k = await add(R, 'brands', 'Nokia');
    // والأعطال الجاهزة بنفس الصلاحية
    await as(R, `insert into issue_presets(id, shop_id, label, issue) values ($1, gen_random_uuid(), 'سماعة', 'السماعة مش شغالة')`, [id()]);
    // والفني لسه لأ
    await expect(add(T, 'brands', 'Lenovo')).rejects.toThrow(/row-level security|policy/);
    // الكل بيشوف (القايمة واحدة للمحل)
    expect((await as(T, `select value from shop_lists where id = $1`, [k])).rows[0].value).toBe('Nokia');
    // الحذف (ناعم) من الاستقبال
    await as(R, `update shop_lists set deleted_at = now() where id = $1`, [k]);
    expect((await admin(`select deleted_at is not null x from shop_lists where id = $1`, [k])).rows[0].x).toBe(true);
    // ولما صاحب المحل يشيل الصلاحية: بتتشال على طول
    await as(O, `update shops set extras = extras - 'lists_edit' where id = $1`, [shop]);
    await expect(add(R, 'brands', 'Sony')).rejects.toThrow(/row-level security|policy/);
  });

  it('سجل النشاط: كل إضافة وحذف متسجلين', async () => {
    const k = await add(O, 'parts', 'فلاتة شحن');
    await as(O, `update shop_lists set deleted_at = now() where id = $1`, [k]);
    const acts = (await admin(`select action from audit_log where entity = 'shop_lists' and entity_id = $1 order by created_at`, [k])).rows.map((r) => r.action);
    expect(acts).toEqual(['insert', 'soft_delete']);
  });

  it('حذف بند من القايمة ما بيغيّرش البيانات القديمة، وقيمة البند نفسها ما بتتعدلش', async () => {
    const k = await add(O, 'brands', 'Motorola');
    const cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [cust, `0107${String(Date.now()).slice(-7)}`]);
    const dev = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Motorola', 'G54', 'شاشة')`, [dev, cust]);
    const item = id();
    await as(O, `insert into items(id, shop_id, kind, name, brand) values ($1, gen_random_uuid(), 'part', 'شاشة G54', 'Motorola')`, [item]);
    await as(O, `update shop_lists set deleted_at = now() where id = $1`, [k]);
    expect((await admin(`select brand from devices where id = $1`, [dev])).rows[0].brand).toBe('Motorola');
    expect((await as(O, `select brand from items_stock() where id = $1`, [item])).rows[0].brand).toBe('Motorola');
    await expect(as(O, `update shop_lists set value = 'Moto' where id = $1`, [k])).rejects.toThrow(/E_LIST_VALUE_FIXED/);
  });
});
