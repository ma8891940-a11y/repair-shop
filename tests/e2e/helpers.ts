import { expect, type Page, type TestInfo } from '@playwright/test';

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

export async function registerShop(page: Page, email: string) {
  await page.goto('/#/register');
  await afterSplash(page);
  const inputs = page.locator('form input');
  await inputs.nth(0).fill('مركز الاختبار');
  await inputs.nth(1).fill('محمود حسن');
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[type=email]').fill(email);
  await page.locator('input[type=password]').nth(0).fill(PASS);
  await page.locator('input[type=password]').nth(1).fill(PASS);
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[autocomplete=one-time-code]').waitFor();
  await page.locator('input[autocomplete=one-time-code]').click();
  await page.keyboard.type(await otpFor(email));
  await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('heading', { name: 'طرق الدفع' })).toBeVisible();
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('heading', { name: 'الشعار والمظهر' })).toBeVisible();
  await page.getByRole('button', { name: 'ابدأ الشغل' }).click();
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
}

