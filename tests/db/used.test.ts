// C4: الأجهزة المستعملة: شراء وبيع بالـ IMEI، وبيانات البائع لصاحب المحل بس، وربح كل جهاز
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
let rec = '';
let tech = '';
let other = '';
let cash = '';
const IMEI = `35${String(Math.floor(Math.random() * 1e13)).padStart(13, '0')}`;
const NID = '29001011234567';

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}
const buy = (uid: string, id: string, imei = IMEI, price = 500000) =>
  as(uid, `select buy_used_device($1, $2::jsonb, $3, $4::jsonb)`, [
    id,
    JSON.stringify({ imei, brand: 'Samsung', model: 'A52', storage: '128GB', color: 'أسود', condition: 'خدش خفيف', buy_price: price, sale_price: 650000 }),
    cash,
    JSON.stringify({ name: 'محمد البائع', phone: '01012345678', nid: NID }),
  ]);
const list = async (uid: string) => (await as(uid, `select * from used_devices_list()`)).rows;
const clean = async () => expect((await as(owner, `select integrity_report() r`)).rows[0].r).toEqual([]);
const balance = async (code: string) =>
  Number((await as(owner, `select coalesce(sum(l.debit - l.credit), 0)::bigint b from journal_lines l join accounts a on a.id = l.account_id where a.code = $1`, [code])).rows[0].b);

