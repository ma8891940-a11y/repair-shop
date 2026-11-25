// 50.4 (0090): إعادة الطباعة بنفس القالب وبيانات المحل بتوع أول طباعة، والنسخ ثابتة وبترجع مع الاسترجاع
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';
import { defaultBlocks, type Block, type TemplateDoc } from '../../src/lib/printTemplate';

cleanupAfterFile();
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;
const admin = (sql: string, params: unknown[] = []) => db.query(sql, params);
async function on(c: pg.Client, uid: string, sql: string, params: unknown[] = []) {
  await c.query('begin');
  try {
    await c.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await c.query('set local role authenticated');
    const r = await c.query(sql, params);
    await c.query('commit');
    return r;
  } catch (e) {
    await c.query('rollback');
    throw e;
  }
}
const as = (uid: string, sql: string, params: unknown[] = []) => on(db, uid, sql, params);
async function user(email: string) {
  const u = randomUUID();
  await admin('insert into auth.users(id, email, email_confirmed_at) values ($1, $2, now())', [u, email]);
  return u;
}
const id = () => randomUUID();
const tag = randomUUID().slice(0, 6);
interface Doc {
  id: string;
  first_printed_at: string;
  shop: Record<string, unknown>;
  template: { version: number; mode: string; blocks: Block[] } | null;
}

