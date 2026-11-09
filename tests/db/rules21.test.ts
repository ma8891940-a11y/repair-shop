// قواعد من المواصفات اتكمّلت في المراجعة الشاملة (migration 0021): ضمان لكل نوع عطل، والأرشفة والخصم الكبير لصاحب المحل
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

let owner = '';
let rec = '';
let cust = '';
let route = '';
let tech = '';

async function walkToDelivered(dev: string) {
  for (const s of ['inspecting', 'in_repair', 'repaired', 'ready', 'delivered']) await as(owner, `update devices set status = $2 where id = $1`, [dev, s]);
}

d('قواعد المواصفات (0021)', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`r21-o-${tag}@s.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل القواعد')`);
    rec = await staff(owner, 'استقبال', 'reception');
    tech = await staff(owner, 'فني', 'technician');
    cust = id();
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل القواعد', $2)`, [cust, PHONE]);
    await as(owner, `update shops set warranty_days = 30`);
    route = (await as(owner, `select id from routes where code = 'screen_battery'`)).rows[0]?.id;
    expect(route, 'مسار الشاشة والبطارية الافتراضي').toBeTruthy();
  });
  afterAll(async () => db?.end());

  it('الضمان لكل نوع عطل: مدة المسار لو متحددة، وإلا مدة ضمان المحل', async () => {
    await as(owner, `update routes set warranty_days = 90 where id = $1`, [route]);
    const a = id();
    const b = id();
    await as(rec, `insert into devices(id, customer_id, brand, model, issue, route_id) values ($1, $2, 'Samsung', 'A35', 'شاشة', $3)`, [a, cust, route]);
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A78', 'عطل تاني')`, [b, cust]);
    // الاستقبال ما يقدرش يغيّر مدة ضمان المسار (الإعدادات لصاحب المحل)
    expect((await as(rec, `update routes set warranty_days = 1 where id = $1 returning id`, [route])).rowCount).toBe(0);
    // التسليم محتاج تكلفة نهائية (قاعدة ثابتة)
    for (const dv of [a, b]) await as(owner, `insert into device_costs(id, shop_id, device_id, final_cost) values ($1, gen_random_uuid(), $2, 0)`, [id(), dv]);
    await walkToDelivered(a);
    await walkToDelivered(b);
    const rows = (await admin(`select id, warranty_days, round(extract(epoch from (warranty_until - now())) / 86400) as days from devices where id = any($1)`, [[a, b]])).rows;
    const by = Object.fromEntries(rows.map((r) => [r.id, r]));
    expect(by[a].warranty_days).toBe(90);
    expect(Number(by[a].days)).toBe(90);
    expect(by[b].warranty_days).toBe(30);
    expect(Number(by[b].days)).toBe(30);
  });

  it('أرشفة جهاز أو عميل: صاحب المحل بس، وبتتسجل في سجل النشاط', async () => {
    const dv = id();
    const c2 = id();
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Xiaomi', 'Note 12', 'سوفت وير')`, [dv, cust]);
    await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل للأرشفة', $2)`, [c2, `010${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`]);
    await expect(as(rec, `update devices set deleted_at = now() where id = $1`, [dv])).rejects.toThrow(/E_OWNER_APPROVAL/);
    await expect(as(rec, `update customers set deleted_at = now() where id = $1`, [c2])).rejects.toThrow(/E_OWNER_APPROVAL/);
    // الاستقبال بيعدّل باقي البيانات عادي
    await as(rec, `update customers set area = 'المعادي' where id = $1`, [c2]);
    await as(owner, `update devices set deleted_at = now() where id = $1`, [dv]);
    await as(owner, `update customers set deleted_at = now() where id = $1`, [c2]);
    const log = (await admin(`select count(*)::int n from audit_log where entity_id = $1 and after->>'deleted_at' is not null`, [dv])).rows[0].n;
    expect(log).toBeGreaterThanOrEqual(1);
  });

  it('خصم كبير: الاستقبال ما ينزّلش التكلفة عن التقديرية بأكتر من 20% (أو النسبة اللي صاحب المحل يحددها) من غير صاحب المحل', async () => {
    const dv = id();
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Realme', 'C55', 'مش بيشحن')`, [dv, cust]);
    await as(rec, `insert into device_costs(id, shop_id, device_id, estimated_cost) values ($1, gen_random_uuid(), $2, 100000)`, [id(), dv]);
    // لحد 20% خصم: مسموح للاستقبال
    await as(rec, `update device_costs set final_cost = 80000 where device_id = $1`, [dv]);
    // أكتر من 20%: محتاج صاحب المحل
    await expect(as(rec, `update device_costs set final_cost = 79999 where device_id = $1`, [dv])).rejects.toThrow(/E_OWNER_APPROVAL/);
    await expect(as(rec, `update device_costs set estimated_cost = 50000 where device_id = $1`, [dv])).rejects.toThrow(/E_OWNER_APPROVAL/);
    // الزيادة مسموحة عادي
    await as(rec, `update device_costs set final_cost = 150000 where device_id = $1`, [dv]);
    // صاحب المحل يقدر، ويقدر يغيّر النسبة، والاستقبال ما يقدرش يغيّرها
    await as(owner, `update device_costs set final_cost = 10000 where device_id = $1`, [dv]);
    expect((await as(rec, `update shops set max_discount_pct = 100 returning id`)).rowCount).toBe(0);
    await as(owner, `update shops set max_discount_pct = 50`);
    await as(rec, `update device_costs set final_cost = 60000 where device_id = $1`, [dv]);
    await expect(as(rec, `update device_costs set final_cost = 49999 where device_id = $1`, [dv])).rejects.toThrow(/E_OWNER_APPROVAL/);
    // كل تعديل سعر متسجل قبل وبعد
    const n = (await admin(`select count(*)::int n from audit_log where entity = 'device_costs' and action = 'update' and (after->>'device_id') = $1::text`, [dv])).rows[0].n;
    expect(n).toBeGreaterThanOrEqual(4);
  });

  it('تذكيرات تسويقية: العميل اللي وافق بس، وآخر جهاز اتسلّم من 6 شهور، ومرة واحدة لحد تسليم جديد', async () => {
    const yes = id();
    const no = id();
    const recent = id();
    const ph = () => `011${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
    await as(rec, `insert into customers(id, shop_id, name, phone, marketing_ok) values ($1, gen_random_uuid(), 'موافق', $2, true), ($3, gen_random_uuid(), 'مش موافق', $4, false), ($5, gen_random_uuid(), 'قريب', $6, true)`, [yes, ph(), no, ph(), recent, ph()]);
    const devs: Record<string, string> = {};
    for (const [c, days] of [[yes, 200], [no, 200], [recent, 30]] as const) {
      const dv = id();
      devs[c] = dv;
      await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A12', 'بطارية')`, [dv, c]);
      await as(owner, `insert into device_costs(id, shop_id, device_id, final_cost) values ($1, gen_random_uuid(), $2, 0)`, [id(), dv]);
      await walkToDelivered(dv);
      // نرجّع تاريخ التسليم لورا (بيانات اختبار)
      await admin('begin');
      await admin('set local session_replication_role = replica');
      await admin(`update devices set delivered_at = now() - make_interval(days => $2) where id = $1`, [dv, days]);
      await admin('commit');
    }
    const due = async () => (await as(rec, `select customer_id, device_id from marketing_due()`)).rows.map((r) => r.customer_id);
    const list = await due();
    expect(list).toContain(yes);
    expect(list).not.toContain(no);
    expect(list).not.toContain(recent);
    await expect(as(tech, `select * from marketing_due()`)).rejects.toThrow(/E_FORBIDDEN/);
    // بعد ما اتبعتله تذكير، ما يظهرش تاني
    await as(rec, `insert into message_log(id, shop_id, device_id, customer_id, template_key, body) values ($1, gen_random_uuid(), $2, $3, 'marketing', 'تذكير')`, [id(), devs[yes], yes]);
    expect(await due()).not.toContain(yes);
    // قالب التذكير التسويقي يتحفظ
    await as(owner, `insert into message_templates(id, shop_id, key, body) values ($1, gen_random_uuid(), 'marketing', 'أهلًا {name}')`, [id()]);
  });
});
