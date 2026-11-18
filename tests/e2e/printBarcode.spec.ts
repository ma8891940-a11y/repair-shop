import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** باركود EAN-13 صحيح (رقم التحقق محسوب) */
function ean13(base12: string): string {
  const sum = [...base12].reduce((a, d, i) => a + Number(d) * (i % 2 ? 3 : 1), 0);
  return base12 + ((10 - (sum % 10)) % 10);
}

// 6ج: ملصق الباركود من مصمم الطباعة: الافتراضي زي القديم ← طابعة ملصقات 40×30 ← إخفاء السعر ← رجّع الافتراضي
test('ملصق الباركود: الافتراضي ← مقاس طابعة الملصقات ← إخفاء السعر ← رجّع الافتراضي', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('barcode-tpl');
  await registerShop(page, email, 'محل الملصقات');
  const item = randomUUID();
  const code = ean13(`622${String(Date.now()).slice(-9)}`);
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    // كأن صاحب المحل هو اللي ضاف الصنف (المحل بيتحدد من الحساب)
    const uid = (await db.query(`select id from profiles where email = $1`, [email])).rows[0].id;
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    await db.query(`insert into items(id, shop_id, kind, name, sale_price, barcode) values ($1, gen_random_uuid(), 'accessory', 'سماعة الملصق', 12550, $2)`, [item, code]);
    await db.query('commit');
  } finally {
    await db.end();
  }
  const url = `/#/print/barcode/${item}?preview=1`;

  // 1) الافتراضي: اسم المحل، والصنف، والباركود، والسعر، على 50×30
  await page.goto(url);
  const label = page.getByTestId('barcode-label').first();
  await expect(label).toBeVisible();
  await expect(label).toContainText('محل الملصقات');
  await expect(label.getByTestId('barcode-name')).toHaveText('سماعة الملصق');
  await expect(label.getByTestId('barcode-price')).toContainText('125.50');
  expect(await page.evaluate(() => [...document.querySelectorAll('style')].some((s) => s.textContent?.includes('50mm 30mm')))).toBe(true);

  // 2) المصمم: طابعة ملصقات 40×30، وقالب الملصق عليها من غير السعر
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('printer-preset').selectOption({ label: 'Xprinter XP-365B · ملصقات' });
  await page.getByTestId('printer-add').click();
  await expect(page.getByTestId('printer-row')).toHaveCount(1);
  const d = page.getByTestId('print-designer');
  await d.getByTestId('tpl-doc').selectOption('barcode');
  await d.getByTestId('tpl-printer').selectOption({ index: 1 });
  await d.locator('[data-testid="tpl-block"][data-key="price"]').getByTestId('tpl-toggle').click();
  await expect(d.getByTestId('tpl-preview')).toBeVisible();
  await d.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظ القالب')).toBeVisible();

  // 3) الملصق الحقيقي (من غير معاينة): من غير السعر، وعلى مقاس الطابعة
  await page.goto(url.replace('?preview=1', '?preview=0'));
  await expect(page.getByTestId('barcode-label').first()).toBeVisible();
  await expect(page.getByTestId('barcode-price')).toHaveCount(0);
  await expect(page.getByTestId('barcode-name').first()).toHaveText('سماعة الملصق');
  expect(await page.evaluate(() => [...document.querySelectorAll('style')].some((s) => s.textContent?.includes('40mm 30mm')))).toBe(true);

  // 4) رجّع الافتراضي (المحفوظ)
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('print-designer').getByTestId('tpl-doc').selectOption('barcode');
  await page.getByTestId('print-designer').getByTestId('tpl-reset').click();
  await expect(page.getByText('رجع القالب الافتراضي')).toBeVisible();
  await page.goto(url.replace('?preview=1', '?preview=0'));
  await expect(page.getByTestId('barcode-price').first()).toContainText('125.50');
});
