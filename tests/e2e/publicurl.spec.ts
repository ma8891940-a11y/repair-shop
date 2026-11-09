import { expect, test } from '@playwright/test';
import { prefs, quickIntake, registerShop, uniq } from './helpers';

// البند 12: رابط التتبع https في سطر لوحده، و"رابط البرنامج العام" في الإعدادات، وتنبيه لو localhost
test('رابط البرنامج العام: تنبيه وهو localhost، والرابط الغلط بيترفض، وبعد الحفظ رسالة واتساب بالرابط العام في سطر لوحده', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('pub'), 'محل الرابط');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل الرابط');
  // قبل: البرنامج مفتوح من 127.0.0.1 ← رسالة واتساب فيها تنبيه
  await page.getByRole('button', { name: 'واتساب' }).first().click();
  await expect(page.getByTestId('wa-local-link')).toBeVisible();
  await page.keyboard.press('Escape');

  await page.goto('/#/settings');
  const panel = page.getByTestId('public-url');
  await expect(panel.getByTestId('public-url-warn')).toContainText('127.0.0.1');
  const input = panel.getByTestId('public-url-input');
  await input.fill('http://localhost:5173');
  await expect(panel).toContainText('على جهازك أو على شبكة المحل بس');
  await expect(panel.getByRole('button', { name: 'حفظ الرابط' })).toBeDisabled();
  await input.fill('http://gawalak.pages.dev');
  await expect(panel).toContainText('لازم يبدأ بـ https');
  await input.fill('https://gawalak.pages.dev/');
  await panel.getByRole('button', { name: 'حفظ الرابط' }).click();
  await expect(page.getByText('اتحفظت', { exact: false }).first()).toBeVisible();
  await expect(panel.getByTestId('public-url-warn')).toHaveCount(0);
  await expect(panel.getByTestId('public-url-example')).toHaveText('https://gawalak.pages.dev/#/t/…');

  // بعد: الرسالة فيها الرابط العام في سطر لوحده، ومن غير تنبيه
  await page.goto('/#/devices');
  await page.getByText('عميل الرابط').filter({ visible: true }).first().click();
  await page.getByRole('button', { name: 'واتساب' }).first().click();
  const msg = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  const line = msg.split('\n').find((l) => l.includes('/#/t/'));
  expect(line).toMatch(/^https:\/\/gawalak\.pages\.dev\/#\/t\/[0-9a-f]{24}$/);
  await expect(page.getByTestId('wa-local-link')).toHaveCount(0);
});
