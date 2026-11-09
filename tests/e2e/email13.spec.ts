import { expect, test } from '@playwright/test';
import { afterSplash, fillSure, PASS, prefs, uniq } from './helpers';

// البند 13: كود الإيميل: سبب واضح لو الإرسال فشل، و"ابعت تاني" بعداد من رد Supabase
async function toAccount(page: import('@playwright/test').Page, email: string) {
  await page.goto('/#/register');
  await afterSplash(page);
  await fillSure(page, 'form input', 0, 'محل الإيميل');
  await fillSure(page, 'form input', 1, 'صاحب المحل');
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[type=email]').fill(email);
  await fillSure(page, 'input[type=password]', 0, PASS);
  await fillSure(page, 'input[type=password]', 1, PASS);
}

test('الإرسال فشل من إعدادات SMTP: رسالة عربي بالسبب والحل، ومن غير إنجليزي', async ({ page }, info) => {
  test.setTimeout(120_000);
  await prefs(page, info);
  await page.route('**/auth/v1/signup**', (route) => route.fulfill({ status: 500, contentType: 'application/json', body: JSON.stringify({ code: 500, error_code: 'unexpected_failure', msg: 'Error sending confirmation email' }) }));
  await toAccount(page, uniq('smtp'));
  await page.getByRole('button', { name: 'التالي' }).click();
  const err = page.getByRole('alert').filter({ hasText: 'الإيميل ما اتبعتش' });
  await expect(err).toBeVisible();
  await expect(err).toContainText('SMTP');
  await expect(err).toContainText('Brevo');
  await expect(page.locator('body')).not.toContainText('Error sending');
});

test('"ابعت تاني": العداد بيبدأ من الرقم اللي Supabase قاله لما الطلب يتكرر بسرعة', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await toAccount(page, uniq('wait'));
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[autocomplete=one-time-code]').waitFor();
  // العداد الأول بعد الإرسال (60 ثانية)
  await expect(page.getByText(/إعادة الإرسال بعد \d+ ثانية/)).toBeVisible();
  // نخلّص العداد بسرعة: الوقت بيتقدّم
  await page.clock.install();
  await page.clock.runFor(61_000);
  await page.route('**/auth/v1/resend**', (route) => route.fulfill({ status: 429, contentType: 'application/json', body: JSON.stringify({ code: 429, error_code: 'over_request_rate_limit', msg: 'For security purposes, you can only request this after 37 seconds.' }) }));
  await page.getByRole('button', { name: 'إعادة إرسال الرسالة' }).click();
  await expect(page.getByText('استنى 37 ثانية وبعدين جرّب تاني').first()).toBeVisible();
  await expect(page.getByText(/إعادة الإرسال بعد 3[67] ثانية/)).toBeVisible();
});
