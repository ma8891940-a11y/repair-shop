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
  // ضغط متتالي سريع على القائمة (على الموبايل الفريق جوه "المزيد")
  const mobile = info.project.name.startsWith('mobile');
  // القايمة في مجموعات (S2): كل المجموعات المقفولة بتتفتح الأول (وبتفضل مفتوحة، فده مرة واحدة)
  const openAll = async (root: ReturnType<typeof page.locator>) => {
    // القايمة بتتغير مع كل فتحة: نفتح أول مقفولة لحد ما ما يفضلش ولا واحدة
    const closed = root.locator('button[aria-expanded="false"]');
    for (let i = 0; i < 10 && (await closed.count()) > 0; i++) await closed.first().click();
  };
  if (!mobile) await openAll(page.getByTestId('side-nav'));
  const go = async (n: string) => {
    const link = page.getByRole('link', { name: n, exact: true }).filter({ visible: true });
    if (mobile && (await link.count()) === 0) {
      await page.getByRole('button', { name: 'المزيد' }).click();
      await openAll(page.getByTestId('more-nav'));
      const inDialog = page.getByRole('dialog').getByRole('link', { name: n, exact: true });
      await expect(inDialog).toBeVisible();
      await inDialog.click();
      await expect(page.getByRole('dialog')).toBeHidden();
      return;
    }
    await link.first().click();
  };
  for (const n of ['الأجهزة', 'الفريق', 'العملاء', 'الفريق']) await go(n);
  await expect(page.getByLabel('الاسم')).toBeVisible();
  if (mobile) {
    // كل صفحات القائمة متاحة من "المزيد"
    await page.getByRole('button', { name: 'المزيد' }).click();
    await openAll(page.getByTestId('more-nav'));
    for (const n of ['الوضع المالي', 'التقارير', 'الإعدادات', 'سجل النشاط']) await expect(page.getByRole('dialog').getByRole('link', { name: n, exact: true })).toBeVisible();
  }
});
