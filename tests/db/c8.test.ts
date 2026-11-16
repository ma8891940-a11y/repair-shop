// C8: الكتالوج الأونلاين، وبوابة عميل الجملة، وإشعارات تيليجرام، ومكان الفاتورة الإلكترونية
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
let other = '';
let cash = '';
const BOT = '123456789:' + 'A'.repeat(35);

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}
const item = async (name: string, price: number | null, inCat: boolean, img: string | null = null) => {
  const id = randomUUID();
  await as(owner, `insert into items(id, shop_id, kind, name, sale_price, in_catalog, image_path) values ($1, gen_random_uuid(), 'accessory', $2, $3, $4, $5)`, [id, name, price, inCat, img]);
  return id;
};

d('C8: الكتالوج والبوابة وتيليجرام', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`o8-${tag}@t.test`);
    other = await user(`x8-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل الكتالوج')`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    rec = await staff(`r8-${tag}@t.test`, 'reception');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
  });
  afterAll(async () => db?.end());

  it('الكتالوج: صاحب المحل بيفتحه، والزائر بيشوف الأصناف المختارة بالاسم والسعر و"متوفر" بس، والقفل بيلغي الرابط', async () => {
    await expect(as(rec, `select set_catalog(true)`)).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    const tok = (await as(owner, `select set_catalog(true) t`)).rows[0].t as string;
    expect(tok).toMatch(/^[0-9a-f]{32}$/);
    const shop = (await db.query(`select shop_id from profiles where id = $1`, [owner])).rows[0].shop_id;
    const img = `${shop}/${randomUUID()}.jpg`;
    const shown = await item('جراب ظاهر', 15000, true, img);
    await item('جراب مخفي', 15000, false);
    await item('من غير سعر', null, true);
    const c = (await as(null, `select public_catalog($1) c`, [tok])).rows[0].c;
    expect(c.shop.name).toBe('محل الكتالوج');
    expect(c.items.map((i: { name: string }) => i.name)).toEqual(['جراب ظاهر']);
    expect(Object.keys(c.items[0]).sort()).toEqual(['details', 'id', 'image', 'in_stock', 'kind', 'name', 'price']);
    expect(c.items[0]).toMatchObject({ id: shown, price: 15000, in_stock: false });
    // الصورة: بالـ header الصح بس، وللصنف المختار بس
    await db.query(`insert into storage.objects(bucket_id, name) values ('item-images', $1), ('item-images', $2)`, [img, `${shop}/${randomUUID()}.jpg`]);
    const read = async (h: Record<string, string>) => (await as(null, `select name from storage.objects where bucket_id = 'item-images' and name like $1`, [`${shop}/%`], h)).rows.map((r) => r.name);
    expect(await read({ 'x-catalog-token': tok })).toEqual([img]);
    expect(await read({})).toEqual([]);
    // القفل
    expect((await as(owner, `select set_catalog(false) t`)).rows[0].t).toBeNull();
    expect((await as(null, `select public_catalog($1) c`, [tok])).rows[0].c).toBeNull();
    expect(await read({ 'x-catalog-token': tok })).toEqual([]);
    await as(owner, `select set_catalog(true)`);
  });

  it('البوابة: العميل بيشوف رصيده وحركاته هو بس، وبيبعت طلبية من أصناف الكتالوج، والمحل بيغيّر حالتها', async () => {
    const [a, b] = [randomUUID(), randomUUID()];
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'محل الجملة أ', '01155551111'), ($2, gen_random_uuid(), 'محل الجملة ب', '01155552222')`, [a, b]);
    const acc = await item('سكرينة جملة', 5000, true);
    await as(owner, `select owner_capital($1, $2, 100000)`, [randomUUID(), cash]);
    // بيع بالآجل لـ أ (1,000) ودفعة 300 ← عليه 700. وبيع لـ ب
    const sup = randomUUID();
    await as(owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: acc, qty: 100, unit_cost: 2000 }]), cash]);
    await as(owner, `select record_sale($1, $2::jsonb, null, $3)`, [randomUUID(), JSON.stringify([{ item: acc, qty: 20, price: 5000 }]), a]);
    await as(owner, `select record_payment($1, $2, $3, 30000)`, [randomUUID(), a, cash]);
    await as(owner, `select record_sale($1, $2::jsonb, null, $3)`, [randomUUID(), JSON.stringify([{ item: acc, qty: 2, price: 5000 }]), b]);
    const tok = (await as(owner, `select set_portal($1, true) t`, [a])).rows[0].t as string;
    const p = (await as(null, `select public_portal($1) p`, [tok])).rows[0].p;
    expect(p.customer).toEqual({ name: 'محل الجملة أ' });
    expect(Number(p.balance)).toBe(70000);
    expect(p.entries).toHaveLength(2);
    expect(JSON.stringify(p)).not.toContain('محل الجملة ب');
    expect(p.items.map((i: { name: string }) => i.name)).toContain('سكرينة جملة');
    // طلبية
    const o = (await as(null, `select portal_order($1, $2::jsonb, 'بسرعة') o`, [tok, JSON.stringify([{ item: acc, qty: 30 }])])).rows[0].o;
    const hidden = await item('مش في الكتالوج', 1000, false);
    await expect(as(null, `select portal_order($1, $2::jsonb)`, [tok, JSON.stringify([{ item: hidden, qty: 1 }])])).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(null, `select portal_order($1, $2::jsonb)`, [tok, JSON.stringify([{ item: acc, qty: 0 }])])).rejects.toThrow(/E_BAD_AMOUNT/);
    await expect(as(null, `select portal_order($1, $2::jsonb)`, ['0'.repeat(32), JSON.stringify([{ item: acc, qty: 1 }])])).rejects.toThrow(/E_NOT_FOUND/);
    await expect(as(null, `select * from wholesale_orders`)).rejects.toThrow(/permission denied/);
    expect((await as(rec, `update wholesale_orders set status = 'seen' where id = $1 returning status`, [o])).rows[0].status).toBe('seen');
    await expect(as(rec, `update wholesale_orders set lines = '[]' where id = $1`, [o])).rejects.toThrow(/permission denied/);
    expect((await as(other, `select * from wholesale_orders`)).rows).toHaveLength(0);
    // القفل بيلغي الرابط
    await as(owner, `select set_portal($1, false)`, [a]);
    expect((await as(null, `select public_portal($1) p`, [tok])).rows[0].p).toBeNull();
  });

  it('تيليجرام: الـ token مشفّر وما بيرجعش، والرسالة من غير بيانات العميل، والقفل بيوقفها', async () => {
    await expect(as(owner, `select set_telegram('bad', '123456789', null)`)).rejects.toThrow(/E_BAD_TOKEN/);
    await expect(as(rec, `select set_telegram($1, '123456789', null)`, [BOT])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await as(owner, `select set_telegram($1, '987654321', array['intake','delivered'])`, [BOT]);
    const st = (await as(owner, `select telegram_status() s`)).rows[0].s;
    expect(st).toEqual({ configured: true, enabled: true, chat: '987654321', events: ['intake', 'delivered'] });
    expect(JSON.stringify(st)).not.toContain(BOT.slice(-10));
    await expect(as(owner, `select * from shop_telegram`)).rejects.toThrow(/permission denied/);
    const before = Number((await db.query(`select count(*) n from net.test_requests`)).rows[0].n);
    const c = randomUUID();
    await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميلة سرية', '01277778888')`, [c]);
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A57', 'كاميرا')`, [randomUUID(), c]);
    const reqs = (await db.query(`select url, body from net.test_requests order by id desc limit 1`)).rows;
    expect(Number((await db.query(`select count(*) n from net.test_requests`)).rows[0].n)).toBe(before + 1);
    expect(reqs[0].url).toBe(`https://api.telegram.org/bot${BOT}/sendMessage`);
    expect(reqs[0].body.chat_id).toBe('987654321');
    expect(reqs[0].body.text).toContain('Oppo A57');
    expect(reqs[0].body.text).not.toContain('عميلة سرية');
    expect(reqs[0].body.text).not.toContain('01277778888');
    expect((await as(owner, `select telegram_test() ok`)).rows[0].ok).toBe(true);
    await as(owner, `select disable_telegram()`);
    const n = Number((await db.query(`select count(*) n from net.test_requests`)).rows[0].n);
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A58', 'شاشة')`, [randomUUID(), c]);
    expect(Number((await db.query(`select count(*) n from net.test_requests`)).rows[0].n)).toBe(n);
  });

  it('الفاتورة الإلكترونية: مكان في القاعدة بس، لصاحب المحل', async () => {
    await as(owner, `insert into eta_settings(shop_id, taxpayer_id) values (gen_random_uuid(), '123456789')`);
    expect((await as(rec, `select * from eta_settings`)).rows).toHaveLength(0);
    await expect(as(owner, `insert into eta_settings(shop_id, taxpayer_id) values (gen_random_uuid(), '12')`)).rejects.toThrow();
  });
});
