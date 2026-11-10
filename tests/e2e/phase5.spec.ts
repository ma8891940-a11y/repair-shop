import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq, fillAmount } from './helpers';

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
  expect(dl.suggestedFilename()).toMatch(/\.gawalak$/);
  await page.getByLabel('كلمة سر النسخة').last().fill('backup-pass-2026');
  await page.locator('input[type=file]').setInputFiles(path);
  await expect(page.getByTestId('backup-summary')).toContainText('devices: 2');
  await page.getByLabel('كلمة سر النسخة').last().fill('wrong-pass-0000');
  await page.locator('input[type=file]').setInputFiles(path);
  await expect(page.getByText('كلمة السر غلط أو الملف اتعدّل')).toBeVisible();
});

test('الاسترجاع: نسخة من محل فيه شغل ← محل جديد فاضي بيسترجعها من الإعدادات ← نفس العملاء والأجهزة والفلوس ← مرة تانية ممنوع', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('rest-a'), 'المحل الأصلي');
  // جهاز ودفعة كاش 250
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01112223334');
  await page.getByLabel('اسم العميل').fill('عميلة الاسترجاع');
  await page.getByRole('button', { name: 'Oppo', exact: true }).click();
  await page.getByLabel('الموديل').fill('Reno 11');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('مش بيشحن');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await page.getByLabel('التكلفة النهائية').fill('700');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '250');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await expect(page.getByTestId('device-due')).toHaveText('450');
  const order = (await page.getByText(/\d{4}-\d{4}/).first().innerText()).match(/\d{4}-\d{4}/)![0];
  await page.goto('/#/finance');
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  // الأرقام بتعدّ لحد قيمتها (حركة)، فبنستنى القيمة النهائية
  await expect(page.getByTestId('kpi-cash')).toContainText('250');
  await page.waitForTimeout(1500);
  const cashA = await page.getByTestId('kpi-cash').innerText();
  const worthA = await page.getByTestId('kpi-net_worth').innerText();
  // النسخة
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'النسخ الاحتياطي' }).click();
  await page.getByLabel('كلمة سر النسخة').first().fill('restore-pass-2026');
  await page.getByLabel('تأكيد كلمة السر').fill('restore-pass-2026');
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'صدّر النسخة' }).click()]);
  const file = await dl.path();

  // محل جديد فاضي (صاحبه بيسجّل من جهاز تاني)
  const ctx = await browser.newContext(info.project.use);
  const p2 = await ctx.newPage();
  await prefs(p2, info);
  await registerShop(p2, uniq('rest-b'), 'محل جديد');
  await p2.goto('/#/settings');
  await p2.getByRole('tab', { name: 'النسخ الاحتياطي' }).click();
  await p2.getByLabel('كلمة سر النسخة').last().fill('restore-pass-2026');
  await p2.locator('input[type=file]').setInputFiles(file);
  await expect(p2.getByTestId('backup-summary')).toContainText('devices: 1');
  await p2.getByTestId('restore-box').getByRole('button', { name: 'استرجع النسخة' }).click();
  await expect(p2.getByRole('dialog', { name: 'تأكيد الاسترجاع' })).toBeVisible();
  await p2.getByRole('button', { name: 'أيوه، استرجع' }).click();
  await expect(p2.getByText('البيانات رجعت').first()).toBeVisible();
  // البرنامج بيفتح من الأول، وكل حاجة زي المحل الأصلي
  await expect(p2.getByRole('heading', { name: 'الإعدادات' })).toBeVisible({ timeout: 20_000 });
  await p2.goto('/#/devices');
  await expect(p2.getByText('عميلة الاسترجاع').filter({ visible: true }).first()).toBeVisible();
  await expect(p2.getByText(order).filter({ visible: true }).first()).toBeVisible();
  await p2.getByText('عميلة الاسترجاع').filter({ visible: true }).first().click();
  await expect(p2.getByTestId('device-due')).toHaveText('450');
  await p2.goto('/#/finance');
  await expect.poll(() => p2.getByTestId('kpi-cash').innerText()).toBe(cashA);
  await expect.poll(() => p2.getByTestId('kpi-net_worth').innerText()).toBe(worthA);
  await expect(p2.getByTestId('ledger-balanced')).toBeVisible();
  // اسم المحل رجع زي النسخة (في الموبايل الشريط الجانبي مستخبي، فبنشوف النص في الصفحة)
  await expect(p2.locator('body')).toContainText('المحل الأصلي');
  // مرة تانية: ممنوع، برسالة واضحة
  await p2.goto('/#/settings');
  await p2.getByRole('tab', { name: 'النسخ الاحتياطي' }).click();
  await p2.getByLabel('كلمة سر النسخة').last().fill('restore-pass-2026');
  await p2.locator('input[type=file]').setInputFiles(file);
  await p2.getByTestId('restore-box').getByRole('button', { name: 'استرجع النسخة' }).click();
  await p2.getByRole('button', { name: 'أيوه، استرجع' }).click();
  await expect(p2.getByText('المحل ده فيه شغل. الاسترجاع لمحل جديد فاضي بس').first()).toBeVisible();
  await ctx.close();
});
