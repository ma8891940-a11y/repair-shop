// المرحلة 4: الفنيون وتوزيع الشغل (migration 0014)
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
const tag = randomUUID().slice(0, 8);
const id = () => randomUUID();
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@t4.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}
const CHECK = JSON.stringify({ wifi: 'ok', charging: 'ok', screen_touch: 'ok' });

let owner = '';
let rec = '';
let techA = ''; // فك وتركيب
let techM = ''; // ميكروسكوب
let techS = ''; // سوفت وير
let cust = '';
const spec: Record<string, string> = {};
const route: Record<string, string> = {};

async function newDevice(issue: string, brand = 'Samsung', priority = 'normal') {
  const dev = id();
  await as(rec, `insert into devices(id, customer_id, brand, model, issue, priority) values ($1, $2, $3, 'A54', $4, $5)`, [dev, cust, brand, issue, priority]);
  const r = (await as(rec, `select detect_route($1) as r`, [issue])).rows[0].r;
  await as(rec, `select set_route($1, $2)`, [dev, r]);
  return dev;
}
const steps = async (dev: string) =>
  (await admin(`select id, step_no, technician_id, status from repair_steps where device_id = $1 order by step_no`, [dev])).rows as { id: string; step_no: number; technician_id: string | null; status: string }[];
const status = async (dev: string) => (await admin(`select status::text from devices where id = $1`, [dev])).rows[0].status;

