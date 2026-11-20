// R5 (0062): ضريبة القيمة المضافة الاختيارية: السعر شامل، والقيد متوازن وبيفصل الضريبة، والإلغاء بيرجّعها، والسداد، والتقرير
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
const FROM = () => new Date(Date.now() - 3600_000).toISOString();
const TO = () => new Date(Date.now() + 3600_000).toISOString();

d('ضريبة القيمة المضافة (اختيارية)', () => {
  let O = '';
  let R = '';
  let T = '';
  let shop = '';
  let cash = '';
  let cust = '';
  const part = id();
  const acc = id();
  const srv = id();
  const vatOn = (bp = 1400, reg = '123-456-789') =>
    admin(`update shops set extras = jsonb_set(coalesce(extras, '{}'), '{vat}', $2::jsonb) where id = $1`, [shop, JSON.stringify({ enabled: true, rate_bp: bp, reg_no: reg })]);
  const vatOff = () => admin(`update shops set extras = extras - 'vat' where id = $1`, [shop]);
  /** سطور القيد بكود الحساب ونوعه */
  const lines = async (e: string) =>
    (await admin(`select coalesce(a.code, a.kind) c, l.debit::bigint dr, l.credit::bigint cr from journal_lines l join accounts a on a.id = l.account_id where l.entry_id = $1 order by a.code`, [e])).rows.map((r) => ({
      c: r.c,
      dr: Number(r.dr),
      cr: Number(r.cr),
    }));
  const balanced = async (e: string) => {
    const r = (await admin(`select sum(debit)::bigint d, sum(credit)::bigint c from journal_lines where entry_id = $1`, [e])).rows[0];
    return Number(r.d) === Number(r.c);
  };
  const report = async () => (await as(O, `select vat_report($1, $2) r`, [FROM(), TO()])).rows[0].r;

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`vat-o-${tag}@v.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الضريبة')).shop_id s`)).rows[0].s;
    for (const [role, name] of [['reception', 'استقبال'], ['technician', 'فني']] as const) {
      const em = `vat-${role}-${tag}@v.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (role === 'reception') R = u;
      else T = u;
    }
    cash = (await as(O, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الضريبة', '01077778888')`, [cust]);
    const sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة', 114000), ($2, gen_random_uuid(), 'accessory', 'جراب', 11400), ($3, gen_random_uuid(), 'service', 'سوفت وير', 5700)`, [part, acc, srv]);
    await as(O, `select record_purchase($1, $2, $3::jsonb, null)`, [id(), sup, JSON.stringify([{ item: part, qty: 5, unit_cost: 60000 }, { item: acc, qty: 5, unit_cost: 3000 }])]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('مقفولة افتراضيًا: البيع زي الأول بالظبط، ومفيش ضريبة. والحساب موجود للمحل الجديد', async () => {
    expect((await as(O, `select count(*)::int n from accounts where code = 'vat_payable' and kind = 'tax' and type = 'liability'`)).rows[0].n).toBe(1);
    const e = (await as(R, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 11400 }]), cash])).rows[0].e;
    expect((await lines(e)).filter((l) => l.c === 'vat_payable')).toEqual([]);
    expect(await as(R, `select sale_invoice($1) i`, [e]).then((r) => r.rows[0].i)).toMatchObject({ total: 11400, vat: 0, net: 11400, vat_no: null });
  });

  it('مفتوحة 14%: العميل بيدفع نفس المبلغ، والقيد متوازن، والضريبة متفصّلة لكل نوع إيراد، والفاتورة بتبيّنها', async () => {
    await vatOn();
    // 2 شاشة × 1140 + جراب 114 + خدمة 57 = 2451 جنيه شامل. الضريبة: 280 + 14 + 7 = 301
    const e = (await as(R, `select record_sale($1, $2::jsonb, $3, $4) e`, [id(), JSON.stringify([{ item: part, qty: 2, price: 114000 }, { item: acc, qty: 1, price: 11400 }, { item: srv, qty: 1, price: 5700 }]), cash, cust])).rows[0].e;
    expect(await balanced(e)).toBe(true);
    const l = await lines(e);
    expect(l.find((x) => x.c === 'cash_cash')).toMatchObject({ dr: 245100 });
    expect(l.find((x) => x.c === 'rev_parts')).toMatchObject({ cr: 200000 });
    expect(l.find((x) => x.c === 'rev_accessories')).toMatchObject({ cr: 10000 });
    expect(l.find((x) => x.c === 'rev_repair')).toMatchObject({ cr: 5000 });
    expect(l.find((x) => x.c === 'vat_payable')).toMatchObject({ cr: 30100 });
    const i = (await as(R, `select sale_invoice($1) i`, [e])).rows[0].i;
    expect(i).toMatchObject({ total: 245100, vat: 30100, net: 215000, paid: 245100, due: 0, vat_no: '123-456-789' });
    // السطور زي ما اتباعت (شاملة)، ومجموعها = الإجمالي
    expect(i.lines.reduce((a: number, x: { amount: number }) => a + Number(x.amount), 0)).toBe(245100);
  });

  it('التقريب بالقروش من غير كسور: مبالغ صغيرة وغريبة، والقيد دايمًا متوازن والضريبة أقل من المبلغ', async () => {
    for (const price of [1, 7, 99, 101, 12345, 99999999]) {
      const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: srv, qty: 1, price }]), cash])).rows[0].e;
      expect(await balanced(e), String(price)).toBe(true);
      const v = (await lines(e)).find((x) => x.c === 'vat_payable')?.cr ?? 0;
      expect(Number.isInteger(v)).toBe(true);
      expect(v).toBe(Math.floor((price * 1400 * 2 + 11400) / (2 * 11400)));
      expect(v).toBeLessThan(price);
    }
  });

  it('التسليم: التكلفة النهائية شاملة، والإيراد صافي، وdevice_vat من القيد نفسه (حتى لو النسبة اتغيرت بعدين). والفني ما يشوفهاش', async () => {
    const dv = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'شاشة')`, [dv, cust]);
    await as(O, `insert into device_costs(shop_id, device_id) values (gen_random_uuid(), $1)`, [dv]);
    await as(O, `update device_costs set final_cost = 57000 where device_id = $1`, [dv]);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [dv, st]);
    await as(R, `select record_payment($1, $2, $3, 57000, $4)`, [id(), cust, cash, dv]);
    await as(R, `update devices set status = 'delivered' where id = $1`, [dv]);
    const e = (await admin(`select id from journal_entries where source_type = 'delivery' and source_id = $1`, [dv])).rows[0].id;
    expect(await balanced(e)).toBe(true);
    const l = await lines(e);
    expect(l.find((x) => x.c === 'ar')).toMatchObject({ dr: 57000 });
    expect(l.find((x) => x.c === 'rev_repair')).toMatchObject({ cr: 50000 });
    expect(l.find((x) => x.c === 'vat_payable')).toMatchObject({ cr: 7000 });
    await vatOn(1000);
    expect((await as(R, `select device_vat($1) v`, [dv])).rows[0].v).toEqual({ vat: 7000, gross: 57000, net: 50000 });
    await expect(as(T, `select device_vat($1)`, [dv])).rejects.toThrow(/E_FORBIDDEN/);
    await vatOn();
  });

  it('الإلغاء بقيد عكسي بيرجّع الضريبة، والتقرير بيحسبها مرتجع', async () => {
    const before = await report();
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: acc, qty: 1, price: 22800 }]), cash])).rows[0].e;
    await as(O, `select reverse_entry($1, 'غلط في البيع')`, [e]);
    const after = await report();
    expect(Number(after.sales_vat) - Number(before.sales_vat)).toBe(2800);
    expect(Number(after.reversed_vat) - Number(before.reversed_vat)).toBe(2800);
    expect(Number(after.due)).toBe(Number(before.due));
  });

  it('سداد الضريبة: صاحب المحل بس، وبيقلل المستحق، والتقرير والوضع المالي متطابقين ومتوازنين', async () => {
    const r0 = await report();
    expect(Number(r0.due)).toBeGreaterThan(0);
    expect(Number(r0.due)).toBe(Number(r0.sales_vat) + Number(r0.repair_vat) - Number(r0.reversed_vat) - Number(r0.paid));
    await expect(as(R, `select pay_vat($1, $2, 1000)`, [id(), cash])).rejects.toThrow(/E_FORBIDDEN|E_ROLE/);
    await expect(as(O, `select pay_vat($1, $2, 0)`, [id(), cash])).rejects.toThrow(/E_BAD_AMOUNT/);
    const pid = id();
    await as(O, `select pay_vat($1, $2, 30000, 'إقرار الشهر')`, [pid, cash]);
    await as(O, `select pay_vat($1, $2, 30000, 'إقرار الشهر')`, [pid, cash]); // نفس الطلب مرتين = مرة
    const r1 = await report();
    expect(Number(r1.paid)).toBe(Number(r0.paid) + 30000);
    expect(Number(r1.due)).toBe(Number(r0.due) - 30000);
    const p = (await as(O, `select financial_position($1, $2) p`, [FROM(), TO()])).rows[0].p;
    expect(p.balanced).toBe(true);
    expect(Number(p.vat_due)).toBe(Number(r1.due));
    // الإيراد في الوضع المالي صافي من الضريبة: مجموع الصافي في التقرير جزء منه
    expect(Number(p.revenue)).toBeGreaterThanOrEqual(Number(r1.sales_net) + Number(r1.repair_net));
    // الاستقبال من غير صلاحية المالية ما يشوفش التقرير
    await expect(as(R, `select vat_report($1, $2)`, [FROM(), TO()])).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('نسبة مش سليمة بتتعامل كـ 14%، وأكتر من 30% بتتقص. والقفل بيرجّع البيع من غير ضريبة', async () => {
    await admin(`update shops set extras = jsonb_set(extras, '{vat}', '{"enabled": true, "rate_bp": "abc"}') where id = $1`, [shop]);
    expect((await admin(`select vat_bp($1) b`, [shop])).rows[0].b).toBe(1400);
    await vatOn(9000);
    expect((await admin(`select vat_bp($1) b`, [shop])).rows[0].b).toBe(3000);
    // "true" كنص مش كفاية (زي الواجهة)
    await admin(`update shops set extras = jsonb_set(extras, '{vat}', '{"enabled": "true", "rate_bp": 1400}') where id = $1`, [shop]);
    expect((await admin(`select vat_bp($1) b`, [shop])).rows[0].b).toBe(0);
    await vatOff();
    expect((await admin(`select vat_bp($1) b`, [shop])).rows[0].b).toBe(0);
    const e = (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item: srv, qty: 1, price: 11400 }]), cash])).rows[0].e;
    expect((await lines(e)).some((x) => x.c === 'vat_payable')).toBe(false);
  });

  it('محل تاني ما يشوفش ضريبة المحل ده', async () => {
    const X = await user(`vat-x-${tag}@v.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    const r = (await as(X, `select vat_report($1, $2) r`, [FROM(), TO()])).rows[0].r;
    expect(r).toMatchObject({ sales_vat: 0, repair_vat: 0, paid: 0, due: 0 });
  });
});
