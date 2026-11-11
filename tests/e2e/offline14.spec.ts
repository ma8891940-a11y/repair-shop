import { expect, test } from '@playwright/test';
import { afterSplash, prefs, quickIntake, registerShop, uniq, fillAmount, pickItem } from './helpers';

// البند 14: الشغل اليومي كله من غير نت، وكل اللي محتاج نت مقفول بهدوء وبيتفتح لوحده.
// بيشتغل على سيرفر التطوير، وعلى نسخة الإنتاج كمان (E2E_PROD=1) بنفس الخطوات.
test('من غير نت: التكلفة والملاحظة والفحص والدفعة والبيع بيتسجلوا على الجهاز ويتبعتوا لوحدهم، والإعدادات والشراء مقفولين بهدوء وبيتفتحوا لوحدهم', async ({ page, context }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('off14'), 'محل من غير نت');

  // مخزون أولي (والنت شغال): صنف واحد 5 قطع
  await page.goto('/#/opening');
  await afterSplash(page);
  const first = page.getByLabel('الصنف 1', { exact: true });
  await first.focus();
  await page.evaluate(() => {
    const el = document.activeElement as HTMLElement;
    const dt = new DataTransfer();
    dt.setData('text/plain', 'جراب شفاف\tإكسسوار\t5\t20\t50');
    el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
  });
  await page.getByTestId('opening-save').click();
  await expect(page.getByText(/اتسجل المخزون الافتتاحي/)).toBeVisible();
  // الشاشات اللي هنشتغل عليها اتفتحت مرة والنت شغال (نسخة على الجهاز)
  await page.goto('/#/inventory');
  await expect(page.getByText('جراب شفاف').first()).toBeVisible();
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل من غير نت');
  await page.getByLabel('التكلفة النهائية').fill('300');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  // فلوس الجهاز اتحدّثت (والنسخة اللي على الجهاز معاها)
  await expect(page.getByRole('button', { name: 'تسجيل دفعة' })).toBeVisible();

  // ---- النت فصل ----
  await context.setOffline(true);
  await expect(page.getByTestId('connection')).toHaveAttribute('data-state', 'offline', { timeout: 15_000 });
  // التكلفة النهائية
  await page.getByLabel('التكلفة النهائية').fill('350');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتسجل على الجهاز').first()).toBeVisible();
  // ملاحظة داخلية
  await page.getByLabel('ملاحظات داخلية').fill('الشاشة محتاجة تتطلب');
  await page.getByLabel('ملاحظات داخلية').press('Control+Enter');
  // الفحص السريع
  await page.getByRole('radiogroup', { name: 'الشاشة' }).first().getByRole('radio', { name: 'شغال' }).click();
  await page.getByRole('button', { name: 'حفظ الفحص' }).click();
  // دفعة
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '100');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  // بيع من المخزون
  await page.goto('/#/inventory');
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  const sale = page.getByRole('dialog');
  await pickItem(sale, 'جراب شفاف', { qty: 5 });
  await sale.getByRole('textbox', { name: 'سعر البيع', exact: true }).fill('50');
  await sale.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  // كله مستني في الطابور
  await expect(page.getByTestId('connection')).toContainText(/بدون نت \(\d+\)/);

  // اللي محتاج نت: مقفول بهدوء (من غير أخطاء حمرا)
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  const purchase = page.getByRole('dialog');
  await expect(purchase).toBeVisible();
  await expect(purchase.getByRole('button', { name: 'سجّل' })).toBeDisabled();
  await expect(purchase.getByTestId('needs-net')).toHaveAttribute('title', /محتاج إنترنت/);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.goto('/#/settings');
  await expect(page.getByTestId('settings-offline')).toBeVisible();
  await expect(page.getByRole('button', { name: 'حفظ الرابط' })).toBeDisabled();

  // ---- النت رجع: الإعدادات بتتفتح لوحدها، والطابور بيتبعت بالترتيب ----
  await context.setOffline(false);
  await expect(page.getByTestId('settings-offline')).toHaveCount(0, { timeout: 15_000 });
  await expect(page.getByTestId('public-url-input')).toBeEnabled();
  await expect(page.getByTestId('connection')).not.toHaveAttribute('data-state', 'offline', { timeout: 15_000 });
  await expect.poll(async () => (await page.getByTestId('connection').innerText()).match(/\(\d+\)/)?.[0] ?? '', { timeout: 60_000 }).toBe('');

  // كله وصل للسيرفر
  await page.goto(dev);
  await afterSplash(page);
  await expect(page.getByLabel('التكلفة النهائية')).toHaveValue('350');
  await expect(page.getByText('الشاشة محتاجة تتطلب')).toBeVisible();
  await expect(page.getByTestId('payment-edit')).toHaveCount(1);
  await expect(page.getByRole('radiogroup', { name: 'الشاشة' }).first().getByRole('radio', { name: 'شغال' })).toHaveAttribute('aria-checked', 'true');
  await page.goto('/#/inventory');
  await expect(page.getByText('جراب شفاف').first()).toBeVisible();
  await expect(page.locator('main')).toContainText('4'); // اتباع واحد من 5
});