d('نسخ القالب الثابتة', () => {
  let O = '';
  let R = '';
  let T = '';
  let X = '';
  let shop = '';
  let cash = '';
  let cust = '';
  let item = '';
  const print = async (u: string, doc: string, ref: string) => (await as(u, `select print_document($1, $2) j`, [doc, ref])).rows[0].j as Doc;
  const blocks = (doc: TemplateDoc, text: string) => [...defaultBlocks(doc), { key: 'text', show: true, size: 'md', align: 'start', bold: false, text } as Block];
  const tpl = async (doc: TemplateDoc, text: string, branch: string | null = null) => {
    const x = id();
    await as(O, `insert into print_templates(id, shop_id, doc, branch_id, name, blocks, is_default) values ($1, gen_random_uuid(), $2, $3, 'ق', $4, true)`, [x, doc, branch, JSON.stringify(blocks(doc, text))]);
    return x;
  };
  const edit = (x: string, doc: TemplateDoc, text: string) => as(O, `update print_templates set blocks = $2 where id = $1`, [x, JSON.stringify(blocks(doc, text))]);
  const textOf = (p: Doc) => p.template?.blocks.find((b) => b.key === 'text')?.text ?? null;
  const sale = async () => (await as(O, `select record_sale($1, $2::jsonb, $3) e`, [id(), JSON.stringify([{ item, qty: 1, price: 1000 }]), cash])).rows[0].e as string;
  const versions = async (x: string) => (await admin(`select version from print_template_versions where template_id = $1 order by version`, [x])).rows.map((r) => r.version);

  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pv-o-${tag}@p.test`);
    shop = (await as(O, `select (bootstrap_account('صاحب', 'الاسم القديم')).shop_id s`)).rows[0].s;
    cash = (await as(O, `select id from accounts where code = 'cash_cash'`)).rows[0].id;
    for (const role of ['reception', 'technician']) {
      const em = `pv-${role}-${tag}@p.test`;
      await as(O, `insert into staff_invites(shop_id, email, full_name, role) values (gen_random_uuid(), $1, $2, $3)`, [em, role, role]);
      const u = await user(em);
      await as(u, `select bootstrap_account($1)`, [role]);
      if (role === 'reception') R = u;
      else T = u;
    }
    X = await user(`pv-x-${tag}@p.test`);
    await as(X, `select bootstrap_account('تاني', 'محل تاني')`);
    item = id();
    await as(O, `insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'service', 'خدمة')`, [item]);
    cust = id();
    await as(O, `insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل', '01077788899')`, [cust]);
  }, 60_000);
  afterAll(async () => db?.end());

  it('من غير قالب محفوظ: الافتراضي، ويفضل كده حتى بعد ما يتعمل قالب', async () => {
    const e = await sale();
    expect((await print(O, 'sale', e)).template).toBeNull();
    const x = await tpl('sale', 'جديد');
    expect((await print(O, 'sale', e)).template).toBeNull();
    expect(textOf(await print(O, 'sale', await sale()))).toBe('جديد');
    expect(await versions(x)).toEqual([1]);
  });

  it('تعديل القالب أو مسحه أو اسم المحل بعد الطباعة ما بيغيّرش المستند القديم', async () => {
    const x = (await as(O, `select id from print_templates where doc = 'sale' and deleted_at is null`)).rows[0].id;
    const e = await sale();
    const a = await print(O, 'sale', e);
    expect(a.shop).toMatchObject({ name: 'الاسم القديم' });
    await edit(x, 'sale', 'معدّل');
    await as(O, `update shops set name = 'الاسم الجديد', address = 'عنوان جديد' where id = $1`, [shop]);
    expect(await print(O, 'sale', e)).toEqual(a);
    const b = await print(O, 'sale', await sale());
    expect([textOf(b), b.shop.name, b.shop.address, b.template!.version]).toEqual(['معدّل', 'الاسم الجديد', 'عنوان جديد', 2]);
    await as(O, `update print_templates set deleted_at = now(), is_default = false where id = $1`, [x]);
    expect(await print(O, 'sale', e)).toEqual(a);
    expect((await print(O, 'sale', await sale())).template).toBeNull();
  });

  it('اللوجو بيتجمّد، ومتخزن مرة واحدة حتى لو العنوان اتغيّر', async () => {
    const logo = (x: string) => `data:image/png;base64,${x}`;
    await admin(`insert into shop_branding(id, shop_id, logo_color) values (gen_random_uuid(), $1, $2) on conflict (shop_id) do update set logo_color = excluded.logo_color`, [shop, logo('AAAA')]);
    const e = await sale();
    expect((await print(O, 'sale', e)).shop.logo_color).toBe(logo('AAAA'));
    await as(O, `update shops set address = 'عنوان تالت' where id = $1`, [shop]);
    await print(O, 'sale', await sale());
    expect((await admin(`select count(*)::int n from print_identities where shop_id = $1 and data ? 'logo_color'`, [shop])).rows[0].n).toBe(1);
    await admin(`update shop_branding set logo_color = $2 where shop_id = $1`, [shop, logo('BBBB')]);
    expect((await print(O, 'sale', e)).shop.logo_color).toBe(logo('AAAA'));
    expect((await print(O, 'sale', await sale())).shop.logo_color).toBe(logo('BBBB'));
  });

  it('كل حفظ بمحتوى جديد = نسخة، ونفس المحتوى أو اسم القالب لأ', async () => {
    const x = await tpl('voucher', 'أ');
    await edit(x, 'voucher', 'ب');
    await edit(x, 'voucher', 'ب');
    await as(O, `update print_templates set name = 'اسم تاني' where id = $1`, [x]);
    expect(await versions(x)).toEqual([1, 2]);
    await edit(x, 'voucher', 'أ');
    expect(await versions(x)).toEqual([1, 2, 3]);
  });

  it('النسخ والوثايق ما بتتعدلش ولا بتتمسح، ومحدش يقراها مباشرة', async () => {
    for (const t of ['print_template_versions', 'print_identities', 'print_documents']) {
      await expect(admin(`update ${t} set updated_at = now() where shop_id = $1`, [shop])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
      await expect(admin(`delete from ${t} where shop_id = $1`, [shop])).rejects.toThrow(/E_LEDGER_IMMUTABLE/);
      for (const u of [O, R]) await expect(as(u, `select * from ${t}`)).rejects.toThrow(/permission denied/);
    }
  });

  it('فاتورة الصيانة والسند: بصلاحيتهم، والفني والمحل التاني لأ، والسند السري بصلاحيته', async () => {
    const dv = id();
    await as(O, `insert into devices(id, customer_id, brand, model, issue) values ($1, $2, 'Samsung', 'A54', 'شاشة')`, [dv, cust]);
    await as(O, `insert into device_costs(shop_id, device_id, final_cost) values (gen_random_uuid(), $1, 50000)`, [dv]);
    for (const st of ['inspecting', 'in_repair', 'repaired', 'ready']) await as(O, `update devices set status = $2 where id = $1`, [dv, st]);
    await as(O, `select deliver_on_credit($1)`, [dv]);
    const inv = (await as(R, `select repair_invoice($1) j`, [dv])).rows[0].j.id as string;
    const a = await print(R, 'invoice', inv);
    expect(await print(O, 'invoice', inv)).toEqual(a);
    const pay = (await as(O, `select record_payment($1, $2, $3, 1000) e`, [id(), cust, cash])).rows[0].e as string;
    const cap = (await as(O, `select owner_capital($1, $2, 1000) e`, [id(), cash])).rows[0].e as string;
    await expect(print(R, 'voucher', pay)).rejects.toThrow(/E_FORBIDDEN/);
    await as(O, `select set_staff_override($1, 'finance', 'view', true)`, [R]);
    expect(textOf(await print(R, 'voucher', pay))).toBe('أ');
    await expect(print(R, 'voucher', cap)).rejects.toThrow(/E_FORBIDDEN/);
    expect((await print(O, 'voucher', cap)).id).toBeTruthy();
    const s = await sale();
    for (const [doc, ref] of [['invoice', inv], ['voucher', pay], ['sale', s]] as const) {
      await expect(print(T, doc, ref)).rejects.toThrow(/E_FORBIDDEN/);
      await expect(print(X, doc, ref)).rejects.toThrow(/E_NOT_FOUND/);
    }
    await expect(print(O, 'sale', pay)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(print(O, 'voucher', s)).rejects.toThrow(/E_NOT_FOUND/);
    await expect(print(O, 'sticker', s)).rejects.toThrow(/E_BAD_INPUT/);
  });

  it('طباعتين متزامنتين لنفس المستند = وثيقة واحدة', async () => {
    const e = await sale();
    const c = new pg.Client({ connectionString: url });
    await c.connect();
    try {
      const [a, b] = await Promise.all([db, c].map((x) => on(x, O, `select print_document('sale', $1) j`, [e])));
      expect(a.rows[0].j).toEqual(b.rows[0].j);
    } finally {
      await c.end();
    }
  });

  it('الاسترجاع: الوثايق بترجع بنفس الشكل، ونسخة قديمة من غيرها بتشتغل', async () => {
    const backup = (await as(O, `select export_backup() b`)).rows[0].b as Record<string, Record<string, unknown>[]>;
    const list = async (s: string) =>
      (await admin(
        `select p.doc, v.version, v.blocks, i.data from print_documents p join print_identities i on i.id = p.identity_id left join print_template_versions v on v.id = p.version_id
         where p.shop_id = $1 order by p.created_at, p.doc, v.version`, [s])).rows;
    const restore = async (k: string, data: unknown) => {
      const u = await user(`pv-${k}-${tag}@p.test`);
      const s = (await as(u, `select (bootstrap_account('x', $1)).shop_id s`, [`استرجاع ${k}`])).rows[0].s as string;
      await as(u, `select restore_backup($1::jsonb)`, [JSON.stringify(data)]);
      return { u, s };
    };
    const a = await restore('a', backup);
    expect(await list(a.s)).toEqual(await list(shop));
    expect((await list(shop)).length).toBeGreaterThan(3);
    // المستند الراجع مربوط بالقيد الجديد
    const ref = (await admin(`select ref_id from print_documents where shop_id = $1 and doc = 'sale' limit 1`, [a.s])).rows[0].ref_id;
    expect((await admin(`select 1 from journal_entries where id = $1 and shop_id = $2`, [ref, a.s])).rowCount).toBe(1);
    // نسخة متلاعب فيها: قالب أو لوجو أو وثيقة محل تاني مرفوضين
    const first = (t: string, patch: object) => ({ ...backup, [t]: [{ ...backup[t][0], ...patch }, ...backup[t].slice(1)] });
    await expect(restore('c', first('print_template_versions', { layout: { html: 'x' } }))).rejects.toThrow(/E_TEMPLATE/);
    await expect(restore('d', first('print_identities', { data: { logo_color: 'data:image/svg+xml,<svg>' } }))).rejects.toThrow(/E_BAD_INPUT/);
    const foreign = (await admin(`select id from print_identities where shop_id = $1 limit 1`, [a.s])).rows[0].id;
    await expect(restore('e', first('print_documents', { identity_id: foreign }))).rejects.toThrow(/E_BAD_INPUT/);
    const old: Record<string, unknown> = { ...backup };
    for (const t of ['print_template_versions', 'print_identities', 'print_documents']) delete old[t];
    const b = await restore('b', old);
    const pay = (await admin(`select id from journal_entries where shop_id = $1 and source_type = 'payment'`, [b.s])).rows[0].id;
    expect(textOf(await print(b.u, 'voucher', pay))).toBe('أ');
  }, 30_000);
});
