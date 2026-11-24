// اختبارات عشوائية (property-based) للحسابات: آلاف العمليات العشوائية من كل نوع، وبعد كل عملية كل الأرصدة لازم تفضل صح:
// - كل قيد متوازن وفيه طرفين على الأقل، والدفتر كله متوازن.
// - قيمة المخزون في الدفتر = حركات المخزون، وكل صنف كميته مش بالسالب، ومفيش قيمة من غير كمية ولا قيمة بالسالب.
// - كل دفعة = المبلغ اللي دخل الخزنة، وكل سطر عملاء/موردين/موظفين عليه طرف.
// - إعادة نفس العملية (زي المزامنة بعد ما النت يرجع) ما بتكررهاش.
// الترتيب ثابت بالـ seed، فلو فشل بيقول رقم العملية والـ seed عشان تتكرر بالظبط.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

// كل اللي الملف ده بيعمله في قاعدة الاختبار بيتمسح في الآخر
cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
const OPS = Number(process.env.PROP_OPS ?? 2000);
const SEED = Number(process.env.PROP_SEED ?? 20261108);

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
/** مولّد أرقام عشوائية ثابت (mulberry32) */
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}

d('الحسابات: عمليات عشوائية، وبعد كل عملية كل الأرصدة صح', () => {
  let O = '';
  let R = '';
  let T = '';
  let S = '';
  const acc: Record<string, string> = {};
  const items: string[] = [];
  const sups: string[] = [];
  const custs: string[] = [];
  const devs: { id: string; cust: string }[] = [];
  const PARTNER = randomUUID();
  const LINK = randomUUID();
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    const tag = randomUUID().slice(0, 6);
    O = await user(`prop-o-${tag}@p.test`);
    S = (await as(O, `select (bootstrap_account('صاحب', 'محل العشوائي')).shop_id s`)).rows[0].s;
    for (const [name, role] of [['استقبال', 'reception'], ['فني', 'technician']] as const) {
      const em = `prop-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [name]);
      if (role === 'reception') R = u;
      else T = u;
    }
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'شريك', 4000)`, [PARTNER]);
    for (let i = 0; i < 4; i++) {
      const it = randomUUID();
      items.push(it);
      await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), $2, $3)`, [it, i % 2 ? 'accessory' : 'part', `صنف ${i}`]);
    }
    for (let i = 0; i < 2; i++) {
      const sp = randomUUID();
      sups.push(sp);
      await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), $2)`, [sp, `مورد ${i}`]);
    }
    for (let i = 0; i < 4; i++) {
      const c = randomUUID();
      custs.push(c);
      await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), $2, $3)`, [c, `عميل ${i}`, `0102${String(Date.now() + i).slice(-7)}`]);
      const dv = randomUUID();
      await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A1', 'عطل')`, [dv, c]);
      await as(O, `insert into device_costs(id, shop_id, device_id) values ($1, gen_random_uuid(), $2)`, [randomUUID(), dv]);
      devs.push({ id: dv, cust: c });
    }
    await as(O, `select link_parties($1, $2, $3)`, [LINK, custs[0], sups[0]]);
  }, 60_000);
  afterAll(async () => db?.end());

  /** كل الشروط: فحص السلامة بتاع البرنامج نفسه، والدفتر كله متوازن، وكل دفعة على الجهاز بتطابق */
  async function check(step: number, what: string) {
    const rep = (await as(O, `select integrity_report() r`)).rows[0].r as unknown[];
    const tb = Number((await admin(`select coalesce(sum(debit - credit), 0) n from journal_lines where shop_id = $1`, [S])).rows[0].n);
    const neg = Number((await admin(`select count(*) n from (select item_id from stock_moves where shop_id = $1 group by item_id having sum(qty) < 0) x`, [S])).rows[0].n);
    const ctx = `seed ${SEED} العملية ${step}: ${what}`;
    expect(rep, ctx).toEqual([]);
    expect(tb, ctx).toBe(0);
    expect(neg, ctx).toBe(0);
  }

  it(`${OPS} عملية عشوائية من كل الأنواع، والأرصدة صح بعد كل واحدة`, async () => {
    const r = rng(SEED);
    const pick = <T,>(a: T[]) => a[Math.floor(r() * a.length)];
    const amt = (max = 500000) => 1 + Math.floor(r() * max);
    const cash = () => pick([acc.cash_cash, acc.cash_wallet, acc.cash_bank_transfer]);
    const done: string[] = [];
    const counts: Record<string, number> = {};
    // أخطاء متوقعة (رفض صح من قاعدة البيانات)، مش أخطاء في الحسابات
    // (E_UNBALANCED مش هنا عن قصد: لو حصل يبقى غلط)
    const ok = /E_STOCK|E_ALREADY_REVERSED|E_INSUFFICIENT|E_COST_LOCKED|E_DELIVERED_LOCKED|E_BAD_AMOUNT|E_NETTING_LIMIT/;
    type Op = [string, () => Promise<unknown>];
    const ops: Op[] = [
      ['رأس مال', () => as(O, `select owner_capital($1, $2, $3)`, [randomUUID(), cash(), amt(2_000_000)])],
      ['سحب', () => as(O, `select owner_drawing($1, $2, $3)`, [randomUUID(), cash(), amt(50_000)])],
      ['مصروف', () => as(O, `select record_expense($1, $2, $3, $4)`, [randomUUID(), pick([acc.exp_rent, acc.exp_electricity]), cash(), amt(80_000)])],
      ['تحويل', () => { const a = cash(); let b = cash(); if (b === a) b = a === acc.cash_cash ? acc.cash_wallet : acc.cash_cash; return as(O, `select transfer_cash($1, $2, $3, $4)`, [randomUUID(), a, b, amt(50_000)]); }],
      ['شراء آجل', () => as(O, `select record_purchase($1, $2, $3::jsonb)`, [randomUUID(), pick(sups), JSON.stringify([{ item: pick(items), qty: 1 + Math.floor(r() * 8), unit_cost: amt(30_000) }])])],
      ['شراء كاش', () => as(O, `select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), pick(sups), JSON.stringify([{ item: pick(items), qty: 1 + Math.floor(r() * 8), unit_cost: amt(30_000) }]), cash()])],
      ['دفع لمورد', () => as(O, `select pay_supplier($1, $2, $3, $4)`, [randomUUID(), pick(sups), cash(), amt(40_000)])],
      ['دفعة عميل على جهاز', () => { const dv = pick(devs); return as(R, `select record_payment($1, $2, $3, $4, $5)`, [randomUUID(), dv.cust, cash(), amt(60_000), dv.id]); }],
      ['دفعة عميل', () => as(R, `select record_payment($1, $2, $3, $4)`, [randomUUID(), pick(custs), cash(), amt(60_000)])],
      ['قطعة في جهاز', () => as(T, `select use_part($1, $2, $3, $4)`, [randomUUID(), pick(devs).id, pick(items), 1 + Math.floor(r() * 2)])],
      ['بيع', () => as(R, `select record_sale($1, $2::jsonb, $3)`, [randomUUID(), JSON.stringify([{ item: pick(items), qty: 1 + Math.floor(r() * 2), price: amt(40_000) }]), cash()])],
      ['سلفة', () => as(O, `select give_advance($1, $2, $3, $4)`, [randomUUID(), pick([R, T]), cash(), amt(30_000)])],
      ['مرتب مستحق', () => as(O, `select accrue_salary($1, $2, $3)`, [randomUUID(), pick([R, T]), amt(300_000)])],
      ['صرف مرتب', () => as(O, `select pay_salary($1, $2, $3, $4)`, [randomUUID(), pick([R, T]), cash(), amt(100_000)])],
      ['تقفيل درج', async () => {
        const cb = cash();
        const bal = Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1`, [cb])).rows[0].b);
        return as(O, `select close_drawer($1, $2, $3)`, [randomUUID(), cb, Math.max(0, bal + Math.floor((r() - 0.5) * 2000))]);
      }],
      ['هالك', () => as(O, `select write_off($1, $2, $3, 'هالك')`, [randomUUID(), pick(items), 1 + Math.floor(r() * 2)])],
      ['مرتجع للمورد', () => as(O, `select supplier_return($1, $2, $3, 1, $4, $5, 'مرتجع')`, [randomUUID(), pick(sups), pick(items), Math.floor(r() * 30_000), r() < 0.5 ? null : cash()])],
      ['مرتجع من عميل', () => as(O, `select sale_return($1, $2, 1, $3, $4, $5, $6, 'مرتجع')`, [randomUUID(), pick(items), Math.floor(r() * 40_000), r() < 0.5 ? cash() : null, pick(custs), r() < 0.7])],
      ['قطعة يدوية', () => as(R, `select device_manual_part($1, $2, 'قطعة', $3, $4)`, [randomUUID(), pick(devs).id, amt(20_000), cash()])],
      ['رصيد افتتاحي', () => {
        const k = pick(['cash', 'customer', 'supplier', 'stock'] as const);
        if (k === 'stock') return as(O, `select opening_balance($1, 'stock', null, null, $2::jsonb)`, [randomUUID(), JSON.stringify([{ item: pick(items), qty: 1 + Math.floor(r() * 5), unit_cost: amt(20_000) }])]);
        const ref = k === 'cash' ? cash() : k === 'customer' ? pick(custs) : pick(sups);
        const a = amt(50_000) * (k !== 'cash' && r() < 0.3 ? -1 : 1);
        return as(O, `select opening_balance($1, $2, $3, $4)`, [randomUUID(), k, ref, a]);
      }],
      ['رأس مال شريك', () => as(O, `select partner_deposit($1, $2, $3, $4)`, [randomUUID(), PARTNER, cash(), amt(500_000)])],
      ['سحب شريك', () => as(O, `select partner_withdraw($1, $2, $3, $4, null, $5)`, [randomUUID(), PARTNER, cash(), amt(30_000), r() < 0.3])],
      ['مقاصة عميل ومورد', async () => {
        // العميل والمورد المربوطين بيتعملهم رصيد الأول (العمليات العشوائية ممكن تصفّرهم)، وبعدين مقاصة بأقصى مبلغ أو بجزء
        await as(O, `select opening_balance($1, 'customer', $2, $3)`, [randomUUID(), custs[0], amt(60_000)]);
        await as(O, `select opening_balance($1, 'supplier', $2, $3)`, [randomUUID(), sups[0], amt(60_000)]);
        return as(O, `select net_parties($1, $2, $3)`, [randomUUID(), LINK, r() < 0.5 ? null : amt(5_000)]);
      }],
      ['إلغاء عملية (قيد عكسي)', async () => {
        const e = (await admin(`select e.id from journal_entries e where e.shop_id = $1 and e.source_type <> 'reversal' and e.source_type <> 'cost_adjust'
                                 and not exists (select 1 from journal_entries x where x.reverses_id = e.id) order by random() limit 1`, [S])).rows[0]?.id;
        if (!e) return;
        return as(O, `select reverse_entry($1, 'اختبار')`, [e]);
      }],
      ['إلغاء شراء (مرتجع للمورد)', async () => {
        const e = (await admin(`select e.id from journal_entries e where e.shop_id = $1 and e.source_type = 'purchase'
                                 and not exists (select 1 from journal_entries x where x.reverses_id = e.id) order by random() limit 1`, [S])).rows[0]?.id;
        if (!e) return;
        return as(O, `select reverse_entry($1, 'مرتجع')`, [e]);
      }],
      ['نفس العملية مرتين (مزامنة)', async () => {
        const id = randomUUID();
        const dv = pick(devs);
        const a = amt(20_000);
        const before = Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [S])).rows[0].n);
        await as(R, `select record_payment($1, $2, $3, $4, $5)`, [id, dv.cust, acc.cash_cash, a, dv.id]);
        await as(R, `select record_payment($1, $2, $3, $4, $5)`, [id, dv.cust, acc.cash_cash, a, dv.id]).catch(() => undefined);
        const after = Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [S])).rows[0].n);
        expect(after - before, 'المزامنة كررت العملية').toBe(1);
      }],
    ];
    for (let i = 1; i <= OPS; i++) {
      const [name, run] = pick(ops);
      try {
        await run();
        counts[name] = (counts[name] ?? 0) + 1;
      } catch (e) {
        const msg = (e as Error).message;
        if (!ok.test(msg)) throw new Error(`seed ${SEED} العملية ${i} (${name}): ${msg}`);
        counts[`${name} (اترفضت صح)`] = (counts[`${name} (اترفضت صح)`] ?? 0) + 1;
      }
      done.push(name);
      await check(i, name);
    }
    // اتعملت عمليات كتير من كل نوع فعلًا (مش كلها اترفضت)
    for (const [name] of ops) expect(counts[name] ?? 0, name).toBeGreaterThan(OPS / ops.length / 4);
    console.log('PROPERTY', JSON.stringify(counts));
  }, 900_000);

  it('الخطأ اللي اتلقى: إلغاء شراء بعد صرف جزء من البضاعة ما بيسيبش الصنف بقيمة غلط', async () => {
    const it = randomUUID();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'صنف الحالة')`, [it]);
    const p1 = (await as(O, `select record_purchase($1, $2, $3::jsonb) e`, [randomUUID(), sups[0], JSON.stringify([{ item: it, qty: 5, unit_cost: 100 }])])).rows[0].e;
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [randomUUID(), sups[0], JSON.stringify([{ item: it, qty: 10, unit_cost: 1 }])]);
    await as(T, `select use_part($1, $2, $3, 9)`, [randomUUID(), devs[0].id, it]);
    const entry = (await admin(`select entry_id from purchases where id = $1 or entry_id = $1`, [p1])).rows[0]?.entry_id ?? p1;
    await as(O, `select reverse_entry($1, 'مرتجع')`, [entry]);
    const st = (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1`, [it])).rows[0];
    // فاضل وحدة واحدة: قيمتها مش بالسالب (قبل التصليح كانت -296 قرش)
    expect(st.q).toBe(1);
    expect(st.v).toBeGreaterThanOrEqual(0);
    await check(0, 'إلغاء شراء بعد صرف');
  });
});
