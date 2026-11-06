import { expect, type Browser, type Page, type TestInfo } from '@playwright/test';

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

export async function registerShop(page: Page, email: string, shopName = 'مركز الاختبار') {
  await page.goto('/#/register');
  await afterSplash(page);
  const inputs = page.locator('form input');
  await inputs.nth(0).fill(shopName);
  await inputs.nth(1).fill('محمود حسن');
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[type=email]').fill(email);
  await fillSure(page, 'input[type=password]', 0, PASS);
  await fillSure(page, 'input[type=password]', 1, PASS);
  await expect(page.locator('input[type=password]').nth(0)).toHaveValue(PASS);
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[autocomplete=one-time-code]').waitFor();
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
