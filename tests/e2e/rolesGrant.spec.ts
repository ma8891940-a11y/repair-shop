import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, prefs, registerShop, uniq } from './helpers';

// P (المرحلة التانية): صاحب المحل بيدي الموظف صلاحيات ما كانتش عنده (الوضع المالي، والمشتريات)،
// وبتتشال تاني، والفني ما بياخدش فلوس خالص (الخانات مقفولة)
test('الأدوار: فتح الوضع المالي والمشتريات لموظف الاستقبال ← بيظهروا ← بيتشالوا ← الفني مقفول', async ({ page, browser }, info) => {
  test.setTimeout(300_000);
  await prefs(page, info);
  await registerShop(page, uniq('grant'), 'محل الصلاحيات');

  // موظف استقبال
  await page.goto('/#/users');
  await afterSplash(page);
  const em = uniq('recep');
  await page.getByLabel('الاسم').fill('سارة');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const { ctx, page: c } = await activateInvite(browser, info, em);

  // قبل أي حاجة: زي الأول (ولا الوضع المالي ولا الشراء)
  await expect(c.getByRole('link', { name: 'الوضع المالي' })).toHaveCount(0);
  await c.goto('/#/inventory');
  await afterSplash(c);
  await expect(c.getByRole('button', { name: 'بيع', exact: true })).toBeVisible();
  await expect(c.getByRole('button', { name: 'شراء', exact: true })).toHaveCount(0);

  // صاحب المحل: استثناء "مسموح" للوضع المالي والمشتريات
  await page.reload();
  await afterSplash(page);
  const openRoles = async () => {
    await page.getByRole('listitem').filter({ hasText: 'سارة' }).getByTestId('member-roles').click();
    return page.getByRole('dialog');
  };
  let dlg = await openRoles();
  const grid = dlg.getByTestId('staff-grid');
  // الشركاء والمرتبات والإعدادات لصاحب المحل بس: الخانات مقفولة
  await expect(grid.getByTestId('perm-partners-view')).toBeDisabled();
  await expect(grid.getByTestId('perm-staff-view')).toBeDisabled();
  await grid.getByTestId('perm-finance-view').click();
  await grid.getByTestId('perm-purchases-view').click();
  await grid.getByTestId('perm-purchases-add').click();
  await expect(grid.getByTestId('perm-finance-view')).toHaveAttribute('aria-checked', 'true');
  await dlg.getByTestId('staff-roles-save').click();
  await expect(page.getByText('اتحفظت أدوار سارة')).toBeVisible();

  // الموظف: بيظهروا على طول (من غير خروج ودخول)
  await c.reload();
  await afterSplash(c);
  await expect(c.getByRole('link', { name: 'الوضع المالي' })).toBeVisible();
  await c.goto('/#/finance');
  await afterSplash(c);
  await expect(c.getByTestId('ready-reports')).toBeVisible();
  // المرتبات والسلف ورأس المال لصاحب المحل بس، والمصروف ما اتداش
  await expect(c.getByRole('button', { name: 'مرتب مستحق' })).toHaveCount(0);
  await expect(c.getByRole('button', { name: 'إضافة رأس مال' })).toHaveCount(0);
  await expect(c.getByRole('button', { name: 'مصروف', exact: true })).toHaveCount(0);
  await expect(c.getByTestId('ready-partners')).toHaveCount(0);
  await expect(c.getByTestId('ready-employees')).toHaveCount(0);
  await c.goto('/#/inventory');
  await afterSplash(c);
  await expect(c.getByRole('button', { name: 'شراء', exact: true })).toBeVisible();
  await expect(c.getByRole('tab', { name: 'الموردين' })).toBeVisible();

  // بيتشالوا: بيختفوا تاني، وحتى بالرابط
  dlg = await openRoles();
  for (const k of ['perm-finance-view', 'perm-purchases-view', 'perm-purchases-add']) {
    // الاستثناء بيتشال ← زي الدور
    await dlg.getByTestId('staff-grid').getByTestId(k).click();
  }
  await expect(dlg.getByTestId('staff-grid').getByTestId('perm-finance-view')).toHaveAttribute('aria-checked', 'false');
  await dlg.getByTestId('staff-roles-save').click();
  await expect(page.getByText('اتحفظت أدوار سارة')).toBeVisible();
  await c.goto('/#/finance');
  await c.reload();
  await afterSplash(c);
  await expect(c.getByTestId('ready-reports')).toHaveCount(0);
  await expect(c.getByRole('link', { name: 'الوضع المالي' })).toHaveCount(0);
  await ctx.close();

  // الفني: خانات الفلوس مقفولة في الأدوار المبنية عليه
  await page.goto('/#/settings?tab=roles');
  await afterSplash(page);
  await page.getByTestId('roles-settings').getByTestId('role-tab').filter({ hasText: 'فني' }).click();
  await expect(page.getByTestId('role-grid').getByTestId('perm-finance-view')).toBeDisabled();
  await expect(page.getByTestId('role-grid').getByTestId('perm-devices-amounts')).toBeDisabled();
  await expect(page.getByTestId('role-grid').getByTestId('perm-devices-view')).toBeEnabled();
});
