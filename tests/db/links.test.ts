// البند 6: ربط عميل بمورد: رصيد صافي في كشف واحد، ومقاصة بقيد، وفك الربط
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
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();

d('ربط عميل بمورد', () => {
  let O = '';
  let R = '';
  let O2 = '';
  const acc: Record<string, string> = {};
  const cust = id();
  const sup = id();
  const cust2 = id();
  let link = '';
  const info = async () => (await as(O, `select party_link_info('link', $1) i`, [link])).rows[0].i;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`lk-o-${tag}@l.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل الربط')`);
    const em = `lk-r-${tag}@l.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    O2 = await user(`lk-o2-${tag}@l.test`);
    await as(O2, `select bootstrap_account('تاني', 'محل تاني')`);
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'حسن التاجر', $3), ($2, gen_random_uuid(), 'عميل تاني', $4)`, [cust, cust2, `0103${String(Date.now()).slice(-7)}`, `0104${String(Date.now()).slice(-7)}`]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'حسن التاجر')`, [sup]);
    // حسن عليه 700 ج كعميل، والمحل عليه ليه 500 ج كمورد
    await as(O, `select opening_balance($1, 'customer', $2, 70000)`, [id(), cust]);
    await as(O, `select opening_balance($1, 'supplier', $2, 50000)`, [id(), sup]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الربط: لصاحب المحل بس، ومرة واحدة لكل عميل ومورد، والمحل التاني ما يوصلش', async () => {
    await expect(as(R, `select link_parties($1, $2, $3)`, [id(), cust, sup])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O2, `select link_parties($1, $2, $3)`, [id(), cust, sup])).rejects.toThrow(/E_NOT_FOUND/);
    link = id();
    await as(O, `select link_parties($1, $2, $3)`, [link, cust, sup]);
    expect((await as(O, `select link_parties($1, $2, $3) x`, [link, cust, sup])).rows[0].x).toBe(link); // نفس الطلب مرتين
    await expect(as(O, `select link_parties($1, $2, $3)`, [id(), cust2, sup])).rejects.toThrow(/E_ALREADY_LINKED/);
    expect((await as(R, `select * from party_links`)).rowCount).toBe(0);
  });

  it('الرصيد الصافي في كشف واحد: 700 عليه − 500 ليه = 200 عليه', async () => {
    expect(await info()).toMatchObject({ receivable: 70000, payable: 50000, net: 20000, max_netting: 50000, customer: 'حسن التاجر' });
    expect((await as(O, `select party_link_info('customer', $1) i`, [cust])).rows[0].i.id).toBe(link);
    expect((await as(O, `select party_link_info('supplier', $1) i`, [sup])).rows[0].i.id).toBe(link);
    expect((await as(O, `select party_link_info('customer', $1) i`, [cust2])).rows[0].i).toBeNull();
    const st = (await as(O, `select statement('linked', $1, $2, $3) s`, [link, FROM(), TO()])).rows[0].s;
    expect(st.moves).toHaveLength(2);
    expect(st.moves.at(-1).balance).toBe(20000);
  });

  it('المقاصة: بتخصم الدينين من بعض لحد أقل رصيد، والصافي ما بيتغيرش، والإلغاء بقيد عكسي', async () => {
    await expect(as(O, `select net_parties($1, $2, 50001)`, [id(), link])).rejects.toThrow(/E_NETTING_LIMIT/);
    await expect(as(R, `select net_parties($1, $2)`, [id(), link])).rejects.toThrow(/E_FORBIDDEN/);
    const k = id();
    const e = (await as(O, `select net_parties($1, $2, 30000) e`, [k, link])).rows[0].e;
    expect((await as(O, `select net_parties($1, $2, 30000) e`, [k, link])).rows[0].e).toBe(e);
    expect(await info()).toMatchObject({ receivable: 40000, payable: 20000, net: 20000, max_netting: 20000 });
    // كشف العميل لوحده وكشف المورد لوحده بيبينوا المقاصة
    const cs = (await as(O, `select statement('customer', $1, $2, $3) s`, [cust, FROM(), TO()])).rows[0].s;
    expect(cs.moves.at(-1)).toMatchObject({ source_type: 'netting', amount: -30000, balance: 40000 });
    const ss = (await as(O, `select statement('supplier', $1, $2, $3) s`, [sup, FROM(), TO()])).rows[0].s;
    expect(ss.moves.at(-1)).toMatchObject({ source_type: 'netting', amount: -30000, balance: 20000 });
    // الباقي كله
    await as(O, `select net_parties($1, $2)`, [id(), link]);
    expect(await info()).toMatchObject({ receivable: 20000, payable: 0, net: 20000, max_netting: 0 });
    await expect(as(O, `select net_parties($1, $2)`, [id(), link])).rejects.toThrow(/E_NETTING_LIMIT/);
    await as(O, `select reverse_entry($1, 'غلط')`, [e]);
    expect(await info()).toMatchObject({ receivable: 50000, payable: 30000, net: 20000 });
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('فك الربط: الكشف المجمّع بيقفل، والقيود والكشوف لكل واحد زي ما هي، وينفع يتربط تاني', async () => {
    await as(O, `select unlink_parties($1)`, [link]);
    expect((await as(O, `select party_link_info('customer', $1) i`, [cust])).rows[0].i).toBeNull();
    await expect(as(O, `select statement('linked', $1, $2, $3)`, [link, FROM(), TO()])).rejects.toThrow(/E_NOT_FOUND/);
    const cs = (await as(O, `select statement('customer', $1, $2, $3) s`, [cust, FROM(), TO()])).rows[0].s;
    expect(cs.moves.at(-1).balance).toBe(50000);
    await expect(as(O, `select unlink_parties($1)`, [link])).rejects.toThrow(/E_NOT_FOUND/);
    await as(O, `select link_parties($1, $2, $3)`, [id(), cust, sup]);
    expect((await as(O, `select party_link_info('supplier', $1) i`, [sup])).rows[0].i.net).toBe(20000);
  });
});
