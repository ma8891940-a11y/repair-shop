// P المرحلة التانية: صاحب المحل بيدي الموظف صلاحيات ما كانتش عنده (مشتريات، ووضع مالي، وتقارير، وتحويل خزن، وهالك، ومصروفات، وسجل النشاط)
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

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
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const FROM = () => new Date(Date.now() - 86400_000).toISOString();
const TO = () => new Date(Date.now() + 86400_000).toISOString();

d('الأدوار: فتح صلاحيات جديدة للموظف', () => {
  let O = '';
  let R = ''; // استقبال
  let T = ''; // فني
  let shop = '';
  let item = '';
  let sup = '';
  let other = ''; // فرع تاني
  const role: Record<string, string> = {};
  const acc: Record<string, string> = {};
  const invite = async (em: string, base: string, roleIds: string[] = []) => {
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, em, base, roleIds]);
    const u = await user(em);
    await as(u, `select bootstrap_account($1)`, [em]);
    return u;
  };
  const ok = (uid: string, sql: string, p: unknown[] = []) => as(uid, sql, p);
  const no = (uid: string, sql: string, p: unknown[] = []) => expect(as(uid, sql, p)).rejects.toThrow(/E_FORBIDDEN/);
  const grant = (uid: string, sec: string, op: string, v: boolean | null) => as(O, `select set_staff_override($1, $2, $3, $4)`, [uid, sec, op, v]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`rg-o-${tag}@r.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الصلاحيات')).shop_id s`)).rows[0].s;
    for (const r of (await admin(`select id, preset from roles where shop_id = $1`, [shop])).rows) role[r.preset] = r.id;
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    R = await invite(`rg-r-${tag}@r.test`, 'reception');
    T = await invite(`rg-t-${tag}@r.test`, 'technician');
    item = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'جراب')`, [item]);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), acc.cash_cash]);
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item, qty: 10, unit_cost: 2000 }]), acc.cash_cash]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('من غير ما صاحب المحل يدي حاجة: الاستقبال زي الأول بالظبط (ولا مصروفات ولا مشتريات ولا وضع مالي)', async () => {
    const p = (await as(R, `select my_perms() p`)).rows[0].p;
    expect(p.expenses).toBeUndefined();
    expect(p.finance).toBeUndefined();
    await no(R, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 1, unit_cost: 2000 }])]);
    await no(R, `select financial_position($1, $2)`, [FROM(), TO()]);
    await no(R, `select record_expense($1, $2, $3, 1000)`, [id(), acc.exp_rent, acc.cash_cash]);
    expect((await as(R, `select count(*)::int n from journal_entries`)).rows[0].n).toBe(0);
    expect((await as(R, `select count(*)::int n from suppliers`)).rows[0].n).toBe(0);
  });

  it('صاحب المحل بيدي المشتريات: الموظف بيشتري ويشوف الموردين، وبيتشال: بيترفض على طول', async () => {
    await grant(R, 'purchases', 'view', true);
    await grant(R, 'purchases', 'add', true);
    expect((await as(R, `select count(*)::int n from suppliers`)).rows[0].n).toBe(1);
    await ok(R, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 2, unit_cost: 2000 }])]);
    await ok(R, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الموظف')`, [id()]);
    // مرتجع للمورد محتاج "يعدّل"
    await no(R, `select supplier_return($1, $2, $3, 1, 2000)`, [id(), sup, item]);
    await grant(R, 'purchases', 'add', null);
    await no(R, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 1, unit_cost: 2000 }])]);
    await grant(R, 'purchases', 'view', null);
    expect((await as(R, `select count(*)::int n from suppliers`)).rows[0].n).toBe(0);
  });

  it('الوضع المالي والتقارير: بيتفتحوا بالصلاحية، والمرتبات والشركاء لصاحب المحل بس', async () => {
    await no(R, `select pl_breakdown($1, $2)`, [FROM(), TO()]);
    await grant(R, 'finance', 'view', true);
    const fp = (await as(R, `select financial_position($1, $2) f`, [FROM(), TO()])).rows[0].f;
    expect(fp).toBeTruthy();
    await ok(R, `select * from pl_breakdown($1, $2)`, [FROM(), TO()]);
    expect((await as(R, `select count(*)::int n from journal_entries`)).rows[0].n).toBeGreaterThan(0);
    await ok(R, `select * from party_balances('suppliers')`);
    await no(R, `select * from party_balances('employees')`);
    await no(R, `select statement('employee', $1, $2, $3)`, [R, FROM(), TO()]);
    // حسابات المرتبات والشركاء مش ظاهرة
    expect((await as(R, `select count(*)::int n from accounts where kind in ('advances', 'salaries', 'partner_capital', 'partner_current')`)).rows[0].n).toBe(0);
    await no(R, `select inventory_summary($1, $2)`, [FROM(), TO()]);
    await grant(R, 'reports', 'view', true);
    await ok(R, `select inventory_summary($1, $2)`, [FROM(), TO()]);
    // لسه مش بيقدر يعدّل الإعدادات ولا المرتبات ولا الشركاء ولا النسخ الاحتياطي
    await expect(as(R, `select * from partner_balances()`)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select export_backup()`)).rejects.toThrow();
    await grant(R, 'finance', 'view', null);
    await grant(R, 'reports', 'view', null);
    expect((await as(R, `select count(*)::int n from journal_entries`)).rows[0].n).toBe(0);
  });

  it('الفني: حتى لو صاحب المحل علّم الصلاحية، ما بيشوفش فلوس (الفني ما يشوفش أسعار ولا أرباح)', async () => {
    await grant(T, 'finance', 'view', true);
    await grant(T, 'purchases', 'add', true);
    await grant(T, 'reports', 'view', true);
    await no(T, `select financial_position($1, $2)`, [FROM(), TO()]);
    await no(T, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 1, unit_cost: 2000 }])]);
    await no(T, `select inventory_summary($1, $2)`, [FROM(), TO()]);
    expect((await as(T, `select count(*)::int n from journal_entries`)).rows[0].n).toBe(0);
    expect((await as(T, `select count(*)::int n from suppliers`)).rows[0].n).toBe(0);
    for (const s of ['finance', 'purchases', 'reports']) await grant(T, s, s === 'purchases' ? 'add' : 'view', null);
  });

  it('الهالك والتحويل بين الخزن والمصروفات وسجل النشاط بالصلاحية', async () => {
    await grant(R, 'expenses', 'add', true);
    await ok(R, `select record_expense($1, $2, $3, 1000)`, [id(), acc.exp_rent, acc.cash_cash]);
    await grant(R, 'expenses', 'add', null);
    await no(R, `select record_expense($1, $2, $3, 1000)`, [id(), acc.exp_rent, acc.cash_cash]);
    await no(R, `select write_off($1, $2, 1, 'اتكسر')`, [id(), item]);
    await grant(R, 'inventory', 'delete', true);
    await ok(R, `select write_off($1, $2, 1, 'اتكسر')`, [id(), item]);
    await no(R, `select transfer_cash($1, $2, $3, 100)`, [id(), acc.cash_cash, acc.cash_instapay]);
    await grant(R, 'cashbox', 'edit', true);
    await ok(R, `select transfer_cash($1, $2, $3, 100)`, [id(), acc.cash_cash, acc.cash_instapay]);
    expect((await as(R, `select count(*)::int n from audit_log`)).rows[0].n).toBe(0);
    await grant(R, 'audit', 'view', true);
    expect((await as(R, `select count(*)::int n from audit_log`)).rows[0].n).toBeGreaterThan(0);
    for (const [s, o] of [['inventory', 'delete'], ['cashbox', 'edit'], ['audit', 'view']]) await grant(R, s, o, null);
  });

  it('فرعين: الموظف اللي ليه فرع واحد بيشوف الوضع المالي بتاع فرعه بس، والتقارير على مستوى المحل مرفوضة', async () => {
    other = id();
    await as(O, `select save_branch($1, 'فرع تاني', 'B2')`, [other]);
    const otherCash = (await admin(`select id from accounts where branch_id = $1 and kind = 'cash' limit 1`, [other])).rows[0].id;
    await grant(R, 'finance', 'view', true);
    await grant(R, 'reports', 'view', true);
    // الموظف مربوط بالرئيسي بس (الافتراضي)
    const mineBr = (await as(R, `select my_branch_ids() b`)).rows[0].b;
    expect(mineBr).toHaveLength(1);
    expect((await as(R, `select count(*)::int n from journal_entries where branch_id = $1`, [other])).rows[0].n).toBe(0);
    expect((await as(R, `select count(*)::int n from accounts where id = $1`, [otherCash])).rows[0].n).toBe(0);
    await no(R, `select statement('cashbox', $1, $2, $3)`, [otherCash, FROM(), TO()]);
    await no(R, `select * from cashbox_daily($1, $2)`, [FROM(), TO()]);
    // طلب فرع مش بتاعه ← بيرجع لفرعه هو
    const a = (await as(R, `select financial_position($1, $2, $3) f`, [FROM(), TO(), other])).rows[0].f;
    const b = (await as(R, `select financial_position($1, $2, $3) f`, [FROM(), TO(), mineBr[0]])).rows[0].f;
    expect(a).toEqual(b);
    for (const s of ['finance', 'reports']) await grant(R, s, 'view', null);
  });

  it('الأدوار الجاهزة: مدير الفرع والمحاسب جواهم الصلاحيات الجديدة، والاستقبال من غير مصروفات', async () => {
    const perms = async (p: string) => (await admin(`select perms from roles where id = $1`, [role[p]])).rows[0].perms;
    expect((await perms('reception')).expenses).toBeUndefined();
    expect((await perms('branch_manager')).purchases).toEqual(['view', 'add', 'edit']);
    expect((await perms('accountant')).finance).toEqual(['view', 'amounts', 'export']);
    // موظف بدور "محاسب": بيشوف الوضع المالي من غير ما يبيع
    const A = await invite(`rg-a-${tag}@r.test`, 'reception', [role.accountant]);
    await ok(A, `select financial_position($1, $2)`, [FROM(), TO()]);
    await expect(as(A, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 3000 }]), acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN/);
  });
});
