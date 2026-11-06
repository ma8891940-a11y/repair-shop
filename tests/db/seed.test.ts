// البيانات التجريبية (supabase/seed_demo.sql) بتشتغل على Supabase حقيقي، والقيود متوازنة، وتكرارها ما بيكررش حاجة.
// بيتخطى على قاعدة الاختبار المؤقتة (مفيهاش auth.identities).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const url = process.env.TEST_DATABASE_URL;
let db: pg.Client;
let real = false;

describe.skipIf(!url)('البيانات التجريبية', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
    real = (await db.query(`select to_regclass('auth.identities') is not null as ok`)).rows[0].ok;
  });
  afterAll(async () => db?.end());

  it('بتتعمل مرة واحدة: محل، و3 أدوار، و20 جهاز بحالات مختلفة، ودفتر متوازن', async (ctx) => {
    if (!real) ctx.skip();
    const sql = readFileSync(join(__dirname, '..', '..', 'supabase', 'seed_demo.sql'), 'utf8');
    await db.query(sql);
    await db.query(sql); // التكرار آمن
    const shop = (await db.query(`select shop_id from profiles where email = 'owner@gawalak.demo'`)).rows;
    expect(shop).toHaveLength(1);
    const s = shop[0].shop_id;
    const roles = (await db.query(`select role::text from profiles where shop_id = $1 order by role`, [s])).rows.map((r) => r.role);
    expect(roles).toEqual(['owner', 'reception', 'technician']);
    const dev = (await db.query(`select count(*)::int n, count(distinct status)::int k from devices where shop_id = $1`, [s])).rows[0];
    expect(dev).toEqual({ n: 20, k: 9 });
    const bal = (await db.query(`select sum(debit) = sum(credit) as ok, count(distinct entry_id)::int n from journal_lines where shop_id = $1`, [s])).rows[0];
    expect(bal.ok).toBe(true);
    expect(bal.n).toBeGreaterThanOrEqual(20);
    const pw = (await db.query(`select count(*)::int n from auth.users where email like '%@gawalak.demo' and encrypted_password = crypt('Gawalak#2026', encrypted_password)`)).rows[0].n;
    expect(pw).toBe(3);
  });
});
