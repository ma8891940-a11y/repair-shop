import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

test('المرحلة 5: النت فصل ← تغيير حالة واستلام جهاز بيتسجلوا على الجهاز ← النت رجع ← المزامنة بالترتيب ← نسخة احتياطية مشفّرة', async ({ page, context }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('owner5'));
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'online');

  // جهاز اتسجل والنت شغال
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01188889999');
  await page.getByLabel('اسم العميل').fill('عميل النت');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A15');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('حاجة غريبة');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  // صفحة الجهاز نفسها اتحمّلت (واتحفظت نسخة منها على الجهاز)
  await expect(page.getByRole('button', { name: 'جاري الفحص', exact: true })).toBeVisible();
  const deviceHash = page.url().replace(/^.*#/, '/#');

  // النت فصل
  await context.setOffline(true);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'offline');
  await page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await expect(page.getByText('اتسجل على الجهاز، وهيتبعت أول ما النت يرجع').first()).toBeVisible();
  await expect(page.getByTestId('connection')).toContainText('1');

  // استلام جهاز تاني بدون نت (عميل جديد)
  await page.getByRole('link', { name: 'استلام جهاز' }).filter({ visible: true }).first().click();
  await page.locator('#intake-phone').fill('01177776666');
  await page.getByLabel('اسم العميل').fill('عميل بدون نت');
  await page.getByRole('button', { name: 'Xiaomi', exact: true }).click();
  await page.getByLabel('الموديل').fill('Note 13');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة مكسورة');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('رقم مؤقت')).toBeVisible();
  await expect(page.getByTestId('connection')).toContainText('2');
  await noHorizontalScroll(page);

  // النت رجع: المزامنة لوحدها
  await context.setOffline(false);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', /online|pending/);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'online', { timeout: 30_000 });
  await page.goto(deviceHash);
  await afterSplash(page);
  await expect(page.getByText('جاري الفحص').first()).toBeVisible();
  await page.goto('/#/devices');
  await expect(page.getByText('Note 13').filter({ visible: true }).first()).toBeVisible();
  await expect(page.getByText(`${new Date().getFullYear()}-0002`).filter({ visible: true }).first()).toBeVisible();

  // نسخة احتياطية مشفّرة وفتحها
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'النسخ الاحتياطي' }).click();
  await page.getByLabel('كلمة سر النسخة').first().fill('backup-pass-2026');
  await page.getByLabel('تأكيد كلمة السر').fill('backup-pass-2026');
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'صدّر النسخة' }).click()]);
  const path = await dl.path();
  expect(dl.suggestedFilename()).toMatch(/\.warsha$/);
  await page.getByLabel('كلمة سر النسخة').last().fill('backup-pass-2026');
  await page.locator('input[type=file]').setInputFiles(path);
  await expect(page.getByTestId('backup-summary')).toContainText('devices: 2');
  await page.getByLabel('كلمة سر النسخة').last().fill('wrong-pass-0000');
  await page.locator('input[type=file]').setInputFiles(path);
  await expect(page.getByText('كلمة السر غلط أو الملف اتعدّل')).toBeVisible();
});
