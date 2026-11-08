import { expect, test } from '@playwright/test';
import { readFileSync, writeFileSync } from 'node:fs';
import { afterSplash, noHorizontalScroll, prefs, quickIntake, registerShop, uniq } from './helpers';

// البند 3: المخزون قسم مستقل بحساباته
test('المخزون: استيراد Excel ← شراء ← هالك ← مرتجع مورد ← بيع ومرتجع عميل ← باركود وبحث ← حركة الصنف ← تعديل جماعي ← حسابات المخزون ← قطعة يدوية', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  page.on('console', (m) => m.type() === 'error' && console.log('CONSOLE', m.text()));
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
  await registerShop(page, uniq('inv'), 'محل المخزون');

  // مورد
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الموردين' }).click();
  await page.getByRole('button', { name: 'مورد جديد' }).click();
  await page.getByRole('dialog').getByLabel('اسم المورد').fill('مورد القطع');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف المورد')).toBeVisible();
  await page.getByRole('tab', { name: 'الأصناف' }).click();

  // استيراد من Excel (CSV): صنفين صح وسطر غلط بسببه
  const file = info.outputPath('items.csv');
  writeFileSync(file, '﻿الصنف,النوع,التصنيف,الباركود,سعر البيع,الحد الأدنى\nجراب شفاف,إكسسوار,جرابات,,٥٠,٢\nشاشة A15,قطعة غيار,شاشات,,900,1\n,إكسسوار,,,,\n');
  await page.getByTestId('inv-import').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.waitForTimeout(500);
  await page.getByTestId('import-file').setInputFiles({ name: 'items.csv', mimeType: 'text/csv', buffer: readFileSync(file) });
  await expect(page.getByTestId('import-preview')).toContainText('2 صنف جاهز');
  await expect(page.getByTestId('import-preview')).toContainText('السطر 4: اسم الصنف ناقص');
  await page.getByTestId('import-save').click();
  await expect(page.getByText('اتستورد 2 صنف')).toBeVisible();
  await expect(page.getByTestId('item-row')).toHaveCount(2);

  // شراء 10 جرابات × 20 ج
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  let dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ label: 'جراب شفاف (0)' });
  await dlg.getByLabel('الكمية').fill('10');
  await dlg.getByLabel('سعر الوحدة').fill('20');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل الشراء')).toBeVisible();

  // هالك جراب
  await page.getByTestId('op-write_off').click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ label: 'جراب شفاف (10)' });
  await dlg.getByTestId('invop-submit').click();
  await expect(dlg.getByText('اكتب سبب التصحيح')).toBeVisible();
  await dlg.getByLabel('السبب').fill('اتقطع');
  await dlg.getByTestId('invop-submit').click();
  await expect(page.getByText('اتسجل الهالك')).toBeVisible();

  // مرتجع للمورد: جراب، والمورد خصم 15 بس (التكلفة 20 ← فرق 5)
  await page.getByTestId('op-supplier_return').click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ label: 'جراب شفاف (9)' });
  await dlg.getByRole('combobox', { name: /^المورد/ }).selectOption({ label: 'مورد القطع' });
  await expect(dlg.getByText('تكلفتها عندك 20')).toBeVisible();
  await dlg.getByLabel('المورد هيرجّع أو هيخصم').fill('15');
  await dlg.getByLabel('السبب').fill('لون غلط');
  await dlg.getByTestId('invop-submit').click();
  await expect(page.getByText('اتسجل المرتجع للمورد')).toBeVisible();

  // بيع 3 بـ 50، ومرتجع واحد سليم بفلوس من الخزنة
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ label: 'جراب شفاف (8)' });
  await dlg.getByLabel('الكمية').fill('3');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل البيع')).toBeVisible();
  await page.getByTestId('op-sale_return').click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ label: 'جراب شفاف (5)' });
  await dlg.getByLabel('المبلغ اللي هيرجع للعميل').fill('50');
  await dlg.getByLabel('السبب').fill('غيّر رأيه');
  await dlg.getByTestId('invop-submit').click();
  await expect(page.getByText('اتسجل المرتجع من العميل')).toBeVisible();
  await expect(page.getByTestId('item-row').filter({ hasText: 'جراب شفاف' })).toContainText('6');

  // باركود: اعمل واحد، واحفظ، والبحث بالباركود + Enter بيفتح الصنف
  await page.getByTestId('item-row').filter({ hasText: 'جراب شفاف' }).getByRole('button', { name: 'جراب شفاف' }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('barcode-generate').click();
  const code = await dlg.getByTestId('item-barcode').inputValue();
  expect(code).toMatch(/^2\d{12}$/);
  // حركة الصنف: شراء، هالك، مرتجع، بيع، مرتجع عميل (الأحدث فوق)
  await expect(dlg.getByTestId('item-move')).toHaveCount(5);
  await expect(dlg.getByTestId('item-move').first()).toContainText('مرتجع من عميل');
  await expect(dlg.getByTestId('item-move').first()).toContainText('6');
  await dlg.getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await expect(page.getByTestId('item-row').filter({ hasText: code })).toHaveCount(1);
  await page.getByTestId('inv-search').fill(code);
  await page.getByTestId('inv-search').press('Enter');
  await expect(page.getByRole('dialog').getByTestId('barcode-print')).toBeVisible();
  await page.getByRole('dialog').getByTestId('barcode-print').click();
  await expect(page.getByTestId('barcode-label')).toHaveCount(1);
  await expect(page.getByTestId('barcode-svg')).toHaveAttribute('aria-label', code);
  await page.goto('/#/inventory');
  await afterSplash(page);

  // تعديل جماعي: التصنيف للصنفين
  await expect(page.getByTestId('item-row')).toHaveCount(2);
  for (const r of await page.getByTestId('item-row').all()) await r.getByRole('checkbox').click();
  await page.getByTestId('bulk-edit').click();
  await page.getByRole('dialog').getByLabel('التصنيف').fill('مستلزمات');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتعدّل 2 صنف')).toBeVisible();
  await expect(page.getByTestId('item-row').filter({ hasText: 'مستلزمات' })).toHaveCount(2);

  // حسابات المخزون: مبيعات 150-50 = 100، تكلفتها 60-20 = 40، هالك 20، فرق مرتجع 5 ← ربح 35
  await page.getByRole('tab', { name: 'الحسابات' }).click();
  await expect(page.getByTestId('inv-sum-sales')).toContainText('100');
  await expect(page.getByTestId('inv-sum-sales_cost')).toContainText('40');
  await expect(page.getByTestId('inv-sum-wastage')).toContainText('20');
  await expect(page.getByTestId('inv-sum-return_diff')).toContainText('5');
  await expect(page.getByTestId('inv-sum-profit')).toContainText('35');
  await noHorizontalScroll(page);

  // ربط المخزون بالصيانة مقفول ← القطعة بتتكتب يدوي على الجهاز
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'إضافات' }).click();
  await page.getByRole('checkbox', { name: 'ربط المخزون بالصيانة' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await quickIntake(page, `011${String(Date.now()).slice(-8)}`, 'عميل القطعة');
  await page.getByTestId('manual-part-name').fill('فلاتة شحن');
  await page.getByTestId('manual-part-cost').fill('120');
  await page.getByTestId('manual-part-add').click();
  await expect(page.getByText('اتسجلت القطعة على الجهاز')).toBeVisible();
  // تكلفة القطع على الجهاز (صاحب المحل بيشوفها)
  await expect(page.locator('body')).toContainText('120');
});
