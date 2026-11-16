// الميزات الجديدة (C4-C8) بالفروع: كل فرع ليه بياناته وحساباته، و"كل الفروع" لصاحب المحل، والموظف بيشوف فرعه بس
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
/** branch = الفرع الشغال اللي التطبيق بيبعته في الهيدر x-branch-id */
async function as(uid: string | null, sql: string, params: unknown[] = [], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
    if (uid) {
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
    } else {
      await db.query(`select set_config('request.jwt.claims', '', true)`);
      await db.query('set local role anon');
    }
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
const imei = () => `35${String(Math.floor(Math.random() * 1e13)).padStart(13, '0')}`;

d('الميزات الجديدة بالفروع', () => {
  let O = '';
  let R2 = '';
  let T = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash1 = '';
  let cash2 = '';
  const balanced = async (b: string) => {
    const rows = (await as(O, `select sum(debit) d, sum(credit) c from trial_balance($1)`, [b])).rows[0];
    expect(Number(rows.d)).toBe(Number(rows.c));
  };

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`bf-o-${tag}@b.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل فروع جديد')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع الدقي', 'D2', '0233000000', 'الدقي')`, [B2]);
    cash1 = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    cash2 = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, B2])).rows[0].id;
    const em = `bf-r2-${tag}@b.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, 'استقبال الدقي', 'reception', $2)`, [em, [B2]]);
    R2 = await user(em);
    await as(R2, `select bootstrap_account('استقبال الدقي')`);
    const et = `bf-t-${tag}@b.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, 'فني', 'technician', $2)`, [et, [main, B2]]);
    T = await user(et);
    await as(T, `select bootstrap_account('فني')`);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash1]);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash2]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('المستعمل: الشرا في فرع الخزنة، والبيع بخزنة فرعه بس، وموظف الفرع التاني ما يشوفوش، وكل فرع متوازن', async () => {
    const u = id();
    await as(O, `select buy_used_device($1, $2::jsonb, $3, $4::jsonb)`, [u, JSON.stringify({ imei: imei(), brand: 'Apple', model: 'iPhone 12', buy_price: 800000 }), cash1, JSON.stringify({ name: 'بائع' })], main);
    expect((await admin(`select branch_id from used_devices where id = $1`, [u])).rows[0].branch_id).toBe(main);
    expect((await as(R2, `select * from used_devices_list()`)).rows).toHaveLength(0);
    expect((await as(O, `select * from used_devices_list($1)`, [B2])).rows).toHaveLength(0);
    expect((await as(O, `select * from used_devices_list($1)`, [main])).rows).toHaveLength(1);
    expect((await as(O, `select * from used_devices_list()`)).rows).toHaveLength(1);
    // موظف الدقي ما يبيعش جهاز الرئيسي، وخزنة الدقي ما تنفعش لجهاز الرئيسي
    await expect(as(R2, `select sell_used_device($1, $2, 900000, $3)`, [id(), u, cash2])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O, `select sell_used_device($1, $2, 900000, $3)`, [id(), u, cash2])).rejects.toThrow(/E_BAD_BRANCH/);
    const e = (await as(O, `select sell_used_device($1, $2, 900000, $3) e`, [id(), u, cash1], B2)).rows[0].e;
    expect((await admin(`select branch_id from journal_entries where id = $1`, [e])).rows[0].branch_id).toBe(main);
    await balanced(main);
    await balanced(B2);
  });

  it('العمولات: قاعدة الفرع بتكسب العامة، والعمولة في فرع الجهاز، والتقرير بالفرع', async () => {
    await as(O, `insert into commission_rules(shop_id, mode, value) values (gen_random_uuid(), 'percent', 1000)`);
    await as(O, `insert into commission_rules(shop_id, branch_id, mode, value) values (gen_random_uuid(), $1, 'fixed', 7000)`, [B2]);
    const repair = async (branch: string, cb: string, uid: string) => {
      const c = id();
      const dv = id();
      await as(uid, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [c, `0107${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`], branch);
      await as(uid, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A78', 'شحن')`, [dv, c], branch);
      await as(T, `update devices set status = 'inspecting' where id = $1`, [dv], branch);
      for (const st of ['in_repair', 'repaired', 'ready']) await as(T, `update devices set status = $2 where id = $1`, [dv, st], branch);
      await as(O, `insert into device_costs(shop_id, device_id, estimated_cost, final_cost) values (gen_random_uuid(), $1, 100000, 100000)`, [dv], branch);
      await as(O, `select record_payment($1, $2, $3, 100000, $4)`, [id(), c, cb, dv], branch);
      await as(O, `update devices set status = 'delivered' where id = $1`, [dv], branch);
      return dv;
    };
    const d1 = await repair(main, cash1, O);
    const d2 = await repair(B2, cash2, R2);
    const comm = async (dv: string) => (await admin(`select e.branch_id, sum(l.credit)::bigint amt from journal_entries e join journal_lines l on l.entry_id = e.id where e.source_type = 'commission' and e.device_id = $1 group by e.branch_id`, [dv])).rows[0];
    expect(await comm(d1)).toEqual({ branch_id: main, amt: '10000' });
    expect(await comm(d2)).toEqual({ branch_id: B2, amt: '7000' });
    const rep = async (b: string | null) => (await as(O, `select commission from commissions_report(now() - interval '1 day', now() + interval '1 day', $1) where technician_id = $2`, [b, T])).rows[0].commission;
    expect([await rep(main), await rep(B2), await rep(null)]).toEqual(['10000', '7000', '17000']);
    await balanced(main);
    await balanced(B2);
  });

  it('قوايم الفحص: قالب فرع وقالب للمحل لنفس الماركة', async () => {
    await as(O, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'apple', '[{"key":"wifi"}]')`);
    await as(O, `insert into check_templates(shop_id, brand, branch_id, items) values (gen_random_uuid(), 'apple', $1, '[{"key":"face_id"}]')`, [B2]);
    await expect(as(O, `insert into check_templates(shop_id, brand, branch_id, items) values (gen_random_uuid(), 'apple', $1, '[{"key":"mic"}]')`, [B2])).rejects.toThrow(/duplicate|unique/);
    expect((await as(R2, `select count(*)::int n from check_templates`)).rows[0].n).toBe(2);
  });

  it('الكتالوج: رابط الفرع بيعرض التوفر من مخزون الفرع ده، ورابط كل الفروع من المجموع', async () => {
    const it = id();
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name, sale_price, in_catalog) values ($1, gen_random_uuid(), 'accessory', 'شاحن', 20000, true)`, [it]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: it, qty: 3, unit_cost: 8000 }]), cash1], main);
    const all = (await as(O, `select set_catalog(true) t`)).rows[0].t;
    const t2 = (await as(O, `select set_catalog(true, $1) t`, [B2])).rows[0].t;
    await expect(as(R2, `select set_catalog(true, $1)`, [B2])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    const stock = async (tok: string) => (await as(null, `select public_catalog($1) c`, [tok])).rows[0].c;
    const ca = await stock(all);
    const cb = await stock(t2);
    expect(ca.items.find((x: { id: string }) => x.id === it).in_stock).toBe(true);
    expect(cb.items.find((x: { id: string }) => x.id === it).in_stock).toBe(false);
    expect(cb.shop).toMatchObject({ branch: 'فرع الدقي', phone: '0233000000' });
    expect(ca.shop.branch).toBeNull();
    // المستعمل اللي في الرئيسي ما بيظهرش في كتالوج الدقي
    const u = id();
    await as(O, `select buy_used_device($1, $2::jsonb, $3, $4::jsonb)`, [u, JSON.stringify({ imei: imei(), brand: 'Samsung', model: 'S21', buy_price: 500000, sale_price: 700000 }), cash1, JSON.stringify({ name: 'بائع' })], main);
    await admin(`update items set in_catalog = true where id = (select item_id from used_devices where id = $1)`, [u]);
    expect((await stock(all)).items.some((x: { kind: string }) => x.kind === 'used')).toBe(true);
    expect((await stock(t2)).items.some((x: { kind: string }) => x.kind === 'used')).toBe(false);
  });

  it('بوابة الجملة: موظف الدقي بيفتحها لفرعه بس، والكشف والطلبيات بالفرع، وموظف الفرع التاني ما يشوفهاش', async () => {
    const c = id();
    await as(R2, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'محل جملة', '01177771111')`, [c], B2);
    const tok = (await as(R2, `select set_portal($1, true, $2) t`, [c, main], B2)).rows[0].t;
    expect((await admin(`select portal_branch from customers where id = $1`, [c])).rows[0].portal_branch).toBe(B2);
    const item = (await admin(`select id from items where shop_id = $1 and name = 'شاحن'`, [shop])).rows[0].id;
    const o = (await as(null, `select portal_order($1, $2::jsonb) o`, [tok, JSON.stringify([{ item, qty: 5 }])])).rows[0].o;
    expect((await admin(`select branch_id from wholesale_orders where id = $1`, [o])).rows[0].branch_id).toBe(B2);
    expect((await as(R2, `select id from wholesale_orders`)).rows.map((r) => r.id)).toEqual([o]);
    expect((await as(O, `select id from wholesale_orders`)).rows.map((r) => r.id)).toEqual([o]);
    // استقبال الرئيسي ما بيشوفش طلبيات الدقي
    const em = `bf-r1-${tag}@b.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, 'استقبال الرئيسي', 'reception', $2)`, [em, [main]]);
    const R1 = await user(em);
    await as(R1, `select bootstrap_account('استقبال الرئيسي')`);
    expect((await as(R1, `select id from wholesale_orders`)).rows).toHaveLength(0);
    // كشف الحساب: بيع بالآجل في الرئيسي ما بيظهرش في بوابة الدقي
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 20000 }]), c], main);
    const p = (await as(null, `select public_portal($1) p`, [tok])).rows[0].p;
    expect(Number(p.balance)).toBe(0);
    expect(p.shop.branch).toBe('فرع الدقي');
  });

  it('التحليلات: صرف 30 يوم بالفرع', async () => {
    const item = (await admin(`select id from items where shop_id = $1 and name = 'شاحن'`, [shop])).rows[0].id;
    const used = async (b: string | null) => Number((await as(O, `select coalesce(sum(used), 0) u from items_usage30($1) where item_id = $2`, [b, item])).rows[0].u);
    expect([await used(main), await used(B2), await used(null)]).toEqual([1, 0, 1]);
    expect(await used(null)).toBe((await used(main)) + (await used(B2)));
  });
});