d('C4: الأجهزة المستعملة', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`ou-${tag}@t.test`);
    other = await user(`xu-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل المستعمل')`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    rec = await staff(`ru-${tag}@t.test`, 'reception');
    tech = await staff(`tu-${tag}@t.test`, 'technician');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    await as(owner, `select owner_capital($1, $2, 5000000)`, [randomUUID(), cash]);
  });
  afterAll(async () => db?.end());

  it('الشراء قيد متوازن (المخزون زاد والخزنة نقصت بنفس المبلغ)، ونفس الـ IMEI ما يدخلش مرتين وهو في المخزون، والقيم الغلط مرفوضة', async () => {
    const [inv0, cash0] = [await balance('inventory'), await balance('cash_cash')];
    const id = randomUUID();
    await buy(owner, id);
    expect(await balance('inventory')).toBe(inv0 + 500000);
    expect(await balance('cash_cash')).toBe(cash0 - 500000);
    await clean();
    // نفس العملية مرتين = مرة واحدة
    await buy(owner, id);
    expect(await balance('inventory')).toBe(inv0 + 500000);
    await expect(buy(owner, randomUUID())).rejects.toThrow(/E_USED_IN_STOCK/);
    await expect(buy(owner, randomUUID(), '123')).rejects.toThrow(/E_BAD_IMEI/);
    await expect(buy(owner, randomUUID(), IMEI.replace(/.$/, '9'), 0)).rejects.toThrow(/E_BAD_AMOUNT/);
    // الفني ما يشتريش، ومحل تاني ما يشوفش
    await expect(buy(tech, randomUUID(), IMEI.replace(/.$/, '8'))).rejects.toThrow();
    expect(await list(other)).toHaveLength(0);
    await expect(list(tech)).rejects.toThrow(/E_FORBIDDEN/);
    const [row] = await list(owner);
    expect(row).toMatchObject({ imei: IMEI, status: 'in_stock', buy_price: '500000', has_seller_id: true });
  });

  it('البيع من شاشة المستعمل بس، ومرة واحدة، والربح = البيع − الشرا، وتكلفة البضاعة = سعر الشرا بالظبط', async () => {
    const [row] = await list(owner);
    // البيع العادي (نقطة البيع) ممنوع للجهاز المستعمل
    await expect(as(owner, `select record_sale($1, $2::jsonb, $3)`, [randomUUID(), JSON.stringify([{ item: row.item_id, qty: 1, price: 600000 }]), cash])).rejects.toThrow(/E_USED_SELL_HERE/);
    const cogs0 = await balance('cogs');
    await as(owner, `select sell_used_device($1, $2, 620000, $3)`, [randomUUID(), row.id, cash]);
    expect(await balance('cogs')).toBe(cogs0 + 500000);
    await clean();
    const [after] = await list(owner);
    expect(after).toMatchObject({ status: 'sold', sold_price: '620000', profit: '120000' });
    await expect(as(owner, `select sell_used_device($1, $2, 620000, $3)`, [randomUUID(), row.id, cash])).rejects.toThrow(/E_STOCK/);
  });

  it('بيانات البائع: صاحب المحل بس (ورقم البطاقة مشفّر وبيرجع صح)، وكل فتح بيتسجل، والجدول نفسه مقفول', async () => {
    const [row] = await list(owner);
    await expect(as(rec, `select * from seller_info($1)`, [row.id])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    const info = (await as(owner, `select * from seller_info($1)`, [row.id])).rows[0];
    expect(info).toMatchObject({ seller_name: 'محمد البائع', seller_phone: '01012345678', nid: NID });
    const stored = (await db.query(`select s.secret from vault.secrets s join used_devices u on u.seller_nid_secret = s.id where u.id = $1`, [row.id])).rows[0].secret as string;
    expect(stored).not.toBe(NID);
    expect((await as(owner, `select count(*)::int n from audit_log where action = 'seller_viewed' and entity_id = $1`, [row.id])).rows[0].n).toBe(1);
    await expect(as(owner, `select * from used_devices`)).rejects.toThrow(/permission denied/);
    await expect(as(rec, `select seller_name from used_devices`)).rejects.toThrow(/permission denied/);
    // الاستقبال بتشوف القايمة من غير مبالغ الشرا والربح
    const [r] = await list(rec);
    expect(r.buy_price).toBeNull();
    expect(r.profit).toBeNull();
  });

  it('عكس البيع بيرجّع الجهاز للمخزون، وعكس الشرا بيلغيه، والدفتر متوازن طول الوقت', async () => {
    const id = randomUUID();
    const imei2 = IMEI.replace(/^35/, '86');
    await buy(owner, id, imei2, 300000);
    const sale = (await as<{ e: string }>(owner, `select sell_used_device($1, $2, 350000, $3) e`, [randomUUID(), id, cash])).rows[0].e;
    await as(owner, `select reverse_entry($1, 'العميل رجّعه')`, [sale]);
    expect((await list(owner)).find((x) => x.id === id)).toMatchObject({ status: 'in_stock', profit: null });
    const buyEntry = (await db.query(`select buy_entry from used_devices where id = $1`, [id])).rows[0].buy_entry;
    await as(owner, `select reverse_entry($1, 'اتسجل غلط')`, [buyEntry]);
    expect((await list(owner)).find((x) => x.id === id)?.status).toBe('cancelled');
    await clean();
  });

  it('صورة البطاقة: اللي اشترى يرفعها في فولدر المحل، والقراية لصاحب المحل بس', async () => {
    const [row] = await list(owner);
    const shop = (await db.query(`select shop_id from used_devices where id = $1`, [row.id])).rows[0].shop_id;
    const path = `${shop}/${row.id}/${randomUUID()}.jpg`;
    await as(owner, `insert into storage.objects(bucket_id, name) values ('seller-ids', $1)`, [path]);
    await as(owner, `select set_seller_photo($1, $2)`, [row.id, path]);
    await expect(as(owner, `select set_seller_photo($1, $2)`, [row.id, path])).rejects.toThrow(/E_RECEIPT_IMMUTABLE/);
    await expect(as(tech, `insert into storage.objects(bucket_id, name) values ('seller-ids', $1)`, [`${shop}/${row.id}/x.jpg`])).rejects.toThrow();
    expect((await as(rec, `select name from storage.objects where bucket_id = 'seller-ids'`)).rows).toHaveLength(0);
    expect((await as(owner, `select name from storage.objects where bucket_id = 'seller-ids' and name = $1`, [path])).rows).toHaveLength(1);
  });
});
