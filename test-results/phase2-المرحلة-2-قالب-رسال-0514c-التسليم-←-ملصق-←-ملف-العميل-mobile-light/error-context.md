# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase2.spec.ts >> المرحلة 2: قالب رسالة ← استلام بفحص ← واتساب ← تتبع بالـ QR وموافقة ← فحص التسليم ← ملصق ← ملف العميل
- Location: tests/e2e/phase2.spec.ts:4:1

# Error details

```
Error: page.goto: net::ERR_CONNECTION_REFUSED at http://127.0.0.1:5180/#/register
Call log:
  - navigating to "http://127.0.0.1:5180/#/register", waiting until "load"

```

# Test source

```ts
  1  | import { expect, type Browser, type Page, type TestInfo } from '@playwright/test';
  2  | 
  3  | /** يظبط اللغة والوضع والمؤثرات قبل ما الصفحة تفتح */
  4  | export async function prefs(page: Page, info: TestInfo, o: { lang?: 'ar' | 'en'; effects?: boolean } = {}) {
  5  |   const theme = (info.project.metadata as { theme?: string }).theme ?? 'dark';
  6  |   await page.addInitScript(
  7  |     ([t, l, e]) => {
  8  |       try {
  9  |         if (!sessionStorage.getItem('__prefs_set')) {
  10 |           localStorage.setItem('theme', t);
  11 |           localStorage.setItem('lang', l);
  12 |           localStorage.setItem('effects', e);
  13 |           sessionStorage.setItem('__prefs_set', '1');
  14 |         }
  15 |       } catch {
  16 |         /* */
  17 |       }
  18 |     },
  19 |     [theme, o.lang ?? 'ar', o.effects ? '1' : '0'] as const,
  20 |   );
  21 | }
  22 | 
  23 | /** يستنى الشاشة الافتتاحية تختفي */
  24 | export async function afterSplash(page: Page) {
  25 |   await page.waitForFunction(() => !document.querySelector('.z-\\[100\\]'), null, { timeout: 15_000 });
  26 | }
  27 | 
  28 | /** كود التأكيد من صندوق البريد المحلي (Mailpit) */
  29 | export async function otpFor(email: string): Promise<string> {
  30 |   for (let i = 0; i < 40; i++) {
  31 |     const r = await (await fetch(`http://127.0.0.1:54324/api/v1/search?query=${encodeURIComponent('to:' + email)}`)).json();
  32 |     if (r.messages?.length) {
  33 |       const m = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${r.messages[0].ID}`)).json();
  34 |       const code = (m.Text.match(/\b\d{6}\b/) || [])[0];
  35 |       if (code) return code;
  36 |     }
  37 |     await new Promise((ok) => setTimeout(ok, 250));
  38 |   }
  39 |   throw new Error('no otp for ' + email);
  40 | }
  41 | 
  42 | export const uniq = (p: string) => `${p}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}@test.local`;
  43 | 
  44 | export const PASS = 'Secure#2026x';
  45 | 
  46 | export async function noHorizontalScroll(page: Page) {
  47 |   const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  48 |   expect(overflow).toBeLessThanOrEqual(1);
  49 | }
  50 | 
  51 | export async function registerShop(page: Page, email: string) {
> 52 |   await page.goto('/#/register');
     |              ^ Error: page.goto: net::ERR_CONNECTION_REFUSED at http://127.0.0.1:5180/#/register
  53 |   await afterSplash(page);
  54 |   const inputs = page.locator('form input');
  55 |   await inputs.nth(0).fill('مركز الاختبار');
  56 |   await inputs.nth(1).fill('محمود حسن');
  57 |   await page.getByRole('button', { name: 'التالي' }).click();
  58 |   await page.locator('input[type=email]').fill(email);
  59 |   await page.locator('input[type=password]').nth(0).fill(PASS);
  60 |   await page.locator('input[type=password]').nth(1).fill(PASS);
  61 |   await page.getByRole('button', { name: 'التالي' }).click();
  62 |   await page.locator('input[autocomplete=one-time-code]').waitFor();
  63 |   await page.locator('input[autocomplete=one-time-code]').click();
  64 |   await page.keyboard.type(await otpFor(email));
  65 |   await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  66 |   await page.getByRole('button', { name: 'التالي' }).click();
  67 |   await expect(page.getByRole('heading', { name: 'طرق الدفع' })).toBeVisible();
  68 |   await page.getByRole('button', { name: 'التالي' }).click();
  69 |   await expect(page.getByRole('heading', { name: 'الشعار والمظهر' })).toBeVisible();
  70 |   await page.getByRole('button', { name: 'ابدأ الشغل' }).click();
  71 |   await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  72 | }
  73 | 
  74 | 
  75 | export async function activateInvite(browser: Browser, info: TestInfo, email: string) {
  76 |   const ctx = await browser.newContext(info.project.use);
  77 |   const page = await ctx.newPage();
  78 |   await prefs(page, info);
  79 |   await page.goto('/#/join');
  80 |   await afterSplash(page);
  81 |   await expect(page.getByRole('heading', { name: 'تفعيل حساب موظف' })).toBeVisible();
  82 |   await page.locator('input[type=email]').fill(email);
  83 |   await page.locator('input[type=password]').nth(0).fill(PASS);
  84 |   await page.locator('input[type=password]').nth(1).fill(PASS);
  85 |   await page.getByRole('button', { name: 'التالي' }).click();
  86 |   await page.locator('input[autocomplete=one-time-code]').waitFor();
  87 |   await page.locator('input[autocomplete=one-time-code]').click();
  88 |   await page.keyboard.type(await otpFor(email));
  89 |   await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  90 |   return { ctx, page };
  91 | }
  92 | 
  93 | 
```