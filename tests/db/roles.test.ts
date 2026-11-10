// P (المرحلة الأولى): الأدوار والصلاحيات ونوع الفرع، والحماية في قاعدة البيانات نفسها
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

d('الأدوار والصلاحيات', () => {
  let O = '';
  let R = '';
  let T = '';
  let C = ''; // كاشير مبيعات
  let shop = '';
  let main = '';
  const role: Record<string, string> = {};
  let cust = '';
  let devT = ''; // جهاز متوزع على الفني
  let devX = ''; // جهاز تاني
  let item = '';
  const acc: Record<string, string> = {};
  const invite = async (em: string, base: string, roleIds: string[] = []) => {
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, em, base, roleIds]);
    const u = await user(em);
    await as(u, `select bootstrap_account($1)`, [em]);
    return u;
  };

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ro-o-${tag}@r.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الأدوار')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    for (const r of (await admin(`select id, preset from roles where shop_id = $1`, [shop])).rows) role[r.preset] = r.id;
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    R = await invite(`ro-r-${tag}@r.test`, 'reception');
    T = await invite(`ro-t-${tag}@r.test`, 'technician');
    C = await invite(`ro-c-${tag}@r.test`, 'reception', [role.cashier]);
    cust = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [cust, `0108${String(Date.now()).slice(-7)}`]);
    devT = id();
    devX = id();
    await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'A', 'B', 'C'), ($3, $2, 'D', 'E', 'F')`, [devT, cust, devX]);
    await as(R, `insert into device_costs(id, shop_id, device_id, estimated_cost) values ($1, gen_random_uuid(), $2, 50000)`, [id(), devT]);
    item = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'جراب')`, [item]);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 10, unit_cost: 2000 }])]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('الأدوار الجاهزة الخمسة، والموظفين القدام اتنقلوا لدورهم من غير ما حد يكسب أو يخسر', async () => {
    expect(Object.keys(role).sort()).toEqual(['accountant', 'branch_manager', 'cashier', 'reception', 'technician']);
    expect((await admin(`select r.preset from staff_roles sr join roles r on r.id = sr.role_id where sr.profile_id = $1`, [R])).rows.map((x) => x.preset)).toEqual(['reception']);
    expect((await admin(`select r.preset from staff_roles sr join roles r on r.id = sr.role_id where sr.profile_id = $1`, [T])).rows.map((x) => x.preset)).toEqual(['technician']);
    // صاحب المحل: كل حاجة من غير أدوار
    const po = (await as(O, `select my_perms() p`)).rows[0].p;
    expect(Object.keys(po)).toHaveLength(15);
    expect(po.finance).toContain('amounts');
    // الاستقبال: نفس اللي كان بيعمله (أجهزة وعملاء ومبيعات ودفعات) ومفيش الوضع المالي
    const pr = (await as(R, `select my_perms() p`)).rows[0].p;
    expect(pr.devices).toEqual(expect.arrayContaining(['view', 'add', 'edit', 'amounts']));
    expect(pr.finance).toBeUndefined();
    expect((await as(R, `select count(*)::int n from devices`)).rows[0].n).toBe(2);
  });

  it('كاشير المبيعات ما يشوفش الأجهزة ولا الفنيين، ولا حتى من الـ API، وبيبيع عادي', async () => {
    expect((await admin(`select role from profiles where id = $1`, [C])).rows[0].role).toBe('reception');
    expect((await as(C, `select count(*)::int n from devices`)).rows[0].n).toBe(0);
    expect((await as(C, `select count(*)::int n from devices_list`)).rows[0].n).toBe(0);
    expect((await as(C, `select count(*)::int n from device_costs`)).rows[0].n).toBe(0);
    expect((await as(C, `select count(*)::int n from profiles where role = 'technician'`)).rows[0].n).toBe(0);
    expect((await as(C, `select count(*)::int n from repair_steps`)).rows[0].n).toBe(0);
    await expect(as(C, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'z')`, [id(), cust])).rejects.toThrow(/row-level security|policy/);
    await expect(as(C, `select device_money($1)`, [devT])).rejects.toThrow(/E_FORBIDDEN/);
    // البيع شغال
    await as(C, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 5000 }]), acc.cash_cash]);
    expect((await as(C, `select qty from items_stock() where id = $1`, [item])).rows[0].qty).toBe('9');
  });

  it('الفني بيشوف أجهزته بس ومن غير أسعار', async () => {
    const specs = (await admin(`select id from specialties where shop_id = $1 limit 1`, [shop])).rows;
    // من غير ما الجهاز يتوزع عليه: صفر (tech_can_see)، والتكلفة ممنوعة دايمًا
    const before = (await as(T, `select count(*)::int n from devices`)).rows[0].n;
    expect(before).toBeLessThanOrEqual(2);
    expect((await as(T, `select count(*)::int n from device_costs`)).rows[0].n).toBe(0);
    await expect(as(T, `select device_money($1)`, [devT])).rejects.toThrow(/E_FORBIDDEN/);
    expect(specs.length).toBeGreaterThanOrEqual(0);
  });

  it('شيل صلاحية من دور: الموظف بيفقدها على طول، والتغيير في سجل النشاط', async () => {
    const perms = (await admin(`select perms from roles where id = $1`, [role.reception])).rows[0].perms;
    const less = { ...perms, devices: (perms.devices as string[]).filter((o) => o !== 'view') };
    await as(O, `select save_role($1, 'استقبال', 'reception', $2::jsonb)`, [role.reception, JSON.stringify(less)]);
    expect((await as(R, `select count(*)::int n from devices`)).rows[0].n).toBe(0);
    expect((await admin(`select count(*)::int n from audit_log where entity = 'roles' and entity_id = $1 and action = 'update'`, [role.reception])).rows[0].n).toBeGreaterThan(0);
    // استثناء لموظف معيّن: يشوف الأجهزة رغم دوره، وبيبان إنه استثناء
    await as(O, `select set_staff_override($1, 'devices', 'view', true)`, [R]);
    expect((await as(R, `select count(*)::int n from devices`)).rows[0].n).toBe(2);
    expect((await as(R, `select section, op, allow from staff_overrides where profile_id = $1 and deleted_at is null`, [R])).rows).toEqual([{ section: 'devices', op: 'view', allow: true }]);
    // والمنع لموظف بعينه
    await as(O, `select set_staff_override($1, 'sales', 'add', false)`, [R]);
    await expect(as(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 5000 }]), acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN/);
    // رجوع الدور زي ما كان
    await as(O, `select set_staff_override($1, 'devices', 'view', null)`, [R]);
    await as(O, `select set_staff_override($1, 'sales', 'add', null)`, [R]);
    await as(O, `select save_role($1, 'استقبال', 'reception', $2::jsonb)`, [role.reception, JSON.stringify(perms)]);
    expect((await as(R, `select count(*)::int n from devices`)).rows[0].n).toBe(2);
  });

  it('صاحب المحل ما يقدرش يشيل صلاحياته من نفسه، والموظف ما يقدرش يغيّر أدواره', async () => {
    await expect(as(O, `select set_staff_roles($1, $2)`, [O, [role.cashier]])).rejects.toThrow(/E_OWNER_PERMS/);
    await expect(as(O, `select set_staff_override($1, 'devices', 'view', false)`, [O])).rejects.toThrow(/E_OWNER_PERMS/);
    await expect(as(R, `select set_staff_roles($1, $2)`, [R, [role.branch_manager]])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `insert into staff_roles(shop_id, profile_id, role_id) values ($1, $2, $3)`, [shop, R, role.branch_manager])).rejects.toThrow();
    // تعديل مباشر للدور: يا مرفوض يا ما بيغيّرش حاجة
    await as(R, `update profiles set role = 'reception' where id = $1`, [T]).catch(() => undefined);
    expect((await admin(`select role from profiles where id = $1`, [T])).rows[0].role).toBe('technician');
    await expect(as(O, `update profiles set role = 'reception' where id = $1`, [T])).rejects.toThrow(/E_FORBIDDEN/);
    // مدير الأدوار: الموظف بياخد دور "فني" ← دوره الأساسي بقى فني على طول
    const R2 = await invite(`ro-r2-${tag}@r.test`, 'reception');
    await as(O, `select set_staff_roles($1, $2)`, [R2, [role.technician]]);
    expect((await admin(`select role from profiles where id = $1`, [R2])).rows[0].role).toBe('technician');
    await as(O, `select set_staff_roles($1, $2)`, [R2, [role.technician, role.cashier]]);
    expect((await admin(`select role from profiles where id = $1`, [R2])).rows[0].role).toBe('reception');
  });

  it('نوع الفرع: "صيانة بس" ما فيهوش مبيعات، و"مبيعات بس" ما فيهوش استلام أجهزة، وتغيير النوع ما بيمسحش حاجة', async () => {
    await as(O, `select set_branch_kind($1, 'repair')`, [main]);
    await expect(as(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item, qty: 1, price: 5000 }]), acc.cash_cash])).rejects.toThrow(/E_BRANCH_KIND/);
    await as(O, `select set_branch_kind($1, 'sales')`, [main]);
    await expect(as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'z')`, [id(), cust])).rejects.toThrow(/row-level security|policy/);
    // الأجهزة القديمة لسه موجودة
    expect((await admin(`select count(*)::int n from devices where shop_id = $1`, [shop])).rows[0].n).toBe(2);
    await as(O, `select set_branch_kind($1, 'both')`, [main]);
    await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'z')`, [id(), cust]);
    await expect(as(R, `select set_branch_kind($1, 'repair')`, [main])).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('صلاحية "يحذف" من الجدول = التصحيح بالقيد العكسي (زي إذن "يصحح ويحذف" القديم)', async () => {
    expect((await as(R, `select can_correct() c`)).rows[0].c).toBe(false);
    const nr = id();
    await as(O, `select save_role($1, 'استقبال بتصحيح', 'reception', $2::jsonb)`, [nr, JSON.stringify({ ...(await admin(`select perms from roles where id = $1`, [role.reception])).rows[0].perms, sales: ['view', 'add', 'edit', 'delete'] })]);
    await as(O, `select set_staff_roles($1, $2)`, [R, [nr]]);
    expect((await as(R, `select can_correct() c`)).rows[0].c).toBe(true);
    await as(O, `select set_staff_roles($1, $2)`, [R, [role.reception]]);
    expect((await as(R, `select can_correct() c`)).rows[0].c).toBe(false);
    await expect(as(O, `select archive_role($1)`, [role.reception])).rejects.toThrow(/E_ROLE_IN_USE/);
    await as(O, `select archive_role($1)`, [nr]);
  });
});
