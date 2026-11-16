// المراجعة الأمنية الشاملة: بتلف على كل الجداول والدوال والملفات تلقائيًا، فأي جدول جديد بيتغطى لوحده
// - RLS على كل جدول، والعرض (view) بصلاحيات اللي بيقرا.
// - محل ما يشوفش أي صف من محل تاني في أي جدول، بأي دور.
// - Storage: كل bucket معزول بفولدر المحل.
// - الدوال العامة (من غير دخول) محددة بالاسم، ومرجّعة الحقول المتفق عليها بس، وعليها حد محاولات.
// - الفني والاستقبال ما يوصلوش للأرباح والأرصدة حتى من الـ API مباشرة.
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
async function as(uid: string | null, sql: string, params: unknown[] = [], ip = '10.77.0.1') {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': ip })]);
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
const PHONE = `0109${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
const id = () => randomUUID();
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@s.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}

let A = { owner: '', rec: '', tech: '', shop: '' };
let B = { owner: '', rec: '', tech: '', mkt: '', shop: '' };
let devA = '';
let tokenA = '';

async function makeShop(prefix: string, withStaff: boolean) {
  const owner = await user(`${prefix}-o-${tag}@sec.test`);
  const shop = (await as(owner, `select (bootstrap_account('صاحب', $1)).shop_id as s`, [`محل ${prefix}`])).rows[0].s as string;
  if (!withStaff) return { owner, shop, rec: '', tech: '', mkt: '' };
  return { owner, shop, rec: await staff(owner, `${prefix}rec`, 'reception'), tech: await staff(owner, `${prefix}tech`, 'technician'), mkt: await staff(owner, `${prefix}mkt`, 'marketing') };
}

d('المراجعة الأمنية الشاملة', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    const a = await makeShop('seca', true);
    A = { owner: a.owner, rec: a.rec, tech: a.tech, shop: a.shop };
    B = await makeShop('secb', true);
    // محل A فيه شغل في أغلب الجداول
    const cash = (await as(A.owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    const rent = (await as(A.owner, `select id from accounts where code = 'exp_rent'`)).rows[0].id;
    const cust = id();
    devA = id();
    const item = id();
    const sup = id();
    await as(A.rec, `insert into customers(id, shop_id, name, phone, marketing_ok) values ($1, gen_random_uuid(), 'عميل سري', $2, true)`, [cust, PHONE]);
    tokenA = (await as(A.rec, `insert into devices(id, customer_id, brand, model, issue, imei) values ($1, $2, 'Samsung', 'S23', 'شاشة', '356938035643809') returning tracking_token`, [devA, cust])).rows[0].tracking_token;
    await as(A.rec, `insert into device_costs(id, shop_id, device_id, estimated_cost) values ($1, gen_random_uuid(), $2, 50000)`, [id(), devA]);
    await as(A.rec, `insert into device_notes(id, shop_id, device_id, body) values ($1, gen_random_uuid(), $2, 'ملاحظة داخلية')`, [id(), devA]);
    await as(A.rec, `insert into device_checks(id, shop_id, device_id, stage, items) values ($1, gen_random_uuid(), $2, 'intake', '{"wifi":"ok"}')`, [id(), devA]);
    await as(A.rec, `insert into message_log(id, shop_id, device_id, customer_id, template_key, body) values ($1, gen_random_uuid(), $2, $3, 'received', 'رسالة')`, [id(), devA, cust]);
    await as(A.owner, `select owner_capital($1, $2, 500000)`, [id(), cash]);
    await as(A.owner, `select record_expense($1, $2, $3, 10000, 'إيجار')`, [id(), rent, cash]);
    await as(A.rec, `select record_payment($1, $2, $3, 20000, $4)`, [id(), cust, cash, devA]);
    await as(A.owner, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد سري')`, [sup]);
    await as(A.owner, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة S23')`, [item]);
    await as(A.owner, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 1, unit_cost: 30000 }])]);
    await as(A.owner, `insert into message_templates(id, shop_id, key, body) values ($1, gen_random_uuid(), 'received', 'قالب')`, [id()]);
    await as(A.owner, `insert into shop_branding(id, shop_id, tagline) values ($1, gen_random_uuid(), 'شعار')`, [id()]);
    await as(A.owner, `insert into issue_presets(id, shop_id, label, issue, est_cost) values ($1, gen_random_uuid(), 'شاشة', 'تغيير شاشة', 100000)`, [id()]);
    await as(A.owner, `insert into labor_rates(id, shop_id, issue, amount) values ($1, gen_random_uuid(), 'شاشة', 15000)`, [id()]);
    await as(A.owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'مدعو', 'reception')`, [`inv-${tag}@sec.test`]);
  });
  afterAll(async () => db?.end());

  it('RLS شغال على كل جدول، والعرض (view) بصلاحيات اللي بيقرا، والزائر ملوش أي جدول', async () => {
    const noRls = (await admin(`select relname from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity`)).rows;
    expect(noRls).toEqual([]);
    const views = (await admin(`select relname, coalesce(reloptions, '{}') as opts from pg_class where relnamespace = 'public'::regnamespace and relkind in ('v', 'm')`)).rows;
    for (const v of views) expect(v.opts, v.relname).toContain('security_invoker=true');
    const anonTables = (await admin(`select distinct table_name from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public'`)).rows;
    expect(anonTables).toEqual([]);
  });

  it('محل ما يشوفش أي صف من محل تاني في أي جدول فيه shop_id، بأي دور (صاحب محل، استقبال، فني، تسويق)', async () => {
    const tables = (await admin(`select c.table_name from information_schema.columns c join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
      where c.table_schema = 'public' and c.column_name = 'shop_id' and t.table_type in ('BASE TABLE', 'VIEW') order by 1`)).rows.map((r) => r.table_name as string);
    expect(tables.length).toBeGreaterThan(30);
    // محل A فعلًا فيه بيانات في جداول كتير (عشان الاختبار يبقى ليه معنى)
    let withData = 0;
    for (const t of tables) if ((await admin(`select 1 from public.${t} where shop_id = $1 limit 1`, [A.shop])).rowCount) withData++;
    expect(withData).toBeGreaterThanOrEqual(25);
    for (const who of [B.owner, B.rec, B.tech, B.mkt]) {
      for (const t of tables) {
        const r = await as(who, `select count(*)::int n from public.${t} where shop_id = $1`, [A.shop]).catch((e: Error) => {
          // جدول ممنوع خالص على الدور ده = تمام
          if (/permission denied/.test(e.message)) return { rows: [{ n: 0 }] };
          throw e;
        });
        expect(r.rows[0].n, `${t}`).toBe(0);
      }
    }
    // ولا كتابة في محل تاني (الصف بياخد محل المستخدم نفسه، أو بيترفض)
    await as(B.owner, `insert into customers(id, shop_id, name, phone) values ($1, $2, 'متسلل', '01011112222')`, [id(), A.shop]).catch(() => null);
    expect((await admin(`select count(*)::int n from customers where shop_id = $1 and name = 'متسلل'`, [A.shop])).rows[0].n).toBe(0);
    expect((await as(B.owner, `update devices set issue = 'اتغير' where id = $1 returning id`, [devA])).rowCount).toBe(0);
  });

  it('Storage: كل bucket معزول بفولدر المحل، ومحدش يقرا أو يرفع في فولدر محل تاني، والزائر ملوش حاجة', async () => {
    const buckets = (await admin(`select id from storage.buckets order by id`)).rows.map((r) => r.id as string);
    expect(buckets).toEqual(expect.arrayContaining(['device-photos', 'repair-videos', 'shop-logos']));
    for (const b of buckets) {
      await admin(`insert into storage.objects(bucket_id, name) values ($1, $2)`, [b, `${A.shop}/${id()}/sec-${tag}.bin`]);
      for (const who of [B.owner, B.rec, B.tech, B.mkt]) {
        const n = (await as(who, `select count(*)::int n from storage.objects where bucket_id = $1 and name like $2`, [b, `${A.shop}/%`])).rows[0].n;
        expect(n, `${b}`).toBe(0);
        await expect(as(who, `insert into storage.objects(bucket_id, name) values ($1, $2)`, [b, `${A.shop}/x/evil-${tag}.bin`]), `${b}`).rejects.toThrow();
      }
      // الزائر: يا ممنوع خالص، يا بيشوف صفر ملفات (حسب إعداد Supabase)، وفي الحالتين ما يوصلش لأي ملف
      const anon = await as(null, `select count(*)::int n from storage.objects where bucket_id = $1`, [b]).then((r) => r.rows[0].n, () => 0);
      expect(anon, `anon ${b}`).toBe(0);
      await expect(as(null, `insert into storage.objects(bucket_id, name) values ($1, $2)`, [b, `${A.shop}/x/anon-${tag}.bin`]), `anon upload ${b}`).rejects.toThrow();
    }
  });

  it('الدوال اللي الزائر يقدر يشغّلها محددة بالاسم بس (صفحة التتبع والتقييم، وأدوات حساب ما بتلمسش بيانات)', async () => {
    // دوال الإضافات (زي pgcrypto) مستثناة: دي مكتبات قياسية مش دوالنا
    const fns = (await admin(`select p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prorettype <> 'trigger'::regtype and has_function_privilege('anon', p.oid, 'execute')
      and not exists (select 1 from pg_depend dp where dp.objid = p.oid and dp.deptype = 'e') order by 1`)).rows.map((r) => r.proname as string);
    const allowed = ['account_sign', 'add_session_photo', 'catalog_image_allowed', 'current_app_role', 'current_shop_id', 'decide_quote', 'get_tracking', 'has_private_data', 'is_valid_transition', 'ledger_amount', 'ledger_issue_cost', 'ledger_line', 'photo_session', 'photo_upload_allowed', 'portal_order', 'public_app_brand', 'public_catalog', 'public_portal', 'rate_device', 'rating_state', 'track_photo_allowed', 'tracking_client_key', 'tracking_photos', 'valid_payment_methods'];
    expect(fns.filter((f) => !allowed.includes(f))).toEqual([]);
    // U4: رابط دخول المحل بيرجّع الاسم واللوجو واللون بس، ولا أي بيانات تانية
    const brand = (await as(null, `select public_app_brand($1) b`, [A.shop])).rows[0].b;
    expect(Object.keys(brand ?? {}).sort()).toEqual(['accent', 'logo', 'name']);
    // الدوال اللي بترجع حاجة للزائر من غير دخول ما بترجعش أي حاجة لو مش داخل
    expect((await as(null, `select current_shop_id() s, current_app_role() r`)).rows[0]).toEqual({ s: null, r: null });
  });

  it('صفحة التتبع بترجع الحقول المتفق عليها بس، من غير اسم العميل ولا رقمه ولا IMEI', async () => {
    const r = (await as(null, `select * from get_tracking(p_token => $1)`, [tokenA])).rows[0];
    expect(Object.keys(r).sort()).toEqual(['brand', 'can_decide', 'currency', 'decision', 'due', 'estimated_cost', 'final_cost', 'model', 'order_no', 'received_at', 'shop_logo', 'shop_name', 'shop_phone', 'status', 'technician', 'updated_at', 'warranty_until']);
    const text = JSON.stringify(r);
    for (const secret of ['عميل سري', PHONE, '356938035643809', 'ملاحظة داخلية']) expect(text).not.toContain(secret);
    const rs = (await as(null, `select rating_state($1) as s`, [tokenA])).rows[0].s;
    expect(Object.keys(rs).sort()).toEqual(['can_rate', 'stars']);
  });

  it('حد المحاولات على كل دوال الصفحة العامة: التتبع، والموافقة، والتقييم، وحالة التقييم', async () => {
    const ip = (n: number) => `10.90.${n}.${Math.floor(Math.random() * 200) + 1}`;
    const cases: [string, string][] = [
      ['get_tracking', `select * from get_tracking(p_token => $1)`],
      ['decide_quote', `select decide_quote('approved', p_token => $1)`],
      ['rate_device', `select rate_device($1, 5)`],
      ['rating_state', `select rating_state($1)`],
    ];
    let n = 1;
    for (const [name, sql] of cases) {
      const addr = ip(n++);
      for (let i = 0; i < 10; i++) await as(null, sql, [`bad-${name}-${i}-${tag}`], addr).catch(() => null);
      await expect(as(null, sql, [`bad-${name}-x-${tag}`], addr), name).rejects.toThrow(/E_RATE_LIMIT/);
    }
  });

  it('الفني والاستقبال ومدير التسويق ما يوصلوش للأرباح والأرصدة والنسخ الاحتياطي حتى من الـ API مباشرة', async () => {
    const cash = (await as(A.owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    const from = new Date(Date.now() - 86400e3).toISOString();
    const to = new Date(Date.now() + 86400e3).toISOString();
    const calls: [string, unknown[]][] = [
      [`select financial_position($1, $2)`, [from, to]],
      [`select * from pl_breakdown($1, $2)`, [from, to]],
      [`select * from cashbox_daily($1, $2)`, [from, to]],
      [`select * from party_balances('suppliers')`, []],
      [`select * from tech_report($1, $2)`, [from, to]],
      [`select export_backup()`, []],
      [`select * from list_backups()`, []],
      [`select plan_usage()`, []],
      [`select * from admin_shops()`, []],
      [`select owner_capital($1, $2, 100)`, [id(), cash]],
    ];
    for (const who of [A.rec, A.tech]) {
      for (const [sql, params] of calls) await expect(as(who, sql, params), sql).rejects.toThrow(/E_FORBIDDEN|permission denied|E_NO_SHOP/);
    }
    // مدير التسويق ملوش محل في الصلاحيات العادية خالص
    for (const [sql, params] of calls) await expect(as(B.mkt, sql, params), `mkt ${sql}`).rejects.toThrow(/E_FORBIDDEN|permission denied|E_NO_SHOP/);
    // جداول الفلوس المباشرة
    for (const t of ['journal_entries', 'journal_lines', 'drawer_closings', 'purchases', 'stock_moves']) {
      const n = await as(A.tech, `select count(*)::int n from ${t}`).then((r) => r.rows[0].n, () => 0);
      expect(n, `tech ${t}`).toBe(0);
    }
    // الاستقبال ما يشوفش غير خزنة الكاش (عشان تقفل الدرج)، ومن غير أرصدة
    const accs = (await as(A.rec, `select type from accounts`)).rows.map((r) => r.type);
    expect(new Set(accs)).toEqual(new Set(['asset']));
  });
});
