// U6: الميزات الجديدة (C1–C9 وK وWeb Push) بتفضل معزولة: الموظف بيشوف فرعه بس في كل جدول فيه فرع،
// والفني ما يشوفش أسعار ولا أرباح ولا بيانات عملاء في الميزات الجديدة.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string, sql: string, params: unknown[] = [], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
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
const imei = () => `35${String(Math.floor(Math.random() * 1e13)).padStart(13, '0')}`;
const phone = () => `0106${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;

// جداول إعدادات المحل اللي الفرع فيها اختيار (قالب أو طابعة أو قاعدة خاصة بفرع)، ومش بيانات شغل:
// موظف الفرع التاني بيقراها عشان البرنامج يختار "قالب الفرع أو قالب المحل". ما فيهاش فلوس ولا عملاء.
const SHARED_CONFIG = ['check_templates', 'print_templates', 'printers'];

d('U6: عزل الفروع والصلاحيات في الميزات الجديدة', () => {
  let O = '';
  let R1 = ''; // استقبال الرئيسي بس
  let T1 = ''; // فني الرئيسي بس
  let shop = '';
  let main = '';
  const B2 = id();
  let cash2 = '';

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`u6-o-${tag}@u.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل U6')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع المعادي', 'M2', '0225000000', 'المعادي')`, [B2]);
    cash2 = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, B2])).rows[0].id;
    for (const [role, name] of [['reception', 'استقبال الرئيسي'], ['technician', 'فني الرئيسي']] as const) {
      const em = `u6-${role}-${tag}@u.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, name, role, [main]]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (role === 'reception') R1 = u;
      else T1 = u;
    }

    // بيانات في فرع المعادي بكل الميزات (صاحب المحل شغال على فرع المعادي)
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash2], B2);
    const c = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل المعادي', $2)`, [c, phone()], B2);
    const dv = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A78', 'شحن')`, [dv, c], B2);
    // C4 المستعمل
    await as(O, `select buy_used_device($1, $2::jsonb, $3, $4::jsonb)`, [id(), JSON.stringify({ imei: imei(), brand: 'Apple', model: 'iPhone 13', buy_price: 900000, sale_price: 1100000 }), cash2, JSON.stringify({ name: 'بائع المعادي' })], B2);
    // C5 العمولات
    await as(O, `insert into commission_rules(shop_id, branch_id, mode, value) values (gen_random_uuid(), $1, 'fixed', 5000)`, [B2]);
    // C2 قوايم الفحص، وU5 الطابعات والقوالب
    await as(O, `insert into check_templates(shop_id, brand, branch_id, items) values (gen_random_uuid(), 'samsung', $1, '[{"key":"wifi"}]')`, [B2]);
    const pr = id();
    await as(O, `insert into printers(id, shop_id, branch_id, name, kind, width_mm, margin_mm) values ($1, gen_random_uuid(), $2, 'طابعة المعادي', 'thermal80', 80, 3)`, [pr, B2]);
    await as(O, `insert into print_templates(shop_id, doc, branch_id, printer_id, name, blocks, is_default) values (gen_random_uuid(), 'receipt', $1, $2, 'إيصال المعادي', '[]', true)`, [B2, pr]);
    // U3 الأهداف، وN خطة تقسيط، والشركاء
    await as(O, `insert into branch_goals(shop_id, branch_id, month, revenue_target) values (gen_random_uuid(), $1, date_trunc('month', now())::date, 5000000)`, [B2]).catch(() => undefined);
    const item = id();
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'تنظيف', 30000)`, [item]);
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 30000 }]), c], B2);
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), c, JSON.stringify([{ due: new Date(Date.now() + 5 * 86400_000).toISOString().slice(0, 10), amount: 30000 }])], B2);
    // صنف في مخزون المعادي (شراء بخزنة المعادي)
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد المعادي')`, [sup]);
    const acc = id();
    await as(O, `insert into items(id, shop_id, kind, name, sale_price, in_catalog) values ($1, gen_random_uuid(), 'accessory', 'جراب', 15000, true)`, [acc]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: acc, qty: 4, unit_cost: 5000 }]), cash2], B2);
    // C7 بوابة الجملة
    const wc = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'جملة المعادي', $2)`, [wc, phone()], B2);
    const tok = (await as(O, `select set_portal($1, true, $2) t`, [wc, B2], B2)).rows[0].t;
    await db.query(`select set_config('request.jwt.claims', '', false)`);
    await db.query('begin');
    await db.query('set local role anon');
    await db.query(`select portal_order($1, $2::jsonb)`, [tok, JSON.stringify([{ item: acc, qty: 1 }])]);
    await db.query('commit');
  }, 90_000);
  afterAll(async () => db?.end());

  it('كل جدول فيه فرع: موظف الرئيسي ما يشوفش أي صف من فرع المعادي (إلا قوالب وإعدادات الطباعة والفحص)', async () => {
    const tables = (
      await admin(`select c.table_name t from information_schema.columns c join information_schema.tables t using (table_schema, table_name)
        where c.table_schema = 'public' and c.column_name = 'branch_id' and t.table_type = 'BASE TABLE' order by 1`)
    ).rows.map((r) => r.t as string);
    expect(tables.length).toBeGreaterThanOrEqual(15);
    // المعادي فعلًا فيه بيانات في جداول كتير (عشان الاختبار يبقى ليه معنى)
    const withData: string[] = [];
    for (const t of tables) if ((await admin(`select 1 from public.${t} where shop_id = $1 and branch_id = $2 limit 1`, [shop, B2])).rowCount) withData.push(t);
    expect(withData.length, withData.join(',')).toBeGreaterThanOrEqual(12);
    const leaks: string[] = [];
    for (const who of [R1, T1]) {
      for (const t of tables) {
        if (SHARED_CONFIG.includes(t)) continue;
        const n = await as(who, `select count(*)::int n from public.${t} where branch_id = $1`, [B2])
          .then((r) => r.rows[0].n as number)
          .catch((e: Error) => (/permission denied/.test(e.message) ? 0 : Promise.reject(e)));
        if (n > 0) leaks.push(`${who === R1 ? 'reception' : 'technician'}:${t}=${n}`);
      }
    }
    expect(leaks).toEqual([]);
  });

  it('حتى لو الموظف بعت هيدر فرع المعادي: نفس النتيجة (الهيدر بيتجاهل)', async () => {
    for (const t of ['devices', 'used_devices', 'wholesale_orders', 'journal_entries', 'payment_plans', 'accounts']) {
      const n = await as(R1, `select count(*)::int n from public.${t} where branch_id = $1`, [B2], B2)
        .then((r) => r.rows[0].n as number)
        .catch(() => 0);
      expect(n, t).toBe(0);
    }
    expect((await as(R1, `select * from used_devices_list($1)`, [B2], B2).then((r) => r.rows).catch(() => []))).toEqual([]);
  });

  it('الفني: ما يشوفش أسعار المستعمل ولا العمولات ولا أرباح القطع ولا الأقساط', async () => {
    const tryRows = (sql: string, p: unknown[] = []) => as(T1, sql, p).then((r) => r.rows).catch((e: Error) => (/E_FORBIDDEN|E_ROLE|permission denied/.test(e.message) ? 'denied' : Promise.reject(e)));
    // المستعمل في فرعه: من غير سعر شرا ولا بيع ولا بيانات البائع
    await as(O, `select buy_used_device($1, $2::jsonb, (select id from accounts where shop_id = $3 and branch_id = $4 and method = 'cash'), $5::jsonb)`, [id(), JSON.stringify({ imei: imei(), brand: 'Apple', model: 'iPhone 11', buy_price: 600000, sale_price: 750000 }), shop, main, JSON.stringify({ name: 'بائع الرئيسي', phone: '01000000001' })], main);
    const used = await tryRows(`select * from used_devices_list()`);
    if (used !== 'denied') for (const r of used) for (const k of ['buy_price', 'sale_price', 'profit', 'seller_name', 'seller_phone']) expect(r[k] ?? null, k).toBeNull();
    const rules = await tryRows(`select * from commission_rules`);
    expect(rules === 'denied' || rules.length === 0).toBe(true);
    expect(await tryRows(`select * from parts_profit(now() - interval '30 days', now())`)).toBe('denied');
    const plans = await tryRows(`select * from payment_plans`);
    expect(plans === 'denied' || plans.length === 0).toBe(true);
    const feed = await tryRows(`select kind from notifications_feed()`);
    expect(feed === 'denied' || feed.every((r) => !['overdue', 'due_soon'].includes(r.kind))).toBe(true);
  });

  it('كل الدوال الجديدة اللي بترجع فلوس أو بيانات فرع: موظف الرئيسي ما ياخدش بيانات المعادي بتمرير الفرع', async () => {
    const tryRows = (sql: string, p: unknown[] = []) => as(R1, sql, p).then((r) => r.rows).catch(() => 'denied' as const);
    const used = await tryRows(`select * from used_devices_list($1)`, [B2]);
    expect(used === 'denied' || used.length === 0).toBe(true);
    const comm = await tryRows(`select * from commissions_report(now() - interval '1 day', now() + interval '1 day', $1)`, [B2]);
    expect(comm === 'denied' || comm.every((r) => Number(r.commission ?? 0) === 0)).toBe(true);
    const tb = await tryRows(`select sum(debit) d from trial_balance($1)`, [B2]);
    expect(tb === 'denied' || tb[0].d == null || Number(tb[0].d) === 0).toBe(true);
  });
});
