// المرحلة 6: مدير التسويق والفيديوهات، والتقييمات، والمجتمع، والخطط والحدود، ولوحة المشرف (migration 0017)
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
async function as(uid: string | null, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': '10.66.0.1' })]);
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
const tag = randomUUID().slice(0, 8);
const id = () => randomUUID();
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@g6.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}

let owner = '';
let shop = '';
let tech = '';
let mkt = '';
let other = '';
let plat = '';
let cust = '';
let dev = '';
let token = '';
const SHOP = `محل النمو ${tag}`;

d('المرحلة 6: النمو', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`g6o-${tag}@g6.test`);
    shop = (await as(owner, `select (bootstrap_account('صاحب', $1)).shop_id as s`, [SHOP])).rows[0].s;
    tech = await staff(owner, 'فني', 'technician');
    mkt = await staff(owner, 'تسويق', 'marketing');
    other = await user(`g6x-${tag}@g6.test`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني للنمو')`);
    plat = await user(`g6p-${tag}@g6.test`);
    await admin(`insert into platform_admins(user_id) values ($1)`, [plat]);
    cust = id();
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل النمو', '01077770000')`, [cust]);
    dev = id();
    token = (await as(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'شاشة') returning tracking_token`, [dev, cust])).rows[0].tracking_token;
  });
  afterAll(async () => db?.end());

  it('مدير التسويق ما يشوفش أي حاجة في المحل غير الفيديوهات', async () => {
    for (const t of ['devices', 'customers', 'device_costs', 'journal_lines', 'payments', 'device_notes', 'status_log', 'repair_steps', 'accounts', 'audit_log', 'shop_branding'])
      expect((await as(mkt, `select * from ${t}`)).rowCount, t).toBe(0);
    await expect(as(mkt, `select financial_position(now() - interval '1 day', now())`)).rejects.toThrow(/E_FORBIDDEN|E_NO_SHOP/);
    await expect(as(mkt, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'x', '01000000001')`, [id()])).rejects.toThrow();
    await expect(as(mkt, `select community_post($1, 'سؤال')`, [id()])).rejects.toThrow(/E_FORBIDDEN/);
    // حالة الحساب: دوره ومحله بس، من غير أي بيانات تانية
    const acc = (await as(mkt, `select my_account() as a`)).rows[0].a;
    expect(acc.profile).toMatchObject({ id: mkt, role: 'marketing' });
    expect(acc.shop).toMatchObject({ id: shop, suspended: false });
    expect(Object.keys(acc.shop).sort()).toEqual(['id', 'locale', 'name', 'suspended', 'theme']);
    await expect(as(null, `select my_account()`)).rejects.toThrow();
  });

  it('الفيديوهات: الفني بيرفع، ومدير التسويق بيراجع، والمقبول بيزوّد نقاط الفني', async () => {
    const v = id();
    await expect(as(tech, `select add_video($1, 'تغيير شاشة', $2)`, [id(), `not-my-shop/x.mp4`])).rejects.toThrow(/E_BAD_INPUT/);
    await expect(as(tech, `select add_video($1, 'رقم العميل 01012345678', $2)`, [id(), `${shop}/x.mp4`])).rejects.toThrow(/E_PRIVATE_DATA/);
    await as(tech, `select add_video($1, 'تغيير شاشة A54', $2, $3)`, [v, `${shop}/v1.mp4`, dev]);
    expect((await as(mkt, `select title, status from repair_videos`)).rows).toEqual([{ title: 'تغيير شاشة A54', status: 'pending' }]);
    await expect(as(tech, `select review_video($1, true, 10)`, [v])).rejects.toThrow(/E_FORBIDDEN/);
    await as(mkt, `select review_video($1, true, 15, 'ممتاز')`, [v]);
    const rep = (await as(owner, `select points from tech_report(now() - interval '1 day', now() + interval '1 day') where tech_id = $1`, [tech])).rows[0];
    expect(rep.points).toBe(15);
    // محل تاني ما يشوفش فيديوهات المحل ده
    expect((await as(other, `select * from repair_videos`)).rowCount).toBe(0);
  });

  it('تقييم العميل: بعد التسليم بس، مرة واحدة، ومن صفحة التتبع من غير تسجيل دخول', async () => {
    expect((await as(null, `select rating_state($1) as r`, [token])).rows[0].r).toEqual({ can_rate: false, stars: null });
    await expect(as(null, `select rate_device($1, 5)`, [token])).rejects.toThrow(/E_BAD_TRANSITION/);
    await as(owner, `update device_costs set final_cost = 0 where device_id = $1`, [dev]).then(async (r) => {
      if (!r.rowCount) await as(owner, `insert into device_costs(id, shop_id, device_id, final_cost) values ($1, gen_random_uuid(), $2, 0)`, [id(), dev]);
    });
    for (const s of ['inspecting', 'in_repair', 'repaired', 'ready', 'delivered']) await as(owner, `update devices set status = $2 where id = $1`, [dev, s]);
    expect((await as(null, `select rating_state($1) as r`, [token])).rows[0].r).toEqual({ can_rate: true, stars: null });
    await expect(as(null, `select rate_device($1, 7)`, [token])).rejects.toThrow(/E_BAD_INPUT/);
    await as(null, `select rate_device($1, 4, 'شغل نضيف')`, [token]);
    await expect(as(null, `select rate_device($1, 1)`, [token])).rejects.toThrow(/E_ALREADY_RATED/);
    expect((await as(null, `select rating_state($1) as r`, [token])).rows[0].r).toEqual({ can_rate: false, stars: 4 });
    expect((await as(owner, `select stars, comment from device_ratings`)).rows).toEqual([{ stars: 4, comment: 'شغل نضيف' }]);
    expect((await as(tech, `select * from device_ratings`)).rowCount).toBe(0);
    await expect(admin(`update device_ratings set stars = 5 where device_id = $1`, [dev])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
  });

  it('المجتمع: مشترك بين المحلات، ومن غير بيانات عملاء، والمشرف بيخفي المنشور المبلّغ عنه', async () => {
    const p = id();
    await as(tech, `select community_post($1, 'إزاي أعرف إن الـ IC بايظ؟', 'سؤال عن IC')`, [p]);
    await expect(as(tech, `select community_post($1, 'كلمني 01012345678')`, [id()])).rejects.toThrow(/E_PRIVATE_DATA/);
    await expect(as(tech, `select community_post($1, 'IMEI 490154203237518')`, [id()])).rejects.toThrow(/E_PRIVATE_DATA/);
    // محل تاني بيشوفه ويرد
    const feed = (await as(other, `select id, author, shop from community_feed()`)).rows.find((r) => r.id === p);
    expect(feed).toEqual({ id: p, author: 'فني', shop: SHOP });
    await as(other, `select community_post($1, 'جرّب تقيس الجهد', null, $2)`, [id(), p]);
    expect((await as(tech, `select replies from community_feed() where id = $1`, [p])).rows[0].replies).toBe(1);
    // بلاغ ومراجعة
    await as(other, `select community_report($1, 'إعلان')`, [p]);
    await expect(as(owner, `select * from admin_reports()`)).rejects.toThrow(/E_FORBIDDEN/);
    const reps = (await as(plat, `select post_id, reports from admin_reports()`)).rows;
    expect(reps).toContainEqual({ post_id: p, reports: 1 });
    await as(plat, `select admin_moderate($1, true)`, [p]);
    expect((await as(other, `select id from community_feed() where id = $1`, [p])).rowCount).toBe(0);
    expect((await as(tech, `select hidden from community_feed() where id = $1`, [p])).rows[0].hidden).toBe(true); // الكاتب بيشوفه مخفي
    // محدش يكتب في الجدول مباشرة
    await expect(as(tech, `insert into community_posts(id, shop_id, author_id, body) values ($1, $2, $3, 'x')`, [id(), shop, tech])).rejects.toThrow(/permission denied/);
  });

  it('الخطط والحدود: الحد بيتطبق في القاعدة، وصاحب المحل ما يغيّرش خطته', async () => {
    await admin(`insert into plans(code, max_devices_month, max_staff, ai_daily, max_videos) values ('tiny-${tag}', 1, 3, 1, 1) on conflict do nothing`);
    await expect(as(owner, `update shops set plan_code = 'pro'`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(owner, `select admin_set_plan($1, 'pro')`, [shop])).rejects.toThrow(/E_FORBIDDEN/);
    await as(plat, `select admin_set_plan($1, $2)`, [shop, `tiny-${tag}`]);
    const u = (await as(owner, `select plan_usage() as u`)).rows[0].u;
    expect(u).toMatchObject({ plan: `tiny-${tag}`, max_devices_month: 1, devices_month: 1, staff: 3 });
    await expect(as(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'c')`, [id(), cust])).rejects.toThrow(/E_PLAN_LIMIT/);
    await expect(as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'x', 'technician')`, [`more-${tag}@g6.test`])).rejects.toThrow(/E_PLAN_LIMIT/);
    await expect(as(tech, `select add_video($1, 'تاني', $2)`, [id(), `${shop}/v2.mp4`])).rejects.toThrow(/E_PLAN_LIMIT/);
    // المساعد الذكي: سؤال واحد في اليوم
    expect((await as(tech, `select ai_take() as r`)).rows[0].r).toEqual({ left: 0 });
    await expect(as(tech, `select ai_take()`)).rejects.toThrow(/E_PLAN_LIMIT/);
    await expect(as(mkt, `select ai_take()`)).rejects.toThrow(/E_FORBIDDEN/);
    await as(plat, `select admin_set_plan($1, 'pro')`, [shop]);
    await as(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'c')`, [id(), cust]);
  });

  it('لوحة المشرف: المحلات واستخدامها من غير بيانات عملاء، والإيقاف بيقفل المحل كله', async () => {
    await expect(as(owner, `select * from admin_shops()`)).rejects.toThrow(/E_FORBIDDEN/);
    // بحث بالاسم، وصفحات (أقصى 200 في الصفحة)، والعدد الكلي للنتايج
    const rows = (await as(plat, `select * from admin_shops($1)`, [tag])).rows;
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ id: shop, name: SHOP, plan: 'pro', suspended: false, staff: 3, total: 1 });
    // التقسيم لصفحات محتاج 3 محلات على الأقل: الملف بيعمل التالت بنفسه (ما يعتمدش على داتا قديمة في القاعدة)
    const third = await user(`g6-third-${tag}@g6.test`);
    await as(third, `select bootstrap_account('تالت', 'محل تالت للنمو')`);
    const all = (await as(plat, `select id, total from admin_shops(null, 2, 0)`)).rows;
    expect(all).toHaveLength(2);
    expect(all[0].total).toBeGreaterThanOrEqual(3);
    const next = (await as(plat, `select id from admin_shops(null, 2, 2)`)).rows;
    expect(next.map((r) => r.id)).not.toContain(all[0].id);
    expect((await as(plat, `select count(*)::int n from admin_shops(null, 100000, 0)`)).rows[0].n).toBeLessThanOrEqual(200);
    // علامات البحث (% و _) بتتعامل كحروف عادية، مش كأي حاجة
    expect((await as(plat, `select * from admin_shops('%%%')`)).rowCount).toBe(0);
    const cols = Object.keys(rows[0]);
    for (const c of ['phone', 'customer', 'customers', 'email']) expect(cols).not.toContain(c);
    // المشرف نفسه ما يشوفش بيانات المحلات
    expect((await as(plat, `select * from customers`)).rowCount).toBe(0);
    await as(plat, `select admin_suspend($1, true)`, [shop]);
    expect((await as(owner, `select * from devices`)).rowCount).toBe(0);
    await expect(as(owner, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'a', 'b', 'c')`, [id(), cust])).rejects.toThrow();
    // الواجهة بتعرف إن المحل موقوف (عشان تعرض رسالة واضحة بدل شاشة الانضمام)
    const acc = (await as(owner, `select my_account() as a`)).rows[0].a;
    expect(acc).toMatchObject({ shop: { name: SHOP, suspended: true }, profile: { role: 'owner' }, is_admin: false });
    await as(plat, `select admin_suspend($1, false)`, [shop]);
    expect((await as(owner, `select * from devices`)).rowCount).toBeGreaterThan(0);
    const log = (await admin(`select action from audit_log where shop_id = $1 and action like 'admin_%' order by created_at`, [shop])).rows.map((r) => r.action);
    expect(log).toEqual(expect.arrayContaining(['admin_set_plan', 'admin_suspend', 'admin_unsuspend']));
  });
});
