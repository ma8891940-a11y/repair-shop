// 50.2 (0088): فحص القالب على السيرفر: نفس نتيجة فحص الواجهة في كل حالة، والقوالب القديمة والنسخ القديمة زي ما هي
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { cleanupAfterFile } from './purge';
import { TEMPLATE_CASES } from '../../src/lib/printLayoutCases';
import { FLOW_BLOCKS, FREE_FIELDS, PRINT_DOCS } from '../../src/lib/printLayout';
import { DOC_BLOCKS, defaultBlocks, type TemplateDoc } from '../../src/lib/printTemplate';

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
const tag = randomUUID().slice(0, 6);

d('فحص القالب على السيرفر', () => {
  let O = '';
  const save = async (doc: string, mode: string, blocks: unknown, layout: unknown) => {
    const x = randomUUID();
    await as(O, `insert into print_templates(id, shop_id, doc, name, mode, blocks, layout) values ($1, gen_random_uuid(), $2, 'قالب', $3, $4, $5)`, [x, doc, mode, JSON.stringify(blocks), JSON.stringify(layout)]);
    return x;
  };
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    O = await user(`pl2-o-${tag}@p.test`);
    await as(O, `select bootstrap_account('صاحب', 'محل القوالب')`);
  }, 60_000);
  afterAll(async () => db?.end());

  it('نفس نتيجة الواجهة في كل حالة', async () => {
    const got: Record<string, string | null> = {};
    const want: Record<string, string | null> = {};
    for (const c of TEMPLATE_CASES) {
      const k = `${c.mode}: ${c.name}`;
      want[k] = c.error;
      got[k] = (await as(O, `select print_template_error($1, $2, $3, $4) e`, [c.doc, c.mode, JSON.stringify(c.blocks), JSON.stringify(c.layout)])).rows[0].e;
    }
    expect(got).toEqual(want);
  }, 30_000);

  it('قوايم الحقول مطابقة للواجهة', async () => {
    for (const doc of PRINT_DOCS) {
      const r = (await as(O, `select print_free_fields($1) f, print_flow_blocks($1) b`, [doc])).rows[0];
      expect([...r.f].sort()).toEqual([...FREE_FIELDS[doc]].sort());
      expect([...r.b].sort()).toEqual([...FLOW_BLOCKS[doc]].sort());
    }
  });

  it('الحفظ نفسه بيترفض (إضافة وتعديل)، والسليم بيتحفظ، والقديم من غير العمودين زي ما هو', async () => {
    const bad = TEMPLATE_CASES.filter((c) => c.error && !['doc', 'mode', 'type'].includes(c.error));
    expect(bad.length).toBeGreaterThan(40);
    for (const c of bad) await expect(save(c.doc, c.mode, c.blocks, c.layout), c.name).rejects.toThrow(/E_TEMPLATE/);
    await expect(save('statement', 'free', [], {})).rejects.toThrow(/E_TEMPLATE/);
    for (const doc of Object.keys(DOC_BLOCKS) as TemplateDoc[]) {
      const x = randomUUID();
      const blocks = defaultBlocks(doc);
      await as(O, `insert into print_templates(id, shop_id, doc, name, blocks) values ($1, gen_random_uuid(), $2, 'قديم', $3)`, [x, doc, JSON.stringify(blocks)]);
      expect((await as(O, `select mode, blocks, layout from print_templates where id = $1`, [x])).rows[0]).toEqual({ mode: 'flow', blocks, layout: {} });
    }
    const ok = TEMPLATE_CASES.find((c) => c.name === 'حقل عادي')!;
    const x = await save(ok.doc, ok.mode, ok.blocks, ok.layout);
    await expect(as(O, `update print_templates set layout = $2 where id = $1`, [x, JSON.stringify({ paper: { kind: '40x30' }, fields: [{ key: 'script' }] })])).rejects.toThrow(/E_TEMPLATE/);
    expect((await as(O, `select layout from print_templates where id = $1`, [x])).rows[0].layout).toEqual(ok.layout);
  }, 30_000);

  it('الاسترجاع: القالب الحر بيرجع، ونسخة قديمة من غير العمودين وبخانة قديمة بترجع، وlayout متلاعب فيه مرفوض', async () => {
    const b = (await as(O, `select export_backup() b`)).rows[0].b as Record<string, Record<string, unknown>[]>;
    const free = b.print_templates.find((t) => t.mode === 'free')!;
    const restore = async (k: string, data: unknown) => {
      const u = await user(`pl2-${k}-${tag}@p.test`);
      const s = (await as(u, `select (bootstrap_account('x', $1)).shop_id s`, [`استرجاع ${k}`])).rows[0].s;
      await as(u, `select restore_backup($1::jsonb)`, [JSON.stringify(data)]);
      return (await admin(`select doc, mode, blocks, layout from print_templates where shop_id = $1 order by doc, mode`, [s])).rows;
    };
    expect((await restore('a', b)).find((t) => t.mode === 'free')!.layout).toEqual(free.layout);
    const strip = (t: Record<string, unknown>) => {
      const { mode, layout, ...rest } = t;
      void mode;
      void layout;
      return { ...rest, blocks: [{ key: 'legacy' }] };
    };
    const old = { ...b, print_templates: b.print_templates.filter((t) => t.mode === 'flow').map(strip) };
    for (const t of await restore('b', old)) expect(t).toMatchObject({ mode: 'flow', layout: {}, blocks: [{ key: 'legacy' }] });
    await expect(restore('c', { ...b, print_templates: [{ ...free, layout: { html: '<script>' } }] })).rejects.toThrow(/E_TEMPLATE/);
  }, 30_000);
});
