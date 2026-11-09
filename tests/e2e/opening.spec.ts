import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

// البند 4: جرد المحل أول مرة: جدول زي Excel (ولصق منه)، وخزن، وديون عملاء وموردين، وملخص متوازن، ومؤشر تقدم في لوحة التحكم
test('جرد المحل أول مرة: لصق من Excel ← خزن ← ديون ← ملخص ← رأس المال = الأصول − الالتزامات', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('open'), 'محل الجرد');

  // مؤشر التقدم في لوحة التحكم: 0 من 5
  await expect(page.getByTestId('opening-card-count')).toContainText('0');
  await page.getByTestId('opening-card').click();
  await expect(page.getByRole('heading', { name: 'جرد المحل أول مرة' })).toBeVisible();

  // لصق صنفين من Excel مرة واحدة (أعمدة بـ Tab)
  const first = page.getByLabel('الصنف 1', { exact: true });
  await first.focus();
  await page.evaluate(() => {
    const el = document.activeElement as HTMLElement;
    const dt = new DataTransfer();
    dt.setData('text/plain', 'شاشة A05\tقطعة غيار\t٥\t100\t250\nشاحن سريع\tإكسسوار\t3\t25.50\t60');
    el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
  });
  await expect(page.getByLabel('الصنف 2', { exact: true })).toHaveValue('شاحن سريع');
  await expect(page.getByLabel('النوع 2', { exact: true })).toHaveValue('accessory');
  // 5 × 100 + 3 × 25.50 = 576.50
  await expect(page.getByTestId('opening-stock-total')).toContainText('576.50');
  // Enter بينزل للسطر اللي تحته
  await page.getByLabel('الكمية 2', { exact: true }).press('Enter');
  await expect(page.getByLabel('الكمية 3', { exact: true })).toBeFocused();
  await noHorizontalScroll(page);
  await page.getByTestId('opening-save').click();
  await expect(page.getByText('اتسجل المخزون الافتتاحي (2 صنف)')).toBeVisible();

  // الخزن: كاش الدرج 2000
  await page.getByLabel('كاش الدرج').fill('2000');
  await page.getByTestId('opening-save').click();
  await expect(page.getByText('اتسجلت أرصدة الخزن')).toBeVisible();

  // عميل عليه 300، وعميل دافع عربون 50 (المحل عليه ليه)
  await expect(page.getByTestId('opening-customers')).toBeVisible();
  await page.getByLabel('الاسم 1', { exact: true }).fill('عميل مديون');
  await page.getByLabel('التليفون 1', { exact: true }).fill(`010${String(Date.now()).slice(-8)}`);
  await page.getByLabel('المبلغ 1', { exact: true }).fill('300');
  await page.getByLabel('الاسم 2', { exact: true }).fill('عميل عربون');
  await page.getByLabel('التليفون 2', { exact: true }).fill(`012${String(Date.now()).slice(-8)}`);
  await page.getByLabel('المبلغ 2', { exact: true }).fill('50');
  await page.getByLabel('الاتجاه 2', { exact: true }).selectOption('we_owe');
  await page.getByTestId('opening-save').click();
  await expect(page.getByText('اتسجل 2 رصيد')).toBeVisible();

  // مورد ليه 400 (نستنى خطوة الموردين تظهر: خانات العملاء ليها نفس الأسماء)
  await expect(page.getByTestId('opening-suppliers')).toBeVisible();
  await expect(page.getByTestId('opening-step-suppliers')).toHaveAttribute('aria-current', 'step');
  await page.getByLabel('الاسم 1', { exact: true }).fill('مورد الشاشات');
  await page.getByLabel('المبلغ 1', { exact: true }).fill('400');
  await page.getByTestId('opening-save').click();
  await expect(page.getByText('اتسجل 1 رصيد')).toBeVisible();

  // الشركاء: المحل ده ملوش شركاء ← رسالة بتوديك لصفحة الشركاء، ونتخطّى
  await expect(page.getByTestId('opening-partners')).toContainText('مفيش شركاء متسجلين');
  await page.getByTestId('opening-skip').click();

  // الملخص: 576.50 + 2000 + 250 − 400 = 2426.50
  await expect(page.getByTestId('opening-sum-stock')).toContainText('576.50');
  await expect(page.getByTestId('opening-sum-cash')).toContainText('2,000');
  await expect(page.getByTestId('opening-sum-receivables')).toContainText('250');
  await expect(page.getByTestId('opening-sum-payables')).toHaveText('400');
  await expect(page.getByTestId('opening-sum-capital')).toContainText('2,426.50');
  await expect(page.getByTestId('opening-balanced')).toContainText('متوازن');
  await page.getByTestId('opening-finish').click();
  await expect(page.getByText('خلص جرد المحل')).toBeVisible();
  // المؤشر اختفى، والوضع المالي بيقول نفس الأرقام
  await expect(page.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible();
  await expect(page.getByTestId('opening-card')).toHaveCount(0);
  await page.goto('/#/finance');
  await afterSplash(page);
  await expect(page.getByTestId('kpi-net_worth')).toContainText('2,426.50');
  await expect(page.getByTestId('kpi-inventory')).toContainText('576.50');
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
});
