import { expect, test } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

// U6: الشاشات الجديدة (المستعمل، والتصنيفات، والتحليلات، وتبويبات الإعدادات الجديدة) من غير نت:
// ما بتقعش (من غير أخطاء JavaScript)، والبرنامج بيبيّن إن النت فاصل، والإعدادات بتتقفل بهدوء، ولما النت يرجع كله بيرجع لوحده.
const SCREENS = ['/#/used', '/#/categories', '/#/analytics'];
const NEW_TABS = ['alerts', 'checks', 'catalog', 'security', 'printers'];

test('من غير نت: الشاشات الجديدة ما بتقعش، والإعدادات الجديدة مقفولة بهدوء، وبترجع لوحدها', async ({ page, context }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const crashes: string[] = [];
  page.on('pageerror', (e) => crashes.push(`${page.url().replace(/^.*#/, '#')} ${e.message}`));
  await registerShop(page, uniq('u6off'), 'محل من غير نت');

  // أول مرة بالنت (البرنامج بيحمّل الشاشات)
  for (const s of [...SCREENS, ...NEW_TABS.map((t) => `/#/settings?tab=${t}`)]) {
    await page.goto(s);
    await afterSplash(page);
    await expect(page.locator('main').first()).toBeVisible();
  }

  await context.setOffline(true);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'offline', { timeout: 15_000 });

  for (const s of SCREENS) {
    await page.goto(s);
    await expect(page.locator('main').first()).toBeVisible();
    // يا إما البيانات اللي اتحمّلت، يا إما رسالة واضحة. مش شاشة بيضا
    await expect.poll(async () => (await page.locator('main').first().innerText()).trim().length, { message: s }).toBeGreaterThan(10);
    await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'offline');
  }
  for (const t of NEW_TABS) {
    await page.goto(`/#/settings?tab=${t}`);
    await expect(page.getByTestId('settings-offline'), t).toBeVisible();
    // كل أزرار الحفظ جوه التبويب مقفولة (مفيش حاجة تتبعت وتضيع)
    const panel = page.getByRole('tabpanel');
    const saves = panel.getByRole('button', { name: /^(حفظ|احفظ)/ });
    for (const b of await saves.all()) await expect(b, t).toBeDisabled();
  }
  // إشعارات الجهاز: زرار التفعيل مقفول من غير نت (لو المتصفح بيدعمها)
  await page.goto('/#/settings?tab=alerts');
  const enable = page.getByTestId('push-enable');
  if (await enable.count()) await expect(enable).toBeDisabled();

  // النت رجع: كله بيرجع لوحده
  await context.setOffline(false);
  await expect(page.getByTestId('settings-offline')).toHaveCount(0, { timeout: 15_000 });
  for (const s of SCREENS) {
    await page.goto(s);
    await expect(page.locator('main').first()).toBeVisible();
    await expect(page.getByTestId('error-state')).toHaveCount(0, { timeout: 15_000 });
  }
  expect(crashes, crashes.join('\n')).toEqual([]);
});
