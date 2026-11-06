# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: effects.spec.ts >> المؤثرات الكاملة >> مقفولة افتراضيًا
- Location: tests/e2e/effects.spec.ts:5:3

# Error details

```
Error: page.goto: net::ERR_CONNECTION_REFUSED at http://127.0.0.1:5180/
Call log:
  - navigating to "http://127.0.0.1:5180/", waiting until "load"

```

# Test source

```ts
  1  | import { expect, test } from '@playwright/test';
  2  | import { afterSplash, prefs } from './helpers';
  3  | 
  4  | test.describe('المؤثرات الكاملة', () => {
  5  |   test('مقفولة افتراضيًا', async ({ page }, info) => {
  6  |     await prefs(page, info);
> 7  |     await page.goto('/');
     |                ^ Error: page.goto: net::ERR_CONNECTION_REFUSED at http://127.0.0.1:5180/
  8  |     await afterSplash(page);
  9  |     await expect(page.locator('html')).toHaveAttribute('data-lite', '');
  10 |   });
  11 | 
  12 |   test('الحركة الأساسية شغالة افتراضيًا: الخلفية الحية بتتحرك في الدخول حتى والمؤثرات الكاملة مقفولة', async ({ page }, info) => {
  13 |     await prefs(page, info);
  14 |     await page.goto('/');
  15 |     await afterSplash(page);
  16 |     await expect(page.locator('html')).toHaveAttribute('data-lite', '');
  17 |     const frame = () => page.evaluate(() => document.querySelector('canvas')?.toDataURL() ?? '');
  18 |     const a = await frame();
  19 |     await page.waitForTimeout(700);
  20 |     const b = await frame();
  21 |     expect(a.length).toBeGreaterThan(1000);
  22 |     expect(b).not.toBe(a);
  23 |   });
  24 | 
  25 |   test('"تقليل الحركة" في الجهاز بيوقف الحركة كلها', async ({ browser }, info) => {
  26 |     const ctx = await browser.newContext({ ...info.project.use, reducedMotion: 'reduce' });
  27 |     const page = await ctx.newPage();
  28 |     await prefs(page, info);
  29 |     await page.goto('/');
  30 |     await afterSplash(page);
  31 |     await page.waitForTimeout(400);
  32 |     const frame = () => page.evaluate(() => document.querySelector('canvas')?.toDataURL() ?? '');
  33 |     const a = await frame();
  34 |     await page.waitForTimeout(700);
  35 |     expect(await frame()).toBe(a);
  36 |     await ctx.close();
  37 |   });
  38 | 
  39 |   test('القفل التلقائي: بطء تحت 50 إطار لمدة 3 ثواني بيقفلها، والتنبيه فيه "رجّعها"', async ({ page, browserName }, info) => {
  40 |     test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
  41 |     await prefs(page, info, { effects: true });
  42 |     // فترة السماح بتبدأ من فتح الشاشة، فبنقيس من قبل الفتح
  43 |     const opened = Date.now();
  44 |     await page.goto('/');
  45 |     await afterSplash(page);
  46 |     await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
  47 |     // نبطّأ المعالج 20 مرة عشان الأداء ينزل
  48 |     const cdp = await page.context().newCDPSession(page);
  49 |     await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  50 |     const notice = page.getByText('اتقفلت المؤثرات الكاملة عشان الجهاز يفضل سريع');
  51 |     await expect(notice).toBeVisible({ timeout: 25_000 });
  52 |     // مش قبل فترة السماح (2 ثانية) + مدة البطء (3 ثواني) من فتح الشاشة
  53 |     expect(Date.now() - opened).toBeGreaterThanOrEqual(5_000);
  54 |     await expect(page.locator('html')).toHaveAttribute('data-lite', '');
  55 |     expect(await page.evaluate(() => localStorage.getItem('effects'))).toBe('0');
  56 |     await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  57 |     // "رجّعها" بيشغّلها تاني
  58 |     await page.getByRole('button', { name: 'رجّعها' }).click();
  59 |     await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
  60 |     expect(await page.evaluate(() => localStorage.getItem('effects'))).toBe('1');
  61 |   });
  62 | 
  63 |   test('ما بتتقفلش لو الأداء كويس، ولا بسبب بطء أول ثانيتين', async ({ page, browserName }, info) => {
  64 |     test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
  65 |     await prefs(page, info, { effects: true });
  66 |     await page.goto('/');
  67 |     await afterSplash(page);
  68 |     // بطء شديد لمدة ثانية ونص بس، جوه فترة السماح بعد فتح شاشة جديدة
  69 |     await page.goto('/#/register');
  70 |     const cdp = await page.context().newCDPSession(page);
  71 |     await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  72 |     await page.waitForTimeout(1_500);
  73 |     await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  74 |     await page.waitForTimeout(6_000);
  75 |     await expect(page.getByText('اتقفلت المؤثرات الكاملة')).toHaveCount(0);
  76 |     await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
  77 |   });
  78 | });
  79 | 
```