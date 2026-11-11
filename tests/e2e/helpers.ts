import { expect, type Browser, type Locator, type Page, type TestInfo } from '@playwright/test';

/** يظبط اللغة والوضع والمؤثرات قبل ما الصفحة تفتح */
export async function prefs(page: Page, info: TestInfo, o: { lang?: 'ar' | 'en'; effects?: boolean } = {}) {
  const theme = (info.project.metadata as { theme?: string }).theme ?? 'dark';
  await page.addInitScript(
    ([t, l, e]) => {
      try {
        if (!sessionStorage.getItem('__prefs_set')) {
          localStorage.setItem('theme', t);
          localStorage.setItem('lang', l);
          localStorage.setItem('effects', e);
          sessionStorage.setItem('__prefs_set', '1');
        }
      } catch {
        /* */
      }
    },
    [theme, o.lang ?? 'ar', o.effects ? '1' : '0'] as const,
  );
  watchNetwork(page, info);
}

/**
 * تشخيص: الطلبات اللي فشلت أو رجعت خطأ من السيرفر، وأخطاء الكونسول. بتتطبع بس لو الاختبار فشل،
 * عشان لو حاجة فشلت تحت ضغط التشغيل الكامل يبان السبب بالظبط (من غير ما نعيد التشغيل).
 */
function watchNetwork(page: Page, info: TestInfo) {
  const log: string[] = [];
  const at = () => `${((Date.now() - t0) / 1000).toFixed(1)}s`;
  const t0 = Date.now();
  const short = (u: string) => u.replace(/^https?:\/\/[^/]+/, '').slice(0, 140);
  page.on('requestfailed', (r) => log.push(`${at()} FAILED ${r.method()} ${short(r.url())} ${r.failure()?.errorText ?? ''}`));
  page.on('response', (r) => {
    if (r.status() >= 500 || (r.status() >= 400 && r.url().includes('/rest/v1/'))) log.push(`${at()} HTTP ${r.status()} ${r.request().method()} ${short(r.url())}`);
  });
  page.on('console', (m) => m.type() === 'error' && log.push(`${at()} CONSOLE ${m.text().slice(0, 200)}`));
  page.on('pageerror', (e) => log.push(`${at()} PAGEERROR ${String(e).slice(0, 200)}`));
  page.on('close', () => {
    if (info.status !== info.expectedStatus && log.length) console.log(`--- network/console (${info.title}) ---\n${log.slice(-60).join('\n')}`);
  });
}

/** يستنى الشاشة الافتتاحية تختفي */
export async function afterSplash(page: Page) {
  await page.waitForFunction(() => !document.querySelector('.z-\\[100\\]'), null, { timeout: 15_000 });
}

