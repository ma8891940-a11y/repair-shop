import { expect, test } from '@playwright/test';
import { afterSplash, prefs } from './helpers';

// اسم التطبيق "جوالك / Gawalak" ولوجو صاحب المشروع (صورة كما هي) في الافتتاحية والدخول
test('اسم التطبيق جوالك ولوجو صاحب المشروع في الافتتاحية والدخول', async ({ page }, info) => {
  await prefs(page, info);
  await page.goto('/');
  await expect(page).toHaveTitle(/جوالك/);
  // الافتتاحية: اللوجو ظاهر ومتحمّل
  const splash = page.getByRole('status').getByTestId('app-mark');
  await expect(splash).toBeVisible();
  await afterSplash(page);
  const logo = page.getByTestId('app-mark').first();
  await expect(logo).toBeVisible();
  await expect(logo).toHaveAttribute('alt', 'جوالك');
  const size = await logo.evaluate((el: HTMLImageElement) => ({ w: el.naturalWidth, h: el.naturalHeight }));
  expect(size.w).toBeGreaterThan(0);
  // نفس نسبة اللوجو الأصلي (من غير مط): الأصل بعد شيل الهامش الشفاف 1268×1130
  expect(Math.abs(size.w / size.h - 1268 / 1130)).toBeLessThan(0.02);
  const shown = await logo.boundingBox();
  expect(Math.abs(shown!.width / shown!.height - 1268 / 1130)).toBeLessThan(0.05);
  // الاسم القديم مش موجود في أي مكان ظاهر
  await expect(page.getByText(/ورشة|Warsha/)).toHaveCount(0);
  // الأيقونات
  for (const p of ['favicon-16.png', 'favicon-32.png', 'icon-192.png', 'icon-512.png', 'icon-maskable-512.png', 'apple-touch-icon.png']) {
    expect((await page.request.get(p)).status(), p).toBe(200);
  }
});
