import { expect, test, type Page } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

// صورة صغيرة حقيقية (8×8) بدل صورة الكاميرا
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEklEQVR4nGP4z8CAFWEXHbQSACj/P8Fu7N9hAAAAAElFTkSuQmCC', 'base64');
const IMEI = '490154203237518';

async function intakeWithImei(page: Page, phone: string, issue: string, newCustomer = true) {
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(phone);
  if (newCustomer) await page.getByLabel('اسم العميل').fill('عميل الصور');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  await page.getByLabel('IMEI', { exact: true }).fill(IMEI);
  await page.getByLabel('العطل زي ما العميل وصفه').fill(issue);
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
}

test('C1: QR بيفتح صفحة رفع على الموبايل من غير دخول ← الصورة بتظهر على الجهاز ← صور الاستلام في صفحة التتبع ← سجل الجهاز بالـ IMEI', async ({ page, browser }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await registerShop(page, uniq('cap'), 'محل الصور');
  const phone = `010${String(Date.now()).slice(-8)}`;
  await intakeWithImei(page, phone, 'شاشة');
  // QR في شاشة "اتسجّل الجهاز" على طول
  await expect(page.getByTestId('phone-upload-btn')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByRole('button', { name: 'جاري الفحص', exact: true })).toBeVisible();
  const devUrl = page.url().replace(/^.*#/, '/#');

  // أول مرة: سجل الـ IMEI فاضي
  await expect(page.getByTestId('imei-history')).toContainText('أول مرة');

  await page.getByTestId('phone-upload-btn').click();
  const link = page.getByTestId('phone-upload-link');
  await expect(link).toBeVisible();
  const url = (await link.textContent()) ?? '';
  const upPath = url.replace(/^.*#/, '/#');
  expect(upPath).toMatch(/^\/#\/up\/[0-9a-f]{32}$/);

  // الموبايل: من غير تسجيل دخول، ومن غير أي بيانات للعميل
  const ctx = await browser.newContext({ ...info.project.use, storageState: undefined });
  const mob = await ctx.newPage();
  await prefs(mob, info);
  await mob.goto(upPath);
  await expect(mob.getByTestId('phone-upload')).toBeVisible();
  await expect(mob.getByText('محل الصور').first()).toBeVisible();
  await expect(mob.getByTestId('upload-count')).toHaveText('0/6');
  await expect(mob.locator('body')).not.toContainText('عميل الصور');
  await expect(mob.locator('body')).not.toContainText(phone);
  await mob.getByTestId('upload-input').setInputFiles({ name: 'p.png', mimeType: 'image/png', buffer: PNG });
  await expect(mob.getByTestId('upload-done')).toBeVisible();
  await expect(mob.getByTestId('upload-count')).toHaveText('1/6');

  // الصورة ظهرت على الجهاز في المحل والنافذة مفتوحة
  await expect(page.getByText('1/6')).toBeVisible({ timeout: 15_000 });
  await page.keyboard.press('Escape');
  await expect(page.locator('img[alt="صورة 1"]')).toBeVisible();

  // رابط بـ token غلط: رسالة واضحة
  await mob.goto('/#/up/' + '0'.repeat(32));
  await expect(mob.getByTestId('upload-expired')).toBeVisible();

  // صفحة التتبع: صور الاستلام لصاحب الرابط
  await page.getByRole('button', { name: 'واتساب', exact: true }).first().click();
  const msg = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  const token = (msg.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  expect(token).toBeTruthy();
  await page.keyboard.press('Escape');
  await mob.goto(`/#/t/${token}`);
  await expect(mob.getByTestId('track-photos').locator('img')).toHaveCount(1);
  await ctx.close();

  // نفس الـ IMEI دخل تاني: سجل الجهاز بيبيّن الزيارة اللي فاتت
  await intakeWithImei(page, phone, 'بطارية', false);
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByTestId('imei-visit')).toHaveCount(1);
  await expect(page.getByTestId('imei-visit')).toContainText('شاشة');
  await page.getByTestId('imei-visit').getByRole('link').click();
  await expect(page).toHaveURL(new RegExp(devUrl.replace('/#', '#') + '$'));
  await afterSplash(page).catch(() => undefined);
});