/** كود التأكيد من صندوق البريد المحلي (Mailpit) */
export async function otpFor(email: string): Promise<string> {
  for (let i = 0; i < 40; i++) {
    const r = await (await fetch(`http://127.0.0.1:54324/api/v1/search?query=${encodeURIComponent('to:' + email)}`)).json();
    if (r.messages?.length) {
      const m = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${r.messages[0].ID}`)).json();
      const code = (m.Text.match(/\b\d{6}\b/) || [])[0];
      if (code) return code;
    }
    await new Promise((ok) => setTimeout(ok, 250));
  }
  throw new Error('no otp for ' + email);
}

export const uniq = (p: string) => `${p}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}@test.local`;

export const PASS = 'Secure#2026x';

export async function noHorizontalScroll(page: Page) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(1);
}

/**
 * بيكتب في الخانة ويتأكد إن النص وصل. أول تحميل على سيرفر التطوير بطيء، والخطوة اللي قبلها بتفضل ظاهرة
 * لحظة وهي بتختفي، فالكتابة ممكن تروح لنسخة بتتشال. لو ده حصل بيكتب تاني.
 */
export async function fillSure(page: Page, selector: string, index: number, value: string) {
  for (let i = 0; i < 4; i++) {
    const el = page.locator(selector).nth(index);
    await el.fill(value);
    if ((await el.inputValue().catch(() => '')) === value) return;
    await page.waitForTimeout(300);
  }
  await expect(page.locator(selector).nth(index)).toHaveValue(value);
}

/** رابط التأكيد من الإيميل (Mailpit المحلي) */
export async function linkFor(email: string): Promise<string> {
  for (let i = 0; i < 40; i++) {
    const r = await (await fetch(`http://127.0.0.1:54324/api/v1/search?query=${encodeURIComponent('to:' + email)}`)).json();
    if (r.messages?.length) {
      const m = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${r.messages[0].ID}`)).json();
      const href = (/href="(http[^"]*verify[^"]*)"/.exec(m.HTML ?? '') || [])[1];
      if (href) return href.replace(/&amp;/g, '&');
    }
    await new Promise((ok) => setTimeout(ok, 250));
  }
  throw new Error('no link for ' + email);
}

/** التسجيل لحد خطوة تأكيد الإيميل */
export async function startRegister(page: Page, email: string, shopName = 'مركز الاختبار', ownerName = 'محمود حسن') {
  await page.goto('/#/register');
  await afterSplash(page);
  // (أول فتح على npm run dev ممكن الشاشة تترسم تاني وتمسح اللي اتكتب في أول جزء من الثانية)
  await fillSure(page, 'form input', 0, shopName);
  await fillSure(page, 'form input', 1, ownerName);
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[type=email]').fill(email);
  await fillSure(page, 'input[type=password]', 0, PASS);
  await fillSure(page, 'input[type=password]', 1, PASS);
  await expect(page.locator('input[type=password]').nth(0)).toHaveValue(PASS);
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[autocomplete=one-time-code]').waitFor();
}

/** باقي خطوات المعالج (البلد، والدفع، والهوية، والمظهر) لحد لوحة التحكم */
export async function finishWizard(page: Page) {
  await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('heading', { name: 'طرق الدفع' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('heading', { name: 'هوية المحل' })).toBeVisible();
  await page.getByRole('button', { name: 'تخطّي' }).click();
  await expect(page.getByRole('heading', { name: 'المظهر' })).toBeVisible();
  await page.getByRole('button', { name: 'ابدأ الشغل' }).click();
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
}

export async function registerShop(page: Page, email: string, shopName = 'مركز الاختبار') {
  await startRegister(page, email, shopName);
  await page.locator('input[autocomplete=one-time-code]').click();
  await page.keyboard.type(await otpFor(email));
  await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('heading', { name: 'طرق الدفع' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  // هوية المحل: خطوة اختيارية
  await expect(page.getByRole('heading', { name: 'هوية المحل' })).toBeVisible();
  await page.getByRole('button', { name: 'تخطّي' }).click();
  await expect(page.getByRole('heading', { name: 'المظهر' })).toBeVisible();
  await page.getByRole('button', { name: 'ابدأ الشغل' }).click();
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
}


export async function activateInvite(browser: Browser, info: TestInfo, email: string, landing = 'لوحة التحكم') {
  const ctx = await browser.newContext(info.project.use);
  const page = await ctx.newPage();
  await prefs(page, info);
  await page.goto('/#/join');
  await afterSplash(page);
  await expect(page.getByRole('heading', { name: 'تفعيل حساب موظف' })).toBeVisible();
  await page.locator('input[type=email]').fill(email);
  await fillSure(page, 'input[type=password]', 0, PASS);
  await fillSure(page, 'input[type=password]', 1, PASS);
  await expect(page.locator('input[type=password]').nth(0)).toHaveValue(PASS);
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[autocomplete=one-time-code]').waitFor();
  await page.locator('input[autocomplete=one-time-code]').click();
  await page.keyboard.type(await otpFor(email));
  await expect(page.getByRole('heading', { name: landing })).toBeVisible();
  return { ctx, page };
}


/** استلام جهاز سريع، وبيرجّع رابط صفحة الجهاز */
export async function quickIntake(page: Page, phone: string, name = 'عميل') {
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill(name);
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة مكسورة');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByRole('button', { name: 'جاري الفحص', exact: true })).toBeVisible();
  return page.url().replace(/^.*#/, '/#');
}

/**
 * كتابة المبلغ في نافذة فلوس: بيستنى النافذة تبقى جاهزة الأول (القوايم وصلت والمبلغ المستحق اتحط)،
 * لأن الكتابة في أول جزء من الثانية بعد الفتح (تحت ضغط) كانت ممكن تضيع والمستحق يتسجل بدالها.
 * وبيتأكد إن المبلغ اتكتب فعلًا.
 */
export async function fillAmount(dlg: Locator, value: string) {
  const form = dlg.locator('form[data-ready]');
  if (await form.count()) await expect(form.first()).toHaveAttribute('data-ready', 'true', { timeout: 15_000 });
  const input = dlg.getByLabel('المبلغ');
  await expect(input).toBeEditable();
  await fillField(input, value);
}

/**
 * بيكتب في خانة (Locator) ويتأكد إن النص وصل، ولو ضاع بيكتب تاني (لحد 4 مرات).
 * اتأكدنا بالتتبع (trace) إن تحت ضغط التشغيل الكامل، أول كتابة بعد ما نافذة تفتح على طول ممكن توصل للمتصفح
 * من غير ما React يستلمها، فالخانة بترجع فاضية. النتيجة المطلوبة نفسها ما بتتغيرش: القيمة لازم توصل.
 */
export async function fillField(input: Locator, value: string) {
  for (let i = 0; i < 4; i++) {
    await input.fill(value);
    try {
      await expect(input).toHaveValue(value, { timeout: 1500 });
      return;
    } catch {
      /* ضاعت: نكتب تاني */
    }
  }
  await expect(input).toHaveValue(value);
}

/**
 * تشخيص الخلفية المتحركة (قرار صاحب المشروع: لو اختبار الحركة فشل في تشغيل كامل، يبان السبب بالظبط):
 * بيطبع حالة الحارس وآخر قراءات الإطارات لو الشرط فشل، وبعدين بيرمي نفس الخطأ.
 */
export async function withMotionDiag<T>(page: Page, what: string, fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    const d = await page
      .evaluate(() => {
        const m = (window as unknown as { __motionDiag?: { log: unknown[] } & Record<string, unknown> }).__motionDiag;
        // قراءات لحظة الوقوف (محفوظة على الجهاز، فبتفضل حتى بعد إعادة تحميل الصفحة)
        let why: string | null = null;
        try {
          why = localStorage.getItem('bg-still-why');
        } catch {
          why = null;
        }
        return (m ? JSON.stringify({ ...m, log: m.log.slice(-25) }) : 'no __motionDiag') + `\nlast trip: ${why ?? 'none'}`;
      })
      .catch((x) => `diag failed: ${String(x)}`);
    console.log(`--- motion diag (${what}) ---\n${d}`);
    throw e;
  }
}

