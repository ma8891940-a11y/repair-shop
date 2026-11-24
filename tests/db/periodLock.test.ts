// (6) 0077: قفل الفترة: ممنوع قيد أو إلغاء أو تعديل جواها، لصاحب المحل بس، والفتح بسبب ومتسجل
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
const login = async (c: pg.Client, uid: string) => {
  await c.query('begin');
  await c.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
  await c.query('set local role authenticated');
};
async function as(uid: string, sql: string, params: unknown[] = []) {
  await login(db, uid);
  try {
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

d('قفل الفترة المحاسبية', () => {
  let O = '';
  let R = '';
  let X = '';
  let shop = '';
  let cash = '';
  let rent = '';
  let partner = '';
  let cust = '';
  const acc = id();
  let today = '';
  const day = (n: number) => new Date(Date.parse(`${today}T00:00:00Z`) + n * 86400_000).toISOString().slice(0, 10);
  const lock = (u: string, until: string | null, reason: string | null = null) => as(u, `select set_period_lock($1, $2)::text r`, [until, reason]).then((r) => r.rows[0].r);
  const expense = async (when: string) => {
    const e = (await as(O, `select record_expense($1, $2, $3, 1000) e`, [id(), rent, cash])).rows[0].e;
    await admin(`set session_replication_role = replica`);
    await admin(`update journal_entries set occurred_at = ($2::timestamp at time zone 'Africa/Cairo') where id = $1`, [e, when]);
    await admin(`set session_replication_role = origin`);
    return e as string;
  };
  const count = async () => Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [shop])).rows[0].n);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    today = (await admin(`select ((now() at time zone 'Africa/Cairo')::date)::text t`)).rows[0].t;
    O = await user(`pl-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل القفل')).shop_id s`)).rows[0].s;
    cash = (await as(O, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    rent = (await as(O, `select id from accounts where code = 'exp_rent'`)).rows[0].id;
    const em = `pl-r-${tag}@p.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال', 'reception')`, [em]);
    R = await user(em);
    await as(R, `select bootstrap_account('استقبال')`);
    X = await user(`pl-x-${tag}@p.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    partner = id();
    cust = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'شريك', 1000)`, [partner]);
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', '01044445555')`, [cust]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'service', 'خدمة')`, [acc]);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('قيد بتاريخ جوه الفترة مرفوض، وآخر يوم مقفول داخل، واللي بعده مسموح', async () => {
    expect(await lock(O, day(-5))).toBe(day(-5));
    const back = (when: string) => as(O, `select partner_capital_in($1, $2, 'cash', 1000, $3, $4)`, [id(), partner, when, cash]);
    const n = await count();
    for (const x of [-30, -6, -5]) await expect(back(day(x)), String(x)).rejects.toThrow(/E_PERIOD_LOCKED/);
    expect(await count()).toBe(n);
    await back(day(-4));
    await as(O, `select record_expense($1, $2, $3, 500)`, [id(), rent, cash]); // شغل النهارده عادي
    expect(await count()).toBe(n + 2);
  });

  it('إلغاء وتعديل قيد جوه الفترة مرفوض حتى لصاحب المحل، والحدود بتوقيت القاهرة', async () => {
    const inside = await expense(`${day(-5)} 23:59:59`);
    const outside = await expense(`${day(-4)} 00:00:00`);
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [inside])).rejects.toThrow(/E_PERIOD_LOCKED/);
    const args = (await as(O, `select entry_args($1) a`, [inside])).rows[0].a;
    await expect(as(O, `select edit_entry($1, 'غلط', $2::jsonb)`, [inside, JSON.stringify({ ...args, id: id(), amount: 700 })])).rejects.toThrow(/E_PERIOD_LOCKED/);
    expect((await admin(`select count(*)::int n from journal_entries where reverses_id = $1`, [inside])).rows[0].n).toBe(0);
    await as(O, `select reverse_entry($1, 'غلط')`, [outside]);
  });

  it('مرتجع النهارده لبيع جوه الفترة مسموح (قيد جديد)، وإلغاء البيع نفسه لأ', async () => {
    const e = (await as(R, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 5000 }]), cash])).rows[0].e;
    const line = (await admin(`select id from sale_lines where entry_id = $1`, [e])).rows[0].id;
    await admin(`set session_replication_role = replica`);
    await admin(`update journal_entries set occurred_at = now() - interval '20 days' where id = $1`, [e]);
    await admin(`set session_replication_role = origin`);
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_PERIOD_LOCKED/);
    await as(R, `select sale_line_return($1, $2, 1, $3, true, 'رجع')`, [id(), line, cash]);
  });

  it('الفتح بسبب ومتسجل، ومن غيره مرفوض، والقفل ما يعدّيش امبارح', async () => {
    for (const bad of [null, '  ']) await expect(lock(O, null, bad)).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(lock(O, day(-9))).rejects.toThrow(/E_REASON_REQUIRED/);
    for (const x of [0, 1, 400]) await expect(lock(O, day(x))).rejects.toThrow(/E_PERIOD_DATE/);
    expect(await lock(O, day(-1))).toBe(day(-1));
    expect(await lock(O, day(-1))).toBe(day(-1)); // نفس التاريخ: ولا حاجة
    expect(await lock(O, day(-9), 'فاتورة اتنسيت')).toBe(day(-9));
    expect(await lock(O, null, 'مراجعة')).toBeNull();
    const log = (await admin(`select action, before ->> 'until' b, after ->> 'until' a, after ->> 'reason' r, actor_id from audit_log where shop_id = $1 and action like 'period_%' order by created_at, id`, [shop])).rows;
    expect(log.map((x) => [x.action, x.b, x.a, x.r])).toEqual([
      ['period_lock', null, day(-5), null],
      ['period_lock', day(-5), day(-1), null],
      ['period_unlock', day(-1), day(-9), 'فاتورة اتنسيت'],
      ['period_unlock', day(-9), null, 'مراجعة'],
    ]);
    expect(new Set(log.map((x) => x.actor_id))).toEqual(new Set([O]));
    await as(O, `select partner_capital_in($1, $2, 'cash', 1000, $3, $4)`, [id(), partner, day(-30), cash]);
  });

  it('صاحب المحل بس، ومن الدالة بس، وكلمة السر الرئيسية للفتح، والمحل التاني مش متأثر', async () => {
    await as(O, `select set_can_correct($1, true)`, [R]);
    await expect(lock(R, day(-3))).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_can_correct($1, false)`, [R]);
    await lock(O, day(-3));
    await expect(as(O, `update shops set books_locked_until = null where id = $1`, [shop])).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `update shops set name = 'اسم جديد' where id = $1`, [shop]);
    expect((await admin(`select books_locked_until::text l from shops where id = $1`, [shop])).rows[0].l).toBe(day(-3));
    expect((await as(X, `select books_locked_until l from shops`)).rows).toEqual([{ l: null }]);
    expect((await admin(`select has_function_privilege('anon', 'public.set_period_lock(date,text)', 'execute') x`)).rows[0].x).toBe(false);
    await as(O, `select set_master_password(null, 'secret77')`);
    await admin(`update master_unlocks set deleted_at = now() where shop_id = $1`, [shop]).catch(() => undefined);
    await expect(lock(O, null, 'سبب')).rejects.toThrow(/E_MASTER_REQUIRED/);
    await as(O, `select verify_master('secret77')`);
    expect(await lock(O, null, 'سبب')).toBeNull();
  });

  it('قفل وقيد قديم في نفس اللحظة: القيد ما يعدّيش بعد القفل', async () => {
    const c2 = new pg.Client({ connectionString: url });
    await c2.connect();
    try {
      await login(db, O);
      await db.query(`select set_period_lock($1)`, [day(-2)]);
      await login(c2, O);
      const p = c2.query(`select partner_capital_in($1, $2, 'cash', 1000, $3, $4)`, [id(), partner, day(-10), cash]).then(() => null, (e: Error) => e.message);
      await new Promise((r) => setTimeout(r, 300));
      await db.query('commit');
      expect(await p).toMatch(/E_PERIOD_LOCKED/);
      await c2.query('rollback');
    } finally {
      await c2.end();
    }
  });

  it('استرجاع نسخة في محل جديد: القيود القديمة بترجع عادي', async () => {
    const backup = (await as(O, `select export_backup() b`)).rows[0].b;
    const N = await user(`pl-n-${tag}@p.test`);
    await as(N, `select bootstrap_account('جديد', 'محل جديد')`);
    await lock(N, day(-1));
    await as(N, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const s2 = (await admin(`select shop_id from profiles where id = $1`, [N])).rows[0].shop_id;
    expect(Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [s2])).rows[0].n)).toBe(await count());
  });
});