d('المرحلة 4: الفنيون', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`t4-o-${tag}@t4.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل الفنيين')`);
    rec = await staff(owner, 'استقبال', 'reception');
    techA = await staff(owner, 'أحمد فك', 'technician');
    techM = await staff(owner, 'محمد ميكرو', 'technician');
    techS = await staff(owner, 'سامي سوفت', 'technician');
    for (const r of (await as(owner, `select id, code from specialties`)).rows) spec[r.code] = r.id;
    for (const r of (await as(owner, `select id, code from routes`)).rows) route[r.code] = r.id;
    for (const [t, c] of [[techA, 'assembly'], [techM, 'micro'], [techS, 'software']])
      await as(owner, `insert into staff_specialties(id, shop_id, profile_id, specialty_id) values ($1, gen_random_uuid(), $2, $3)`, [id(), t, spec[c]]);
    cust = id();
    await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', '01012340000')`, [cust]);
  });
  afterAll(async () => db?.end());

  it('كل محل جديد بياخد 3 تخصصات و4 مسارات من المواصفات، وصاحب المحل بس يعدّلهم', async () => {
    expect(Object.keys(spec).sort()).toEqual(['assembly', 'micro', 'software']);
    expect(Object.keys(route).sort()).toEqual(['board', 'screen_battery', 'software', 'unknown']);
    const b = (await as(owner, `select steps from routes where code = 'board'`)).rows[0].steps;
    expect(b).toEqual([spec.assembly, spec.micro, spec.assembly]);
    await expect(as(rec, `update routes set sort = 1 where code = 'board'`)).resolves.toMatchObject({ rowCount: 0 });
    await expect(as(techA, `insert into specialties(id, shop_id, name) values ($1, gen_random_uuid(), 'x')`, [id()])).rejects.toThrow();
  });

  it('المسار بيتحدد من وصف العطل', async () => {
    const r = async (issue: string) => (await as(rec, `select code from routes where id = detect_route($1)`, [issue])).rows[0].code;
    expect(await r('شاشة مكسورة')).toBe('screen_battery');
    expect(await r('البطارية بتفصل')).toBe('screen_battery');
    expect(await r('مش بيشحن خالص')).toBe('board');
    expect(await r('محتاج سوفت وير')).toBe('software');
    expect(await r('حاجة غريبة')).toBe('unknown');
  });

  it('مسار IC: فك ← ميكروسكوب ← نفس الفني اللي فك يركّب ويقفل بفحص نهائي، والجهاز بيبقى جاهز', async () => {
    const dev = await newDevice('IC شحن');
    let s = await steps(dev);
    expect(s.map((x) => x.technician_id)).toEqual([techA, null, null]);
    // الفني التاني ما يشوفش الجهاز لسه، ولا يقدر يبدأ خطوة مش بتاعته
    expect((await as(techM, `select id from devices where id = $1`, [dev])).rowCount).toBe(0);
    expect((await as(techS, `select * from my_queue()`)).rowCount).toBe(0);
    await expect(as(techM, `select start_step($1)`, [s[0].id])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(techA, `select start_step($1)`, [s[1].id])).rejects.toThrow(/E_FORBIDDEN|E_STEP_ORDER/);
    await as(techA, `select start_step($1)`, [s[0].id]);
    expect(await status(dev)).toBe('inspecting');
    const f1 = (await as(techA, `select finish_step($1) as r`, [s[0].id])).rows[0].r;
    expect(f1).toMatchObject({ next_tech: techM, ready: false });
    expect((await as(techM, `select order_no from my_queue()`)).rowCount).toBe(1);
    await as(techM, `select start_step($1)`, [s[1].id]);
    expect(await status(dev)).toBe('in_repair');
    await as(techM, `select finish_step($1)`, [s[1].id]);
    s = await steps(dev);
    expect(s[2].technician_id).toBe(techA); // اللي فك هو اللي يركّب
    await as(techA, `select start_step($1)`, [s[2].id]);
    await expect(as(techA, `select finish_step($1)`, [s[2].id])).rejects.toThrow(/E_FINAL_CHECK_REQUIRED/);
    const f3 = (await as(techA, `select finish_step($1, $2::jsonb) as r`, [s[2].id, CHECK])).rows[0].r;
    expect(f3).toMatchObject({ ready: true });
    expect(await status(dev)).toBe('ready');
    const ck = (await admin(`select items from device_checks where device_id = $1 and stage = 'delivery'`, [dev])).rows[0].items;
    expect(ck).toEqual(JSON.parse(CHECK));
    // كل خطوة ليها وقت بداية ونهاية
    for (const x of (await admin(`select started_at, finished_at from repair_steps where device_id = $1`, [dev])).rows) {
      expect(x.started_at).toBeInstanceOf(Date);
      expect(x.finished_at).toBeInstanceOf(Date);
    }
  });

  it('الفني ما يبدأش ولا يكمّل والجهاز مستني موافقة العميل', async () => {
    const dev = await newDevice('شاشة');
    const [s] = await steps(dev);
    await as(techA, `select start_step($1)`, [s.id]);
    await as(rec, `update devices set status = 'awaiting_approval' where id = $1`, [dev]);
    await expect(as(techA, `select finish_step($1, $2::jsonb)`, [s.id, CHECK])).rejects.toThrow(/E_AWAITING_APPROVAL/);
    const dev2 = await newDevice('شاشة');
    await as(rec, `update devices set status = 'inspecting' where id = $1`, [dev2]);
    await as(rec, `update devices set status = 'awaiting_approval' where id = $1`, [dev2]);
    await expect(as(techA, `select start_step($1)`, [(await steps(dev2))[0].id])).rejects.toThrow(/E_AWAITING_APPROVAL/);
  });

  it('عطل غير معروف: فني الفك بيفحص ويحدد المسار، والجهاز بيروح لفني السوفت وير', async () => {
    const dev = await newDevice('حاجة غريبة');
    const [s] = await steps(dev);
    expect(s.technician_id).toBe(techA);
    await as(techA, `select start_step($1)`, [s.id]);
    await expect(as(techA, `select finish_step($1)`, [s.id])).rejects.toThrow(/E_ROUTE_REQUIRED/);
    const r = (await as(techA, `select finish_step($1, null, $2) as r`, [s.id, route.software])).rows[0].r;
    expect(r.next_tech).toBe(techS);
    expect((await admin(`select route_id from devices where id = $1`, [dev])).rows[0].route_id).toBe(route.software);
    expect((await as(techS, `select device_id from my_queue()`)).rows.map((x) => x.device_id)).toContain(dev);
    // فني تاني ما يقدرش يغيّر المسار
    await expect(as(techM, `select set_route($1, $2)`, [dev, route.board])).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('قائمة الفني: بالأولوية (عاجل، ضمان، عادي) ثم بتاريخ الاستلام، والمتأخر متعلّم', async () => {
    const n1 = await newDevice('شاشة رقم 1');
    const u = await newDevice('شاشة عاجلة', 'Samsung', 'urgent');
    const n2 = await newDevice('شاشة رقم 2');
    await admin(`update devices set est_minutes = 1 where id = $1`, [n2]);
    await admin(`update devices set received_at = received_at - interval '1 hour' where id = $1`, [n2]).catch(() => null);
    const q = (await as(techA, `select device_id, priority, late from my_queue()`)).rows.filter((r) => [n1, u, n2].includes(r.device_id));
    expect(q[0].device_id).toBe(u);
    expect(q.map((r) => r.device_id).indexOf(n1)).toBeLessThan(q.map((r) => r.device_id).indexOf(n2));
    // ومن غير أسعار ولا بيانات عملاء
    const cols = (await as(techA, `select * from my_queue() limit 1`)).fields.map((f) => f.name);
    for (const c of ['customer_name', 'phone', 'final_cost', 'estimated_cost']) expect(cols).not.toContain(c);
  });

  it('مرتجع الضمان بيرجع لنفس الفني اللي قفله بأولوية ضمان، وبيتحسب عليه في التقرير', async () => {
    const dev = await newDevice('بطارية');
    const [s] = await steps(dev);
    await as(techA, `select start_step($1)`, [s.id]);
    await as(techA, `select finish_step($1, $2::jsonb)`, [s.id, CHECK]);
    await as(owner, `update device_costs set final_cost = 50000 where device_id = $1`, [dev]).then(async (r) => {
      if (r.rowCount === 0) await as(owner, `insert into device_costs(id, shop_id, device_id, final_cost) values ($1, gen_random_uuid(), $2, 50000)`, [id(), dev]);
    });
    await as(rec, `select record_payment($1, $2, (select id from accounts where code = 'cash_cash'), 50000, $3)`, [id(), cust, dev]);
    await as(rec, `update devices set status = 'delivered' where id = $1`, [dev]);
    await as(rec, `update devices set status = 'warranty_return' where id = $1`, [dev]);
    const dv = (await admin(`select priority, return_of_tech from devices where id = $1`, [dev])).rows[0];
    expect(dv).toEqual({ priority: 'warranty', return_of_tech: techA });
    const last = (await steps(dev)).at(-1)!;
    expect(last).toMatchObject({ technician_id: techA, status: 'pending' });
    const rep = (await as(owner, `select * from tech_report(now() - interval '1 day', now() + interval '1 day') where tech_id = $1`, [techA])).rows[0];
    expect(rep.returns).toBeGreaterThanOrEqual(1);
    expect(rep.devices).toBeGreaterThanOrEqual(2);
    expect(Number(rep.revenue)).toBeGreaterThanOrEqual(50000);
    await expect(as(rec, `select * from tech_report(now() - interval '1 day', now())`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(techA, `select * from issue_report(now() - interval '1 day', now())`)).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('تقدير الوقت: لو فيه 5 أجهزة مشابهة أو أكتر بيقترح المتوسط، ولو أقل ما بيقترحش', async () => {
    const brand = `Brand${tag}`;
    const est = async () => (await as(rec, `select estimate_minutes($1, $2) as e`, [brand, route.software])).rows[0].e;
    for (let i = 0; i < 5; i++) {
      const dev = await newDevice('سوفت وير', brand);
      const [s] = await steps(dev);
      await as(techS, `select start_step($1)`, [s.id]);
      await admin(`update repair_steps set started_at = now() - make_interval(mins => $2) where id = $1`, [s.id, 30 + i * 10]);
      await as(techS, `select finish_step($1, $2::jsonb)`, [s.id, CHECK]);
      if (i === 3) expect(await est()).toEqual({ n: 4, minutes: null });
    }
    expect(await est()).toEqual({ n: 5, minutes: 50 }); // (30 + 40 + 50 + 60 + 70) / 5
  });

  it('محل فيه فني واحد من غير تخصصات: بياخد كل الخطوات (فني عام)', async () => {
    const o = await user(`t4-solo-${tag}@t4.test`);
    await as(o, `select bootstrap_account('صاحب', 'محل صغير')`);
    const t = await staff(o, `فني-وحيد`, 'technician');
    const c = id();
    await as(o, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'ع', '01012349999')`, [c]);
    const dev = id();
    await as(o, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'IC شبكة')`, [dev, c]);
    await as(o, `select set_route($1, detect_route('IC شبكة'))`, [dev]);
    expect((await steps(dev))[0].technician_id).toBe(t);
    expect((await as(t, `select id from devices where id = $1`, [dev])).rowCount).toBe(1);
    const [s1] = await steps(dev);
    await as(t, `select start_step($1)`, [s1.id]);
    const r = (await as(t, `select finish_step($1) as r`, [s1.id])).rows[0].r;
    expect(r.next_tech).toBe(t);
  });

  it('الأجهزة اللي ملهاش مسار لسه ظاهرة لكل الفنيين (زي المرحلة 1)', async () => {
    const dev = id();
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'z')`, [dev, cust]);
    expect((await as(techM, `select id from devices where id = $1`, [dev])).rowCount).toBe(1);
  });

  it('الرسايل باسم الفني الحالي (الاسم الأول بس)', async () => {
    const dev = await newDevice('IC شبكة');
    expect((await as(rec, `select device_tech_name($1) as n`, [dev])).rows[0].n).toBe('أحمد');
  });
});
