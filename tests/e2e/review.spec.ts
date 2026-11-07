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
  // منشورات المجتمع والفيديوهات كلام كتبه المستخدمين (من محلات تانية كمان)، فما بتتترجمش
  // (أزرار المنشور نفسها بتفضل متراجعة)
  const ugc = page.locator('[data-testid="community-post"], [data-testid="video-item"]');
  const buttons = new Set((await ugc.locator('button, a').allInnerTexts()).map((b) => b.trim()));
  for (const c of await ugc.allInnerTexts()) {
    for (const line of c.split('\n').map((l) => l.trim()).filter((l) => l.length > 1 && !buttons.has(l))) txt = txt.split(line).join(' ');
  }
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

// الـ service worker موجود في نسخة الإنتاج بس (npm run build)، فالاختبار ده بيشتغل مع E2E_PROD=1
test('فتح التطبيق من الأول والنت فاصل (نسخة الإنتاج): بيفتح من الجهاز ولوحة التحكم ظاهرة والمؤشر "بدون نت"', async ({ page, context }, info) => {
  test.skip(!process.env.E2E_PROD, 'الـ service worker في نسخة الإنتاج بس: شغّل E2E_PROD=1 npm run test:e2e');
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('cold'));
  await quickIntake(page, '01036363636', 'عميل من غير نت');
  // الـ service worker اتسجل وبقى متحكم في الصفحة
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await page.goto('/#/');
  await page.reload();
  await expect.poll(() => page.evaluate(() => !!navigator.serviceWorker.controller), { timeout: 30_000 }).toBe(true);
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  // قائمة الأجهزة اتفتحت مرة والنت شغال (فاتحفظت منها نسخة على الجهاز)
  await page.goto('/#/devices');
  await expect(page.getByText('عميل من غير نت').filter({ visible: true }).first()).toBeVisible();

  // النت فصل، والتطبيق اتقفل واتفتح من الأول (صفحة جديدة)
  await context.setOffline(true);
  await page.close();
  const p2 = await context.newPage();
  await p2.goto('/#/devices');
  await expect(p2.getByTestId('connection')).toHaveAttribute('data-state', 'offline', { timeout: 30_000 });
  await expect(p2.getByText('عميل من غير نت').filter({ visible: true }).first()).toBeVisible({ timeout: 30_000 });
  await p2.goto('/#/');
  await expect(p2.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  await context.setOffline(false);
});

test('الدفعة: "سجّل" على طول بعد فتح الفورم ما بيبعتش طلب ناقص، والدفعة والنت فاصل بتتسجل بخزنة صح وتتبعت لما النت يرجع', async ({ page, context }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('pay'));
  await quickIntake(page, '01037373737', 'عميل الدفعة');
  await page.getByLabel('التكلفة النهائية').fill('1000');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await expect(page.getByTestId('device-due')).toHaveText('1,000');

  // النت فصل قبل ما فورم الدفعة يتفتح خالص على الجهاز ده
  await context.setOffline(true);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'offline');
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  const dlg = page.getByRole('dialog');
  await dlg.getByLabel('المبلغ').fill('400');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل على الجهاز، وهيتبعت أول ما النت يرجع').first()).toBeVisible();
  await expect(dlg).toHaveCount(0);

  // النت رجع: الدفعة اتبعتت من غير خطأ، والمتبقي 600
  await context.setOffline(false);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'online', { timeout: 30_000 });
  await page.reload();
  await expect(page.getByTestId('device-due')).toHaveText('600', { timeout: 15_000 });
  await expect(page.getByTestId('connection')).not.toContainText(/تعارض|conflict/i);

  // "سجّل" على طول بعد ما الفورم يتفتح: بيستنى الخزن ويتسجل صح
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await expect(page.getByTestId('device-due')).toHaveText('0');
});

test('المساعد متفعّل (رد السيرفر متمثّل): الإجابة بتظهر، واللي بيخرج من المتصفح الموديل ووصف العطل بس من غير بيانات العميل', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const sent: unknown[] = [];
  await page.route('**/functions/v1/assistant', async (route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 200, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } });
    const body = route.request().postDataJSON();
    sent.push(body);
    const json = body?.status ? { enabled: true } : { answer: '1) سوكت الشحن\n2) IC الشحن', left: 9 };
    await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: JSON.stringify(json) });
  });
  await registerShop(page, uniq('ai'));
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01038383838');
  await page.getByLabel('اسم العميل').fill('سامح عبد الله');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A54');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('مش بيشحن، سامح قال كلموني على 01038383838');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByTestId('assistant-disabled')).toHaveCount(0);
  await page.getByRole('button', { name: 'اقترح الأسباب وخطوات الفحص' }).click();
  await expect(page.getByTestId('assistant-answer')).toContainText('IC الشحن');
  const ask = sent.find((b) => !(b as { status?: boolean }).status) as Record<string, string>;
  expect(Object.keys(ask).sort()).toEqual(['device', 'issue']);
  expect(ask.device).toContain('A54');
  expect(ask.issue).toContain('مش بيشحن');
  expect(JSON.stringify(ask)).not.toContain('01038383838');
  expect(JSON.stringify(ask)).not.toContain('سامح');
});

test('تقسيم البرنامج: الشاشات الأساسية بتتحمّل في الخلفية بعد الافتتاحية، فبتفتح من غير أي لحظة تحميل', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  // بيسجّل لو "لحظة التحميل" ظهرت في أي وقت
  await page.addInitScript(() => {
    const w = window as unknown as { __loadingSeen: string[] };
    w.__loadingSeen = [];
    new MutationObserver(() => {
      if (document.querySelector('[data-testid="screen-loading"]')) w.__loadingSeen.push(location.hash);
    }).observe(document, { childList: true, subtree: true });
  });
  await registerShop(page, uniq('split'));
  await quickIntake(page, '01039393939', 'عميل التقسيم');
  // فتح البرنامج من الأول (زي ما المستخدم بيفتحه كل يوم)، وبعد الافتتاحية بلحظة
  await page.goto('/#/');
  await page.reload();
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  await page.waitForFunction(() => !document.querySelector('[data-testid="splash"]'));
  await page.waitForTimeout(1500);
  await page.evaluate(() => ((window as unknown as { __loadingSeen: string[] }).__loadingSeen = []));
  const nav = page.getByRole('navigation', { name: 'القائمة الرئيسية' }).filter({ visible: true });
  const go = async (name: string, heading: string) => {
    const link = nav.getByRole('link', { name, exact: true });
    if (await link.count()) await link.first().click();
    else await page.goto({ 'الأجهزة': '/#/devices', 'استلام جهاز': '/#/intake', 'الوضع المالي': '/#/finance', 'الدرج': '/#/drawer', 'لوحة التحكم': '/#/' }[name]!);
    await expect(page.getByRole('heading', { name: heading }).first()).toBeVisible();
  };
  await go('الأجهزة', 'الأجهزة');
  await page.getByText('عميل التقسيم').filter({ visible: true }).first().click();
  await expect(page.getByRole('button', { name: 'جاري الفحص', exact: true })).toBeVisible();
  // الجهاز بيفتح فوق القايمة: نقفله الأول
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await go('استلام جهاز', 'استلام جهاز');
  await go('الوضع المالي', 'الوضع المالي');
  await go('الدرج', 'الدرج');
  await go('لوحة التحكم', 'لوحة التحكم');
  expect(await page.evaluate(() => (window as unknown as { __loadingSeen: string[] }).__loadingSeen)).toEqual([]);
});
