import { expect, test } from '@playwright/test';
import { prefs, registerShop, uniq } from './helpers';

// خطأ اتصلح: التنقل السريع بين الشاشات (قبل ما حركة الشاشة اللي قبلها تخلص) كان ممكن يسيب الصفحة فاضية
test('التنقل السريع بين الشاشات ما بيسيبش الصفحة فاضية', async ({ page }, info) => {
  await prefs(page, info);
  await registerShop(page, uniq('nav'));
  for (const [path, label] of [
    ['/#/users', 'الاسم'],
    ['/#/devices', 'بحث'],
    ['/#/users', 'الاسم'],
    ['/#/settings', null],
    ['/#/users', 'الاسم'],
  ] as const) {
    await page.goto(path);
    if (label) await expect(page.getByLabel(label).first()).toBeVisible();
  }
  // ضغط متتالي سريع على القائمة
  for (const n of ['الأجهزة', 'الفريق', 'العملاء', 'الفريق']) await page.getByRole('link', { name: n }).filter({ visible: true }).first().click();
  await expect(page.getByLabel('الاسم')).toBeVisible();
});
