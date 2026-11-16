// C3: كلمة السر الرئيسية للعمليات الحساسة
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

async function staff(email: string, role: string) {
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'موظف', $2)`, [email, role]);
  const u = await user(email);
  await as(u, `select bootstrap_account('موظف')`);
  return u;
}
const pay = async (uid: string, amount: number) => {
  const c = randomUUID();
  await as(uid, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [c, `0102${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`]);
  return (await as<{ e: string }>(uid, `select record_payment($1, $2, $3, $4) e`, [randomUUID(), c, cash, amount])).rows[0].e;
};

d('C3: كلمة السر الرئيسية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    owner = await user(`om-${tag}@t.test`);
    other = await user(`xm-${tag}@t.test`);
    await as(owner, `select bootstrap_account('صاحب', 'محل السر')`);
    await as(other, `select bootstrap_account('تاني', 'محل تاني')`);
    rec = await staff(`rm-${tag}@t.test`, 'reception');
    await as(owner, `select set_can_correct($1, true)`, [rec]);
    cash = (await as(owner, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
  });
  afterAll(async () => db?.end());

  it('من غير كلمة: كل حاجة زي الأول', async () => {
    expect((await as(owner, `select has_master_password() h`)).rows[0].h).toBe(false);
    const e = await pay(owner, 1000);
    await as(owner, `select reverse_entry($1, 'غلط')`, [e]);
  });

  it('صاحب المحل بس يحدد الكلمة، ومحدش يقدر يقراها، وهي hash', async () => {
    await expect(as(rec, `select set_master_password(null, 'secret99')`)).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await expect(as(owner, `select set_master_password(null, '123')`)).rejects.toThrow(/E_MASTER_SHORT/);
    await as(owner, `select set_master_password(null, 'secret99')`);
    expect((await as(rec, `select has_master_password() h`)).rows[0].h).toBe(true);
    expect((await as(other, `select has_master_password() h`)).rows[0].h).toBe(false);
    // الجدول مقفول على الكل
    await expect(as(owner, `select * from shop_secrets`)).rejects.toThrow(/permission denied/);
    await expect(as(owner, `select * from master_attempts`)).rejects.toThrow(/permission denied/);
    const h = (await db.query(`select master_hash from shop_secrets s join profiles p on p.shop_id = s.shop_id where p.id = $1`, [owner])).rows[0].master_hash as string;
    expect(h).toMatch(/^\$2[abxy]?\$/);
    expect(h).not.toContain('secret99');
    // التغيير محتاج القديمة صح، والسجل من غير الكلمة
    expect((await as(owner, `select set_master_password('wrong', 'other123') r`)).rows[0].r).toBe('wrong');
    const log = (await as(owner, `select action, after from audit_log where action like 'master_%'`)).rows;
    expect(log.map((r) => r.action)).toEqual(['master_set']);
    expect(JSON.stringify(log)).not.toContain('secret99');
  });

  it('العكس والحذف والخصم الكبير محتاجين الكلمة (حتى لصاحب المحل)، والفتح 5 دقايق لحساب اللي كتبها بس', async () => {
    const e = await pay(rec, 2000);
    await expect(as(rec, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_MASTER_REQUIRED/);
    await expect(as(owner, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_MASTER_REQUIRED/);
    expect((await as(rec, `select verify_master('nope') v`)).rows[0].v).toEqual({ status: 'wrong' });
    const v = (await as(rec, `select verify_master('secret99') v`)).rows[0].v as { status: string; until: string };
    expect(v.status).toBe('ok');
    expect(new Date(v.until).getTime() - Date.now()).toBeGreaterThan(4 * 60_000);
    await as(rec, `select reverse_entry($1, 'غلط')`, [e]);
    // صاحب المحل لسه محتاج يكتبها بنفسه
    const e2 = await pay(owner, 3000);
    await expect(as(owner, `select reverse_entry($1, 'غلط')`, [e2])).rejects.toThrow(/E_MASTER_REQUIRED/);
    // الحذف
    const c = randomUUID();
    await as(owner, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'للحذف', '01155550000')`, [c]);
    await expect(as(owner, `select soft_delete('customer', $1, 'مكرر')`, [c])).rejects.toThrow(/E_MASTER_REQUIRED/);
    await as(owner, `select verify_master('secret99')`);
    await as(owner, `select soft_delete('customer', $1, 'مكرر')`, [c]);
    await as(owner, `select reverse_entry($1, 'غلط')`, [e2]);
    // الفتح بينتهي
    await db.query(`update master_unlocks set expires_at = now() - interval '1 second'`);
    const e3 = await pay(owner, 4000);
    await expect(as(owner, `select reverse_entry($1, 'غلط')`, [e3])).rejects.toThrow(/E_MASTER_REQUIRED/);
  });

  it('الخصم الكبير عن التقديرية: الاستقبال بالكلمة بدل صاحب المحل', async () => {
    const c = randomUUID();
    const dv = randomUUID();
    await as(rec, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'خصم', '01166660000')`, [c]);
    await as(rec, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A5', 'شحن')`, [dv, c]);
    await as(rec, `insert into device_costs(shop_id, device_id, estimated_cost) values (gen_random_uuid(), $1, 100000)`, [dv]);
    await expect(as(rec, `update device_costs set final_cost = 50000 where device_id = $1`, [dv])).rejects.toThrow(/E_MASTER_REQUIRED/);
    await as(rec, `update device_costs set final_cost = 95000 where device_id = $1`, [dv]);
    await as(rec, `select verify_master('secret99')`);
    await as(rec, `update device_costs set final_cost = 50000 where device_id = $1`, [dv]);
  });

  it('5 محاولات غلط في ربع ساعة بتقفل حتى الكلمة الصح، وشيل الكلمة بيرجّع كل حاجة زي الأول', async () => {
    // (فيه محاولة غلط واحدة من الاختبار اللي فات)
    for (let i = 0; i < 4; i++) expect((await as(rec, `select verify_master('bad') v`)).rows[0].v).toEqual({ status: 'wrong' });
    await expect(as(rec, `select verify_master('secret99')`)).rejects.toThrow(/E_MASTER_LOCKED/);
    // صاحب المحل مش مقفول (المحاولات لكل مستخدم)
    expect((await as(owner, `select set_master_password('secret99', '') r`)).rows[0].r).toBe('removed');
    expect((await as(owner, `select has_master_password() h`)).rows[0].h).toBe(false);
    const e = await pay(rec, 5000);
    await as(rec, `select reverse_entry($1, 'غلط')`, [e]);
  });

  it('2FA: الحساب اللي فعّله ما يوصلش للبيانات إلا بعد الخطوة التانية (aal2)، والباقيين زي الأول', async () => {
    const claims = (aal: string) => JSON.stringify({ sub: owner, role: 'authenticated', aal });
    const q = async (aal: string) => {
      await db.query('begin');
      try {
        await db.query(`select set_config('request.jwt.claims', $1, true)`, [claims(aal)]);
        await db.query('set local role authenticated');
        return (await db.query(`select current_shop_id() s, (select count(*)::int from accounts) n`)).rows[0];
      } finally {
        await db.query('rollback');
      }
    };
    expect((await q('aal1')).s).not.toBeNull();
    const f = randomUUID();
    await db.query(`insert into auth.mfa_factors(id, user_id, status) values ($1, $2, 'unverified')`, [f, owner]);
    // لسه ما اتأكدش: زي الأول
    expect((await q('aal1')).s).not.toBeNull();
    await db.query(`update auth.mfa_factors set status = 'verified' where id = $1`, [f]);
    expect(await q('aal1')).toEqual({ s: null, n: 0 });
    const ok = await q('aal2');
    expect(ok.s).not.toBeNull();
    expect(ok.n).toBeGreaterThan(0);
    // موظف من غير 2FA: زي ما هو
    expect((await as(rec, `select current_shop_id() s`)).rows[0].s).not.toBeNull();
    await db.query(`delete from auth.mfa_factors where id = $1`, [f]);
  });
});
