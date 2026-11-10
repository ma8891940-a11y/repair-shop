import { expect, test } from '@playwright/test';
import { prefs, registerShop, uniq } from './helpers';

// الميزات الإضافية: الأعطال الجاهزة، والطباعة التلقائية، وملخص اليوم على واتساب. وكل واحدة بتتقفل من الإعدادات
test('الإضافات: عطل جاهز بيملا العطل والتكلفة ← الطباعة التلقائية ← ملخص اليوم من غير بيانات عملاء ← القفل من الإعدادات', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    (window as unknown as { __opened: string[] }).__opened = [];
    window.open = ((u: string) => {
      (window as unknown as { __opened: string[] }).__opened.push(String(u));
      return null;
    }) as typeof window.open;
    window.print = () => undefined;
  });
  await registerShop(page, uniq('extras'), 'محل الإضافات');

  // 1) الإعدادات: عطل جاهز، وتشغيل الطباعة التلقائية
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'إضافات' }).click();
  await page.getByLabel('اسم الزرار').fill('شاشة A54');
  await page.getByLabel('وصف العطل').fill('تغيير شاشة أصلية');
  await page.getByLabel('التكلفة التقريبية').fill('1,500.50');
  await page.getByRole('button', { name: 'أضف' }).click();
  await expect(page.getByTestId('preset-list')).toContainText('شاشة A54');
  await expect(page.getByTestId('preset-list')).toContainText('1,500.50');
  const autoPrint = page.getByRole('checkbox', { name: 'اطبع الإيصال تلقائيًا بعد الاستلام' });
  await expect(autoPrint).toHaveAttribute('data-state', 'unchecked');
  await autoPrint.click();
  await expect(autoPrint).toHaveAttribute('data-state', 'checked');

  // 2) الاستلام: الزرار بيملا العطل والتكلفة، والحفظ بيفتح الإيصال للطباعة
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01055554444');
  await page.getByLabel('اسم العميل').fill('عميل الإضافات');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A54');
  await page.getByTestId('intake-presets').getByRole('button', { name: /^شاشة A54/ }).click();
  await expect(page.getByLabel('العطل زي ما العميل وصفه')).toHaveValue('تغيير شاشة أصلية');
  await expect(page.getByLabel('التكلفة التقديرية')).toHaveValue('1,500.50');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  // "اطبع تلقائي" = الاستيكر والإيصال الورقي بيتطبعوا لوحدهم من نفس الشاشة ("طباعة وإرسال")، من غير ما نسيبها
  await expect(page.getByTestId('print-send')).toBeVisible();
  await expect(page.getByTestId('ps-sticker-done')).toHaveAttribute('data-done', 'true', { timeout: 30_000 });
  await expect(page.getByTestId('ps-paper-done')).toHaveAttribute('data-done', 'true', { timeout: 30_000 });
  await expect(page).toHaveURL(/#\/intake/);
  // التنبيهات ("اتسجّل الجهاز"...) ما بتتطبعش على الإيصال
  await page.keyboard.press('Escape');
  await page.goto('/#/devices');
  await page.getByText('عميل الإضافات').filter({ visible: true }).first().click();
  const id = page.url().split('/devices/')[1];
  await page.goto(`/#/print/receipt/${id}`);
  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('[aria-live="polite"]').first()).toBeHidden();
  await page.emulateMedia({ media: 'screen' });
  await expect(page.getByText('محل الإضافات').first()).toBeVisible();

  // 3) ملخص اليوم: أرقام بس، والاسم ورقم العميل مش في الرسالة
  await page.goto('/#/');
  await page.getByRole('button', { name: 'ملخص اليوم' }).click();
  await expect.poll(async () => (await page.evaluate(() => (window as unknown as { __opened: string[] }).__opened)).length).toBe(1);
  const url = (await page.evaluate(() => (window as unknown as { __opened: string[] }).__opened))[0];
  expect(url).toMatch(/^https:\/\/wa\.me\/\?text=/);
  const text = decodeURIComponent(url.split('text=')[1]);
  expect(text).toContain('ملخص اليوم: محل الإضافات');
  expect(text).toContain('أجهزة دخلت: 1');
  expect(text).not.toContain('عميل الإضافات');
  expect(text).not.toContain('01055554444');

  // 4) القفل من الإعدادات: الزرار والأعطال الجاهزة بيختفوا
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'إضافات' }).click();
  await page.getByRole('checkbox', { name: 'ملخص اليوم على واتساب' }).click();
  await expect(page.getByRole('checkbox', { name: 'ملخص اليوم على واتساب' })).toHaveAttribute('data-state', 'unchecked');
  await page.getByRole('checkbox', { name: 'أعطال جاهزة في الاستلام' }).click();
  await expect(page.getByRole('checkbox', { name: 'أعطال جاهزة في الاستلام' })).toHaveAttribute('data-state', 'unchecked');
  await page.goto('/#/');
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'ملخص اليوم' })).toHaveCount(0);
  await page.goto('/#/intake');
  await expect(page.getByLabel('الموديل')).toBeVisible();
  await expect(page.getByTestId('intake-presets')).toHaveCount(0);
});
