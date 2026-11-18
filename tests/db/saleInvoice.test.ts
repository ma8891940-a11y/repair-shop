// 6ب (0060): سطور البيع زي ما اتباعت، وفاتورة البيع بمبالغ الدفتر، والصلاحيات، والتعديل والإلغاء، والبيع القديم
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

d('فاتورة البيع (سطور البيع)', () => {
  let O = '';
  let R1 = ''; // استقبال الرئيسي
  let R2 = ''; // استقبال الفرع التاني
  let T = '';
  let shop = '';
  let main = '';
  const B2 = id();
  let cash = '';
  let cust = '';
  const part = id();
  const acc = id();
  const srv = id();
  const inv = async (uid: string, e: string) => (await as(uid, `select sale_invoice($1) i`, [e])).rows[0].i;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`si-o-${tag}@s.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الفواتير')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    await as(O, `select save_branch($1, 'فرع تاني', 'F2', null, null)`, [B2]);
    cash = (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = 'cash'`, [shop, main])).rows[0].id;
    for (const [role, name, branches] of [['reception', 'استقبال الرئيسي', [main]], ['reception', 'استقبال التاني', [B2]], ['technician', 'فني', [main]]] as const) {
      const em = `si-${name.length}-${role}-${branches[0].slice(0, 4)}-${tag}@s.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4)`, [em, name, role, branches]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (name === 'استقبال الرئيسي') R1 = u;
      else if (name === 'استقبال التاني') R2 = u;
      else T = u;
    }
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الفاتورة', '01055556666')`, [cust]);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    // سعر الصنف المسجل غير سعر البيع، عشان نتأكد إن الفاتورة بسعر البيع الفعلي
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة A35', 99900), ($2, gen_random_uuid(), 'accessory', 'جراب', 11100), ($3, gen_random_uuid(), 'service', 'تنظيف', 22200)`, [part, acc, srv]);
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cash], main);
    await as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: part, qty: 5, unit_cost: 60000 }, { item: acc, qty: 5, unit_cost: 3000 }]), cash], main);
  }, 60_000);
  afterAll(async () => db?.end());

  const lines = [
    { item: part, qty: 2, price: 150000 },
    { item: acc, qty: 1, price: 8050 },
    { item: srv, qty: 1, price: 5000 },
  ];

  it('بيع كاش بـ 3 أصناف: كل سطر بسعره الفعلي، ومجموع السطور = إيراد القيد بالظبط، والمدفوع = الإجمالي', async () => {
    const e = (await as(R1, `select record_sale($1, $2::jsonb, $3, $4, 'بيع كاش') e`, [id(), JSON.stringify(lines), cash, cust], main)).rows[0].e;
    const sl = (await admin(`select name, qty::int, price::int, seq from sale_lines where entry_id = $1 order by seq`, [e])).rows;
    expect(sl).toEqual([
      { name: 'شاشة A35', qty: 2, price: 150000, seq: 1 },
      { name: 'جراب', qty: 1, price: 8050, seq: 2 },
      { name: 'تنظيف', qty: 1, price: 5000, seq: 3 },
    ]);
    const i = await inv(R1, e);
    expect(i).toMatchObject({ total: 313050, paid: 313050, due: 0, legacy: false, cancelled_by: null });
    expect(i.lines.map((x: { amount: number }) => Number(x.amount)).reduce((a: number, b: number) => a + b, 0)).toBe(Number(i.total));
    // نفس إيراد القيد في الدفتر
    const rev = (await admin(`select sum(l.credit)::bigint r from journal_lines l join accounts a on a.id = l.account_id where l.entry_id = $1 and a.type = 'revenue'`, [e])).rows[0].r;
    expect(Number(rev)).toBe(313050);
    // entry_args (التعديل) بقى بالسعر الفعلي، مش سعر الصنف المسجل
    const args = (await as(O, `select entry_args($1) a`, [e])).rows[0].a;
    expect(args.lines.map((x: { price: number }) => Number(x.price))).toEqual([150000, 8050, 5000]);
  });

  it('بيع آجل لعميل: المدفوع 0، والباقي = الإجمالي، واسم العميل', async () => {
    const e = (await as(O, `select record_sale($1, $2::jsonb, null, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 2, price: 7525 }]), cust], main)).rows[0].e;
    expect(await inv(O, e)).toMatchObject({ total: 15050, paid: 0, due: 15050, customer: 'عميل الفاتورة', phone: '01055556666' });
  });

  it('الصلاحيات: الفني لأ، وموظف فرع تاني لأ، وصاحب المحل وموظف الفرع آه. والفني ما بيقراش السطور', async () => {
    const e = (await as(R1, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: srv, qty: 1, price: 1000 }]), cash], main)).rows[0].e;
    await expect(inv(T, e)).rejects.toThrow(/E_FORBIDDEN/);
    await expect(inv(R2, e)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await inv(O, e)).total).toBe(1000);
    expect((await inv(R1, e)).total).toBe(1000);
    expect((await as(T, `select count(*)::int n from sale_lines`)).rows[0].n).toBe(0);
    await expect(as(O, `select sale_invoice($1)`, [id()])).rejects.toThrow(/E_NOT_FOUND/);
  });

  it('السطور ما بتتعدلش ولا بتتحذف، حتى لصاحب قاعدة البيانات', async () => {
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: srv, qty: 1, price: 2000 }]), cash], main)).rows[0].e;
    await expect(admin(`update sale_lines set price = 1 where entry_id = $1`, [e])).rejects.toThrow();
    await expect(admin(`delete from sale_lines where entry_id = $1`, [e])).rejects.toThrow();
    expect((await admin(`select price::int p from sale_lines where entry_id = $1`, [e])).rows[0].p).toBe(2000);
  });

  it('التعديل: القيد القديم ملغي، والجديد بسطوره الجديدة. والإلغاء بيبان في الفاتورة', async () => {
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 9000 }]), cash], main)).rows[0].e;
    const ne = (await as(O, `select edit_entry($1, 'السعر اتغيّر', $2::jsonb) n`, [e, JSON.stringify({ id: id(), lines: [{ item: acc, qty: 1, price: 8500 }], cashbox: cash })])).rows[0].n;
    expect((await inv(O, e)).cancelled_by).not.toBeNull();
    const n = await inv(O, ne);
    expect(n).toMatchObject({ total: 8500, cancelled_by: null });
    expect(n.lines.map((x: { price: number }) => Number(x.price))).toEqual([8500]);
  });

  it('بيع قديم (من غير سطور): الأصناف والكميات من حركة المخزون، والإجمالي من الدفتر، ومن غير سعر كل صنف', async () => {
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: part, qty: 1, price: 140000 }, { item: acc, qty: 1, price: 9900 }]), cash], main)).rows[0].e;
    // تمثيل بيع اتعمل قبل 0060: من غير سطور (الحماية مقفولة لحظة بس في الاختبار)
    await admin(`set session_replication_role = replica`);
    await admin(`delete from sale_lines where entry_id = $1`, [e]);
    await admin(`set session_replication_role = origin`);
    const i = await inv(O, e);
    expect(i).toMatchObject({ legacy: true, total: 149900, paid: 149900 });
    expect(i.lines).toEqual([
      { name: 'شاشة A35', qty: 1, price: null, amount: null },
      { name: 'جراب', qty: 1, price: null, amount: null },
    ]);
  });
});
