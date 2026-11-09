import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, prefs, registerShop, uniq } from './helpers';

// القايمة الجانبية في مجموعات: بتتفتح وتتقفل وبتتحفظ، والمفضلة، والصلاحيات، و"المزيد" على الموبايل
test('القايمة في مجموعات: فتح وقفل محفوظ، والمفضلة فوق، والاستقبال ما يشوفش المالية', async ({ page, browser }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('navg'));
  const mobile = info.project.name.startsWith('mobile');

  if (!mobile) {
    const nav = page.getByTestId('side-nav');
    for (const g of ['repair', 'sales', 'finance', 'people', 'reports', 'settings']) await expect(nav.getByTestId(`nav-group-${g}`)).toBeVisible();
    // افتح المالية: الوضع المالي والخزن والمصروفات والشركاء
    const fin = nav.getByTestId('nav-group-finance');
    await fin.getByRole('button', { name: 'المالية' }).click();
    for (const k of ['finance', 'cashboxes', 'expenses', 'partners']) await expect(fin.getByTestId(`nav-${k}`)).toBeVisible();
    // "المصروفات" بيفتح فورم المصروف على طول
    await fin.getByTestId('nav-expenses').click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await page.keyboard.press('Escape');
    // المبيعات: "بيع" بيفتح فورم البيع
    await nav.getByTestId('nav-group-sales').getByRole('button', { name: 'المبيعات والمخزون' }).click();
    await nav.getByTestId('nav-sale').click();
    await expect(page.getByRole('dialog').getByRole('button', { name: 'سجّل' })).toBeVisible();
    await page.keyboard.press('Escape');
    // المفضلة: ثبّت الشركاء ← بيظهر فوق، وبعد إعادة التحميل المجموعات المفتوحة والمفضلة زي ما هي
    await fin.getByTestId('nav-partners').hover();
    await fin.getByTestId('pin-partners').click();
    await expect(nav.getByTestId('nav-favorites').getByTestId('nav-partners')).toBeVisible();
    await fin.getByRole('button', { name: 'المالية' }).click();
    await expect(fin.getByTestId('nav-partners')).toHaveCount(0);
    await page.reload();
    await afterSplash(page);
    await expect(page.getByTestId('nav-favorites').getByTestId('nav-partners')).toBeVisible();
    await expect(page.getByTestId('nav-group-finance').getByTestId('nav-partners')).toHaveCount(0);
    await expect(page.getByTestId('nav-group-sales').getByTestId('nav-inventory')).toBeVisible();
  } else {
    await page.getByRole('button', { name: 'المزيد' }).click();
    const more = page.getByTestId('more-nav');
    await expect(more.getByTestId('more-group-finance')).toBeVisible();
    await more.getByRole('button', { name: 'المالية' }).click();
    await expect(more.getByTestId('more-partners')).toBeVisible();
    await more.getByTestId('more-partners').click();
    await expect(page.getByRole('heading', { name: 'الشركاء' })).toBeVisible();
  }

  // الاستقبال: من غير المالية والتقارير خالص
  await page.goto('/#/users');
  const em = uniq('rec-nav');
  await page.getByLabel('الاسم').fill('منى');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByLabel('الدور').selectOption('reception');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const R = await activateInvite(browser, info, em);
  if (!mobile) {
    const nav = R.page.getByTestId('side-nav');
    await expect(nav.getByTestId('nav-group-repair')).toBeVisible();
    await expect(nav.getByTestId('nav-group-reports')).toHaveCount(0);
    for (const k of ['partners', 'expenses', 'suppliers', 'purchases', 'stocktake']) await expect(nav.getByTestId(`nav-${k}`)).toHaveCount(0);
    await nav.getByTestId('nav-group-finance').getByRole('button').click();
    await expect(nav.getByTestId('nav-drawer')).toBeVisible();
    await expect(nav.getByTestId('nav-finance')).toHaveCount(0);
  } else {
    await R.page.getByRole('button', { name: 'المزيد' }).click();
    await expect(R.page.getByTestId('more-group-reports')).toHaveCount(0);
    await expect(R.page.getByTestId('more-partners')).toHaveCount(0);
  }
  await R.ctx.close();
});
