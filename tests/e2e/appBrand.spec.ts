import { expect, test } from '@playwright/test';
import { afterSplash, fillField, prefs, registerShop, uniq } from './helpers';

// صورة PNG صغيرة (مربع أحمر 8×8) عشان نجرّب لوجو المحل
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEklEQVR4nGP4z8CAFWEXHbQSACj/P8Fu7N9hAAAAAElFTkSuQmCC', 'base64');

// U3 + U4: شاشة الأداء والتحليلات، وهوية صاحب المحل في التطبيق (الاسم واللوجو في الشريط والعنوان والدخول)
test('هوية المحل في التطبيق والتحليلات: اسم ولوجو ولون ← الشريط والعنوان ← الافتتاحية والدخول بعد الخروج', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('brand'), 'محل الهوية');
  // التحليلات بتفتح وبتعرض المجموع
  await page.goto('/#/analytics');
  await afterSplash(page);
  await expect(page.getByTestId('an-total-revenue')).toBeVisible();
  await expect(page.getByTestId('an-branch')).toHaveCount(1);
  // الإعدادات ← تطبيقي
  await page.goto('/#/settings?tab=app');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'تطبيقي' }).click();
  const s = page.getByTestId('app-brand-settings');
  await fillField(s.getByTestId('app-name'), 'ورشة الأحلام');
  await s.getByTestId('app-logo-file').setInputFiles({ name: 'logo.png', mimeType: 'image/png', buffer: PNG });
  await s.getByTestId('app-accent').fill('#7c3aed');
  await s.getByTestId('app-brand-save').click();
  await expect(page.getByText('اتحفظت الإعدادات').first()).toBeVisible();
  await expect(s.getByText('شيل التثبيت وثبّته تاني')).toBeVisible();
  // الاسم واللوجو في الشريط وعنوان التبويب، ولون الإبراز اتطبّق
  await expect(page).toHaveTitle('ورشة الأحلام');
  await expect(page.getByTestId('app-mark').first()).toHaveAttribute('alt', 'ورشة الأحلام');
  await expect(page.getByTestId('app-mark').first()).toHaveAttribute('src', /^data:image\/png/);
  expect(await page.evaluate(() => document.getElementById('brand-accent')?.textContent ?? '')).toContain('--accent');
  // بعد إعادة التحميل: الافتتاحية بلوجو المحل من أول لحظة (من الجهاز)
  // الهوية متحفظة على الجهاز (الافتتاحية والدخول بيقروها قبل أي تسجيل)
  const cached = await page.evaluate(() => JSON.parse(localStorage.getItem('app-brand') ?? '{}'));
  expect(cached.name).toBe('ورشة الأحلام');
  expect(cached.logo).toMatch(/^data:image\/png/);
  await page.reload();
  await afterSplash(page);
  await expect(page).toHaveTitle('ورشة الأحلام');
  // رابط الدخول الخاص بالمحل موجود
  await expect(page.getByTestId('app-link')).toContainText('?shop=');
});
