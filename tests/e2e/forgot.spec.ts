import { expect, test, type Page } from '@playwright/test';
import { afterSplash, fillSure, PASS, prefs } from './helpers';

// نسيت كلمة السر، والتسجيل بإيميل عنده حساب (ردود Supabase متقلّدة، من غير إيميل حقيقي)
const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
const USER = { id: '11111111-1111-4111-8111-111111111111', aud: 'authenticated', email: 'forgot@x.test', role: 'authenticated', app_metadata: {}, user_metadata: {}, factors: [], created_at: '2026-01-01T00:00:00Z' };
const exp = 4102444800;
const TOKEN = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: USER.id, exp, aal: 'aal1', role: 'authenticated', session_id: 's' })}.x`;
const SESSION = { access_token: TOKEN, token_type: 'bearer', expires_in: 3600, expires_at: exp, refresh_token: 'r', user: USER };
const json = (body: unknown, status = 200) => ({ status, contentType: 'application/json', headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' }, body: JSON.stringify(body) });

async function mock(page: Page) {
  const calls: { verify: unknown[]; user: { password?: string }[]; logout: string[] } = { verify: [], user: [], logout: [] };
  const cors = { status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } };
  await page.route('**/rest/v1/**', (r) => (r.request().method() === 'OPTIONS' ? r.fulfill(cors) : r.fulfill(json(null))));
  await page.route('**/auth/v1/**', (r) => {
    const q = r.request();
    const u = q.url();
    if (q.method() === 'OPTIONS') return r.fulfill(cors);
    if (u.includes('/recover')) return r.fulfill(json({}));
    if (u.includes('/verify')) {
      const b = q.postDataJSON() as { token: string };
      calls.verify.push(b);
      return b.token === '123456' ? r.fulfill(json(SESSION)) : r.fulfill(json({ code: 403, error_code: 'otp_expired', msg: 'Token has expired or is invalid' }, 403));
    }
    if (u.includes('/user') && q.method() === 'PUT') {
      calls.user.push(q.postDataJSON() as { password?: string });
      return r.fulfill(json(USER));
    }
    if (u.includes('/logout')) calls.logout.push(u);
    return r.fulfill(json(u.includes('/user') ? USER : {}));
  });
  return calls;
}

test('نسيت كلمة السر: الرابط من الدخول ← كود غلط ← كود صح ← كلمة سر جديدة، والأجهزة التانية بتخرج', async ({ page }, info) => {
  await prefs(page, info);
  const calls = await mock(page);
  await page.goto('/');
  await afterSplash(page);
  await page.locator('input[type=email]').fill('Forgot@x.test');
  await page.getByTestId('forgot-link').click();
  const s = page.getByTestId('forgot-screen');
  await expect(s.locator('input[type=email]')).toHaveValue('Forgot@x.test');
  await s.getByRole('button', { name: 'ابعت' }).click();
  await expect(s.getByText('forgot@x.test')).toBeVisible();
  const first = s.locator('input').first();
  await first.click();
  await page.keyboard.type('000000');
  await expect(s.getByText('الكود غلط أو انتهت صلاحيته')).toBeVisible();
  await first.click();
  await page.keyboard.type('123456');
  const n = page.getByTestId('new-password-screen');
  await expect(n).toBeVisible();
  expect(calls.verify.at(-1)).toMatchObject({ email: 'forgot@x.test', type: 'recovery' });
  // إعادة التحميل ما تعدّيش الشاشة
  await page.reload();
  await expect(n).toBeVisible({ timeout: 20_000 });
  await n.locator('input').nth(0).fill('short');
  await n.getByRole('button', { name: 'احفظ' }).click();
  await expect(n.getByRole('alert')).toBeVisible();
  await n.locator('input').nth(0).fill('NewPass-2026');
  await n.locator('input').nth(1).fill('NewPass-2027');
  await n.getByRole('button', { name: 'احفظ' }).click();
  await expect(n.getByRole('alert')).toBeVisible();
  expect(calls.user).toHaveLength(0);
  await n.locator('input').nth(1).fill('NewPass-2026');
  await n.getByRole('button', { name: 'احفظ' }).click();
  await expect(n).toBeHidden();
  expect(calls.user).toEqual([expect.objectContaining({ password: 'NewPass-2026' })]);
  expect(calls.logout.some((u) => u.includes('scope=others'))).toBe(true);
});

test('رابط الاستعادة (القالب الافتراضي): بيفتح كلمة السر الجديدة مش البرنامج', async ({ page }, info) => {
  await prefs(page, info);
  await mock(page);
  await page.goto(`/#access_token=${TOKEN}&expires_at=${exp}&expires_in=3600&refresh_token=r&token_type=bearer&type=recovery`);
  await expect(page.getByTestId('new-password-screen')).toBeVisible({ timeout: 20_000 });
});

test('تسجيل بإيميل عنده حساب: رسالة واضحة بدل انتظار كود مش هييجي', async ({ page }, info) => {
  await prefs(page, info);
  await mock(page);
  await page.route('**/auth/v1/signup**', (r) => (r.request().method() === 'OPTIONS' ? r.fallback() : r.fulfill(json({ ...USER, identities: [] }))));
  await page.goto('/#/register');
  await afterSplash(page);
  await fillSure(page, 'form input', 0, 'محل');
  await fillSure(page, 'form input', 1, 'صاحب');
  await page.getByRole('button', { name: 'التالي' }).click();
  await page.locator('input[type=email]').fill('old@x.test');
  await fillSure(page, 'input[type=password]', 0, PASS);
  await fillSure(page, 'input[type=password]', 1, PASS);
  await page.getByRole('button', { name: 'التالي' }).click();
  await expect(page.getByRole('alert').filter({ hasText: 'عنده حساب' })).toBeVisible();
  await expect(page.locator('input[autocomplete=one-time-code]')).toHaveCount(0);
});
