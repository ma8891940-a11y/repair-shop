import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq, fillAmount } from './helpers';

// البند 5: الشركاء: النسب لحد 100%، ورأس المال، وتوزيع الأرباح، والسحب مش مصروف، وكشف حساب الشريك
test('الشركاء: نسب ← إيداع ← ربح من بيع ← توزيع ← سحب (الربح زي ما هو) ← كشف حساب', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('partners'), 'محل الشركاء');

  await page.goto('/#/partners');
  await afterSplash(page);
  await expect(page.getByRole('heading', { name: 'الشركاء' })).toBeVisible();
  const addPartner = async (name: string, share: string) => {
    await page.getByTestId('partners-add').click();
    const dlg = page.getByRole('dialog');
    await dlg.getByLabel('اسم الشريك').fill(name);
    await dlg.getByLabel('النسبة من صافي الربح').fill(share);
    await dlg.getByTestId('partner-save').click();
  };
  await addPartner('أحمد', '60');
  await expect(page.getByText('اتحفظ الشريك')).toBeVisible();
  await addPartner('سامي', '٣٠');
  await expect(page.getByTestId('partner-row')).toHaveCount(2);
  await expect(page.getByTestId('partners-rest')).toContainText('10');
  // أكتر من 100%: بيترفض برسالة واضحة
  await addPartner('زيادة', '20');
  await expect(page.getByRole('dialog').getByText(/هيعدّي 100%/)).toBeVisible();
  await page.getByRole('dialog').getByRole('button', { name: 'إلغاء' }).click();

  // إيداع رأس مال لأحمد 5000
  await page.getByTestId('partner-row').filter({ hasText: 'أحمد' }).getByTestId('partner-deposit').click();
  await fillAmount(page.getByRole('dialog'), '5000');
  await page.getByRole('dialog').getByTestId('partner-money-save').click();
  await expect(page.getByText('اتسجل إيداع أحمد')).toBeVisible();
  await expect(page.getByTestId('partner-row').filter({ hasText: 'أحمد' }).getByTestId('partner-capital')).toContainText('5,000');

  // ربح: صنف بـ 20، بيع 10 بـ 50 ← ربح 300
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الموردين' }).click();
  await page.getByRole('button', { name: 'مورد جديد' }).click();
  await page.getByRole('dialog').getByLabel('اسم المورد').fill('مورد');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف المورد')).toBeVisible();
  await page.getByRole('tab', { name: 'الأصناف' }).click();
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  await page.getByRole('dialog').getByLabel('الصنف').fill('جراب');
  await page.getByRole('dialog').getByLabel('النوع').selectOption('accessory');
  await page.getByRole('dialog').getByLabel('سعر البيع').fill('50');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف الصنف')).toBeVisible();
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  let dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  await dlg.getByLabel('الكمية').fill('10');
  await dlg.getByLabel('سعر الوحدة').fill('20');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل الشراء')).toBeVisible();
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  await dlg.getByLabel('الكمية').fill('10');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل البيع')).toBeVisible();

  // التوزيع: معاينة ← أحمد 180 وسامي 90 والمحل 30
  await page.goto('/#/partners');
  await afterSplash(page);
  await page.getByTestId('partners-distribute').click();
  await expect(page.getByTestId('distribute-profit')).toContainText('300');
  await expect(page.getByTestId('distribute-share').filter({ hasText: 'أحمد' })).toContainText('180');
  await expect(page.getByTestId('distribute-share').filter({ hasText: 'سامي' })).toContainText('90');
  await page.getByTestId('distribute-confirm').click();
  await expect(page.getByText('اتوزعت الأرباح')).toBeVisible();
  await expect(page.getByTestId('partner-row').filter({ hasText: 'أحمد' }).getByTestId('partner-current')).toContainText('180');
  // نفس الفترة تاني: ممنوع
  await page.getByTestId('partners-distribute').click();
  await expect(page.getByRole('dialog').getByText(/اتوزعت أرباحها قبل كده/)).toBeVisible();
  await expect(page.getByTestId('distribute-confirm')).toBeDisabled();
  await page.getByRole('dialog').getByRole('button', { name: 'إلغاء' }).click();

  // سحب سامي 50: جاريه 40، وصافي الربح في الوضع المالي لسه 300
  await page.getByTestId('partner-row').filter({ hasText: 'سامي' }).getByTestId('partner-withdraw').click();
  await fillAmount(page.getByRole('dialog'), '50');
  await page.getByRole('dialog').getByTestId('partner-money-save').click();
  await expect(page.getByText('اتسجل سحب سامي')).toBeVisible();
  await expect(page.getByTestId('partner-row').filter({ hasText: 'سامي' }).getByTestId('partner-current')).toContainText('40');
  await noHorizontalScroll(page);

  // كشف حساب أحمد
  await page.getByTestId('partner-row').filter({ hasText: 'أحمد' }).getByTestId('partner-statement').click();
  await expect(page.getByTestId('statement-balance')).toContainText('5,180');
  await expect(page.getByTestId('move-row')).toHaveCount(2);

  await page.goto('/#/finance');
  await afterSplash(page);
  await expect(page.getByTestId('kpi-profit')).toContainText('300');
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  const payables = await page.getByTestId('kpi-payables').innerText();

  // شريك جديد داخل بـ 50,000 كاش من فورم الشريك نفسه: الخزنة بتزيد، والربح و"عليّا للناس" زي ما هما
  await page.goto('/#/partners');
  await afterSplash(page);
  await page.getByTestId('partners-add').click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('اسم الشريك').fill('كريم');
  await dlg.getByLabel('النسبة من صافي الربح').fill('5');
  await dlg.getByTestId('cap-kind-cash').click();
  await dlg.getByTestId('cap-amount').fill('50000');
  await dlg.getByTestId('partner-save').click();
  await expect(page.getByText('اتحفظ الشريك')).toBeVisible();
  await expect(page.getByTestId('partner-row').filter({ hasText: 'كريم' }).getByTestId('partner-capital')).toContainText('50,000');

  // وشريك داخل ببضاعة (3 جرابات × 20): المخزون بيزيد
  await page.getByTestId('partners-add').click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('اسم الشريك').fill('منير');
  await dlg.getByLabel('النسبة من صافي الربح').fill('0');
  await dlg.getByTestId('cap-kind-goods').click();
  await dlg.getByLabel('الصنف 1', { exact: true }).selectOption({ label: 'جراب' });
  await dlg.getByLabel('الكمية 1', { exact: true }).fill('3');
  await dlg.getByLabel('تكلفة الوحدة 1', { exact: true }).fill('20');
  await dlg.getByTestId('partner-save').click();
  await expect(page.getByTestId('partner-row').filter({ hasText: 'منير' }).getByTestId('partner-capital')).toContainText('60');

  await page.goto('/#/finance');
  await afterSplash(page);
  await expect(page.getByTestId('kpi-profit')).toContainText('300');
  expect(await page.getByTestId('kpi-payables').innerText()).toBe(payables);
  await expect(page.getByTestId('kpi-inventory')).toContainText('60');
  // حقوق الملكية في قسم لوحده، والمعادلة متوازنة
  const eq = page.getByTestId('equity-panel');
  await expect(eq).toBeVisible();
  await expect(eq.getByTestId('equity-partner').filter({ hasText: 'كريم' })).toContainText('50,000');
  await expect(eq.getByTestId('equity-partners-due')).toContainText('أرباح مستحقة للشركاء');
  await expect(page.getByTestId('equity-equation')).toHaveClass(/text-ok/);
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
});
