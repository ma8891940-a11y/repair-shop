// استرجاع النسخة الاحتياطية لمحل جديد فاضي: نسخة من محل فيه شغل حقيقي (فلوس ومخزون وأجهزة وموظفين)،
// وبعدين محل جديد بيسترجعها، وكل الأرقام بتتقارن: رصيد كل حساب، والوضع المالي، والعملاء والموردين والموظفين،
// والمخزون، والأجهزة، والدفتر متوازن.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

// كل اللي الملف ده بيعمله في قاعدة الاختبار بيتمسح في الآخر
cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function as(uid: string | null, sql: string, params: unknown[] = []) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify({ 'x-forwarded-for': '10.88.0.1' })]);
    if (uid) {
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
    } else {
      await db.query(`select set_config('request.jwt.claims', '', true)`);
      await db.query('set local role anon');
    }
    const r = await db.query(sql, params);
    await db.query('commit');
    return r;
  } catch (e) {
    await db.query('rollback');
    throw e;
  }
}
const tag = randomUUID().slice(0, 8);
const id = () => randomUUID();
const ph = () => `011${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
async function staff(owner: string, name: string, role: string) {
  const em = `${name}-${tag}@r.test`;
  await as(owner, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, name, role]);
  const u = await user(em);
  await as(u, `select bootstrap_account($1)`, [name]);
  return u;
}
async function newShop(name: string) {
  const o = await user(`rs-${name}-${randomUUID().slice(0, 6)}@r.test`);
  const s = (await as(o, `select (bootstrap_account('صاحب ${name}', $1)).shop_id as s`, [name])).rows[0].s as string;
  return { o, s };
}

/** كل الأرقام اللي لازم تطابق بين المحل الأصلي والمسترجع (من غير ids) */
async function numbers(o: string, s: string) {
  const all = `'2000-01-01'::timestamptz, now() + interval '1 day'`;
  const pos = (await as(o, `select financial_position(${all}) p`)).rows[0].p;
  // رصيد كل حساب من القيود مباشرة (بالكود، أو بالاسم والنوع للحسابات المضافة)
  const balances = Object.fromEntries(
    (await admin(`select coalesce(a.code, a.type || ':' || a.name) k, coalesce(sum(l.debit - l.credit), 0)::bigint b
                    from accounts a left join journal_lines l on l.account_id = a.id where a.shop_id = $1 group by 1 order by 1`, [s])).rows.map((r) => [r.k, Number(r.b)]),
  );
  const parties: Record<string, unknown[]> = {};
  const partnerRows = (await as(o, `select name, share_bp, joined_on::text, capital, current, total from partner_balances()`)).rows.map((r) => [r.name, r.share_bp, r.joined_on, Number(r.capital), Number(r.current), Number(r.total)]);
  for (const k of ['customers', 'suppliers', 'employees'])
    parties[k] = (await as(o, `select name, account, balance::bigint b from party_balances($1) order by name, account`, [k])).rows.map((r) => [r.name, r.account, Number(r.b)]);
  const stock = (await as(o, `select name, kind, qty::bigint, avg_cost::bigint, value::bigint from items_stock() order by name`)).rows.map((r) => [r.name, r.kind, Number(r.qty), Number(r.avg_cost), Number(r.value)]);
  const devices = (await admin(
    `select d.order_no, d.status, d.brand, d.model, d.issue, d.received_at, d.delivered_at, d.warranty_until, c.estimated_cost, c.final_cost, cu.name customer
       from devices d left join device_costs c on c.device_id = d.id left join customers cu on cu.id = d.customer_id where d.shop_id = $1 order by d.order_no`, [s])).rows;
  const entries = (await admin(
    `select e.entry_no, e.occurred_at, e.source_type, e.memo, (e.reverses_id is not null) rev, sum(l.debit)::bigint dr, sum(l.credit)::bigint cr
       from journal_entries e join journal_lines l on l.entry_id = e.id where e.shop_id = $1 group by e.id order by e.entry_no`, [s])).rows.map((r) => ({ ...r, dr: Number(r.dr), cr: Number(r.cr) }));
  const counts: Record<string, number> = {};
  for (const t of ['customers', 'devices', 'device_costs', 'status_log', 'device_notes', 'device_checks', 'journal_entries', 'journal_lines', 'payments', 'purchases', 'stock_moves', 'drawer_closings', 'items', 'suppliers', 'repair_steps', 'partners', 'profit_distributions', 'party_links', 'branch_goals', 'printers', 'print_templates', 'check_templates'])
    counts[t] = Number((await admin(`select count(*) n from ${t} where shop_id = $1`, [s])).rows[0].n);
  const unbalanced = Number((await admin(`select count(*) n from (select entry_id from journal_lines where shop_id = $1 group by entry_id having sum(debit) <> sum(credit)) x`, [s])).rows[0].n);
  const notes = (await admin(`select n.body, p.full_name from device_notes n left join profiles p on p.id = n.author_id where n.shop_id = $1 order by n.created_at`, [s])).rows;
  const statusLog = (await admin(`select l.old_status, l.new_status, p.full_name by from status_log l left join profiles p on p.id = l.changed_by where l.shop_id = $1 order by l.created_at, l.new_status`, [s])).rows;
  const drawers = (await admin(`select expected, counted, diff, p.full_name by from drawer_closings c left join profiles p on p.id = c.closed_by where c.shop_id = $1 order by c.created_at`, [s])).rows;
  const shop = (await admin(`select name, phone, address, receipt_terms, warranty_days, currency, payment_methods, default_margin_pct, extras, max_discount_pct from shops where id = $1`, [s])).rows[0];
  const templates = (await admin(`select key, body from message_templates where shop_id = $1 order by key`, [s])).rows;
  // الـ ids جديدة بعد الاسترجاع (مقصود)، وصاحب المحل اللي بيسترجع هو صاحب المحل في النسخة: بنقارن من غيرهم
  const owner = (await admin(`select full_name from profiles where id = $1`, [o])).rows[0].full_name as string;
  const out = { pos, balances, parties, partnerRows, stock, devices, entries, counts, unbalanced, notes, statusLog, drawers, shop, templates };
  return JSON.parse(JSON.stringify(out).replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g, '<id>').split(owner).join('<owner>')) as typeof out;
}

let A = { o: '', s: '' };
let R = '';
let T = '';
let backup: Record<string, unknown> = {};
let before: Awaited<ReturnType<typeof numbers>>;
const dev: string[] = [];

d('استرجاع النسخة الاحتياطية لمحل جديد فاضي', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    A = await newShop(`محل أصلي ${tag}`);
    R = await staff(A.o, 'استقبال الأصلي', 'reception');
    T = await staff(A.o, 'فني الأصلي', 'technician');
    const acc: Record<string, string> = {};
    for (const r of (await as(A.o, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    const [cash, wallet, bank] = [acc.cash_cash, acc.cash_wallet, acc.cash_bank_transfer];
    // الاستقبال مسؤولة عن كاش الدرج (من الإعدادات)، فهي اللي بتقفله
    await as(A.o, `select update_account($1, p_holder => $2)`, [cash, R]);
    await as(A.o, `update shops set phone = '0225550000', address = 'شارع التحرير', receipt_terms = 'شروط محل الأصل', warranty_days = 45, max_discount_pct = 15, default_margin_pct = 25 where id = $1`, [A.s]);
    await as(A.o, `update message_templates set body = 'أهلًا {{name}}، جهازك {{order}} اتسجّل في محل الأصل' where key = 'received'`);

    // مخزون وموردين
    const [sup, screen, cases] = [id(), id(), id()];
    await as(A.o, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الأصل')`, [sup]);
    await as(A.o, `insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة A54', 90000), ($2, gen_random_uuid(), 'accessory', 'جراب', 7500)`, [screen, cases]);
    await as(A.o, `select owner_capital($1, $2, 3000000)`, [id(), cash]);
    await as(A.o, `select owner_capital($1, $2, 1500000)`, [id(), bank]);
    await as(A.o, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: screen, qty: 5, unit_cost: 40000 }])]);
    await as(A.o, `select record_purchase($1, $2, $3::jsonb, $4)`, [id(), sup, JSON.stringify([{ item: cases, qty: 30, unit_cost: 2500 }]), cash]);
    await as(A.o, `select record_expense($1, $2, $3, 400000, 'إيجار')`, [id(), acc.exp_rent, cash]);
    // (البند 5) شريك برأس مال وتوزيع أرباح وسحب: لازم يرجعوا زي ما هما
    const partner = id();
    await as(A.o, `insert into partners(id, shop_id, name, share_bp, joined_on) values ($1, gen_random_uuid(), 'شريك النسخة', 2500, '2026-01-01')`, [partner]);
    await as(A.o, `select partner_deposit($1, $2, $3, 700000)`, [id(), partner, cash]);
    // (البند 6) عميل مربوط بمورد ومقاصة بينهم
    const linkCust = id();
    const linkSup = id();
    await as(A.o, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'تاجر مربوط', '01099990000')`, [linkCust]);
    await as(A.o, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'تاجر مربوط')`, [linkSup]);
    await as(A.o, `select opening_balance($1, 'customer', $2, 30000)`, [id(), linkCust]);
    await as(A.o, `select opening_balance($1, 'supplier', $2, 20000)`, [id(), linkSup]);
    const linkId = id();
    await as(A.o, `select link_parties($1, $2, $3)`, [linkId, linkCust, linkSup]);
    await as(A.o, `select net_parties($1, $2, 15000)`, [id(), linkId]);
    await as(A.o, `select pay_supplier($1, $2, $3, 100000)`, [id(), sup, bank]);

    // عملاء وأجهزة
    const cust: string[] = [];
    for (const n of ['أحمد سمير', 'منى خالد', 'كريم فؤاد']) {
      const c = id();
      cust.push(c);
      await as(R, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), $2, $3)`, [c, n, ph()]);
    }
    for (const [i, c] of cust.entries()) {
      const dv = id();
      dev.push(dv);
      await as(R, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', $3, 'شاشة مكسورة')`, [dv, c, `A5${i}`]);
      await as(A.o, `insert into device_costs(id, shop_id, device_id, estimated_cost) values ($1, gen_random_uuid(), $2, 150000)`, [id(), dv]);
      await as(T, `insert into device_notes(id, shop_id, device_id, body) values ($1, gen_random_uuid(), $2, $3)`, [id(), dv, `ملاحظة الفني على الجهاز ${i + 1}`]);
    }
    await as(R, `select record_payment($1, $2, $3, 50000, $4)`, [id(), cust[0], cash, dev[0]]);
    await as(T, `select use_part($1, $2, $3, 1)`, [id(), dev[0], screen]);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(A.o, `update devices set status = $2 where id = $1`, [dev[0], st]);
    await as(A.o, `update device_costs set final_cost = 140000 where device_id = $1`, [dev[0]]);
    await as(R, `select record_payment($1, $2, $3, 90000, $4)`, [id(), cust[0], wallet, dev[0]]);
    await as(R, `update devices set status = 'delivered' where id = $1`, [dev[0]]);
    // جهاز اتسلّم بالآجل (العميل عليه فلوس)
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(A.o, `update devices set status = $2 where id = $1`, [dev[1], st]);
    await as(A.o, `update device_costs set final_cost = 120000 where device_id = $1`, [dev[1]]);
    await as(A.o, `select deliver_on_credit($1)`, [dev[1]]);
    await as(R, `select record_payment($1, $2, $3, 20000)`, [id(), cust[1], cash]);
    // بيع إكسسوارات، وتحويل، وسلفة ومرتب، وقيد عكسي لمصروف غلط
    await as(R, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: cases, qty: 3, price: 7500 }]), cash]);
    await as(A.o, `select transfer_cash($1, $2, $3, 300000)`, [id(), bank, cash]);
    await as(A.o, `select give_advance($1, $2, $3, 50000)`, [id(), T, cash]);
    await as(A.o, `select accrue_salary($1, $2, 400000)`, [id(), R]);
    await as(A.o, `select pay_salary($1, $2, $3, 250000)`, [id(), R, cash]);
    const wrong = (await as(A.o, `select record_expense($1, $2, $3, 12345, 'غلط') e`, [id(), acc.exp_electricity, cash])).rows[0].e;
    await as(A.o, `select reverse_entry($1, 'اتسجل بالغلط')`, [wrong]);
    // تقفيل الدرج بعجز 10 جنيه
    const exp = Number((await as(A.o, `select close_drawer($1, $2, 0) r`, [id(), wallet])).rows[0].r.expected);
    expect(exp).toBe(90000);
    const drawer = (await admin(`select coalesce(sum(l.debit - l.credit), 0)::bigint b from journal_lines l where l.account_id = $1`, [cash])).rows[0].b;
    await as(R, `select close_drawer($1, $2, $3)`, [id(), cash, Number(drawer) - 1000]);

    // توزيع أرباح كل الفترة لحد دلوقتي، وسحب الشريك من جاريه
    await as(A.o, `select distribute_profit($1, '2000-01-01', now() + interval '1 minute')`, [id()]);
    const pid = (await as(A.o, `select id from partners where name = 'شريك النسخة'`)).rows[0].id;
    await as(A.o, `select partner_withdraw($1, $2, $3, 1000)`, [id(), pid, cash]);

    // U3/U5/C2: أهداف الفروع، والطابعات، وقوالب الطباعة (بتشاور على الطابعة)، وقوالب الفحص لازم يرجعوا كمان
    const mainBr = (await admin(`select id from branches where shop_id = $1 and is_main`, [A.s])).rows[0].id;
    await as(A.o, `select save_goal($1, current_date, 'revenue', 5000000)`, [mainBr]);
    const prn = id();
    await as(A.o, `insert into printers(id, shop_id, name, kind, width_mm, margin_mm) values ($1, gen_random_uuid(), 'حراري الأصل', 'thermal80', 72, 3)`, [prn]);
    await as(A.o, `insert into print_templates(shop_id, doc, printer_id, name, blocks, is_default) values (gen_random_uuid(), 'invoice', $1, 'فاتورة الأصل', '[{"key":"total","show":true,"size":"lg","align":"start","bold":true}]', true)`, [prn]);
    await as(A.o, `insert into check_templates(shop_id, brand, items) values (gen_random_uuid(), 'samsung', '[{"key":"wifi"},{"key":"c_1","label":"فتحة الكارت"}]')`);

    before = await numbers(A.o, A.s);
    expect(before.unbalanced).toBe(0);
    expect(before.counts.printers).toBe(1);
    expect(before.counts.partners).toBe(1);
    expect(before.counts.profit_distributions).toBe(1);
    backup = (await as(A.o, `select export_backup() b`)).rows[0].b;
  }, 120_000);
  afterAll(async () => db?.end());

  it('محل جديد بيسترجع النسخة: كل الأرقام مطابقة بالظبط، والدفتر متوازن، والقيود زي ما هي', async () => {
    const B = await newShop(`محل جديد ${tag}`);
    const r = (await as(B.o, `select restore_backup($1::jsonb) r`, [JSON.stringify(backup)])).rows[0].r;
    expect(r.restored).toBe(true);
    const after = await numbers(B.o, B.s);
    expect(after.unbalanced).toBe(0);
    // رصيد كل حساب، والوضع المالي كله (النقدية، وليّا وعليّا، والمخزون، والإيراد والمصروف والربح، والمعادلة)
    expect(after.balances).toEqual(before.balances);
    expect(after.pos).toEqual(before.pos);
    expect(after.pos.balanced).toBe(true);
    expect(after.parties).toEqual(before.parties);
    expect(after.stock).toEqual(before.stock);
    expect(after.entries).toEqual(before.entries);
    expect(after.counts).toEqual(before.counts);
    // الأجهزة بأرقام طلباتها وحالاتها وتكاليفها ومواعيدها، والملاحظات والحالات والدرج بأسامي اللي عملوها
    expect(after.devices).toEqual(before.devices);
    expect(after.notes).toEqual(before.notes);
    expect(after.statusLog).toEqual(before.statusLog);
    expect(after.drawers).toEqual(before.drawers);
    expect(after.shop).toEqual({ ...before.shop, name: before.shop.name });
    expect(after.templates).toEqual(before.templates);
    // قالب الطباعة بيشاور على الطابعة الجديدة (مش القديمة)، وقالب الفحص زي ما هو
    expect((await admin(`select count(*)::int n from print_templates t join printers p on p.id = t.printer_id and p.shop_id = t.shop_id where t.shop_id = $1`, [B.s])).rows[0].n).toBe(1);
    expect((await admin(`select items from check_templates where shop_id = $1`, [B.s])).rows[0].items).toEqual([{ key: 'wifi' }, { key: 'c_1', label: 'فتحة الكارت' }]);
    // الأرقام نفسها مش صفر (السيناريو فيه شغل فعلًا)
    expect(before.counts.journal_entries).toBeGreaterThan(15);
    expect(before.pos.cash).toBeGreaterThan(0);
    // ليّا = العميل التاني عليه 1,000 (1,200 بالآجل − 200 دفعهم) + سلفة الفني 500 + التاجر المربوط 150 (300 − مقاصة 150)
    expect(before.pos.receivables).toBe(165000);
  });

  it('بعد الاسترجاع: الموظفين القدام "سابقين" ومحتاجين دعوة، ورقم الطلب الجاي بيكمل، والتتبع شغال، والمحل الأصلي ما اتلمسش', async () => {
    const B = await newShop(`محل تاني ${tag}`);
    await as(B.o, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    const staffB = (await admin(`select full_name, role, deleted_at is not null former from profiles where shop_id = $1 order by full_name`, [B.s])).rows;
    expect(staffB.filter((p) => p.former).map((p) => p.full_name).sort()).toEqual(['استقبال الأصلي', 'فني الأصلي']);
    expect(staffB.filter((p) => !p.former)).toHaveLength(1);
    // رقم الطلب الجاي بعد آخر رقم راجع
    const last = (await admin(`select max(order_no) m from devices where shop_id = $1`, [B.s])).rows[0].m as string;
    const c = id();
    await as(B.o, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل جديد', $2)`, [c, ph()]);
    const nd = id();
    await as(B.o, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Xiaomi', 'Note 13', 'بطارية')`, [nd, c]);
    const next = (await admin(`select order_no from devices where id = $1`, [nd])).rows[0].order_no as string;
    expect(Number(next.split('-')[1])).toBe(Number(last.split('-')[1]) + 1);
    // التتبع: المحل الأصلي لسه في نفس المشروع، فالجهاز الراجع خد كود جديد، والكود القديم لسه بتاع المحل الأصلي
    const tokA = (await admin(`select tracking_token t from devices where id = $1`, [dev[2]])).rows[0].t;
    const tokB = (await admin(`select tracking_token t from devices where shop_id = $1 and model = 'A52'`, [B.s])).rows[0].t;
    expect(tokB).not.toBe(tokA);
    expect((await as(null, `select shop_name from get_tracking(p_token => $1)`, [tokB])).rows[0].shop_name).toBe(`محل أصلي ${tag}`);
    // القيود الجديدة بعد الاسترجاع شغالة عادي والدفتر متوازن
    const cashB = (await admin(`select id from accounts where shop_id = $1 and code = 'cash_cash'`, [B.s])).rows[0].id;
    await as(B.o, `select record_payment($1, $2, $3, 10000)`, [id(), c, cashB]);
    expect(Number((await admin(`select count(*) n from (select entry_id from journal_lines where shop_id = $1 group by entry_id having sum(debit) <> sum(credit)) x`, [B.s])).rows[0].n)).toBe(0);
    // المحل الأصلي زي ما هو بالظبط
    expect(await numbers(A.o, A.s)).toEqual(before);
  });

  it('مشروع Supabase جديد (مفيش تعارض): كود التتبع (الـ QR) بيفضل زي ما هو', async () => {
    // بنمثّل المشروع الجديد بنسخة أكوادها مش موجودة هنا
    const copy = JSON.parse(JSON.stringify(backup)) as { devices: { tracking_token: string }[] };
    for (const dv of copy.devices) dv.tracking_token = randomUUID().replace(/-/g, '').slice(0, 24);
    const B = await newShop(`محل مشروع جديد ${tag}`);
    await as(B.o, `select restore_backup($1::jsonb)`, [JSON.stringify(copy)]);
    const toks = (await admin(`select tracking_token t from devices where shop_id = $1 order by order_no`, [B.s])).rows.map((r) => r.t).sort();
    expect(toks).toEqual(copy.devices.map((dv) => dv.tracking_token).sort());
  });

  it('ممنوع: على محل فيه شغل، أو مرتين، أو من غير صاحب المحل، أو ملف مش نسخة، أو على المحل نفسه', async () => {
    const B = await newShop(`محل فيه شغل ${tag}`);
    await as(B.o, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل قديم', $2)`, [id(), ph()]);
    await expect(as(B.o, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow(/E_RESTORE_NOT_EMPTY/);
    const C = await newShop(`محل مرتين ${tag}`);
    await as(C.o, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)]);
    await expect(as(C.o, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow(/E_RESTORE_NOT_EMPTY/);
    // الاستقبال والفني ما يقدروش (حتى في محل فاضي)
    const D = await newShop(`محل بموظف ${tag}`);
    const rec = await staff(D.o, `استقبال ${randomUUID().slice(0, 4)}`, 'reception');
    await expect(as(rec, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow(/E_FORBIDDEN/);
    await expect(as(null, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow();
    const E = await newShop(`محل ملف غلط ${tag}`);
    await expect(as(E.o, `select restore_backup($1::jsonb)`, [JSON.stringify({ format: 'x', version: 1 })])).rejects.toThrow(/E_BACKUP_FORMAT/);
    await expect(as(A.o, `select restore_backup($1::jsonb)`, [JSON.stringify(backup)])).rejects.toThrow(/E_BACKUP_FORMAT|E_RESTORE_NOT_EMPTY/);
    // لو أي رقم مش مطابق: الاسترجاع كله بيتلغي ومحدش بيتغيّر
    const bad = JSON.parse(JSON.stringify(backup)) as { journal_lines: { debit: number; credit: number }[] };
    const line = bad.journal_lines.find((l) => Number(l.debit) > 0)!;
    line.debit = Number(line.debit) + 1;
    const F = await newShop(`محل نسخة متلعّب فيها ${tag}`);
    await expect(as(F.o, `select restore_backup($1::jsonb)`, [JSON.stringify(bad)])).rejects.toThrow(/E_RESTORE|balanced|unbalanced|متوازن/i);
    expect(Number((await admin(`select count(*) n from devices where shop_id = $1`, [F.s])).rows[0].n)).toBe(0);
    expect(Number((await admin(`select count(*) n from journal_entries where shop_id = $1`, [F.s])).rows[0].n)).toBe(0);
  });

  it('وقت الاسترجاع بس التريجرات بتسيب الصفوف زي ما هي: بره الاسترجاع كل حاجة شغالة زي الأول', async () => {
    const G = await newShop(`محل عادي ${tag}`);
    const c = id();
    await as(G.o, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [c, ph()]);
    const dv = id();
    // حتى لو حد بعت رقم طلب وحالة بنفسه: رقم الطلب بيتولد والحالة "استلام" وسجل النشاط بيتسجل
    await as(G.o, `insert into devices(id, customer_id, brand, model, issue, order_no, status) values ($1, $2, 'Oppo', 'A78', 'شحن', '1999-9999', 'delivered')`, [dv, c]);
    const row = (await admin(`select order_no, status from devices where id = $1`, [dv])).rows[0];
    expect(row.order_no).not.toBe('1999-9999');
    expect(row.status).toBe('received');
    expect(Number((await admin(`select count(*) n from status_log where device_id = $1`, [dv])).rows[0].n)).toBe(1);
    expect(Number((await admin(`select count(*) n from audit_log where entity_id = $1 and action = 'insert'`, [dv])).rows[0].n)).toBe(1);
    // علامة الاسترجاع ما تتفعّلش من بره الدالة
    expect((await as(G.o, `select public.restoring() r`)).rows[0].r).toBe(false);
  });
});
