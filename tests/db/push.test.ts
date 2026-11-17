// Web Push (0058): الاشتراك لصاحبه بس، والإشعارات بصلاحيات كل مستخدم، ومرة واحدة بس، والتوقيت، وزرار "اتقرا"
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomBytes, randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';
import { windowOpen } from '../../src/lib/pushWindow';

cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function run(role: string, claims: object | null, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    if (claims) await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify(claims)]);
    await db.query(`set local role ${role}`);
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const as = (uid: string, sql: string, params: unknown[] = []) => run('authenticated', { sub: uid, role: 'authenticated' }, sql, params);
const anon = (sql: string, params: unknown[] = []) => run('anon', { role: 'anon' }, sql, params);
const service = (sql: string, params: unknown[] = []) => run('service_role', { role: 'service_role' }, sql, params);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const day = (n: number) => new Date(Date.now() + n * 86400_000).toISOString().slice(0, 10);
const b64 = (n: number) => randomBytes(n).toString('base64url');
const sub = () => ({ endpoint: `https://push.example.com/send/${b64(24)}`, p256dh: b64(65), auth: b64(16) });
const save = (uid: string, s: ReturnType<typeof sub>, locale = 'ar') =>
  as(uid, `select save_push_subscription($1, $2, $3, $4, 'test-agent') id`, [s.endpoint, s.p256dh, s.auth, locale]);
// الساعة 12 الضهر و11 بالليل بتوقيت القاهرة
const NOON = new Date(Date.now()).toISOString().slice(0, 10) + 'T12:00:00+02:00';
const NIGHT = new Date(Date.now()).toISOString().slice(0, 10) + 'T23:00:00+02:00';
const due = async (at = NOON) => (await service(`select * from push_due($1)`, [at])).rows;

