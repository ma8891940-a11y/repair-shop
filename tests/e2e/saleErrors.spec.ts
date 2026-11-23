import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, pickItem, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// بند 13 (qa-37): الخطأ عند الحقل، والإجمالي ما يبانش رقم صالح مع مدخل غلط، والبيع المجاني محتاج سبب
test('أخطاء البيع: كمية صفر وسعر سالب تحت السطر، والمجاني بسبب', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('sale-err');
  await registerShop(page, email, 'محل الأخطاء');
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const { id: uid } = (await db.query(`select id from profiles where email = $1`, [email])).rows[0];
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    await db.query(`insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'تنظيف كامل', 15025), ($2, gen_random_uuid(), 'service', 'لزق اسكرينة', 1000)`, [randomUUID(), randomUUID()]);
    await db.query('commit');
  } finally {
    await db.end();
  }
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByTestId('op-sale').click();
  const dlg = page.getByRole('dialog');
  await pickItem(dlg, 'تنظيف كامل');
  const row = dlg.getByTestId('line').first();
  const qty = row.getByLabel('الكمية');
  const price = row.getByLabel('سعر البيع');
  await qty.fill('0');
  await price.fill('-5');
  await dlg.getByTestId('lines-save').click();
  await expect(dlg.getByTestId('line-err-qty')).toHaveText('الكمية لازم تكون عدد صحيح أكبر من صفر');
  await expect(dlg.getByTestId('line-err-price')).toHaveText('السعر مش صحيح');
  await expect(qty).toHaveAttribute('aria-invalid', 'true');
  await expect(dlg.getByText('الإجمالي').locator('..')).toContainText('—');
  // التصحيح بيشيل الرسالة على طول
  await qty.fill('1');
  await price.fill('150.25');
  await expect(dlg.getByTestId('line-err-qty')).toHaveCount(0);
  await expect(dlg.getByTestId('line-err-price')).toHaveCount(0);
  // سطر تاني مجاني
  await dlg.getByRole('button', { name: 'سطر تاني' }).click();
  const row2 = dlg.getByTestId('line').nth(1);
  await pickItem(row2, 'لزق اسكرينة');
  await row2.getByLabel('سعر البيع').fill('0');
  await dlg.getByTestId('lines-save').click();
  await expect(dlg.getByText('لازم تكتب السبب')).toBeVisible();
  await dlg.getByTestId('free-reason').fill('هدية');
  await dlg.getByTestId('lines-save').click();
  await expect(page.getByText('اتسجل البيع').first()).toBeVisible();
});
