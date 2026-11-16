// K: التصنيفات (مستويين، منتجات وخدمات) والخدمات من غير مخزون، والتحويل من التصنيفات النصية القديمة
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
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
const tag = randomUUID().slice(0, 8);
let owner = '';
let rec = '';
let other = '';
let cash = '';
let shop = '';

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}
const cat = async (name: string, parent: string | null = null, section = 'products') => {
  const id = randomUUID();
  await as(owner, `insert into categories(id, shop_id, parent_id, section, name, icon) values ($1, gen_random_uuid(), $2, $3, $4, 'box')`, [id, parent, section, name]);
  return id;
};

d('K: التصنيفات والخدمات', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`ok-${tag}@t.test`);
    other = await user(`xk-${tag}@t.test`);
    shop = (await as(owner, `select (bootstrap_account('صاحب', 'محل التصنيفات')).shop_id s`)).rows[0].s;
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    rec = await staff(`rk-${tag}@t.test`, 'reception');
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
  });
  afterAll(async () => db?.end());

  it('مستويين بس، والفرعي بياخد قسم الرئيسي، والاسم ما يتكررش تحت نفس الأب، ومحل تاني ما يشوفهاش', async () => {
    const parts = await cat('قطع الغيار');
    const screens = await cat('شاشات', parts);
    await expect(cat('شاشات', parts)).rejects.toThrow(/duplicate|unique/);
    await expect(cat('أصغر', screens)).rejects.toThrow(/E_CATEGORY_DEPTH/);
    const srv = await cat('خدمات', null, 'services');
    const clean = await cat('تنظيف', srv, 'products');
    expect((await admin(`select section from categories where id = $1`, [clean])).rows[0].section).toBe('services');
    expect((await as(other, `select * from categories`)).rows).toHaveLength(0);
    // الاستقبال من غير صلاحية "إضافة صنف جديد" ما تضيفش
    await expect(as(rec, `insert into categories(id, shop_id, name) values ($1, gen_random_uuid(), 'x')`, [randomUUID()])).rejects.toThrow();
    expect((await as(rec, `select count(*)::int n from categories`)).rows[0].n).toBe(4);
  });

  it('الصنف بيتربط بالتصنيف، واسمه بيتنسخ للنص القديم، وتغيير الاسم بيتنسخ، والتصنيف اللي فيه أصناف ما يتأرشفش', async () => {
    const acc = await cat('إكسسوارات');
    const cases = await cat('جرابات', acc);
    const it = randomUUID();
    await as(owner, `insert into items(id, shop_id, kind, name, sale_price, category_id) values ($1, gen_random_uuid(), 'accessory', 'جراب A54', 15000, $2)`, [it, cases]);
    expect((await admin(`select category from items where id = $1`, [it])).rows[0].category).toBe('جرابات');
    await as(owner, `update categories set name = 'جرابات وكفرات' where id = $1`, [cases]);
    expect((await admin(`select category from items where id = $1`, [it])).rows[0].category).toBe('جرابات وكفرات');
    await expect(as(owner, `update categories set deleted_at = now() where id = $1`, [cases])).rejects.toThrow(/E_CATEGORY_NOT_EMPTY/);
    await expect(as(owner, `update categories set deleted_at = now() where id = $1`, [acc])).rejects.toThrow(/E_CATEGORY_NOT_EMPTY/);
    await expect(db.query(`delete from categories where id = $1`, [cases])).rejects.toThrow(/E_HARD_DELETE/);
  });

  it('الشجرة بالعدد: الأصناف والمتوفر (الفرعي جوه الرئيسي)، والخدمة دايمًا متوفرة', async () => {
    const acc = (await admin(`select id from categories where shop_id = $1 and name = 'إكسسوارات'`, [shop])).rows[0].id;
    const cases = (await admin(`select id from categories where shop_id = $1 and parent_id = $2`, [shop, acc])).rows[0].id;
    const it = (await admin(`select id from items where shop_id = $1 and name = 'جراب A54'`, [shop])).rows[0].id;
    const tree = async () => Object.fromEntries((await as(owner, `select id, items, in_stock from category_tree()`)).rows.map((r) => [r.id, [Number(r.items), Number(r.in_stock)]]));
    expect((await tree())[acc]).toEqual([1, 0]);
    const sup = randomUUID();
    await as(owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(owner, `select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: it, qty: 4, unit_cost: 5000 }]), cash]);
    expect((await tree())[acc]).toEqual([1, 1]);
    expect((await tree())[cases]).toEqual([1, 1]);
    const srv = (await admin(`select id from categories where shop_id = $1 and name = 'خدمات'`, [shop])).rows[0].id;
    await as(owner, `insert into items(id, shop_id, kind, name, sale_price, category_id) values ($1, gen_random_uuid(), 'service', 'تنظيف شامل', 20000, $2)`, [randomUUID(), srv]);
    expect((await tree())[srv]).toEqual([1, 1]);
  });

  it('بيع خدمة: من غير مخزون ولا تكلفة، والإيراد إيراد الصيانة، والقيد متوازن، ومعاها صنف عادي في نفس الفاتورة', async () => {
    const svc = (await admin(`select id from items where shop_id = $1 and kind = 'service'`, [shop])).rows[0].id;
    const it = (await admin(`select id from items where shop_id = $1 and name = 'جراب A54'`, [shop])).rows[0].id;
    const e = (await as(rec, `select record_sale($1, $2::jsonb, $3) e`, [randomUUID(), JSON.stringify([{ item: svc, qty: 2, price: 20000 }, { item: it, qty: 1, price: 15000 }]), cash])).rows[0].e;
    const lines = (await admin(`select a.code, l.debit::int, l.credit::int from journal_lines l join accounts a on a.id = l.account_id where l.entry_id = $1 order by a.code`, [e])).rows;
    expect(lines).toEqual([
      { code: 'cash_cash', debit: 55000, credit: 0 },
      { code: 'cogs', debit: 5000, credit: 0 },
      { code: 'inventory', debit: 0, credit: 5000 },
      { code: 'rev_accessories', debit: 0, credit: 15000 },
      { code: 'rev_repair', debit: 0, credit: 40000 },
    ]);
    expect((await admin(`select count(*)::int n from stock_moves where item_id = $1`, [svc])).rows[0].n).toBe(0);
    expect((await as(owner, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('التحويل من التصنيفات النصية القديمة: كل نص بقى تصنيف، والأصناف اتربطت، ومرة تانية ما بيكررش', async () => {
    const a = randomUUID();
    const b = randomUUID();
    await as(owner, `insert into items(id, shop_id, kind, name, category) values ($1, gen_random_uuid(), 'part', 'سوكت شحن', 'سوكتات'), ($2, gen_random_uuid(), 'part', 'سوكت تاني', ' سوكتات ')`, [a, b]);
    expect(Number((await db.query(`select categories_from_text() n`)).rows[0].n)).toBeGreaterThanOrEqual(1);
    const ids = (await admin(`select distinct category_id from items where id in ($1, $2)`, [a, b])).rows;
    expect(ids).toHaveLength(1);
    expect((await admin(`select name, parent_id from categories where id = $1`, [ids[0].category_id])).rows[0]).toEqual({ name: 'سوكتات', parent_id: null });
    expect(Number((await db.query(`select categories_from_text() n`)).rows[0].n)).toBe(0);
  });

  it('صنف بتصنيف نصي بس (زي الاستيراد): بيتربط بتصنيف بنفس الاسم، ولو مش موجود بيتعمل', async () => {
    const a = randomUUID();
    const b = randomUUID();
    await as(owner, `insert into items(id, shop_id, kind, name, category) values ($1, gen_random_uuid(), 'accessory', 'جراب X', 'جرابات وكفرات')`, [a]);
    const cases = (await admin(`select id from categories where shop_id = $1 and name = 'جرابات وكفرات'`, [shop])).rows[0].id;
    expect((await admin(`select category_id from items where id = $1`, [a])).rows[0].category_id).toBe(cases);
    await as(owner, `insert into items(id, shop_id, kind, name, category) values ($1, gen_random_uuid(), 'part', 'كاميرا', 'كاميرات جديدة')`, [b]);
    const made = (await admin(`select c.name, c.parent_id from items i join categories c on c.id = i.category_id where i.id = $1`, [b])).rows[0];
    expect(made).toEqual({ name: 'كاميرات جديدة', parent_id: null });
  });

  it('التصنيفات الجاهزة: بتتضاف مرة واحدة (التشغيل التاني ما بيكررش)، وصاحب المحل بس', async () => {
    const tree = JSON.stringify([{ name: 'قطع الغيار', icon: 'chip', children: [{ name: 'شاشات', icon: 'screen' }, { name: 'بطاريات', icon: 'battery' }] }, { name: 'خدمات الصيانة', section: 'services', children: [{ name: 'فحص' }] }]);
    await expect(as(rec, `select seed_categories($1::jsonb)`, [tree])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    const n1 = (await as(owner, `select seed_categories($1::jsonb) n`, [tree])).rows[0].n;
    expect(n1).toBe(3); // قطع الغيار وشاشات موجودين قبل كده
    expect((await as(owner, `select seed_categories($1::jsonb) n`, [tree])).rows[0].n).toBe(0);
  });
});
