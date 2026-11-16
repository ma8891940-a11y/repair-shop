import { createHmac } from 'node:crypto';
import { expect, test, type Page } from '@playwright/test';
import { PASS, afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

/** كود TOTP (RFC 6238) من المفتاح، زي ما تطبيق التحقق على الموبايل بيحسبه */
function totp(secret: string, at = Date.now()): string {
  const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of secret.replace(/=+$/, '').toUpperCase()) bits += alpha.indexOf(c).toString(2).padStart(5, '0');
  const key = Buffer.from(bits.match(/.{8}/g)!.map((b) => parseInt(b, 2)));
  const msg = Buffer.alloc(8);
  msg.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)));
  const h = createHmac('sha1', key).update(msg).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}
async function typeCode(page: Page, code: string) {
  await page.getByLabel('كود التحقق 1', { exact: true }).click();
  await page.keyboard.type(code);
}
async function signOut(page: Page) {
  const direct = page.getByRole('button', { name: 'خروج' }).filter({ visible: true });
  if (await direct.count()) return direct.first().click();
  await page.getByRole('button', { name: 'المزيد' }).filter({ visible: true }).first().click();
  await page.getByRole('dialog').getByRole('button', { name: 'خروج' }).click();
}

test('C3: كلمة السر الرئيسية ← الخصم الكبير بيسأل عنها (الغلط مرفوض) ← 2FA: الدخول بيطلب الكود ← الكود الصح بيفتح ← القفل', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('sec');
  await registerShop(page, email, 'محل الأمان');

  // كلمة السر الرئيسية
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الأمان' }).click();
  await page.getByTestId('master-new').fill('secret99');
  await page.getByTestId('master-repeat').fill('secret99');
  await page.getByTestId('master-save').click();
  await expect(page.getByText('اتحفظت كلمة السر الرئيسية').first()).toBeVisible();
  await expect(page.getByTestId('master-settings')).toContainText('شغالة');

  // خصم كبير عن التقديرية (1000 ← 100): بيسأل عن الكلمة، والغلط مرفوض، والصح بيحفظ
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`);
  await page.goto(dev);
  await page.getByLabel('التكلفة التقديرية').fill('1000');
  await page.getByLabel('التكلفة النهائية').fill('100');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  const prompt = page.getByTestId('master-prompt');
  await expect(prompt).toBeVisible();
  await prompt.getByTestId('master-input').fill('wrong-one');
  await prompt.getByTestId('master-submit').click();
  await expect(prompt.getByText('الكلمة غلط')).toBeVisible();
  await prompt.getByTestId('master-input').fill('secret99');
  await prompt.getByTestId('master-submit').click();
  await expect(prompt).toHaveCount(0);
  await expect(page.getByText('اتحفظت التكلفة').first()).toBeVisible();

  // 2FA
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الأمان' }).click();
  await page.getByTestId('mfa-enable').click();
  const secret = ((await page.getByTestId('mfa-secret').textContent()) ?? '').trim();
  expect(secret).toMatch(/^[A-Z2-7]{16,}$/);
  await typeCode(page, totp(secret));
  await page.getByTestId('mfa-confirm').click().catch(() => undefined);
  await expect(page.getByText('اتفعّل التحقق بخطوتين').first()).toBeVisible();
  await expect(page.getByTestId('mfa-disable')).toBeVisible();

  // الخروج والدخول: كلمة السر لوحدها مش كفاية
  await signOut(page);
  await page.locator('input[type=email]').fill(email);
  await page.locator('input[type=password]').fill(PASS);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByTestId('mfa-screen')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toHaveCount(0);
  await typeCode(page, totp(secret, Date.now() + 30_000 * 5));
  await expect(page.getByText('الكود غلط').first()).toBeVisible();
  // (الكود اللي فات اتستخدم: بنستنى الكود الجاي)
  await page.waitForTimeout(31_000 - (Date.now() % 30_000));
  await typeCode(page, totp(secret));
  // دخل (على آخر شاشة كان فيها) والبيانات اتفتحت
  await expect(page.getByTestId('mfa-screen')).toHaveCount(0, { timeout: 15_000 });
  await page.goto('/#/');
  await afterSplash(page).catch(() => undefined);
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();

  // القفل
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الأمان' }).click();
  await page.getByTestId('mfa-disable').click();
  await expect(page.getByText('اتقفل التحقق بخطوتين').first()).toBeVisible();
  await expect(page.getByTestId('mfa-enable')).toBeVisible();
});
