import { expect, test } from '@playwright/test';
import { afterSplash, prefs } from './helpers';

test.describe('المؤثرات الكاملة', () => {
  test('مقفولة افتراضيًا', async ({ page }, info) => {
    await prefs(page, info);
    await page.goto('/');
    await afterSplash(page);
    await expect(page.locator('html')).toHaveAttribute('data-lite', '');
  });

  test('القفل التلقائي: بطء تحت 50 إطار لمدة 3 ثواني بيقفلها، والتنبيه فيه "رجّعها"', async ({ page, browserName }, info) => {
    test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
    await prefs(page, info, { effects: true });
    await page.goto('/');
    await afterSplash(page);
    await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
    // نبطّأ المعالج 20 مرة عشان الأداء ينزل
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
    const started = Date.now();
    const notice = page.getByText('اتقفلت المؤثرات الكاملة عشان الجهاز يفضل سريع');
    await expect(notice).toBeVisible({ timeout: 25_000 });
    // مش قبل فترة السماح (2 ثانية) + مدة البطء (3 ثواني)
    expect(Date.now() - started).toBeGreaterThanOrEqual(4_500);
    await expect(page.locator('html')).toHaveAttribute('data-lite', '');
    expect(await page.evaluate(() => localStorage.getItem('effects'))).toBe('0');
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
    // "رجّعها" بيشغّلها تاني
    await page.getByRole('button', { name: 'رجّعها' }).click();
    await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
    expect(await page.evaluate(() => localStorage.getItem('effects'))).toBe('1');
  });

  test('ما بتتقفلش لو الأداء كويس، ولا بسبب بطء أول ثانيتين', async ({ page, browserName }, info) => {
    test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
    await prefs(page, info, { effects: true });
    await page.goto('/');
    await afterSplash(page);
    // بطء شديد لمدة ثانية ونص بس، جوه فترة السماح بعد فتح شاشة جديدة
    await page.goto('/#/register');
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
    await page.waitForTimeout(1_500);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
    await page.waitForTimeout(6_000);
    await expect(page.getByText('اتقفلت المؤثرات الكاملة')).toHaveCount(0);
    await expect(page.locator('html')).not.toHaveAttribute('data-lite', '');
  });
});
