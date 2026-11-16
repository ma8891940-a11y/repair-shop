import { expect, test } from '@playwright/test';
import { fillField, prefs, registerShop, uniq } from './helpers';

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEklEQVR4nGP4z8CAFWEXHbQSACj/P8Fu7N9hAAAAAElFTkSuQmCC', 'base64');

test('C4: شراء جهاز مستعمل ببيانات البائع وصورة البطاقة ← في المخزون ← البيع من الشاشة ← الربح = البيع − الشرا ← بيانات البائع لصاحب المحل', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await registerShop(page, uniq('used'), 'محل المستعمل');
  const imei = `35${String(Date.now()).slice(-13)}`;

  await page.goto('/#/used');
  await expect(page.getByTestId('used-screen')).toBeVisible();
  await expect(page.getByText('مفيش أجهزة مستعملة هنا')).toBeVisible();
  await page.getByTestId('used-buy').click();
  const dlg = page.getByRole('dialog');
  await dlg.getByLabel('الماركة').fill('Samsung');
  await dlg.getByLabel('الموديل').fill('A52');
  await dlg.getByLabel('IMEI').fill(imei);
  await dlg.getByLabel('سعر الشرا').fill('5,000');
  await dlg.getByLabel('سعر البيع المطلوب').fill('6,500');
  await expect(dlg.getByTestId('used-privacy')).toContainText('محدش يشوفها غير صاحب المحل');
  await dlg.getByLabel('اسم البائع').fill('محمد البائع');
  await dlg.getByLabel('موبايل البائع').fill('01012345678');
  await dlg.getByLabel('الرقم القومي').fill('29001011234567');
  await dlg.getByTestId('used-id-photo').setInputFiles({ name: 'id.png', mimeType: 'image/png', buffer: PNG });
  await dlg.getByTestId('used-buy-save').click();
  await expect(page.getByText('اتسجل شرا الجهاز').first()).toBeVisible();
  await expect(page.getByTestId('used-stock-count')).toHaveText('1');
  const row = page.getByTestId('used-row').filter({ hasText: imei });
  await expect(row).toContainText('في المخزون');

  // نفس الـ IMEI مرة تانية وهو في المخزون: مرفوض
  await page.getByTestId('used-buy').click();
  await dlg.getByLabel('الماركة').fill('Samsung');
  await dlg.getByLabel('الموديل').fill('A52');
  await dlg.getByLabel('IMEI').fill(imei);
  await dlg.getByLabel('سعر الشرا').fill('100');
  await dlg.getByLabel('اسم البائع').fill('حد تاني');
  await dlg.getByTestId('used-buy-save').click();
  await expect(dlg.getByText('لسه في المخزون')).toBeVisible();
  await dlg.getByRole('button', { name: 'إلغاء' }).click();
  await expect(dlg).toHaveCount(0);

  // بيانات البائع: رقم البطاقة والصورة
  await row.getByTestId('used-seller').click();
  const sellerInfo = page.getByTestId('seller-info');
  await expect(sellerInfo).toContainText('محمد البائع');
  await expect(page.getByTestId('seller-nid')).toHaveText('29001011234567');
  await expect(sellerInfo.locator('img')).toBeVisible();
  await page.keyboard.press('Escape');

  // البيع بسعر 6,200 ← ربح 1,200
  await row.getByTestId('used-sell').click();
  await fillField(page.getByTestId('used-sell-price'), '6,200');
  await page.getByTestId('used-sell-save').click();
  await expect(page.getByText('اتباع الجهاز').first()).toBeVisible();
  await page.getByLabel('العرض').selectOption('sold');
  await expect(row).toContainText('اتباع');
  await expect(row.getByTestId('used-profit')).toHaveText('1,200');
  await expect(page.getByTestId('used-stock-count')).toHaveText('0');
});
