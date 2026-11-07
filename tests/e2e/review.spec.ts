import { expect, test, type Page } from '@playwright/test';
import { activateInvite, prefs, quickIntake, registerShop, uniq } from './helpers';

// المراجعة الشاملة: اللغتين، ومفيش أخطاء في الـ console، ومفيش نصوص مش مترجمة، والحالات الغلط

/** الشاشات الأساسية لصاحب المحل (كل اللي في القائمة) */
const SCREENS = ['/#/', '/#/devices', '/#/intake', '/#/customers', '/#/finance', '/#/finance/pl', '/#/inventory', '/#/reports', '/#/drawer', '/#/users', '/#/audit', '/#/settings', '/#/videos', '/#/community'];
const SETTINGS_TABS_AR = ['هوية المحل', 'طرق الدفع', 'الفنيين والمسارات', 'الخزن والمصروفات', 'الرسائل', 'إضافات', 'النسخ الاحتياطي', 'المظهر'];
const SETTINGS_TABS_EN = ['Shop identity', 'Payment methods', 'Technicians & routes', 'Cashboxes & expenses', 'Messages', 'Extras', 'Backup', 'Appearance'];

function consoleErrors(page: Page) {
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(`[${page.url().replace(/^.*#/, '#')}] ${m.text()}`));
  page.on('pageerror', (e) => errors.push(`[pageerror ${page.url().replace(/^.*#/, '#')}] ${e.message}`));
  return errors;
}
/** النص الظاهر من غير بيانات المستخدم (اسم المحل والعميل وغيرهم) */
async function visibleText(page: Page, userData: string[]) {
  // اسم كل لغة بيتكتب بلغتها (زي "العربية" في اختيار اللغة): ده مقصود
  let txt = (await page.locator('body').innerText()).split('العربية').join(' ');
  for (const u of userData) txt = txt.split(u).join(' ');
  // الإيميلات بيانات مستخدم كمان (زي x@test.local)
  txt = txt.replace(/[\w.+-]+@[\w.-]+/g, ' ');
  return txt;
}

test('اللغتين: كل الشاشات بالعربي والإنجليزي من غير نصوص مش مترجمة، ومن غير مفاتيح ترجمة ظاهرة، ومن غير أخطاء في الـ console', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const errors = consoleErrors(page);
  const shopName = 'مركز الاختبار';
  await registerShop(page, uniq('lang'), shopName);
  await quickIntake(page, '01045454545', 'عميل اللغة');
  const userData = [shopName, 'محمود حسن', 'عميل اللغة', 'Samsung', 'A35', 'شاشة مكسورة', 'Galaxy'];

  for (const lang of ['ar', 'en'] as const) {
    if (lang === 'en') {
      await page.goto('/#/settings');
      await page.getByRole('button', { name: 'Switch to English' }).first().click();
      await expect(page.locator('html')).toHaveAttribute('lang', 'en');
    }
    await expect(page.locator('html')).toHaveAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
    for (const s of SCREENS) {
      await page.goto(s);
      await page.waitForLoadState('networkidle').catch(() => undefined);
      await expect(page.locator('main, [role="main"], h1').first()).toBeVisible();
      await expect(page.locator('[data-testid="error-state"], .animate-pulse').first()).toHaveCount(0, { timeout: 15_000 }).catch(() => undefined);
      const txt = await visibleText(page, userData);
      // مفتاح ترجمة ظاهر (زي settings.title أو register.steps.verify.title)
      expect(txt.match(/\b[a-z]+(?:\.[a-zA-Z0-9_]+){1,4}\b/g)?.filter((k) => !/^(www|gawalak|localhost|e\.g|i\.e)\b/i.test(k)) ?? [], `${lang} ${s}`).toEqual([]);
      // في الإنجليزي: مفيش نص عربي غير بيانات المستخدم
      if (lang === 'en') expect(txt.match(/[؀-ۿ]{2,}[^\n]{0,30}/g) ?? [], `en ${s}`).toEqual([]);
    }
    // كل تبويبات الإعدادات
    await page.goto('/#/settings');
    for (const tab of lang === 'ar' ? SETTINGS_TABS_AR : SETTINGS_TABS_EN) {
      await page.getByRole('tab', { name: tab }).click();
      await page.waitForTimeout(400);
      const txt = await visibleText(page, userData);
      expect(txt.match(/\b[a-z]+(?:\.[a-zA-Z0-9_]+){1,4}\b/g)?.filter((k) => !/^(www|gawalak|localhost|e\.g|i\.e)\b/i.test(k)) ?? [], `${lang} settings ${tab}`).toEqual([]);
      if (lang === 'en') expect(txt.match(/[؀-ۿ]{2,}[^\n]{0,30}/g) ?? [], `en settings ${tab}`).toEqual([]);
    }
  }
  expect(errors, errors.join('\n')).toEqual([]);
});

test('الحالات الغلط: حقول فاضية، ومبالغ كبيرة، وأرقام عربية، ومستخدم من غير صلاحية بيحاول يفتح شاشة مش بتاعته', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('edge'));

  // حقول فاضية: الحفظ ما بيحصلش، والأخطاء بالعربي جنب كل حقل
  await page.goto('/#/intake');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  // (اسم العميل بيتطلب بعد ما الرقم يتكتب ويطلع عميل جديد، فالرقم الأول)
  await expect(page.getByText('رقم موبايل مصري من 11 رقم (010، 011، 012، 015)')).toBeVisible();
  await expect(page.getByText('اختار أو اكتب النوع')).toBeVisible();
  await expect(page.getByText('اكتب الموديل')).toBeVisible();
  await expect(page.getByText('اكتب العطل زي ما العميل قاله')).toBeVisible();
  // الرقم اتكتب وطلع عميل جديد: دلوقتي الاسم مطلوب
  await page.locator('#intake-phone').fill('01066667777');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اكتب اسم العميل')).toBeVisible();
  await expect(page).toHaveURL(/#\/intake/);

  // مبلغ أكبر من الحد (20 مليون جنيه) بيترفض، والحد نفسه مقبول بالأرقام العربية
  await page.locator('#intake-phone').fill('٠١٠٥٥٥٤٤٤٣٣');
  await page.getByLabel('اسم العميل').fill('عميل المبالغ');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('S24');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة');
  await page.getByLabel('التكلفة التقديرية').fill('25000000');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('رقم غير صحيح. مثال: 350 أو 350.50')).toBeVisible();
  await page.getByLabel('التكلفة التقديرية').fill('١٩٬٩٩٩٬٩٩٩٫٩٩');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();

  // مستخدمين من غير صلاحية: الرابط المباشر بيرجّعهم للوحة التحكم
  for (const role of ['technician', 'reception'] as const) {
    const email = uniq(`edge-${role}`);
    await page.goto('/#/users');
    await page.getByLabel('الاسم').fill(role === 'technician' ? 'فني الحدود' : 'استقبال الحدود');
    await page.getByLabel('الإيميل').fill(email);
    await page.getByLabel('الدور').selectOption(role);
    await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
    await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
    const u = await activateInvite(browser, info, email);
    const forbidden = role === 'technician' ? ['/#/finance', '/#/customers', '/#/intake', '/#/users', '/#/audit', '/#/reports', '/#/drawer'] : ['/#/finance', '/#/finance/pl', '/#/users', '/#/audit', '/#/reports'];
    for (const r of forbidden) {
      await u.page.goto(r);
      await expect(u.page, `${role} ${r}`).toHaveURL(/#\/$/);
    }
    await u.ctx.close();
  }
});
