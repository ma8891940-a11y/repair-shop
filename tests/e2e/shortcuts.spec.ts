import { expect, test, type Page } from '@playwright/test';
import { activateInvite, afterSplash, prefs, registerShop, uniq } from './helpers';

// كل اختصار في البرنامج: برا الخانات وجوه الخانات، والتعديل من صاحب المحل، والمحجوز بيترفض، والصلاحيات
const heading = (page: Page, name: string) => expect(page.getByRole('heading', { name, exact: true }).first()).toBeVisible();

test('كل الاختصارات: التنقل (Alt+رقم وF)، ولوحة الأوامر، والوضع واللغة، وشاشة الاختصارات، والتشخيص، جوه الخانات وبرّاها', async ({ page }, info) => {
  test.skip(info.project.name.startsWith('mobile'), 'الكيبورد للكمبيوتر');
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('keys'));

  const nav: [string, string][] = [
    ['Alt+2', 'استلام جهاز'],
    ['Alt+3', 'الأجهزة'],
    ['Alt+4', 'العملاء'],
    ['Alt+5', 'الوضع المالي'],
    ['Alt+6', 'المخزون'],
    ['Alt+1', 'لوحة التحكم'],
    ['F2', 'استلام جهاز'],
    ['F3', 'الأجهزة'],
    ['F4', 'العملاء'],
    ['F1', 'لوحة التحكم'],
  ];
  for (const [key, name] of nav) {
    await page.keyboard.press(key);
    await heading(page, name);
  }
  // جوه خانة (رقم الموبايل في الاستلام): التنقل شغال برضه
  await page.keyboard.press('Alt+2');
  await page.locator('#intake-phone').click();
  await page.keyboard.press('Alt+3');
  await heading(page, 'الأجهزة');
  await page.keyboard.press('Alt+2');
  await page.locator('#intake-phone').click();
  await page.keyboard.press('F4');
  await heading(page, 'العملاء');

  // لوحة الأوامر
  await page.keyboard.press('Control+K');
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);

  // الوضع الداكن/الفاتح واللغة
  const theme = () => page.evaluate(() => document.documentElement.classList.contains('dark') || document.documentElement.dataset.theme === 'dark');
  const before = await theme();
  await page.keyboard.press('Alt+T');
  await expect.poll(theme).toBe(!before);
  await page.keyboard.press('Alt+T');
  await expect.poll(theme).toBe(before);
  await page.keyboard.press('Alt+L');
  await expect.poll(() => page.evaluate(() => document.documentElement.lang)).toBe('en');
  await page.keyboard.press('Alt+L');
  await expect.poll(() => page.evaluate(() => document.documentElement.lang)).toBe('ar');

  // ؟ برا الخانات بيفتح شاشة الاختصارات، وجوه الخانة بيتكتب عادي
  await page.keyboard.press('Shift+Slash');
  await expect(page.getByTestId('shortcuts-table')).toBeVisible();
  for (const id of ['nav.dashboard', 'nav.intake', 'nav.devices', 'nav.customers', 'nav.finance', 'nav.inventory', 'palette', 'theme', 'lang', 'help', 'diag']) await expect(page.getByTestId(`shortcut-${id}`)).toBeVisible();
  await page.keyboard.press('Escape');
  await page.keyboard.press('Alt+2');
  await page.getByLabel('الموديل').click();
  await page.keyboard.press('Shift+Slash');
  await expect(page.getByTestId('shortcuts-table')).toHaveCount(0);
  await expect(page.getByLabel('الموديل')).toHaveValue('?');

  // شاشة التشخيص
  await page.keyboard.press('Control+Alt+Shift+M');
  await expect(page.getByTestId('motion-diag')).toBeVisible();
  await page.keyboard.press('Control+Alt+Shift+M');
  await expect(page.getByTestId('motion-diag')).toHaveCount(0);
  // Ctrl+Enter بيحفظ الاستلام (والخانات ناقصة: بيبين الغلط بدل ما يسجل)
  await page.getByLabel('الموديل').fill('');
  await page.getByLabel('الموديل').focus();
  await page.keyboard.press('Control+Enter');
  await expect(page.locator('[aria-invalid="true"]').first()).toBeVisible();
});

test('صاحب المحل بيغيّر اختصار، والمحجوز بيترفض بالسبب، والاستقبال ما يوصلش للي ملوش صلاحية عليه', async ({ page, browser }, info) => {
  test.skip(info.project.name.startsWith('mobile'), 'الكيبورد للكمبيوتر');
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('keys2'));
  await page.getByTestId('open-shortcuts').click();
  await page.getByTestId('shortcut-edit-nav.intake').click();
  await expect(page.getByTestId('shortcut-recording')).toBeVisible();
  await page.keyboard.press('Control+J'); // التنزيلات في Chrome
  await expect(page.getByTestId('shortcut-error')).toContainText('محجوز للمتصفح');
  await page.keyboard.press('Alt+Shift+1');
  await expect(page.getByTestId('shortcut-error')).toContainText('بيغيّر لغة الكيبورد');
  await page.keyboard.press('Alt+3'); // مستخدم للأجهزة
  await expect(page.getByTestId('shortcut-error')).toContainText('مستخدم في حاجة تانية');
  await page.keyboard.press('Alt+9');
  await expect(page.getByText('اتحفظ الاختصار')).toBeVisible();
  await expect(page.getByTestId('shortcut-nav.intake')).toContainText('Alt');
  await expect(page.getByTestId('shortcut-nav.intake')).toContainText('9');
  await page.keyboard.press('Escape');
  await page.keyboard.press('Alt+9');
  await heading(page, 'استلام جهاز');
  await page.keyboard.press('Alt+1');
  await page.keyboard.press('Alt+2');
  await heading(page, 'لوحة التحكم');
  // الافتراضي يرجع
  await page.getByTestId('open-shortcuts').click();
  await page.getByTestId('shortcut-reset-nav.intake').click();
  await expect(page.getByTestId('shortcut-nav.intake')).toContainText('2');
  await page.keyboard.press('Escape');

  // الاستقبال: Alt+5 (الوضع المالي) ما بيعملش حاجة، وما فيش زرار "غيّر"
  await page.goto('/#/users');
  const em = uniq('rec-keys');
  await page.getByLabel('الاسم').fill('سارة');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByLabel('الدور').selectOption('reception');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const R = await activateInvite(browser, info, em);
  await R.page.keyboard.press('Alt+5');
  await R.page.waitForTimeout(400);
  await heading(R.page, 'لوحة التحكم');
  await R.page.keyboard.press('Alt+2');
  await heading(R.page, 'استلام جهاز');
  // الاستلام بيفتح والمؤشر في خانة التليفون: نخرج منها الأول (جوه الخانة ؟ بيتكتب)
  await R.page.getByRole('heading', { name: 'استلام جهاز' }).first().click();
  await R.page.keyboard.press('Shift+Slash');
  await expect(R.page.getByTestId('shortcuts-table')).toBeVisible();
  await expect(R.page.getByTestId('shortcut-edit-nav.intake')).toHaveCount(0);
  await afterSplash(R.page);
  await R.ctx.close();
});
