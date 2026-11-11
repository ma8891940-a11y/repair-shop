import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

// P (المرحلة الأولى): الأدوار والصلاحيات من الإعدادات، وكاشير المبيعات ما يشوفش الأجهزة ولا الاستلام،
// وشيل صلاحية بيتطبق على طول، و"صيانة بس" ما فيهوش بيع، وصاحب المحل عنده كل حاجة دايمًا
test('الأدوار والصلاحيات: الأدوار الجاهزة ← كاشير مبيعات من غير أجهزة ← نوع الفرع ← صاحب المحل ثابت', async ({ page, browser }, info) => {
  test.setTimeout(300_000);
  await prefs(page, info);
  await registerShop(page, uniq('roles'), 'محل الأدوار');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل الأدوار');

  // 1) الإعدادات ← الأدوار والصلاحيات: الأدوار الجاهزة الخمسة، وجدول الصلاحيات
  await page.goto('/#/settings?tab=roles');
  const rs = page.getByTestId('roles-settings');
  await expect(rs.getByTestId('role-tab')).toHaveCount(5);
  for (const n of ['مدير فرع', 'استقبال', 'فني', 'كاشير مبيعات', 'محاسب']) await expect(rs.getByTestId('role-tab').filter({ hasText: n })).toHaveCount(1);
  await expect(rs).toContainText('صاحب المحل: كل الصلاحيات');
  await rs.getByTestId('role-tab').filter({ hasText: 'كاشير مبيعات' }).click();
  await expect(page.getByTestId('perm-devices-view')).toHaveAttribute('aria-checked', 'false');
  await expect(page.getByTestId('perm-sales-add')).toHaveAttribute('aria-checked', 'true');

  // 2) موظف بدور "كاشير مبيعات"
  await page.goto('/#/users');
  const em = uniq('cashier');
  await page.getByLabel('الاسم').fill('كاشير');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const { ctx, page: c } = await activateInvite(browser, info, em);
  await page.reload();
  await afterSplash(page);
  await page.getByRole('listitem').filter({ hasText: 'كاشير' }).getByTestId('member-roles').click();
  const dlg = page.getByRole('dialog');
  await dlg.getByTestId('staff-roles').getByRole('checkbox', { name: 'استقبال' }).click();
  await dlg.getByTestId('staff-roles').getByRole('checkbox', { name: 'كاشير مبيعات' }).click();
  await dlg.getByTestId('staff-roles-save').click();
  await expect(page.getByText('اتحفظت أدوار كاشير')).toBeVisible();

  // الكاشير: من غير أجهزة ولا استلام ولا فنيين في القايمة، وبيشوف البيع والمخزون (بيتطبق على طول)
  await c.reload();
  await afterSplash(c);
  await expect(c.getByRole('link', { name: 'الأجهزة' })).toHaveCount(0);
  await expect(c.getByRole('link', { name: 'استلام جهاز' })).toHaveCount(0);
  // ولا في الشريط السفلي على الموبايل
  await expect(c.locator('nav[aria-label]').getByText('الأجهزة', { exact: true })).toHaveCount(0);
  await expect(c.getByTestId('dashboard-sales-only')).toBeVisible();
  // ولا حتى بالرابط
  await c.goto('/#/devices');
  await afterSplash(c);
  await expect(c.getByText('عميل الأدوار')).toHaveCount(0);
  await ctx.close();

  // 3) صاحب المحل ثابت: مفيش "الأدوار" جنبه
  await expect(page.getByRole('listitem').filter({ hasText: '(أنت)' }).getByTestId('member-roles')).toHaveCount(0);

  // 4) نوع الفرع: "صيانة بس" ← البيع بيختفي من القايمة، والأجهزة القديمة موجودة
  await page.goto('/#/settings?tab=branches');
  await page.getByTestId('branch-kind').first().selectOption('repair');
  await expect(page.getByText('اتغيّر نوع الفرع')).toBeVisible();
  await page.reload();
  await afterSplash(page);
  await expect(page.getByRole('link', { name: 'بيع', exact: true })).toHaveCount(0);
  await page.goto('/#/devices');
  await afterSplash(page);
  await expect(page.locator('main').getByText('عميل الأدوار').filter({ visible: true }).first()).toBeVisible();
  await page.goto('/#/settings?tab=branches');
  await page.getByTestId('branch-kind').first().selectOption('both');
  await expect(page.getByText('اتغيّر نوع الفرع')).toBeVisible();
});
