import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

// R3: استيراد العملاء من ملف: 3 سليمين و1 غلط ← المعاينة ← استيراد ← ظاهرين في القايمة. والمرة التانية نفس الملف = "موجود"
test('استيراد العملاء من ملف CSV: معاينة بالسليم والغلط، واستيراد، والموجود بيتخطى', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('cimp'), 'محل الاستيراد');
  await page.goto('/#/customers');
  await afterSplash(page);

  const csv = '﻿الاسم,الموبايل,العنوان\nعميل أول,01011112222,المعادي\nعميل تاني,٠١١٢٢٢٢٣٣٣٣,\nعميل تالت,+20 122 333 4444,الهرم\nغلط,0101,\n';
  const file = { name: 'customers.csv', mimeType: 'text/csv', buffer: Buffer.from(csv, 'utf8') };

  await page.getByTestId('customers-import').click();
  let dlg = page.getByRole('dialog');
  await dlg.getByTestId('cimport-file').setInputFiles(file);
  await expect(dlg.getByTestId('cimport-ok')).toContainText('3');
  await expect(dlg.getByTestId('cimport-bad')).toContainText('1');
  await expect(dlg.getByTestId('cimport-row')).toHaveCount(4);
  await expect(dlg.locator('[data-testid=cimport-row][data-state=phone]')).toContainText('الموبايل مش رقم مصري صح');
  await noHorizontalScroll(page);
  await dlg.getByTestId('cimport-save').click();
  await expect(page.getByText('اتستورد 3 عميل')).toBeVisible();
  await expect(dlg).toHaveCount(0);
  for (const n of ['عميل أول', 'عميل تاني', 'عميل تالت']) await expect(page.getByText(n, { exact: true })).toBeVisible();
  await expect(page.getByText('01122223333')).toBeVisible();

  // نفس الملف تاني: كلهم موجودين، ومفيش حاجة تتستورد
  await page.getByTestId('customers-import').click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('cimport-file').setInputFiles(file);
  await expect(dlg.getByTestId('cimport-ok')).toContainText('0');
  await expect(dlg.locator('[data-testid=cimport-row][data-state=exists]')).toHaveCount(3);
  await expect(dlg.getByTestId('cimport-save')).toBeDisabled();
});
