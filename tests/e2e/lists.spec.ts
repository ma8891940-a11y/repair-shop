import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, quickIntake, registerShop, uniq } from './helpers';

// البند 7: القوائم من الإعدادات، و"إضافة «...» للقائمة" من مكان الشغل، والحالات الفرعية، والحذف ما بيأثرش على القديم
test('القوائم: ماركة جديدة ← بتظهر في الاستلام، و"إضافة للقائمة" للون، وحالة فرعية، وحذف بند من غير ما القديم يتأثر', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('lists'), 'محل القوائم');

  // الإعدادات ← القوائم: ماركة جديدة، وحالة فرعية تحت "استلام"
  await page.goto('/#/settings');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'القوائم' }).click();
  const brands = page.getByTestId('list-brands');
  await expect(brands.getByTestId('list-item')).toHaveCount(10); // الافتراضية
  await brands.getByLabel('بند جديد في الماركات').fill('Nothing');
  await brands.getByRole('button', { name: 'ضيف' }).click();
  await expect(brands.getByTestId('list-item')).toHaveCount(11);
  const sub = page.getByTestId('sub-status-received');
  await sub.getByRole('textbox').fill('مستني العميل يجيب الشاحن');
  await sub.getByRole('button', { name: 'ضيف' }).click();
  await expect(sub.getByTestId('list-item')).toHaveCount(1);
  await noHorizontalScroll(page);

  // الاستلام: الماركة الجديدة زرار، واللون الجديد بـ "إضافة للقائمة"
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.getByRole('button', { name: 'Nothing', exact: true })).toBeVisible();
  await page.getByLabel('اللون').fill('بنفسجي');
  await page.getByTestId('inline-add-colors').click();
  await expect(page.getByText('اتضاف «بنفسجي» للقايمة')).toBeVisible();
  await expect(page.getByTestId('inline-add-colors')).toHaveCount(0);
  // الحالة الشكلية بدوسة، والموديل الجديد بـ "إضافة للقائمة"
  await page.getByTestId('condition-chips').getByRole('button', { name: 'خدوش', exact: true }).click();
  await page.getByTestId('condition-chips').getByRole('button', { name: 'خبطة', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'الحالة الشكلية' })).toHaveValue('خدوش، خبطة');
  await page.getByLabel('الموديل').fill('Phone 2a');
  await page.getByTestId('inline-add-models').click();
  await expect(page.getByText('اتضاف «Phone 2a» للقايمة')).toBeVisible();

  // جهاز بماركة Nothing، وبعدين الماركة تتشال من القايمة: الجهاز القديم زي ما هو
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل القوائم');
  // quickIntake بيختار Samsung: نغيّرها من الاستلام التاني عشان نتأكد من القايمة الجديدة
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(`012${String(Date.now()).slice(-8)}`);
  await page.getByLabel('اسم العميل').fill('عميل Nothing');
  await page.getByRole('button', { name: 'Nothing', exact: true }).click();
  await page.getByLabel('الموديل').fill('Phone 2');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('مش بيشحن');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.locator('body')).toContainText('Nothing');

  // الحالة الفرعية: بتظهر تحت الحالة الحالية، والاختيار بيتحفظ، ولما الحالة تتغير بتتشال
  const picker = page.getByTestId('sub-status-picker');
  await picker.getByRole('button', { name: 'مستني العميل يجيب الشاحن' }).click();
  await expect(page.getByTestId('device-sub-status')).toHaveText('مستني العميل يجيب الشاحن');
  await page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await expect(page.getByTestId('device-sub-status')).toHaveCount(0);
  const devNothing = page.url().replace(/^.*#/, '/#');

  await page.goto('/#/settings');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'القوائم' }).click();
  await page.getByTestId('list-brands').getByRole('button', { name: 'شيل «Nothing» من القايمة' }).click();
  await expect(page.getByTestId('list-brands').getByTestId('list-item')).toHaveCount(10);
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.getByRole('button', { name: 'Nothing', exact: true })).toHaveCount(0);
  await page.goto(devNothing);
  await afterSplash(page);
  await expect(page.locator('body')).toContainText('Nothing');
  await page.goto(dev);
  await afterSplash(page);
  await expect(page.locator('body')).toContainText('Samsung');
});
