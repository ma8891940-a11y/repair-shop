// B. الفروع: الفرع الرئيسي، والبادئة، والمخزون والخزن لكل فرع، والتحويل بين الفروع، والموظف مربوط بفرعه (RLS)
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';

cleanupAfterFile();

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
/** branch = الفرع الشغال اللي التطبيق بيبعته في الهيدر x-branch-id */
async function as(uid: string, sql: string, params: unknown[] = [], branch?: string) {
  await db.query('begin');
  try {
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query(`select set_config('request.headers', $1, true)`, [JSON.stringify(branch ? { 'x-branch-id': branch } : {})]);
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
const year = new Date().getFullYear();

d('الفروع', () => {
  let O = '';
  let R2 = ''; // استقبال مربوط بفرع "المعادي" بس
  let shop = '';
  let main = '';
  const B2 = id();
  const acc: Record<string, string> = {};
  let cash2 = '';
  let sup = '';
  const glass = id();
  let custId = '';
  const bal = async (accId: string) => Number((await admin(`select coalesce(sum(debit - credit), 0) b from journal_lines where account_id = $1`, [accId])).rows[0].b);
  const stockAt = async (item: string, branch: string) =>
    (await admin(`select coalesce(sum(qty), 0)::int q, coalesce(sum(value), 0)::int v from stock_moves where item_id = $1 and branch_id = $2`, [item, branch])).rows[0];
  const newDevice = async (uid: string, branch?: string) => {
    const dv = id();
    await as(uid, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Oppo', 'A78', 'شحن')`, [dv, custId], branch);
    return (await admin(`select order_no, branch_id from devices where id = $1`, [dv])).rows[0] as { order_no: string; branch_id: string } & { id?: string };
  };

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`br-o-${tag}@b.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'محل الفروع')).shop_id s`)).rows[0].s;
    main = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop])).rows[0].id;
    for (const r of (await as(O, `select id, code from accounts where code is not null`)).rows) acc[r.code] = r.id;
    sup = id();
    await as(O, `insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'part', 'شاشة A78')`, [glass]);
    custId = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', $2)`, [custId, `0106${String(Date.now()).slice(-7)}`]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('المحل الجديد: فرع رئيسي واحد، والخزن الأساسية فيه، ورقم الطلب زي الأول (من غير بادئة)', async () => {
    expect((await admin(`select count(*)::int n from branches where shop_id = $1`, [shop])).rows[0].n).toBe(1);
    expect((await admin(`select count(*)::int n from accounts where shop_id = $1 and kind = 'cash' and branch_id is distinct from $2`, [shop, main])).rows[0].n).toBe(0);
    expect((await admin(`select count(*)::int n from accounts where shop_id = $1 and kind <> 'cash' and branch_id is not null`, [shop])).rows[0].n).toBe(0);
    const dv = await newDevice(O);
    expect(dv.order_no).toMatch(new RegExp(`^${year}-0001$`));
    expect(dv.branch_id).toBe(main);
  });

  it('فرع جديد ببادئة: خزنة لكل طريقة دفع، وأرقام طلبات لوحده (B2-سنة-0001)، والبادئة والاسم ما يتكرروش', async () => {
    await as(O, `select save_branch($1, 'فرع المعادي', 'b2', '0225000000', 'المعادي')`, [B2]);
    expect((await admin(`select prefix from branches where id = $1`, [B2])).rows[0].prefix).toBe('B2');
    const cbs = (await admin(`select id, method from accounts where branch_id = $1 order by method`, [B2])).rows;
    expect(cbs.map((r) => r.method)).toContain('cash');
    cash2 = cbs.find((r) => r.method === 'cash')!.id;
    await expect(as(O, `select save_branch($1, 'تاني', 'B2')`, [id()])).rejects.toThrow(/E_DUP_PREFIX/);
    await expect(as(O, `select save_branch($1, 'فرع المعادي', 'B3')`, [id()])).rejects.toThrow(/E_DUP_NAME/);
    await expect(as(O, `select save_branch($1, 'من غير بادئة', '')`, [id()])).rejects.toThrow(/E_BAD_PREFIX/);
    const a = await newDevice(O, B2);
    const b = await newDevice(O, B2);
    expect([a.order_no, b.order_no]).toEqual([`B2-${year}-0001`, `B2-${year}-0002`]);
    expect(a.branch_id).toBe(B2);
    // الرئيسي كمّل عدّه لوحده
    expect((await newDevice(O)).order_no).toBe(`${year}-0002`);
    // الرئيسي: البادئة ما بتتغيرش (الأرقام القديمة تفضل زي ما هي)
    await as(O, `select save_branch($1, 'الفرع الرئيسي - وسط البلد', 'ZZ')`, [main]);
    expect((await admin(`select name, prefix from branches where id = $1`, [main])).rows[0]).toEqual({ name: 'الفرع الرئيسي - وسط البلد', prefix: '' });
  });

  it('المخزون لكل فرع: شراء في الرئيسي، وتحويل 4 للمعادي بنفس التكلفة، وحساب المخزون زي ما هو، والبيع من غير رصيد في الفرع مرفوض', async () => {
    await as(O, `select record_purchase($1, $2, $3::jsonb)`, [id(), sup, JSON.stringify([{ item: glass, qty: 10, unit_cost: 30000 }])], main);
    expect(await stockAt(glass, main)).toEqual({ q: 10, v: 300000 });
    const inv0 = await bal(acc.inventory);
    const e = (await as(O, `select transfer_stock($1, $2, 4, $3, $4, 'نقل') e`, [id(), glass, main, B2])).rows[0].e;
    expect(await stockAt(glass, main)).toEqual({ q: 6, v: 180000 });
    expect(await stockAt(glass, B2)).toEqual({ q: 4, v: 120000 });
    expect(await bal(acc.inventory)).toBe(inv0);
    // بيع 5 من المعادي (فيه 4 بس) ← مرفوض، و4 بتكلفة 120,000
    await expect(as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: glass, qty: 5, price: 50000 }]), cash2], B2)).rejects.toThrow(/E_STOCK/);
    await as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: glass, qty: 4, price: 50000 }]), cash2], B2);
    expect(await stockAt(glass, B2)).toEqual({ q: 0, v: 0 });
    expect(await stockAt(glass, main)).toEqual({ q: 6, v: 180000 });
    expect(await bal(cash2)).toBe(200000);
    // التحويل نفسه بيتلغي بقيد عكسي؟ المعادي باع البضاعة خلاص ← مرفوض (المخزون مايبقاش بالسالب)
    await expect(as(O, `select reverse_entry($1, 'غلط')`, [e])).rejects.toThrow(/E_STOCK/);
    expect((await as(O, `select integrity_report() r`)).rows[0].r).toEqual([]);
  });

  it('عكس تحويل بضاعة بيرجّع كل فرع زي ما كان', async () => {
    const e = (await as(O, `select transfer_stock($1, $2, 2, $3, $4) e`, [id(), glass, main, B2])).rows[0].e;
    expect(await stockAt(glass, B2)).toEqual({ q: 2, v: 60000 });
    await as(O, `select reverse_entry($1, 'رجعت')`, [e]);
    expect(await stockAt(glass, main)).toEqual({ q: 6, v: 180000 });
    expect(await stockAt(glass, B2)).toEqual({ q: 0, v: 0 });
    expect((await admin(`select branch_id from journal_entries where reverses_id = $1`, [e])).rows[0].branch_id).toBe(main);
  });

  it('خزنة فرع تاني في عملية فرع ← مرفوض، وتحويل الفلوس بين خزن الفرعين مسموح', async () => {
    await expect(
      as(O, `insert into journal_entries(shop_id, source_type) values ($1, 'sale') returning id`, [shop]),
    ).rejects.toThrow(/permission denied|policy/);
    // بيع في الرئيسي بخزنة المعادي ← مرفوض (خزنة فرع تاني)
    await expect(as(O, `select record_sale($1, $2::jsonb, $3)`, [id(), JSON.stringify([{ item: glass, qty: 1, price: 50000 }]), cash2], main)).rejects.toThrow(/E_BRANCH_CASHBOX/);
    const before = (await bal(acc.cash_cash)) + (await bal(cash2));
    await as(O, `select transfer_cash($1, $2, $3, 50000)`, [id(), cash2, acc.cash_cash]);
    expect(await bal(cash2)).toBe(150000);
    expect((await bal(acc.cash_cash)) + (await bal(cash2))).toBe(before);
  });

  it('الوضع المالي بفلتر الفرع: خزن الفرع ومخزونه وإيراده بس، والمعادلة والتوازن للمحل كله', async () => {
    const F = new Date(Date.now() - 3600_000).toISOString();
    const T = new Date(Date.now() + 3600_000).toISOString();
    const pos = async (b?: string) => (await as(O, `select financial_position($1, $2, $3) p`, [F, T, b ?? null])).rows[0].p;
    const all = await pos();
    const p2 = await pos(B2);
    const pm = await pos(main);
    // المعادي: باع 4 بـ 200,000 وتكلفتهم 120,000، وحوّل 50,000 للرئيسي
    expect(p2.revenue).toBe(200000);
    expect(p2.expenses).toBe(120000);
    expect(p2.cash).toBe(150000);
    expect(p2.inventory).toBe(0);
    expect(pm.inventory).toBe(180000);
    expect(p2.cashboxes.every((c: { branch_id: string }) => c.branch_id === B2)).toBe(true);
    // الفروع مع بعض = المحل كله
    expect(pm.revenue + p2.revenue).toBe(all.revenue);
    expect(pm.cash + p2.cash).toBe(all.cash);
    expect(pm.inventory + p2.inventory).toBe(all.inventory);
    expect(p2.balanced).toBe(true);
    expect(p2.equation).toEqual(all.equation);
  });

  it('شريك على فرع: نصيبه من ربح الفرع بس، ومجموع النسب في الفرع مايعديش 100%', async () => {
    const F = new Date(Date.now() - 3600_000).toISOString();
    const T = new Date(Date.now() + 3600_000).toISOString();
    const shopP = id();
    const brP = id();
    await as(O, `insert into partners(id, shop_id, name, share_bp) values ($1, gen_random_uuid(), 'شريك المحل', 6000)`, [shopP]);
    // 60% على المحل كله + 50% على المعادي = 110% من ربح المعادي ← مرفوض
    await expect(as(O, `insert into partners(id, shop_id, name, share_bp, branch_id) values ($1, gen_random_uuid(), 'شريك المعادي', 5000, $2)`, [brP, B2])).rejects.toThrow(/E_SHARE_OVER_100/);
    await as(O, `insert into partners(id, shop_id, name, share_bp, branch_id) values ($1, gen_random_uuid(), 'شريك المعادي', 4000, $2)`, [brP, B2]);
    const sp = (await as(O, `select profit_split($1, $2) s`, [F, T])).rows[0].s;
    const of = (pid: string) => sp.shares.find((x: { partner: string }) => x.partner === pid);
    // ربح المعادي في الفترة: 200,000 مبيعات − 120,000 تكلفة = 80,000 ← 40% = 32,000
    expect(of(brP)).toMatchObject({ branch_id: B2, base: 80000, amount: 32000 });
    expect(of(shopP)).toMatchObject({ branch_id: null, base: sp.profit, amount: Math.trunc((sp.profit * 6000) / 10000) });
    const e = (await as(O, `select distribute_profit($1, $2, $3) e`, [id(), F, T])).rows[0].e;
    const lines = (await admin(`select party_id, credit - debit v from journal_lines where entry_id = $1 and party_id is not null`, [e])).rows;
    expect(Number(lines.find((l) => l.party_id === brP).v)).toBe(32000);
    const bal = (await as(O, `select branch_id from partner_balances() where id = $1`, [brP])).rows[0];
    expect(bal.branch_id).toBe(B2);
  });

  it('الموظف مربوط بفرعه: ما يشوفش أجهزة ولا خزن الفرع التاني، والهيدر بتاع فرع تاني بيتجاهل', async () => {
    const em = `br-r2-${tag}@b.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role, branch_ids) values (gen_random_uuid(), $1, 'استقبال المعادي', 'reception', $2)`, [em, [B2]]);
    R2 = await user(em);
    await as(R2, `select bootstrap_account('استقبال المعادي')`);
    expect((await as(R2, `select my_branch_ids() b`)).rows[0].b).toEqual([B2]);
    const seen = (await as(R2, `select distinct branch_id from devices`)).rows.map((r) => r.branch_id);
    expect(seen).toEqual([B2]);
    const cbs = (await as(R2, `select distinct branch_id from accounts`)).rows.map((r) => r.branch_id);
    expect(cbs).toEqual([B2]);
    // حتى لو بعت هيدر الرئيسي: الجهاز بيتسجل في فرعه
    const dv = await newDevice(R2, main);
    expect(dv.branch_id).toBe(B2);
    // ومايقدرش يحط جهاز في الرئيسي بإيده
    await expect(
      as(R2, `insert into devices(id, customer_id, brand, model, issue, branch_id) values ($1, $2, 'X', 'Y', 'Z', $3)`, [id(), custId, main]),
    ).rejects.toThrow(/E_FORBIDDEN|policy/);
    // ولا يستخدم خزنة الرئيسي
    await expect(as(R2, `select record_payment($1, $2, $3, 1000)`, [id(), custId, acc.cash_cash])).rejects.toThrow(/E_FORBIDDEN|E_BAD_ACCOUNT/);
    // الموظف من غير فروع محددة (دعوة قديمة) = الرئيسي بس
    const em3 = `br-r3-${tag}@b.test`;
    await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, 'استقبال قديم', 'reception')`, [em3]);
    const R3 = await user(em3);
    await as(R3, `select bootstrap_account('استقبال قديم')`);
    expect((await as(R3, `select my_branch_ids() b`)).rows[0].b).toEqual([main]);
    // صاحب المحل بيغيّر فروعه ← بيتطبق على طول، ومتسجل في سجل النشاط
    await as(O, `select set_staff_branches($1, $2)`, [R3, [main, B2]]);
    expect((await as(R3, `select my_branch_ids() b`)).rows[0].b).toEqual([main, B2]);
    expect((await admin(`select count(*)::int n from audit_log where action = 'staff_branches' and entity_id = $1`, [R3])).rows[0].n).toBe(1);
    await expect(as(R3, `select set_staff_branches($1, $2)`, [R3, [main]])).rejects.toThrow(/E_FORBIDDEN/);
  });

  it('جهاز "في الطريق للفرع": بيتبعت من الرئيسي، والمعادي بيشوفه ويستلمه، وفرعه ما بيتغيرش بتعديل مباشر', async () => {
    const dv = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Vivo', 'Y36', 'بوردة')`, [dv, custId], main);
    await expect(as(O, `update devices set branch_id = $2 where id = $1`, [dv, B2])).rejects.toThrow(/E_BRANCH_MOVE/);
    expect((await as(R2, `select count(*)::int n from devices where id = $1`, [dv])).rows[0].n).toBe(0);
    await as(O, `select send_device($1, $2)`, [dv, B2]);
    expect((await as(R2, `select transfer_to from devices where id = $1`, [dv])).rows[0].transfer_to).toBe(B2);
    await expect(as(O, `select send_device($1, $2)`, [dv, B2])).rejects.toThrow(/E_IN_TRANSIT/);
    await as(R2, `select receive_device($1)`, [dv]);
    const row = (await admin(`select branch_id, transfer_to, order_no from devices where id = $1`, [dv])).rows[0];
    expect(row.branch_id).toBe(B2);
    expect(row.transfer_to).toBeNull();
    expect(row.order_no).toMatch(new RegExp(`^${year}-`)); // رقمه زي ما هو
    expect((await admin(`select array_agg(action order by created_at) a from audit_log where entity_id = $1 and action like 'device_%'`, [dv])).rows[0].a).toEqual(['device_send', 'device_receive']);
  });

  it('قفل فرع: الرئيسي لأ، وفرع فيه أجهزة مفتوحة أو فلوس لأ', async () => {
    await expect(as(O, `select archive_branch($1)`, [main])).rejects.toThrow(/E_MAIN_BRANCH/);
    await expect(as(O, `select archive_branch($1)`, [B2])).rejects.toThrow(/E_HAS_OPEN_DEVICES|E_HAS_BALANCE/);
    const B3 = id();
    await as(O, `select save_branch($1, 'فرع مؤقت', 'B3')`, [B3]);
    await as(O, `select archive_branch($1)`, [B3]);
    expect((await admin(`select deleted_at is not null x from branches where id = $1`, [B3])).rows[0].x).toBe(true);
    expect((await admin(`select bool_and(not active) x from accounts where branch_id = $1`, [B3])).rows[0].x).toBe(true);
    // بادئته اتحررت
    await as(O, `select save_branch($1, 'فرع جديد', 'B3')`, [id()]);
  });

  it('النقل للفرع الرئيسي: نسخة قديمة (من غير فروع) بترجع كلها في الرئيسي، والأرصدة زي ما هي بالظبط', async () => {
    const b = (await as(O, `select export_backup() b`)).rows[0].b as Record<string, unknown[]>;
    // شكل البيانات قبل الفروع: من غير جداول الفروع ولا عمود الفرع، وكله في الرئيسي
    const legacy: Record<string, unknown> = { ...b };
    delete legacy.branches;
    delete legacy.staff_branches;
    const onlyMain = (rows: Record<string, unknown>[]) => rows.filter((r) => !('branch_id' in r) || r.branch_id === main || r.branch_id == null);
    for (const t of ['devices', 'journal_entries', 'stock_moves', 'accounts']) {
      const rows = onlyMain(b[t] as Record<string, unknown>[]);
      const ids = new Set(rows.map((r) => r.id));
      legacy[t] = rows.map(({ branch_id: _b, transfer_to: _t, transfer_at: _a, transfer_by: _y, ...r }) => r);
      if (t === 'journal_entries') legacy.journal_lines = (b.journal_lines as Record<string, unknown>[]).filter((l) => ids.has(l.entry_id));
    }
    // قيود الفرع التاني اتشالت من النسخة، فبنشيل اللي مربوط بيها
    const entryIds = new Set((legacy.journal_entries as Record<string, unknown>[]).map((r) => r.id));
    for (const t of ['payments', 'purchases', 'drawer_closings', 'profit_distributions']) legacy[t] = ((b[t] ?? []) as Record<string, unknown>[]).filter((r) => !r.entry_id || entryIds.has(r.entry_id));
    legacy.stock_moves = (legacy.stock_moves as Record<string, unknown>[]).filter((r) => entryIds.has(r.entry_id as string));
    legacy.journal_entries = (legacy.journal_entries as Record<string, unknown>[]).filter((r) => !r.reverses_id || entryIds.has(r.reverses_id as string));
    const devIds = new Set((legacy.devices as Record<string, unknown>[]).map((r) => r.id));
    for (const t of ['device_costs', 'status_log', 'device_notes', 'device_checks', 'device_photos', 'quote_decisions', 'repair_steps', 'device_ratings', 'message_log'])
      legacy[t] = ((b[t] ?? []) as Record<string, unknown>[]).filter((r) => !r.device_id || devIds.has(r.device_id));
    legacy.journal_entries = (legacy.journal_entries as Record<string, unknown>[]).filter((r) => !r.device_id || devIds.has(r.device_id));
    const keptEntries = new Set((legacy.journal_entries as Record<string, unknown>[]).map((r) => r.id));
    legacy.journal_lines = (legacy.journal_lines as Record<string, unknown>[]).filter((l) => keptEntries.has(l.entry_id));
    legacy.stock_moves = (legacy.stock_moves as Record<string, unknown>[]).filter((r) => keptEntries.has(r.entry_id));
    legacy.audit_log = [];
    legacy.partners = ((b.partners ?? []) as Record<string, unknown>[]).map(({ branch_id: _b, ...r }) => r);

    const O2 = await user(`br-o2-${tag}@b.test`);
    const shop2 = (await as(O2, `select (bootstrap_account('صاحب', 'محل جديد')).shop_id s`)).rows[0].s;
    await as(O2, `select restore_backup($1::jsonb)`, [JSON.stringify(legacy)]);
    const main2 = (await admin(`select id from branches where shop_id = $1 and is_main`, [shop2])).rows[0].id;
    for (const t of ['devices', 'journal_entries', 'stock_moves']) {
      expect((await admin(`select count(*)::int n from ${t} where shop_id = $1 and branch_id is distinct from $2`, [shop2, main2])).rows[0].n, t).toBe(0);
    }
    expect((await admin(`select count(*)::int n from accounts where shop_id = $1 and kind = 'cash' and branch_id is distinct from $2`, [shop2, main2])).rows[0].n).toBe(0);
    // الأرصدة: كل حساب = رصيده في النسخة (restore_backup بيتأكد من ده، وهنا تأكيد تاني بالرقم)
    const want = new Map<string, number>();
    for (const l of legacy.journal_lines as { account_id: string; debit: number; credit: number }[]) want.set(l.account_id, (want.get(l.account_id) ?? 0) + Number(l.debit) - Number(l.credit));
    const codeOf = new Map((b.accounts as { id: string; code: string | null; name: string | null; method: string | null }[]).map((a) => [a.id, a.code ?? `${a.name}|${a.method}`]));
    const got = (
      await admin(`select coalesce(a.code, a.name || '|' || a.method) k, sum(l.debit - l.credit)::bigint b from journal_lines l join accounts a on a.id = l.account_id where l.shop_id = $1 group by 1`, [shop2])
    ).rows;
    const gotMap = new Map(got.map((r) => [r.k, Number(r.b)]));
    for (const [acc, v] of want) expect(gotMap.get(codeOf.get(acc)!) ?? 0, codeOf.get(acc)).toBe(v);
    // ورقم الطلب الجاي بيكمّل بعد آخر رقم راجع
    const c2 = id();
    await as(O2, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'ع', '01077770000')`, [c2]);
    const nd = id();
    await as(O2, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'A', 'B', 'C')`, [nd, c2]);
    const maxOld = Math.max(...(legacy.devices as { order_no: string }[]).filter((x) => x.order_no.startsWith(`${year}-`)).map((x) => Number(x.order_no.split('-')[1])));
    expect((await admin(`select order_no from devices where id = $1`, [nd])).rows[0].order_no).toBe(`${year}-${String(maxOld + 1).padStart(4, '0')}`);
  });

  it('النسخة الجديدة (بالفروع) بترجع بفروعها وبادئاتها، ورصيد خزنة كل فرع زي ما هو', async () => {
    const b = (await as(O, `select export_backup() b`)).rows[0].b;
    const O3 = await user(`br-o3-${tag}@b.test`);
    const shop3 = (await as(O3, `select (bootstrap_account('صاحب', 'محل تالت')).shop_id s`)).rows[0].s;
    await as(O3, `select restore_backup($1::jsonb)`, [JSON.stringify(b)]);
    const br = (await admin(`select name, prefix, is_main from branches where shop_id = $1 and deleted_at is null order by is_main desc, prefix`, [shop3])).rows;
    expect(br.map((r) => r.prefix)).toEqual(['', 'B2', 'B3']);
    const cash2new = (await admin(`select a.id from accounts a join branches x on x.id = a.branch_id where a.shop_id = $1 and x.prefix = 'B2' and a.method = 'cash'`, [shop3])).rows[0].id;
    expect(await bal(cash2new)).toBe(await bal(cash2));
    // المعادي بيكمّل أرقامه
    const c3 = id();
    await as(O3, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'ع', '01077770001')`, [c3]);
    const b2new = (await admin(`select id from branches where shop_id = $1 and prefix = 'B2'`, [shop3])).rows[0].id;
    const nd = id();
    await as(O3, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'A', 'B', 'C')`, [nd, c3], b2new);
    const last = Math.max(...(b.devices as { order_no: string }[]).filter((x) => x.order_no.startsWith(`B2-${year}-`)).map((x) => Number(x.order_no.split('-')[2])));
    expect((await admin(`select order_no from devices where id = $1`, [nd])).rows[0].order_no).toBe(`B2-${year}-${String(last + 1).padStart(4, '0')}`);
  });

  it('U2: كل فرع متوازن لوحده، والموحّد = أرصدة الحسابات بالظبط، والمستحقات بين الفرعين بتلغي بعض', async () => {
    const tb = async (b: string | null) => (await as(O, `select * from trial_balance($1)`, [b])).rows.map((r) => ({ ...r, balance: Number(r.balance) }));
    const sum = (rows: { balance: number }[]) => rows.reduce((a, r) => a + r.balance, 0);
    const tMain = await tb(main);
    const t2 = await tb(B2);
    const all = await tb(null);
    // كل فرع بيقفل متوازن لوحده (مدين = دائن)
    expect(sum(tMain)).toBe(0);
    expect(sum(t2)).toBe(0);
    expect(sum(all)).toBe(0);
    // الموحّد: مفيش مستحقات بين الفروع، وكل حساب = رصيده في الدفتر نفسه (ولا رقم اتغير)
    expect(all.filter((r) => r.kind === 'inter_branch')).toHaveLength(0);
    const direct = (await admin(`select l.account_id, sum(l.debit - l.credit)::bigint b from journal_lines l where l.shop_id = $1 group by 1 having sum(l.debit - l.credit) <> 0`, [shop])).rows;
    expect(Object.fromEntries(all.map((r) => [r.account_id, r.balance]))).toEqual(Object.fromEntries(direct.map((r) => [r.account_id, Number(r.b)])));
    // الفرعين: مجموع كل حساب = الموحّد، والمستحق على واحد = المستحق للتاني
    const dueMain = tMain.find((r) => r.kind === 'inter_branch')?.balance ?? 0;
    const due2 = t2.find((r) => r.kind === 'inter_branch')?.balance ?? 0;
    expect(dueMain + due2).toBe(0);
    expect(dueMain).not.toBe(0);
    const dues = (await as(O, `select * from inter_branch_dues()`)).rows.map((r) => ({ b: r.branch_id, o: r.other_id, a: Number(r.amount) }));
    expect(dues.find((d) => d.b === main && d.o === B2)?.a).toBe(dueMain);
    expect(dues.find((d) => d.b === B2 && d.o === main)?.a).toBe(due2);
    // خزنة المعادي في ميزان المعادي بس، وبنفس رصيدها
    expect(t2.find((r) => r.account_id === cash2)?.balance).toBe(await bal(cash2));
    expect(tMain.find((r) => r.account_id === cash2)).toBeUndefined();
    // تحويل جديد بين الفرعين: إجمالي المحل ما اتغيرش، والفرعين لسه متوازنين
    const before = Object.fromEntries((await tb(null)).map((r) => [r.account_id, r.balance]));
    await as(O, `select transfer_cash($1, $2, $3, 10000)`, [id(), acc.cash_cash, cash2]);
    const after = Object.fromEntries((await tb(null)).map((r) => [r.account_id, r.balance]));
    expect(after[acc.cash_cash] + after[cash2]).toBe(before[acc.cash_cash] + before[cash2]);
    expect(sum(await tb(main))).toBe(0);
    expect(sum(await tb(B2))).toBe(0);
    // موظف المعادي بيشوف ميزان فرعه بس (لو اتفتحله الوضع المالي)
    await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [R2]);
    await expect(as(R2, `select * from trial_balance($1)`, [main], B2)).rejects.toThrow(/E_FORBIDDEN/);
    const mine = (await as(R2, `select * from trial_balance(null)`, [], B2)).rows;
    expect(mine.some((r) => r.account_id === cash2)).toBe(true);
    await as(O, `select set_staff_override($1, 'finance', 'view', null)`, [R2]);
  });

  it('U3: مؤشرات كل فرع = حساب مباشر من القيود والأجهزة والمخزون، والهدف الشهري لصاحب المحل بس', async () => {
    const F = new Date(Date.now() - 86400_000 * 365).toISOString();
    const T = new Date(Date.now() + 86400_000).toISOString();
    const k = Object.fromEntries((await as(O, `select * from branch_kpis($1, $2)`, [F, T])).rows.map((r) => [r.branch_id, r]));
    for (const b of [main, B2]) {
      // الإيرادات: سطور حسابات الإيراد (من غير زيادة الدرج) في قيود الفرع
      const rev = Number((await admin(
        `select coalesce(sum(l.credit - l.debit), 0) v from journal_lines l join journal_entries e on e.id = l.entry_id join accounts a on a.id = l.account_id
         where e.shop_id = $1 and e.branch_id = $2 and a.type = 'revenue' and a.kind = 'revenue' and e.occurred_at >= $3 and e.occurred_at < $4`, [shop, b, F, T])).rows[0].v);
      const cogs = Number((await admin(
        `select coalesce(sum(l.debit - l.credit), 0) v from journal_lines l join journal_entries e on e.id = l.entry_id join accounts a on a.id = l.account_id
         where e.shop_id = $1 and e.branch_id = $2 and a.kind = 'cogs' and e.occurred_at >= $3 and e.occurred_at < $4`, [shop, b, F, T])).rows[0].v);
      const din = Number((await admin(`select count(*) n from devices where shop_id = $1 and branch_id = $2 and deleted_at is null and received_at >= $3 and received_at < $4`, [shop, b, F, T])).rows[0].n);
      const sv = Number((await admin(`select coalesce(sum(v), 0) v from (select sum(value) v, sum(qty) q from stock_moves where shop_id = $1 and branch_id = $2 group by item_id) x where q > 0`, [shop, b])).rows[0].v);
      expect(Number(k[b].revenue)).toBe(rev);
      expect(Number(k[b].cogs)).toBe(cogs);
      expect(Number(k[b].devices_in)).toBe(din);
      expect(Number(k[b].stock_value)).toBe(sv);
    }
    expect(Number(k[B2].revenue)).toBe(200000);
    // الهدف: صاحب المحل بيحدده، والموظف لأ
    const m = new Date().toISOString().slice(0, 8) + '01';
    await as(O, `select save_goal($1, $2, 'revenue', 300000)`, [B2, m]);
    const k2 = (await as(O, `select * from branch_kpis($1, $2)`, [m, T])).rows.find((r) => r.branch_id === B2);
    expect(Number(k2.goal_revenue)).toBe(300000);
    await expect(as(R2, `select save_goal($1, $2, 'revenue', 1)`, [B2, m], B2)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select save_goal($1, $2, 'revenue', 0)`, [B2, m]);
    expect((await as(O, `select * from branch_kpis($1, $2)`, [m, T])).rows.find((r) => r.branch_id === B2).goal_revenue).toBeNull();
  });

  it('(35ج) بادئة اتستخدمت قبل كده ما تتعادش، لا لفرع جديد ولا لفرع موجود', async () => {
    const x = id();
    const y = id();
    await as(O, `select save_branch($1, 'فرع اكس', 'PX')`, [x]);
    await as(O, `select save_branch($1, 'فرع واي', 'PY')`, [y]);
    expect((await newDevice(O, x)).order_no).toBe(`PX-${year}-0001`);
    // تعديل الاسم بنفس البادئة المستخدمة عادي
    await as(O, `select save_branch($1, 'فرع اكس 2', 'PX')`, [x]);
    await as(O, `select save_branch($1, 'فرع اكس 2', 'PZ')`, [x]);
    await expect(as(O, `select save_branch($1, 'جديد', 'px')`, [id()])).rejects.toThrow(/E_PREFIX_USED/);
    await expect(as(O, `select save_branch($1, 'فرع واي', 'PX')`, [y])).rejects.toThrow(/E_PREFIX_USED/);
    // العدّاد كمّل للفرع نفسه بالبادئة الجديدة
    expect((await newDevice(O, x)).order_no).toBe(`PZ-${year}-0002`);
    // بادئة شبه السنة ما بتتلخبطش مع أرقام الرئيسي
    await as(O, `select save_branch($1, 'فرع واي', $2)`, [y, String(year)]);
    // محل تاني مالوش دعوة
    const X = await user(`br-px-${tag}@b.test`);
    await as(X, `select bootstrap_account('تاني', 'محل البادئة')`);
    await as(X, `select save_branch($1, 'فرع', 'PX')`, [id()]);
  });

  it('(35ج) محل وقع فيها خلاص: الاستلام بيعدّي الأرقام المستخدمة ويكمّل', async () => {
    const x = id();
    const y = id();
    await as(O, `select save_branch($1, 'قديم', 'QA')`, [x]);
    await newDevice(O, x);
    await newDevice(O, x);
    // الحالة القديمة قبل 0082: البادئة اتنقلت لفرع تاني
    await admin(`update branches set prefix = 'QB' where id = $1`, [x]);
    await as(O, `select save_branch($1, 'وارث', 'QC')`, [y]);
    await admin(`update branches set prefix = 'QA' where id = $1`, [y]);
    expect((await newDevice(O, y)).order_no).toBe(`QA-${year}-0003`);
    expect((await newDevice(O, y)).order_no).toBe(`QA-${year}-0004`);
  });

  it('(35ج) الرقم بعد 9999 بيكمّل 5 خانات من غير قص', async () => {
    const x = id();
    await as(O, `select save_branch($1, 'كبير', 'BG')`, [x]);
    await newDevice(O, x);
    await admin(`update order_counters set last_value = 9998 where branch_id = $1`, [x]);
    expect((await newDevice(O, x)).order_no).toBe(`BG-${year}-9999`);
    expect((await newDevice(O, x)).order_no).toBe(`BG-${year}-10000`);
  });
});
