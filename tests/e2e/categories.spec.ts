import { expect, test } from '@playwright/test';
import { fillField, prefs, registerShop, uniq } from './helpers';

test('K: تصفح التصنيفات: التصنيفات الجاهزة ← بلاطات بأيقونات ← خدمة في تصنيف فرعي ← بيعها من البلاطة بسعرها ← تصنيف فرعي جديد', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await registerShop(page, uniq('cats'), 'محل التصنيفات');

  // فاضي ← التصنيفات الجاهزة
  await page.goto('/#/categories');
  await expect(page.getByText('مفيش تصنيفات لسه')).toBeVisible();
  await page.getByTestId('cats-seed').click();
  await expect(page.getByText(/اتضاف \d+ تصنيف/).first()).toBeVisible();
  await expect(page.getByTestId('cats-title')).toHaveText('قطع الغيار');
  await expect(page.getByTestId('cats-tile').filter({ hasText: 'شاشات' })).toBeVisible();
  await expect(page.getByTestId('cats-tile')).toHaveCount(12);

  // الماركات بالاسم (من غير لوجوهات منسوخة)
  await page.getByTestId('cats-top').filter({ hasText: 'موبايلات جديدة' }).filter({ visible: true }).first().click();
  await expect(page.getByTestId('cats-tile').filter({ hasText: 'Samsung' })).toBeVisible();

  // خدمة جديدة في "خدمات التنظيف"
  await page.goto('/#/inventory');
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  const dlg = page.getByRole('dialog');
  await dlg.getByTestId('new-item-kind').selectOption('service');
  await dlg.getByLabel(/^الصنف/).first().fill('تنظيف شامل للجهاز');
  const opt = await dlg.getByTestId('new-item-category').locator('option', { hasText: 'خدمات التنظيف' }).getAttribute('value');
  await dlg.getByTestId('new-item-category').selectOption(opt!);
  await fillField(dlg.getByLabel('سعر البيع'), '200');
  await dlg.getByRole('button', { name: 'حفظ' }).click();
  await expect(dlg).toHaveCount(0);

  // التصنيفات ← الخدمات ← خدمات التنظيف ← الخدمة "خدمة" ← بيع بسعرها
  await page.goto('/#/categories');
  await page.getByTestId('cats-top').filter({ hasText: 'خدمات الصيانة' }).filter({ visible: true }).first().click();
  const tile = page.getByTestId('cats-tile').filter({ hasText: 'خدمات التنظيف' });
  await expect(tile).toContainText('1 صنف');
  await tile.click();
  const item = page.getByTestId('cats-item').filter({ hasText: 'تنظيف شامل للجهاز' });
  await expect(item).toContainText('خدمة');
  await item.getByTestId('cats-sell').click();
  const sale = page.getByRole('dialog');
  await expect(sale.locator('input[inputmode="decimal"]').first()).toHaveValue(/200/);
  await sale.getByRole('button', { name: /سجّل|بيع/ }).last().click();
  await expect(page.getByText('اتسجل البيع').first()).toBeVisible();
  await expect(page.getByText('200').first()).toBeVisible();

  // تصنيف فرعي جديد بأيقونة
  await page.goto('/#/categories');
  await page.getByTestId('cats-top').filter({ hasText: 'إكسسوارات' }).filter({ visible: true }).first().click();
  await page.getByTestId('cats-add-sub').click();
  await page.getByTestId('cat-name').fill('حوامل موبايل');
  await page.getByRole('radio', { name: 'جراب' }).click();
  await page.getByTestId('cat-save').click();
  await expect(page.getByTestId('cats-title')).toHaveText('حوامل موبايل');
  await expect(page.getByText('مفيش أصناف في التصنيف ده')).toBeVisible();
});
