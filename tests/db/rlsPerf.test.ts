// سرعة الـ RLS (0061): دالة المحل والدور في السياسات بتتحسب مرة واحدة في الاستعلام ((select ...))، مش مع كل صف.
// أي سياسة جديدة فيها current_shop_id() أو current_app_role() من غير (select ...) بتفشّل الاختبار ده.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import pg from 'pg';

const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;
let db: pg.Client;

d('سرعة سياسات الـ RLS', () => {
  beforeAll(async () => {
    db = new pg.Client({ connectionString: url });
    await db.connect();
  });
  afterAll(async () => db?.end());

  it('مفيش سياسة بتنادي current_shop_id() أو current_app_role() مع كل صف', async () => {
    const r = await db.query(`
      select tablename || '.' || policyname p, coalesce(qual, '') || ' ' || coalesce(with_check, '') t
      from pg_policies where schemaname = 'public'`);
    // بنشيل الشكل الملفوف (SELECT current_shop_id() AS current_shop_id)، واللي يفضل يبقى نداء مع كل صف
    const bare = r.rows
      .filter((x) => /\b(current_shop_id|current_app_role)\(\)/.test(x.t.replace(/SELECT (public\.)?(current_shop_id|current_app_role)\(\) AS \w+/g, '')))
      .map((x) => x.p);
    expect(bare).toEqual([]);
    // وفيه سياسات كتير ملفوفة فعلًا (مش اختبار فاضي)
    expect(r.rows.filter((x) => /SELECT (public\.)?current_shop_id\(\) AS/.test(x.t)).length).toBeGreaterThan(50);
  });
});
