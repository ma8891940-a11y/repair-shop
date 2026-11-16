// C2: قوالب الفحص لكل ماركة، وتوقيع العميل وقت التسليم
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
async function device(uid: string) {
  const c = randomUUID();
  const id = randomUUID();
  await as(uid, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'سارة علي', $2)`, [c, `0101${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`]);
  const r = await as<{ tracking_token: string; shop_id: string }>(uid, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A52', 'شاشة') returning tracking_token, shop_id`, [id, c]);
  return { id, ...r.rows[0] };
}
const SIG = 'data:image/png;base64,iVBORw0KGgo=';
const tag = randomUUID().slice(0, 8);
let owner = '';
let rec = '';
let tech = '';
let other = '';

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}

d('C2: قوالب الفحص والتوقيع', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`ok-${tag}@t.test`);
    other = await user(`xk-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل الفحص')`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    rec = await staff(`rk-${tag}@t.test`, 'reception');
    tech = await staff(`tk-${tag}@t.test`, 'technician');
  });
  afterAll(async () => db?.end());

  it('صاحب المحل بس يعدّل القالب، وقالب واحد لكل ماركة، والمحل التاني ما يشوفوش، والماركة لازم تكون معروفة', async () => {
    const items = JSON.stringify([{ key: 'wifi' }, { key: 'c_1', label: 'فتحة الكارت' }]);
    await as(owner, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'samsung', $1)`, [items]);
    await expect(as(owner, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'samsung', $1)`, [items])).rejects.toThrow(/duplicate|unique/);
    await expect(as(owner, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'nokia', $1)`, [items])).rejects.toThrow(/check/);
    await expect(as(owner, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'apple', '[]')`)).rejects.toThrow(/check/);
    await expect(as(rec, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'apple', $1)`, [items])).rejects.toThrow();
    // الكل بيقرا (اللي بيفحص محتاجه)، والتعديل لصاحب المحل بس
    expect((await as(tech, `select brand from check_templates`)).rows).toEqual([{ brand: 'samsung' }]);
    expect((await as(rec, `update check_templates set items = '[{"key":"mic"}]' returning id`)).rows).toHaveLength(0);
    expect((await as(other, `select * from check_templates`)).rows).toHaveLength(0);
    // الحذف الفعلي ممنوع
    await expect(db.query(`delete from check_templates where brand = 'samsung'`)).rejects.toThrow(/E_HARD_DELETE/);
  });

  it('الفحص بيتحفظ بأسماء البنود اللي كتبها صاحب المحل', async () => {
    const dev = await device(owner);
    await as(rec, `insert into device_checks(shop_id, device_id, stage, items, labels) values (gen_random_uuid(), $1, 'intake', '{"wifi":"ok","c_1":"fail"}', '{"c_1":"فتحة الكارت"}')`, [dev.id]);
    expect((await as(owner, `select labels from device_checks where device_id = $1`, [dev.id])).rows[0].labels).toEqual({ c_1: 'فتحة الكارت' });
    await expect(as(rec, `insert into device_checks(shop_id, device_id, stage, items, labels) values (gen_random_uuid(), $1, 'delivery', '{}', '[]')`, [dev.id])).rejects.toThrow(/check/);
  });

  it('توقيع التسليم: بعد التسليم بس، ومن الاستقبال أو صاحب المحل، ومرة واحدة', async () => {
    const dev = await device(owner);
    await expect(as(rec, `update devices set delivery_signature = $2 where id = $1`, [dev.id, SIG])).rejects.toThrow(/E_NOT_DELIVERED/);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(owner, `update devices set status = $2 where id = $1`, [dev.id, st]);
    await as(owner, `insert into device_costs(shop_id, device_id, estimated_cost, final_cost) values (gen_random_uuid(), $1, 50000, 50000)`, [dev.id]);
    await as(owner, `select deliver_on_credit($1)`, [dev.id]);
    await expect(as(tech, `update devices set delivery_signature = $2 where id = $1`, [dev.id, SIG])).rejects.toThrow();
    await expect(as(rec, `update devices set delivery_signature = 'javascript:alert(1)' where id = $1`, [dev.id])).rejects.toThrow(/check/);
    await as(rec, `update devices set delivery_signature = $2 where id = $1`, [dev.id, SIG]);
    await expect(as(owner, `update devices set delivery_signature = $2 where id = $1`, [dev.id, SIG.replace('=', 'A=')])).rejects.toThrow(/E_RECEIPT_IMMUTABLE/);
    await expect(as(owner, `update devices set delivery_signature = null where id = $1`, [dev.id])).rejects.toThrow(/E_RECEIPT_IMMUTABLE/);
    expect((await as(owner, `select delivery_signature s from devices where id = $1`, [dev.id])).rows[0].s).toBe(SIG);
  });
});
