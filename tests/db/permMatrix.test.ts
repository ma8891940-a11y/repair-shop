// (34): مصفوفة الصلاحيات على الـ API مباشرة: الأدوار الخمسة الجاهزة × الدوال الحساسة، وعزل الفرع التاني.
// المتوقع مكتوب بالإيد من جدول الصلاحيات (preset_perms) وقواعد CLAUDE.md، مش محسوب من الكود.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function run(uid: string, sql: string, params: unknown[], end: 'commit' | 'rollback') {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    const r = await db.query(sql, params);
    await db.query(end);
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const as = (uid: string, sql: string, params: unknown[] = []) => run(uid, sql, params, 'commit');
/** تجربة من غير ما حاجة تتحفظ: null = نجحت، أو رسالة الخطأ */
const tryAs = (uid: string, sql: string, params: unknown[] = []) => run(uid, sql, params, 'rollback').then(() => null, (e: Error) => e.message);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
const FROM = new Date(Date.now() - 86400_000).toISOString();
const TO = new Date(Date.now() + 86400_000).toISOString();
const DENIED = /E_FORBIDDEN|permission denied|row-level security/;
const ROLES = ['reception', 'branch_manager', 'technician', 'cashier', 'accountant'] as const;
type Role = (typeof ROLES)[number];

