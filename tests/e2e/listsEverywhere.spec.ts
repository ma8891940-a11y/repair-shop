import { expect, test, type Page } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

// قوائم الملء السريع في البرنامج كله: ماركة اتضافت من الاستلام بتظهر في المخزون والجرد،
// والحذف من القايمة المنسدلة ما بيأثرش على الأجهزة القديمة، ومن غير نت بتتسجل وتتبعت بعدين
const BRAND = `Nothing${Date.now() % 1000}`;

async function openCombo(page: Page, testid: string, typed: string) {
  const input = page.getByTestId(testid);
  await input.click();
  await input.fill(typed);
  return page.getByTestId(`${testid}-menu`);
}

test('قوائم الملء السريع: ماركة من الاستلام ← المخزون والجرد ← حذف من القايمة المنسدلة ← القديم زي ما هو ← من غير نت', async ({ page, context }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('lists'), 'محل القوايم');

  // 1) الاستلام: ماركة جديدة من نفس الخانة، والجهاز بيتسجل بيها
  await page.goto('/#/intake');
  await afterSplash(page);
  await page.locator('#intake-phone').fill(`010${String(Date.now()).slice(-8)}`);
  await page.getByLabel('اسم العميل').fill('عميل الماركة');
  const menu = await openCombo(page, 'intake-brand', BRAND);
  await menu.getByTestId('inline-add-brands').click();
  await expect(page.getByText(`اتضاف «${BRAND}» للقايمة`)).toBeVisible();
  await page.getByTestId('intake-model').fill('Phone 2');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();

  // 2) المخزون: صنف جديد ← الماركة موجودة في القايمة
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  const dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف', { exact: true }).fill(`شاشة ${BRAND}`);
  const m2 = await openCombo(page, 'new-item-brand', BRAND.slice(0, 5));
  await m2.getByTestId('list-option').filter({ hasText: BRAND }).getByRole('button').first().click();
  await expect(page.getByTestId('new-item-brand')).toHaveValue(BRAND);
  await dlg.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByTestId('item-row').filter({ hasText: `شاشة ${BRAND}` })).toBeVisible();
  // وفلتر الماركة فيه الماركة
  await expect(page.getByTestId('inv-brand-filter').locator('option', { hasText: BRAND })).toHaveCount(1);

  // 3) الجرد: نفس القايمة في عمود الماركة
  await page.goto('/#/opening');
  await afterSplash(page);
  const m3 = await openCombo(page, 'opening-brand', BRAND.slice(0, 5));
  await expect(m3.getByTestId('list-option').filter({ hasText: BRAND })).toHaveCount(1);
  await page.keyboard.press('Escape');

  // 4) الحذف من القايمة المنسدلة نفسها (بتأكيد)
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByTestId('item-row').filter({ hasText: `شاشة ${BRAND}` }).click();
  const m4 = await openCombo(page, 'item-brand', BRAND);
  const opt = m4.getByTestId('list-option').filter({ hasText: BRAND });
  await opt.getByTestId('list-option-remove').click();
  await expect(opt).toContainText('إزالة');
  await opt.getByTestId('list-option-remove-yes').click();
  await expect(page.getByText(`اتشال «${BRAND}» من القائمة`)).toBeVisible();
  await page.getByTestId('item-brand').fill(BRAND.slice(0, 5));
  await expect(page.getByTestId('item-brand-menu').getByTestId('list-option').filter({ hasText: BRAND })).toHaveCount(0);
  await page.keyboard.press('Escape');
  await page.keyboard.press('Escape');

  // 5) البيانات القديمة زي ما هي: الجهاز لسه بالماركة، والصنف لسه بالماركة
  await page.goto('/#/devices');
  await afterSplash(page);
  await expect(page.locator('main').getByText(`${BRAND} Phone 2`).filter({ visible: true }).first()).toBeVisible();
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByTestId('inv-brand-filter').selectOption({ label: BRAND });
  await expect(page.getByTestId('item-row')).toHaveCount(1);

  // 6) من غير نت: الإضافة بتتسجل على الجهاز، وبتتبعت لما النت يرجع
  await page.goto('/#/intake');
  await afterSplash(page);
  await context.setOffline(true);
  const OFF = `Offline${Date.now() % 1000}`;
  const m6 = await openCombo(page, 'intake-color', OFF);
  await m6.getByTestId('inline-add-colors').click();
  await expect(page.getByText('اتسجلت على الجهاز، وهتتبعت لما النت يرجع')).toBeVisible();
  await context.setOffline(false);
  // بعد المزامنة: في القايمة من السيرفر (بعد إعادة التحميل)
  await expect
    .poll(async () => {
      await page.reload();
      await afterSplash(page);
      const m = await openCombo(page, 'intake-color', OFF.slice(0, 6));
      return m.getByTestId('list-option').filter({ hasText: OFF }).count().catch(() => 0);
    }, { timeout: 60_000, intervals: [2000, 3000, 5000] })
    .toBe(1);
});
