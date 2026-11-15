import { expect, test } from '@playwright/test';
import { afterSplash, fillAmount, prefs, quickIntake, registerShop, uniq } from './helpers';

// U5: الطابعات ومصمم الطباعة: طابعة من موديل جاهز ← شيل خانة "المدفوع" من الفاتورة واحفظ ← الفاتورة من غيرها، والمبالغ زي البرنامج
test('مصمم الطباعة: طابعة جاهزة ← إخفاء خانة ← الفاتورة من غيرها والإجمالي والباقي مطابقين ← رجّع الافتراضي', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('printer'), 'محل الطباعة');
  const devUrl = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل الطباعة');
  const inv = `${devUrl.replace('/devices/', '/print/invoice/')}?preview=1`;
  await page.getByLabel('التكلفة النهائية').fill('700');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();

  // الفاتورة بالقالب الافتراضي: المدفوع ظاهر
  await page.goto(inv);
  await expect(page.getByTestId('invoice-paid')).toContainText('200');
  await expect(page.getByTestId('invoice-total')).toContainText('700');

  // الإعدادات ← الطابعات: طابعة A4 جاهزة، وإخفاء "المدفوع" من فاتورة التسليم
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('printer-preset').selectOption({ label: 'HP LaserJet (A4) · A4' });
  await page.getByTestId('printer-add').click();
  await expect(page.getByTestId('printer-row')).toHaveCount(1);
  const d = page.getByTestId('print-designer');
  await d.getByTestId('tpl-doc').selectOption('invoice');
  await d.getByTestId('tpl-printer').selectOption({ index: 1 });
  await d.locator('[data-testid="tpl-block"][data-key="paid"]').getByTestId('tpl-toggle').click();
  await expect(d.getByTestId('tpl-preview')).toBeVisible();
  await d.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظ القالب')).toBeVisible();

  // الفاتورة الحقيقية (من غير معاينة) دلوقتي من غير المدفوع، والإجمالي والباقي من البرنامج زي ما هم
  await page.goto(inv.replace('?preview=1', ''));
  await expect(page.getByTestId('invoice-total')).toContainText('700');
  await expect(page.getByTestId('invoice-due')).toContainText('500');
  await expect(page.getByTestId('invoice-paid')).toHaveCount(0);
  expect(await page.evaluate(() => [...document.querySelectorAll('style')].some((s) => s.textContent?.includes('210mm')))).toBe(true);

  // رجّع الافتراضي: المدفوع رجع
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('print-designer').getByTestId('tpl-doc').selectOption('invoice');
  await page.getByTestId('print-designer').getByTestId('tpl-reset').click();
  await expect(page.getByText('رجع القالب الافتراضي')).toBeVisible();
  await page.goto(inv);
  await expect(page.getByTestId('invoice-paid')).toContainText('200');
});