d('Web Push', () => {
  let O = '';
  let R = '';
  let T = '';
  let shop = '';
  let cust = '';
  const sO = sub();
  const sR = sub();
  const sT = sub();

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`push-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الإشعارات')).shop_id s`)).rows[0].s;
    for (const [role, name] of [['reception', 'استقبال'], ['technician', 'فني']] as const) {
      const em = `push-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (role === 'reception') R = u;
      else T = u;
    }
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الإشعار', $2)`, [cust, `0108${String(Date.now()).slice(-7)}`]);
    const item = id();
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'خدمة', 50000)`, [item]);
    await as(O, `select record_sale($1, $2::jsonb, null, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 50000 }]), cust]);
    // قسط متأخر: إشعار لصاحب المحل بس (الاستقبال من غير صلاحية الوضع المالي، والفني لأ)
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(-3), amount: 50000 }])]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الاشتراك: بيانات سليمة بس، وصاحبه بس اللي يشوفه، والزائر ما يقدرش', async () => {
    for (const bad of [
      { ...sub(), endpoint: 'http://push.example.com/x' },
      { ...sub(), endpoint: 'https://localhost/x' },
      { ...sub(), endpoint: 'https://user@push.example.com/x' },
      { ...sub(), p256dh: 'abc' },
      { ...sub(), auth: 'a b c d e f g h i j k l m n' },
    ]) {
      await expect(save(O, bad)).rejects.toThrow(/E_BAD_INPUT/);
    }
    await expect(anon(`select save_push_subscription($1, $2, $3)`, [sO.endpoint, sO.p256dh, sO.auth])).rejects.toThrow(/permission denied/);
    await save(O, sO);
    await save(R, sR, 'en');
    await save(T, sT);
    expect((await as(O, `select endpoint, locale from push_subscriptions`)).rows).toEqual([{ endpoint: sO.endpoint, locale: 'ar' }]);
    expect((await as(R, `select endpoint, locale from push_subscriptions`)).rows).toEqual([{ endpoint: sR.endpoint, locale: 'en' }]);
    // الإرسال والنتيجة لمفتاح السيرفر بس
    await expect(as(O, `select * from push_due()`)).rejects.toThrow(/permission denied/);
    await expect(anon(`select push_result('[]'::jsonb)`)).rejects.toThrow(/permission denied/);
  });

  it('كل واحد بيوصله اللي في جرسه بصلاحياته بالظبط، ومرة واحدة بس', async () => {
    const rows = await due();
    const mine = rows.filter((r) => r.endpoint === sO.endpoint);
    expect(mine.map((r) => r.kind)).toContain('overdue');
    const od = mine.find((r) => r.kind === 'overdue')!;
    expect(od.args).toMatchObject({ name: 'عميل الإشعار', amount: 50000 });
    expect(od.link).toBe(`/finance/customer/${cust}`);
    expect(od.token).toMatch(/^[0-9a-f]{32}$/);
    expect(od).toMatchObject({ p256dh: sO.p256dh, auth: sO.auth, locale: 'ar' });
    // الاستقبال من غير صلاحية الوضع المالي والفني: ولا قسط ولا فلوس
    expect(rows.filter((r) => r.endpoint !== sO.endpoint && ['overdue', 'due_soon'].includes(r.kind))).toEqual([]);
    // المرة التانية: مفيش تكرار
    expect((await due()).filter((r) => r.endpoint === sO.endpoint && r.kind === 'overdue')).toEqual([]);
    // الدالة رجّعت الـ claims زي ما كانت (ما فضلش "داخل" باسم حد)
    const c = (await service(`select (select count(*) from push_due($1)) n, current_setting('request.jwt.claims', true) c`, [NOON])).rows[0].c;
    expect(c).toBe(JSON.stringify({ role: 'service_role' }));
  });

  it('التوقيت: برّه الوقت مفيش إرسال، والإشعار بيستنى لحد ما الوقت يفتح', async () => {
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(-1), amount: 1000 }])]);
    expect((await due(NIGHT)).filter((r) => r.endpoint === sO.endpoint)).toEqual([]);
    expect((await due(NOON)).filter((r) => r.endpoint === sO.endpoint && r.kind === 'overdue')).toHaveLength(1);
    // من 22 لـ 2 (بيعدّي نص الليل): 11 بالليل مفتوح، و12 الضهر مقفول
    await admin(`update shops set extras = jsonb_set(coalesce(extras, '{}'), '{reminders}', '{"push_from": 22, "push_to": 2}') where id = $1`, [shop]);
    expect((await admin(`select push_window_open($1, $2) a, push_window_open($1, $3) b`, [shop, NIGHT, NOON])).rows[0]).toEqual({ a: true, b: false });
    await admin(`update shops set extras = jsonb_set(extras, '{reminders}', '{"push_from": 0, "push_to": 24}') where id = $1`, [shop]);
    expect((await admin(`select push_window_open($1, $2) a, push_window_open($1, $3) b`, [shop, NIGHT, NOON])).rows[0]).toEqual({ a: true, b: true });
  });

  it('قواعد الوقت في قاعدة البيانات = نفس اللي في الواجهة (src/lib/pushWindow.ts) لكل الاحتمالات', async () => {
    for (let from = 0; from <= 24; from++) {
      for (let to = 0; to <= 24; to++) {
        await admin(`update shops set extras = jsonb_set(coalesce(extras, '{}'), '{reminders}', $2::jsonb) where id = $1`, [shop, JSON.stringify({ push_from: from, push_to: to })]);
        const got = (await admin(`select array_agg(push_window_open($1, (current_date + make_interval(hours => h)) at time zone 'Africa/Cairo') order by h) a from generate_series(0, 23) h`, [shop])).rows[0].a;
        expect(got, `${from}-${to}`).toEqual(Array.from({ length: 24 }, (_, h) => windowOpen({ from, to }, h)));
      }
    }
    await admin(`update shops set extras = jsonb_set(extras, '{reminders}', '{"push_from": 0, "push_to": 24}') where id = $1`, [shop]);
  });

  it('اللي اتقرا في البرنامج ما يتبعتش، وزرار "اتقرا" بيشتغل مرة واحدة بالـ token بس', async () => {
    const p = id();
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [p, cust, JSON.stringify([{ due: day(-5), amount: 2000 }])]);
    const fresh = (await as(O, `select key from notifications_feed() where not read and kind = 'overdue' and (args ->> 'amount')::int = 2000`)).rows.map((r) => r.key as string);
    expect(fresh).toHaveLength(1);
    await as(O, `select mark_notifications_read($1)`, [fresh]);
    expect((await due()).filter((r) => r.endpoint === sO.endpoint)).toEqual([]);

    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(-6), amount: 3000 }])]);
    const [x] = (await due()).filter((r) => r.endpoint === sO.endpoint);
    expect(x.kind).toBe('overdue');
    expect((await anon(`select push_ack($1) ok`, ['0'.repeat(32)])).rows[0].ok).toBe(false);
    expect((await anon(`select push_ack($1) ok`, ["' or 1=1 --"])).rows[0].ok).toBe(false);
    expect((await anon(`select push_ack($1) ok`, [x.token])).rows[0].ok).toBe(true);
    expect((await anon(`select push_ack($1) ok`, [x.token])).rows[0].ok).toBe(false);
    const feed = (await as(O, `select key, read from notifications_feed() where key = $1`, [x.key])).rows;
    expect(feed).toEqual([{ key: x.key, read: true }]);
    // الزائر ما يقدرش يقرا جدول الإرسال
    await expect(anon(`select count(*) from push_sent`)).rejects.toThrow(/permission denied/);
  });

  it('نتيجة الإرسال: 410 بيشيل الجهاز، و5 فشل ورا بعض بيشيله، والنجاح بيصفّر العدّاد', async () => {
    const a = sub();
    const b = sub();
    const ia = (await save(O, a)).rows[0].id;
    const ib = (await save(O, b)).rows[0].id;
    await service(`select push_result($1::jsonb)`, [JSON.stringify([{ sub_id: ia, status: 410 }])]);
    for (let i = 0; i < 4; i++) await service(`select push_result($1::jsonb)`, [JSON.stringify([{ sub_id: ib, status: 500 }])]);
    expect((await admin(`select fails, deleted_at is null alive from push_subscriptions where id = $1`, [ib])).rows[0]).toEqual({ fails: 4, alive: true });
    await service(`select push_result($1::jsonb)`, [JSON.stringify([{ sub_id: ib, status: 201 }])]);
    expect((await admin(`select fails, last_ok_at is not null ok from push_subscriptions where id = $1`, [ib])).rows[0]).toEqual({ fails: 0, ok: true });
    for (let i = 0; i < 5; i++) await service(`select push_result($1::jsonb)`, [JSON.stringify([{ sub_id: ib, status: 503 }])]);
    const alive = (await as(O, `select id from push_subscriptions`)).rows.map((r) => r.id);
    expect(alive).not.toContain(ia);
    expect(alive).not.toContain(ib);
    expect(alive).toContain((await admin(`select id from push_subscriptions where endpoint = $1`, [sO.endpoint])).rows[0].id);
  });

  it('نفس المتصفح دخل عليه مستخدم تاني: الاشتراك بينتقل له، والأول ما يوصلوش حاجة على الجهاز ده', async () => {
    const shared = sub();
    await save(O, shared);
    await save(R, shared);
    expect((await as(O, `select count(*)::int n from push_subscriptions where endpoint = $1`, [shared.endpoint])).rows[0].n).toBe(0);
    expect((await as(R, `select count(*)::int n from push_subscriptions where endpoint = $1`, [shared.endpoint])).rows[0].n).toBe(1);
    await as(O, `select save_plan($1, 'customer', $2, $3::jsonb)`, [id(), cust, JSON.stringify([{ due: day(-7), amount: 4000 }])]);
    expect((await due()).filter((r) => r.endpoint === shared.endpoint && r.kind === 'overdue')).toEqual([]);
    // الإلغاء من الجهاز
    await as(R, `select remove_push_subscription($1)`, [shared.endpoint]);
    expect((await as(R, `select count(*)::int n from push_subscriptions where endpoint = $1`, [shared.endpoint])).rows[0].n).toBe(0);
  });

  it('موظف اتقفل حسابه: ما يوصلوش أي إشعار', async () => {
    await admin(`update profiles set deleted_at = now() where id = $1`, [R]);
    const s = sub();
    await admin(`insert into push_subscriptions(shop_id, profile_id, endpoint, p256dh, auth) values ($1, $2, $3, $4, $5)`, [shop, R, s.endpoint, s.p256dh, s.auth]);
    expect((await due()).filter((r) => r.endpoint === s.endpoint)).toEqual([]);
  });
});
