// البند 2: تعديل وحذف في كل حاجة من غير ما الأصل يتلمس، ومن غير ما أي رصيد يبوظ
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

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

d('تعديل وحذف: قيد عكسي + قيد جديد في نفس اللحظة، والأصل محفوظ', () => {
  let O = '';
  let R = '';
  let T = '';
  let O2 = '';
  const acc: Record<string, string> = {};
  let cust = '';
  let dev = '';
  let sup = '';
  let item = '';
  const bal = async (code: string) => Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1`, [acc[code]])).rows[0].b);
  const clean = async (u = O) => expect((await as(u, `select integrity_report() r`)).rows[0].r).toEqual([]);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`ed-o-${tag}@e.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل التعديل')`);
    for (const role of ['reception', 'technician'] as const) {
      const em = `ed-${role}-${tag}@e.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    O2 = await user(`ed-o2-${tag}@e.test`);
    await as(O2, `select bootstrap_account('صاحب تاني', 'محل تاني')`);
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    cust = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [cust, `0109${String(Date.now()).slice(-7)}`]);
    dev = id();
    await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A5', 'شاشة')`, [dev, cust]);
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    item = id();
    await as(O, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'accessory', 'جراب', 5000)`, [item]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('تعديل دفعة: المبلغ الجديد بس هو اللي في الخزنة، والأصل موجود ومربوط بقيده العكسي، والسبب في السجل', async () => {
    const cash0 = await bal('cash_cash');
    const p = (await as(R, `select record_payment($1, $2, $3, 10000, $4) e`, [id(), cust, acc.cash_cash, dev])).rows[0].e;
    expect(await bal('cash_cash')).toBe(cash0 + 10000);
    const args = (await as(O, `select entry_args($1) a`, [p])).rows[0].a;
    expect(args).toMatchObject({ source_type: 'payment', amount: 10000, customer: cust, device: dev, cashbox: acc.cash_cash, editable: true });
    const nid = id();
    const ne = (await as(O, `select edit_entry($1, 'المبلغ اتكتب غلط', $2::jsonb) e`, [p, JSON.stringify({ ...args, id: nid, amount: 12500 })])).rows[0].e;
    expect(await bal('cash_cash')).toBe(cash0 + 12500);
    // الأصل لسه موجود بنفس سطوره، وقيده العكسي مربوط بيه
    expect(Number((await admin(`select count(*) n from journal_lines where entry_id = $1`, [p])).rows[0].n)).toBe(2);
    expect(Number((await admin(`select count(*) n from journal_entries where reverses_id = $1`, [p])).rows[0].n)).toBe(1);
    const log = (await admin(`select after from audit_log where action = 'edit_entry' and entity_id = $1`, [p])).rows[0].after;
    expect(log).toMatchObject({ new_entry: ne, reason: 'المبلغ اتكتب غلط' });
    // المدفوع على الجهاز = الجديد بس (الملغي مش محسوب)
    expect(Number((await admin(`select device_paid($1) n`, [dev])).rows[0].n)).toBe(12500);
    // نفس التعديل مرتين (المزامنة): ما بيتكررش
    const again = (await as(O, `select edit_entry($1, 'المبلغ اتكتب غلط', $2::jsonb) e`, [p, JSON.stringify({ ...args, id: nid, amount: 12500 })])).rows[0].e;
    expect(again).toBe(ne);
    expect(await bal('cash_cash')).toBe(cash0 + 12500);
    await clean();
  });

  it('لو البيانات الجديدة غلط: ولا حاجة بتتسجل، والأصل بيفضل ساري (transaction واحدة)', async () => {
    const cash0 = await bal('cash_cash');
    const p = (await as(O, `select record_expense($1, $2, $3, 7000) e`, [id(), acc.exp_rent, acc.cash_cash])).rows[0].e;
    const args = (await as(O, `select entry_args($1) a`, [p])).rows[0].a;
    await expect(as(O, `select edit_entry($1, 'سبب', $2::jsonb)`, [p, JSON.stringify({ ...args, id: id(), amount: 0 })])).rejects.toThrow(/E_BAD_AMOUNT/);
    expect(Number((await admin(`select count(*) n from journal_entries where reverses_id = $1`, [p])).rows[0].n)).toBe(0);
    expect(await bal('cash_cash')).toBe(cash0 - 7000);
    // والسبب إجباري
    await expect(as(O, `select edit_entry($1, '  ', $2::jsonb)`, [p, JSON.stringify({ ...args, id: id(), amount: 6000 })])).rejects.toThrow(/E_REASON_REQUIRED/);
    await expect(as(O, `select reverse_entry($1, '')`, [p])).rejects.toThrow(/E_REASON_REQUIRED/);
    await clean();
  });

  it('تعديل شراء وبيع: الكمية والسعر الجديد في المخزون والإيراد', async () => {
    const pe = (await as(O, `select record_purchase($1, $2, $3::jsonb) e`, [id(), sup, JSON.stringify([{ item, qty: 10, unit_cost: 2000 }])])).rows[0].e;
    const pa = (await as(O, `select entry_args($1) a`, [pe])).rows[0].a;
    expect(pa.lines).toEqual([{ item, qty: 10, unit_cost: 2000 }]);
    await as(O, `select edit_entry($1, 'الكمية 8 مش 10', $2::jsonb)`, [pe, JSON.stringify({ ...pa, id: id(), lines: [{ item, qty: 8, unit_cost: 2000 }] })]);
    const st = (await admin(`select sum(qty)::int q, sum(value)::int v from stock_moves where item_id = $1`, [item])).rows[0];
    expect(st).toEqual({ q: 8, v: 16000 });
    const se = (await as(R, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item, qty: 2, price: 5000 }]), acc.cash_cash])).rows[0].e;
    const sa = (await as(O, `select entry_args($1) a`, [se])).rows[0].a;
    expect(sa.lines).toEqual([{ item, qty: 2, price: 5000 }]);
    const rev0 = await bal('rev_accessories');
    await as(O, `select edit_entry($1, 'خصم', $2::jsonb)`, [se, JSON.stringify({ ...sa, id: id(), lines: [{ item, qty: 2, price: 4500 }] })]);
    expect(await bal('rev_accessories')).toBe(rev0 + 10000 - 9000);
    expect(Number((await admin(`select sum(qty) q from stock_moves where item_id = $1`, [item])).rows[0].q)).toBe(6);
    await clean();
  });

  it('الصلاحية: الموظف ما يصححش غير بإذن من صاحب المحل، وما يدّيش نفسه الإذن، والمحل التاني ما يوصلش', async () => {
    const p = (await as(R, `select record_payment($1, $2, $3, 3000, $4) e`, [id(), cust, acc.cash_cash, dev])).rows[0].e;
    await expect(as(R, `select reverse_entry($1, 'غلط')`, [p])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(R, `select entry_args($1)`, [p])).rejects.toThrow(/E_FORBIDDEN/);
    await as(R, `update profiles set can_correct = true where id = $1`, [R]).catch(() => undefined);
    expect((await admin(`select can_correct from profiles where id = $1`, [R])).rows[0].can_correct).toBe(false);
    await expect(as(R, `select set_can_correct($1, true)`, [R])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(O2, `select reverse_entry($1, 'غلط')`, [p])).rejects.toThrow(/E_NOT_FOUND/);
    await as(O, `select set_can_correct($1, true)`, [R]);
    const args = (await as(R, `select entry_args($1) a`, [p])).rows[0].a;
    await as(R, `select edit_entry($1, 'غلط في المبلغ', $2::jsonb)`, [p, JSON.stringify({ ...args, id: id(), amount: 3500 })]);
    expect((await admin(`select count(*)::int n from audit_log where action = 'set_can_correct' and entity_id = $1`, [R])).rows[0].n).toBe(1);
    // الفني ما ياخدش الإذن ده ولو اتدّاله: ما بيشوفش فلوس أصلًا (العملية نفسها بتترفض)
    await as(O, `select set_can_correct($1, false)`, [R]);
    await expect(as(R, `select reverse_entry($1, 'غلط')`, [p])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(T, `select soft_delete('customer', $1, 'x')`, [cust])).rejects.toThrow(/E_FORBIDDEN/);
    await clean();
  });

  it('الحذف الآمن: اللي عليه فلوس أو في المخزون ما بيتحذفش، وبعد التسوية بيتحذف ناعم وتاريخه القديم زي ما هو', async () => {
    const c = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل للحذف', $2)`, [c, `0111${String(Date.now()).slice(-7)}`]);
    const dv = id();
    await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Nokia', 'G20', 'شحن')`, [dv, c]);
    const pay = (await as(R, `select record_payment($1, $2, $3, 4000, $4) e`, [id(), c, acc.cash_cash, dv])).rows[0].e;
    await expect(as(O, `select soft_delete('device', $1, 'اتسجل غلط')`, [dv])).rejects.toThrow(/E_HAS_MONEY/);
    await expect(as(O, `select soft_delete('customer', $1, 'مكرر')`, [c])).rejects.toThrow(/E_HAS_BALANCE|E_HAS_OPEN_DEVICES/);
    await as(O, `select reverse_entry($1, 'الجهاز اتسجل غلط')`, [pay]);
    await as(O, `select soft_delete('device', $1, 'اتسجل غلط')`, [dv]);
    await as(O, `select soft_delete('customer', $1, 'مكرر')`, [c]);
    expect((await admin(`select deleted_at is not null d from customers where id = $1`, [c])).rows[0].d).toBe(true);
    // البيانات القديمة (الدفعة وقيدها العكسي) زي ما هي
    expect(Number((await admin(`select count(*) n from payments where customer_id = $1`, [c])).rows[0].n)).toBe(1);
    expect((await admin(`select after->>'reason' r from audit_log where action = 'soft_delete' and entity_id = $1 and after ? 'reason'`, [c])).rows[0].r).toBe('مكرر');
    // الصنف اللي في المخزون
    await expect(as(O, `select soft_delete('item', $1)`, [item])).rejects.toThrow(/E_HAS_STOCK/);
    // المورد اللي ليه فلوس
    await expect(as(O, `select soft_delete('supplier', $1)`, [sup])).rejects.toThrow(/E_HAS_BALANCE/);
    // الاستقبال بإذن بتقدر تحذف (قاعدة الأرشفة لصاحب المحل بتتعدّى بالإذن بس)
    const c3 = id();
    await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل 3', $2)`, [c3, `0122${String(Date.now()).slice(-7)}`]);
    await expect(as(R, `select soft_delete('customer', $1)`, [c3])).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_can_correct($1, true)`, [R]);
    await as(R, `select soft_delete('customer', $1)`, [c3]);
    await expect(as(R, `update customers set deleted_at = now() where id = $1`, [cust])).rejects.toThrow(/E_OWNER_APPROVAL/);
    await as(O, `select set_can_correct($1, false)`, [R]);
    await clean();
  });
});
