import type { Page, TestInfo } from '@playwright/test';

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