d('(34) مصفوفة الصلاحيات', () => {
  let O = '';
  const U = {} as Record<Role, string>;
  let main = '';
  const B2 = id();
  const [cust, dev, devB, item, sup] = [id(), id(), id(), id(), id()];
  const [chq, entryMain, entryB, capital] = [id(), id(), id(), id()];
  const E: Record<string, string> = {};
  const [custX, supX, itemX, devX] = [id(), id(), id(), id()];
  let payB = '';
  let cashB = '';
  let shop = '';
  let step = '';
  let stepB = '';
  let route = '';
  let tech2 = '';
  let cash = '';
  let bank = '';
  let rent = '';

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pm-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل المصفوفة')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    // سبع موظفين أكتر من حد الخطة المجانية
    await admin(`set session_replication_role = replica`);
    await admin(`update shops set plan_code = (select code from plans where max_staff is null limit 1) where id = $1`, [shop]);
    await admin(`set session_replication_role = origin`);
    await as(O, `select save_branch($1, 'فرع تاني', 'P2', null, null)`, [B2]);
    const acc = async (b: string, m: string) => (await admin(`select id from accounts where shop_id = $1 and branch_id = $2 and method = $3`, [shop, b, m])).rows[0].id;
    cash = await acc(main, 'cash');
    bank = await acc(main, 'bank_transfer');
    cashB = await acc(B2, 'cash');
    rent = (await admin(`select id from accounts where shop_id = $1 and code = 'exp_rent'`, [shop])).rows[0].id;
    for (const r of ROLES) {
      const roleId = (await admin(`select id from roles where shop_id = $1 and preset = $2`, [shop, r])).rows[0].id;
      const em = `pm-${r}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role, role_ids, branch_ids) values (gen_random_uuid(), $1, $2, $3, $4, $5)`, [em, r, r === 'technician' ? 'technician' : 'reception', [roleId], [main]]);
      U[r] = await user(em);
      await as(U[r], `select bootstrap_account($1)`, [r]);
    }
    const em2 = `pm-t2-${tag}@p.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, 'فني تاني', 'technician', $2)`, [em2, [main]]);
    tech2 = await user(em2);
    await as(tech2, `select bootstrap_account('فني تاني')`);

    E.capital = (await as(O, `select owner_capital($1, $2, 5000000) e`, [capital, cash])).rows[0].e;
    await as(O, `select owner_capital($1, $2, 1000000)`, [id(), cashB]);
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل المصفوفة', $2)`, [cust, `0109${String(Date.now()).slice(-7)}`]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد المصفوفة')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'جراب')`, [item]);
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item, qty: 20, unit_cost: 2000 }])]);
    E.sale = (await as(O, `select record_sale($1, $2::jsonb, null, $3) e`, [id(), JSON.stringify([{ item, qty: 2, price: 50000 }]), cust])).rows[0].e;
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل للحذف', '01077778888')`, [custX]);
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد للحذف')`, [supX]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'صنف للحذف')`, [itemX]);
    await as(O, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $3, 'Oppo', 'A78', 'شحن', $4), ($2, $3, 'Vivo', 'Y20-B2', 'شحن', $5)`, [dev, devB, cust, main, B2]);
    await as(O, `insert into device_costs(shop_id, device_id, final_cost) values (gen_random_uuid(), $1, 50000), (gen_random_uuid(), $2, 60000)`, [dev, devB]);
    // جهاز من غير فلوس للحذف
    await as(O, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $2, 'Oppo', 'F11', 'شحن', $3)`, [devX, cust, main]);
    route = (await admin(`select id from routes where shop_id = $1 and deleted_at is null and not diagnose and array_length(steps, 1) > 0 limit 1`, [shop])).rows[0].id;
    for (const x of [dev, devB]) {
      await as(O, `select set_route($1, $2)`, [x, route]);
      await as(O, `select set_device_passcode($1, 'pin', '4821')`, [x]);
    }
    // الجهازين على الفني التاني بس
    await admin(`update repair_steps set technician_id = $2 where device_id = any ($1) and status = 'pending'`, [[dev, devB], tech2]);
    const firstStep = async (x: string) => (await admin(`select id from repair_steps where device_id = $1 and status = 'pending' order by step_no limit 1`, [x])).rows[0].id;
    step = await firstStep(dev);
    stepB = await firstStep(devB);
    await as(O, `select cheque_receive($1, $2, 'P-1', null, '2026-12-31', 1000)`, [chq, cust]);
    E.main = (await as(O, `select record_expense($1, $2, $3, 1000) e`, [entryMain, rent, cash])).rows[0].e;
    E.b2 = (await as(O, `select record_expense($1, $2, $3, 1000) e`, [entryB, rent, cashB])).rows[0].e;
    // تفاصيل الجهازين في كل الجداول
    for (const [x, box] of [[dev, cash], [devB, cashB]]) {
      await as(O, `insert into device_notes(id, shop_id, device_id, body) values ($1, gen_random_uuid(), $2, 'ملاحظة')`, [id(), x]);
      await as(O, `insert into device_photos(id, shop_id, device_id, storage_path) values ($1, gen_random_uuid(), $2, $3)`, [id(), x, `${shop}/${x}/a.jpg`]);
      await as(O, `insert into device_checks(id, shop_id, device_id, stage, items) values ($1, $2, $3, 'intake', '{"screen":"ok"}')`, [id(), shop, x]);
      await as(O, `insert into message_log(id, shop_id, device_id, customer_id, template_key, body) values ($1, $2, $3, $4, 'ready', 'رسالة')`, [id(), shop, x, cust]);
      await as(O, `select * from start_photo_upload($1)`, [x]);
      const pay = id();
      await as(O, `select record_payment($1, $2, $3, 500, $4)`, [pay, cust, box, x]);
      payB = pay;
      await admin(`insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${shop}/${x}/a.jpg`]);
    }
    E.advance = (await as(O, `select give_advance($1, $2, $3, 1000) e`, [id(), U.technician, cash])).rows[0].e;
  }, 120_000);
  afterAll(async () => db?.end());

  const sale = (price: number) => JSON.stringify([{ item, qty: 1, price }]);
  const buy = () => JSON.stringify([{ item, qty: 1, unit_cost: 2000 }]);
  const M: Role = 'branch_manager';
  const R: Role = 'reception';
  const T: Role = 'technician';
  const C: Role = 'cashier';
  const A: Role = 'accountant';

  // [الاسم، الاستعلام، المدخلات، مين مسموحله غير صاحب المحل]
  const matrix = (): [string, string, unknown[], Role[]][] => [
    // التقارير والوضع المالي
    ['day_cash_report', `select day_cash_report($1, $2)`, [FROM, TO], [M, A]],
    ['financial_position', `select financial_position($1, $2)`, [FROM, TO], [M, A]],
    ['pl_breakdown', `select * from pl_breakdown($1, $2)`, [FROM, TO], [M, A]],
    ['vat_report', `select vat_report($1, $2)`, [FROM, TO], [M, A]],
    ['trial_balance', `select * from trial_balance()`, [], [M, A]],
    ['party_balances suppliers', `select * from party_balances('suppliers')`, [], [M, A]],
    ['party_balances employees', `select * from party_balances('employees')`, [], []],
    ['issue_report', `select * from issue_report($1, $2)`, [FROM, TO], [M, A]],
    ['models_report', `select * from models_report($1, $2)`, [FROM, TO], [M, A]],
    ['inventory_summary', `select inventory_summary($1, $2)`, [FROM, TO], [M, A]],
    ['tech_report (المحل كله)', `select * from tech_report($1, $2)`, [FROM, TO], []],
    ['cashbox_daily (المحل كله)', `select * from cashbox_daily($1, $2)`, [FROM, TO], []],
    // الشيكات
    ['cheques_list', `select * from cheques_list()`, [], [M, A]],
    ['cheque_receive بجهاز', `select cheque_receive($1, $2, 'P-2', null, '2026-12-31', 1000, null, $3)`, [id(), cust, dev], []],
    ['cheque_issue', `select cheque_issue($1, $2, 'P-3', null, '2026-12-31', 1000)`, [id(), sup], []],
    ['cheque_clear', `select cheque_clear($1, $2, $3)`, [id(), chq, bank], []],
    ['cheque_bounce', `select cheque_bounce($1, $2, 'رصيد')`, [id(), chq], []],
    // المخزون
    ['stock_in', `select stock_in($1, $2, 1, 2000, 'تسوية')`, [id(), item], [M, A]],
    ['write_off', `select write_off($1, $2, 1, 'اتكسر')`, [id(), item], [M]],
    ['transfer_stock', `select transfer_stock($1, $2, 1, $3, $4)`, [id(), item, main, B2], [M]],
    ['create_item', `select create_item($1, 'part', 'صنف جديد')`, [id()], []],
    ['item_moves', `select * from item_moves($1)`, [item], [M, A]],
    ['record_purchase', `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, buy()], [M]],
    ['pay_supplier', `select pay_supplier($1, $2, $3, 1000)`, [id(), sup, cash], [M]],
    ['supplier_return', `select supplier_return($1, $2, $3, 1, 2000, null, 'عيب')`, [id(), sup, item], [M]],
    // البيع والخزن
    ['record_sale', `select record_sale($1, $2::jsonb, $3)`, [id(), sale(5000), cash], [R, M, C]],
    ['sale_return', `select sale_return($1, $2, 1, 5000, $3, null, true, 'رجع')`, [id(), item, cash], [R, M, C]],
    ['record_payment', `select record_payment($1, $2, $3, 1000)`, [id(), cust, cash], [R, M, C]],
    ['record_expense', `select record_expense($1, $2, $3, 1000)`, [id(), rent, cash], [M, A]],
    ['transfer_cash', `select transfer_cash($1, $2, $3, 100)`, [id(), cash, bank], [M]],
    // الأجهزة
    ['device_money', `select device_money($1)`, [dev], [R, M]],
    ['suggest_device_price', `select suggest_device_price($1)`, [dev], [R, M]],
    ['device_vat', `select device_vat($1)`, [dev], [R, M, A]],
    ['device_parts', `select * from device_parts($1)`, [dev], [R, M]],
    ['device_manual_part', `select device_manual_part($1, $2, 'قطعة', 1000, $3)`, [id(), dev, cash], [R, M]],
    ['set_device_passcode', `select set_device_passcode($1, 'pin', '1111')`, [dev], [R, M]],
    ['reveal_device_passcode (فني مش جهازه)', `select * from reveal_device_passcode($1)`, [dev], []],
    ['set_route', `select set_route($1, $2)`, [dev, route], [R, M]],
    ['reassign_step', `select reassign_step($1, $2)`, [step, tech2], [R, M]],
    ['start_photo_upload', `select * from start_photo_upload($1)`, [dev], [R, M]],
    ['apply_status_lww', `select apply_status_lww($1, 'inspecting', now() + interval '1 hour')`, [dev], [R, M]],
    ['send_device', `select send_device($1, $2)`, [dev, B2], [R, M]],
    ['use_part (فني مش جهازه)', `select use_part($1, $2, $3)`, [id(), dev, item], []],
    ['deliver_on_credit', `select deliver_on_credit($1)`, [dev], []],
    ['marketing_due', `select * from marketing_due()`, [], [R, M]],
    // صاحب المحل بس
    ['export_backup', `select export_backup()`, [], []],
    ['owner_capital', `select owner_capital($1, $2, 100)`, [id(), cash], []],
    ['give_advance', `select give_advance($1, $2, $3, 100)`, [id(), U.technician, cash], []],
    ['set_staff_override', `select set_staff_override($1, 'finance', 'view', true)`, [U.reception], []],
    ['set_can_correct', `select set_can_correct($1, true)`, [U.reception], []],
    // التصحيح والحذف: "يحذف" في أي قسم (مدير الفرع معاه حذف المخزون)
    ['reverse_entry', `select reverse_entry($1, 'غلط')`, [E.main], [M]],
    ['entry_args', `select entry_args($1)`, [E.main], [M]],
    ['reverse_entry سلفة موظف', `select reverse_entry($1, 'غلط')`, [E.advance], []],
    ['entry_args سلفة موظف', `select entry_args($1)`, [E.advance], []],
    ['reverse_entry رأس المال', `select reverse_entry($1, 'غلط')`, [E.capital], []],
    ['soft_delete جهاز', `select soft_delete('device', $1, 'غلط')`, [devX], [M]],
    ['soft_delete عميل', `select soft_delete('customer', $1, 'غلط')`, [custX], [M]],
    ['soft_delete مورد', `select soft_delete('supplier', $1, 'غلط')`, [supX], [M]],
    ['soft_delete صنف', `select soft_delete('item', $1, 'غلط')`, [itemX], [M]],
    ['طباعة فاتورة البيع', `select sale_invoice($1)`, [E.sale], [R, M, C, A]],
    // الجداول مباشرة
    ['إضافة عميل', `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'جديد', '01055556666')`, [id()], [R, M, C]],
    ['استلام جهاز', `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'x', 'y', 'z')`, [id(), cust], [R, M]],
    ['إضافة مورد', `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'جديد')`, [id()], [M]],
  ];

  it('كل دالة حساسة: صاحب المحل بينفذها، والأدوار زي الجدول بالظبط', async () => {
    const wrong: string[] = [];
    for (const [name, sql, params, allowed] of matrix()) {
      const own = await tryAs(O, sql, params);
      // التسليم بالآجل: الجهاز لسه مش "جاهز"، فصاحب المحل بيعدّي الصلاحية ويقف عند الانتقال
      if (own && own !== 'E_BAD_TRANSITION') wrong.push(`owner ${name}: ${own}`);
      for (const r of ROLES) {
        const e = await tryAs(U[r], sql, params);
        if (allowed.includes(r) ? e !== null : e === null || !DENIED.test(e)) wrong.push(`${r} ${name}: ${e ?? 'اتنفذت'}`);
      }
    }
    expect(wrong).toEqual([]);
  }, 120_000);

  it('القراية من الجداول مباشرة: كل دور بيشوف قسمه بس', async () => {
    const tables: [string, Role[]][] = [
      ['devices', [R, M]],
      ['device_costs', [R, M]],
      ['customers', [R, M, C, A]],
      ['suppliers', [M, A]],
      ['journal_entries', [M, A]],
      ['journal_lines', [M, A]],
      ['stock_moves', [M, A]],
      ['audit_log', [M, A]],
    ];
    const wrong: string[] = [];
    for (const [t, allowed] of tables) {
      for (const r of ROLES) {
        const n = await run(U[r], `select 1 from ${t} limit 1`, [], 'rollback').then((x) => x.rowCount, () => 0);
        if ((n ?? 0) > 0 !== allowed.includes(r)) wrong.push(`${r} ${t}: ${n}`);
      }
    }
    expect(wrong).toEqual([]);
  });

  it('الفرع التاني: ولا مدير الفرع ولا الاستقبال يوصلوا لجهاز أو قيد فيه، حتى بالـ id', async () => {
    const calls: [string, unknown[]][] = [
      [`select device_money($1)`, [devB]],
      [`select suggest_device_price($1)`, [devB]],
      [`select device_vat($1)`, [devB]],
      [`select * from device_parts($1)`, [devB]],
      [`select device_manual_part($1, $2, 'قطعة', 1000, $3)`, [id(), devB, cash]],
      [`select set_device_passcode($1, 'pin', '1111')`, [devB]],
      [`select set_route($1, $2)`, [devB, route]],
      [`select reassign_step($1, $2)`, [stepB, tech2]],
      [`select * from start_photo_upload($1)`, [devB]],
      [`select apply_status_lww($1, 'inspecting', now() + interval '1 hour')`, [devB]],
      [`select send_device($1, $2)`, [devB, main]],
      [`select soft_delete('device', $1, 'غلط')`, [devB]],
      [`select record_payment($1, $2, $3, 500, $4)`, [id(), cust, cash, devB]],
      [`select reverse_entry($1, 'غلط')`, [E.b2]],
      [`select entry_args($1)`, [E.b2]],
    ];
    const wrong: string[] = [];
    for (const [sql, p] of calls)
      for (const r of [M, R] as Role[]) {
        const e = await tryAs(U[r], sql, p);
        if (!e || !/E_FORBIDDEN|E_NOT_FOUND/.test(e)) wrong.push(`${r} ${sql}: ${e ?? 'اتنفذت'}`);
      }
    expect(wrong).toEqual([]);
    // تقرير الموديلات: طلب كل الفروع أو الفرع التاني بيرجّع فرعه هو
    for (const b of [null, B2]) {
      const rows = (await as(U.branch_manager, `select label from models_report($1, $2, $3)`, [FROM, TO, b])).rows.map((x) => x.label);
      expect(rows).not.toContain('Vivo Y20-B2');
    }
  });

  it('عملاء التسويق: الموظف بيشوف أجهزة فرعه بس', async () => {
    await admin(`update customers set marketing_ok = true where id = $1`, [cust]);
    await admin(`alter table devices disable trigger user`);
    try {
      await admin(`update devices set status = 'delivered', delivered_at = now() - interval '200 days' where id = $1`, [devB]);
      expect((await as(O, `select device_id from marketing_due()`)).rows.map((x) => x.device_id)).toEqual([devB]);
      expect((await as(U.reception, `select device_id from marketing_due()`)).rows).toEqual([]);
    } finally {
      await admin(`update devices set status = 'received', delivered_at = null where id = $1`, [devB]);
      await admin(`alter table devices enable trigger user`);
    }
  });

  const CHILD = ['device_costs', 'payments', 'device_photos', 'device_notes', 'status_log', 'device_checks', 'repair_steps', 'message_log', 'device_passcodes', 'photo_upload_sessions'];
  const seen = async (u: string, t: string, x: string) => (await run(u, `select 1 from ${t} where device_id = $1`, [x], 'rollback').catch(() => ({ rowCount: 0 }))).rowCount ?? 0;

  it('تفاصيل جهاز الفرع التاني مش باينة لأي دور، ولا تفاصيل جهاز فني تاني للفني', async () => {
    const wrong: string[] = [];
    for (const t of CHILD) {
      // البيانات موجودة فعلًا، وصاحب المحل ومدير الفرع بيشوفوا المسموح
      if (!(await seen(O, t, devB))) wrong.push(`owner ${t} فاضي`);
      if (!(await seen(U.branch_manager, t, dev))) wrong.push(`branch_manager ${t} فاضي`);
      for (const r of ROLES) if (await seen(U[r], t, devB)) wrong.push(`${r} ${t} فرع تاني`);
      if (await seen(U.technician, t, dev)) wrong.push(`فني مش جهازه ${t}`);
      // الكاشير ملوش أجهزة (الدفعات بتاعة خزنته مسموحة)
      if (t !== 'payments' && (await seen(U.cashier, t, dev))) wrong.push(`cashier ${t}`);
    }
    expect(wrong).toEqual([]);
    for (const t of ['device_notes', 'device_photos', 'status_log', 'device_checks', 'repair_steps', 'device_passcodes']) expect(await seen(tech2, t, dev), t).toBeGreaterThan(0);
    for (const t of ['device_costs', 'payments', 'message_log']) expect(await seen(tech2, t, dev), t).toBe(0);
    // دفعة خزنة الفرع التاني
    expect((await as(U.reception, `select 1 from payments where id = $1`, [payB])).rowCount).toBe(0);
    // ملفات الصور نفسها
    const file = async (u: string, x: string) => (await as(u, `select 1 from storage.objects where bucket_id = 'device-photos' and name = $1`, [`${shop}/${x}/a.jpg`])).rowCount;
    expect([await file(O, devB), await file(U.reception, dev), await file(tech2, dev)]).toEqual([1, 1, 1]);
    expect([await file(U.reception, devB), await file(U.cashier, dev), await file(U.technician, dev)]).toEqual([0, 0, 0]);
    const up = (u: string, x: string) => tryAs(u, `insert into storage.objects(bucket_id, name) values ('device-photos', $1)`, [`${shop}/${x}/${id()}.jpg`]);
    expect(await up(U.reception, dev)).toBeNull();
    for (const [u, x] of [[U.reception, devB], [U.cashier, dev], [U.accountant, dev]]) expect(await up(u, x)).toMatch(DENIED);
  });

  it('الكتابة في تفاصيل جهاز فرع تاني مرفوضة، والكاشير ما يكتبش على أي جهاز', async () => {
    const writes = (x: string): [string, string, unknown[]][] => [
      ['update التكلفة', `update device_costs set estimated_cost = 1000 where device_id = $1 returning 1`, [x]],
      ['update الفحص', `update device_checks set items = '{"screen":"bad"}' where device_id = $1 returning 1`, [x]],
      ['insert الفحص', `insert into device_checks(id, shop_id, device_id, stage, items) values ($1, $2, $3, 'delivery', '{"screen":"ok"}')`, [id(), shop, x]],
      ['insert ملاحظة', `insert into device_notes(id, shop_id, device_id, body) values ($1, gen_random_uuid(), $2, 'x')`, [id(), x]],
      ['insert صورة', `insert into device_photos(id, shop_id, device_id, storage_path) values ($1, gen_random_uuid(), $2, $3)`, [id(), x, `${shop}/${x}/${id()}.jpg`]],
      ['إخفاء صورة', `update device_photos set deleted_at = now() where device_id = $1`, [x]],
      ['insert رسالة', `insert into message_log(id, shop_id, device_id, customer_id, template_key, body) values ($1, $2, $3, $4, 'ready', 'x')`, [id(), shop, x, cust]],
    ];
    const did = async (u: string, sql: string, p: unknown[]) => ((await run(u, sql, p, 'rollback').catch(() => ({ rowCount: 0 }))).rowCount ?? 0) > 0;
    const wrong: string[] = [];
    for (const [n, sql, p] of writes(devB)) {
      if (n !== 'إخفاء صورة' && !(await did(O, sql, p))) wrong.push(`owner ${n}`);
      for (const u of [U.branch_manager, U.reception, U.cashier, U.accountant, tech2]) if (await did(u, sql, p)) wrong.push(`فرع تاني ${n} ${u === tech2 ? 'فني' : ''}`);
    }
    for (const [n, sql, p] of writes(dev)) {
      if (n !== 'إخفاء صورة' && !(await did(U.reception, sql, p))) wrong.push(`reception ${n}`);
      if (await did(U.cashier, sql, p)) wrong.push(`cashier ${n}`);
      if (await did(U.technician, sql, p)) wrong.push(`فني مش جهازه ${n}`);
    }
    if (!(await did(tech2, writes(dev)[3][1], writes(dev)[3][2]))) wrong.push('الفني صاحب الجهاز ما كتبش ملاحظة');
    expect(wrong).toEqual([]);
  });

  it('خطوات الصيانة والتوزيع: الفني في فرعه بس', async () => {
    expect(await tryAs(tech2, `select start_step($1)`, [step])).toBeNull();
    expect(await tryAs(tech2, `select start_step($1)`, [stepB])).toMatch(/E_FORBIDDEN/);
    expect((await as(tech2, `select device_id from my_queue()`)).rows.map((x) => x.device_id)).toEqual([dev]);
    await admin(`update repair_steps set status = 'active' where id = $1`, [stepB]);
    expect(await tryAs(tech2, `select finish_step($1, '{"screen":"ok"}')`, [stepB])).toMatch(/E_FORBIDDEN/);
    await admin(`update repair_steps set status = 'pending' where id = $1`, [stepB]);
    // التوزيع التلقائي ما يديش جهاز الفرع التاني لفني مش هيشوفه
    const x = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $2, 'Oppo', 'A5', 'شحن', $3)`, [x, cust, B2]);
    await as(O, `select set_route($1, $2)`, [x, route]);
    expect((await admin(`select count(technician_id)::int n, count(*)::int t from repair_steps where device_id = $1 and status = 'pending'`, [x])).rows[0]).toMatchObject({ n: 0 });
    expect((await admin(`select count(*)::int t from repair_steps where device_id = $1 and status = 'pending'`, [x])).rows[0].t).toBeGreaterThan(0);
    expect(await tryAs(O, `select reassign_step($1, $2)`, [stepB, tech2])).toMatch(/E_TECH_BRANCH/);
    // اسم فني جهاز الفرع التاني
    expect((await as(U.reception, `select device_tech_name($1) n`, [devB])).rows[0].n).toBeNull();
    expect((await as(U.reception, `select device_tech_name($1) n`, [dev])).rows[0].n).toBe('فني');
  });

  it('جهاز اتنقل لفرع تاني واتستلم: خطواته بتخرج من فني الفرع القديم، والتحصيل الأوفلاين القديم بيتسجل', async () => {
    const x = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $2, 'Oppo', 'A9', 'شحن', $3)`, [x, cust, main]);
    await as(O, `select set_route($1, $2)`, [x, route]);
    await admin(`update repair_steps set technician_id = $2, status = case when step_no = (select min(step_no) from repair_steps where device_id = $1 and status = 'pending') then 'active' else status end where device_id = $1 and status = 'pending'`, [x, tech2]);
    await as(O, `select send_device($1, $2)`, [x, B2]);
    await as(O, `select receive_device($1)`, [x]);
    const open = (await admin(`select technician_id, status from repair_steps where device_id = $1 and status in ('pending', 'active')`, [x])).rows;
    expect(open.length).toBeGreaterThan(0);
    for (const o of open) expect(o).toEqual({ technician_id: null, status: 'pending' });
    // الاستقبال حصّلت كاش أوفلاين قبل النقل
    expect(await tryAs(U.reception, `select record_payment($1, $2, $3, 500, $4)`, [id(), cust, cash, x])).toBeNull();
  });

  it('مرتجع ضمان: ما يروحش لفني اتنقل من الفرع', async () => {
    const x = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $2, 'Oppo', 'A3', 'شحن', $3)`, [x, cust, B2]);
    const sp = (await admin(`select specialty_id from repair_steps where id = $1`, [step])).rows[0].specialty_id;
    await admin(`update repair_steps set status = 'skipped' where device_id = $1`, [x]);
    await admin(`insert into repair_steps(shop_id, device_id, route_id, step_no, specialty_id, technician_id, status) values ($1, $2, $3, 90, $4, $5, 'done')`, [shop, x, route, sp, tech2]);
    await admin(`set session_replication_role = replica`);
    await admin(`update devices set status = 'delivered', delivered_at = now() where id = $1`, [x]);
    await admin(`set session_replication_role = origin`);
    await as(O, `update devices set status = 'warranty_return' where id = $1`, [x]);
    expect((await admin(`select technician_id from repair_steps where device_id = $1 and step_no > 90`, [x])).rows).toEqual([{ technician_id: null }]);
  });

  it('جهاز في الطريق لفرع الموظف: بيشوفه وبيستلمه، وما يعدّلوش قبل الاستلام', async () => {
    await as(O, `select send_device($1, $2)`, [devB, main]);
    try {
      expect(await tryAs(U.reception, `select device_money($1)`, [devB])).toBeNull();
      for (const [sql, p] of [
        [`select set_route($1, $2)`, [devB, route]],
        [`select set_device_passcode($1, 'pin', '1111')`, [devB]],
        [`select apply_status_lww($1, 'inspecting', now() + interval '1 hour')`, [devB]],
        [`select device_manual_part($1, $2, 'قطعة', 1000, $3)`, [id(), devB, cash]],
      ] as [string, unknown[]][])
        expect(await tryAs(U.reception, sql, p), sql).toMatch(/E_FORBIDDEN/);
      expect(await tryAs(U.branch_manager, `select soft_delete('device', $1, 'غلط')`, [devB])).toMatch(/E_FORBIDDEN/);
      for (const t of ["device_costs set estimated_cost = 1", "device_checks set items = '{\"screen\":\"bad\"}'"])
        expect(await tryAs(U.reception, `update ${t} where device_id = $1`, [devB]), t).toMatch(DENIED);
      for (const r of [C, A, T] as Role[]) expect(await tryAs(U[r], `select receive_device($1)`, [devB]), r).toMatch(DENIED);
      expect(await tryAs(U.reception, `select receive_device($1)`, [devB])).toBeNull();
      // نوع الفرع ما يحبسش الجهاز في الطريق
      await as(O, `select set_branch_kind($1, 'sales')`, [main]);
      expect(await tryAs(U.reception, `select receive_device($1)`, [devB])).toBeNull();
      for (const r of [C, A, T] as Role[]) expect(await tryAs(U[r], `select cancel_device_transfer($1)`, [devB]), r).toMatch(DENIED);
      expect(await tryAs(U.reception, `select cancel_device_transfer($1)`, [devB])).toBeNull();
      expect(await tryAs(U.reception, `select * from marketing_due()`)).toBeNull();
    } finally {
      await as(O, `select set_branch_kind($1, 'both')`, [main]);
      await as(O, `select cancel_device_transfer($1)`, [devB]);
    }
  });

  it('سداد الضريبة لصاحب المحل بس، فإلغاؤه كمان', async () => {
    const shopId = (await as(O, `select current_shop_id() s`)).rows[0].s;
    const e = id();
    const tax = (await admin(`select id from accounts where shop_id = $1 and code = 'vat_payable'`, [shopId])).rows[0].id;
    // قيد سداد ضريبة زي اللي pay_vat بيعمله
    await db.query('begin');
    await db.query(`insert into journal_entries(id, shop_id, source_type, source_id, created_by, branch_id) values ($1, $2, 'vat_payment', $1, $3, $4)`, [e, shopId, O, main]);
    await db.query(`insert into journal_lines(shop_id, entry_id, account_id, debit, credit) values ($1, $2, $3, 500, 0), ($1, $2, $4, 0, 500)`, [shopId, e, tax, cash]);
    await db.query('commit');
    expect(await tryAs(U.branch_manager, `select reverse_entry($1, 'غلط')`, [e])).toMatch(/E_FORBIDDEN/);
    expect(await tryAs(O, `select reverse_entry($1, 'غلط')`, [e])).toBeNull();
  });

  it('رصيد الصنف في الفروع: القيمة (التكلفة) لأصحاب صلاحية المبالغ بس، والفني ما يشوفهاش', async () => {
    const val = async (u: string) => (await as(u, `select value from item_branch_stock($1) where branch_id = $2`, [item, main])).rows[0].value;
    expect(await val(O)).toBe('36000');
    expect(await val(U.branch_manager)).toBe('36000');
    for (const r of [R, T, C] as Role[]) expect(await val(U[r]), r).toBeNull();
  });

  it('الفني صاحب الجهاز بيفتح كلمة السر وبيصرف قطعة، والحالة بتتغير عادي', async () => {
    expect(await tryAs(tech2, `select * from reveal_device_passcode($1)`, [dev])).toBeNull();
    expect(await tryAs(tech2, `select use_part($1, $2, $3)`, [id(), dev, item])).toBeNull();
    expect(await tryAs(tech2, `select apply_status_lww($1, 'inspecting', now() + interval '1 hour')`, [dev])).toBeNull();
    // وفي الفرع التاني لأ، حتى لو متعيّن عليه
    expect(await tryAs(tech2, `select * from reveal_device_passcode($1)`, [devB])).toMatch(/E_FORBIDDEN|E_NOT_FOUND/);
  });

  it('البيع المجاني: صلاحية مبالغ المخزون + البيع (مدير الفرع بس من الخمسة)، والحذف المباشر للعميل مش لحد', async () => {
    const free = JSON.stringify([{ item, qty: 1, price: 0, reason: 'هدية' }, { item, qty: 1, price: 5000 }]);
    for (const r of ROLES) {
      const e = await tryAs(U[r], `select record_sale($1, $2::jsonb, $3)`, [id(), free, cash]);
      if (r === M) expect(e).toBeNull();
      else expect(e, r).toMatch(/E_FORBIDDEN|E_FREE_SALE/);
      expect((await run(U[r], `update customers set deleted_at = now() where id = $1 returning 1`, [cust], 'rollback').catch(() => ({ rowCount: 0 }))).rowCount, r).toBe(0);
    }
  });
});
