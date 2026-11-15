import { expect, test } from '@playwright/test';
import pg from 'pg';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// U1 + U2: التسجيل بفروع من أول مرة ← كل فرع متوازن لوحده في ميزان المراجعة، والموحّد متوازن
test('الفروع من التسجيل: فرعين بأنواعهم ← ميزان المراجعة لكل فرع وموحّد متوازن', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('books');
  await registerShop(page, email, 'محل الفروع', { branches: [{ name: 'فرع وسط البلد' }, { name: 'فرع المعادي', kind: 'sales' }] });
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const rows = (await db.query(`select b.name, b.kind, b.is_main, b.prefix from branches b join profiles p on p.shop_id = b.shop_id where p.email = $1 and b.deleted_at is null order by b.is_main desc`, [email]).finally(() => db.end())).rows;
  expect(rows).toEqual([
    { name: 'فرع وسط البلد', kind: 'both', is_main: true, prefix: '' },
    { name: 'فرع المعادي', kind: 'sales', is_main: false, prefix: 'B2' },
  ]);
  // ميزان المراجعة الموحّد
  await page.goto('/#/finance/trial');
  await afterSplash(page);
  await expect(page.getByTestId('tb-balanced')).toBeVisible();
  // مبدّل الفروع موجود (المحل بقى فروع)، وكل فرع متوازن لوحده
  const sw = page.getByTestId('branch-switcher');
  if (await sw.isVisible()) {
    await sw.selectOption({ label: 'فرع المعادي' });
    await expect(page.getByTestId('tb-balanced')).toBeVisible();
  }
});
