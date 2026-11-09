import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

// البند 6: ربط عميل بمورد: كشف صافي، ومقاصة، وفك الربط
test('ربط عميل بمورد: الربط ← الكشف الصافي ← مقاصة ← فك الربط', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('links'), 'محل الربط');

  // حسن عليه 700 كعميل، وليه 500 كمورد (من جرد المحل)
  await page.goto('/#/opening');
  await afterSplash(page);
  await page.getByTestId('opening-skip').click();
  await expect(page.getByLabel('كاش الدرج')).toBeVisible();
  await page.getByTestId('opening-skip').click();
  await expect(page.getByTestId('opening-customers')).toBeVisible();
  await page.getByLabel('الاسم 1', { exact: true }).fill('حسن التاجر');
  await page.getByLabel('التليفون 1', { exact: true }).fill(`010${String(Date.now()).slice(-8)}`);
  await page.getByLabel('المبلغ 1', { exact: true }).fill('700');
  await page.getByTestId('opening-save').click();
  await expect(page.getByTestId('opening-suppliers')).toBeVisible();
  await page.getByLabel('الاسم 1', { exact: true }).fill('حسن التاجر');
  await page.getByLabel('المبلغ 1', { exact: true }).fill('500');
  await page.getByTestId('opening-save').click();
  await expect(page.getByTestId('opening-partners')).toBeVisible();

  // كشف العميل ← اربط بمورد
  await page.goto('/#/finance/balances/customers');
  await afterSplash(page);
  await page.getByTestId('balance-row').filter({ hasText: 'حسن التاجر' }).click();
  await expect(page.getByTestId('party-link')).toBeVisible();
  await page.getByTestId('party-link-add').click();
  await page.getByTestId('party-link-options').getByRole('button', { name: /حسن التاجر/ }).click();
  await expect(page.getByText('اتربطوا')).toBeVisible();
  await expect(page.getByTestId('party-link-with')).toContainText('حسن التاجر');

  // الكشف الصافي: 700 − 500 = 200
  await page.getByTestId('party-link-net').click();
  await expect(page.getByTestId('statement-balance')).toContainText('200');
  await expect(page.getByTestId('move-row')).toHaveCount(2);
  await noHorizontalScroll(page);

  // مقاصة بأقصى مبلغ (500): الصافي لسه 200
  await page.getByTestId('linked-netting').click();
  await expect(page.getByTestId('netting-amount')).toHaveValue('500');
  await page.getByTestId('netting-confirm').click();
  await expect(page.getByText(/اتعملت مقاصة/)).toBeVisible();
  await expect(page.getByTestId('statement-balance')).toContainText('200');
  await expect(page.getByTestId('linked-netting')).toBeDisabled();

  // كشف العميل لوحده: 200، وفك الربط (مع تراجع)
  await page.goto('/#/finance/balances/customers');
  await afterSplash(page);
  await page.getByTestId('balance-row').filter({ hasText: 'حسن التاجر' }).click();
  await expect(page.getByTestId('statement-balance')).toContainText('200');
  await page.getByTestId('party-link-unlink').click();
  await expect(page.getByText('اتفك الربط، والكشوف القديمة زي ما هي')).toBeVisible();
  await expect(page.getByTestId('party-link-add')).toBeVisible();
  await expect(page.getByTestId('statement-balance')).toContainText('200');
});
