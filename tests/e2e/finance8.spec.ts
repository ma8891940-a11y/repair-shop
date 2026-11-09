import { expect, test } from '@playwright/test';
import { prefs, quickIntake, registerShop, uniq } from './helpers';
import { dataRows, readXlsx } from './xlsxRead';

// البند 8: جملة النتيجة بالفصحى والمقارنة، وكل كارت بيفتح تفاصيله في لوح جانبي (بحث، وفلتر، وترتيب، وتصدير)، وتقارير جاهزة
test('الوضع المالي: جملة النتيجة، ولوح التفاصيل بالبحث والفلتر والترتيب والتصدير، والتقارير الجاهزة', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('fin8'), 'محل المالية');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل المالية');
  await page.getByLabel('التكلفة النهائية').fill('1,250');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await page.getByRole('dialog').getByLabel('المبلغ').fill('1,000.25');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();

  await page.goto('/#/finance');
  // جملة النتيجة: لسه مفيش إيراد (الجهاز ما اتسلمش) ← تعادل، ومقارنة بالفترة اللي قبلها
  const sentence = page.getByTestId('result-sentence');
  await expect(sentence).toContainText('لم يحقّق المحلّ ربحًا ولا خسارة');
  await expect(sentence).toHaveAttribute('data-cmp', 'same');

  // الكاش: لوح جانبي، والأصفار مخفية افتراضيًا
  await page.getByTestId('kpi-cash').click();
  const sheet = page.getByTestId('kpi-sheet');
  await expect(sheet).toBeVisible();
  await expect(sheet.getByTestId('kpi-row')).toHaveCount(1);
  await expect(sheet.getByTestId('kpi-row').first()).toContainText('كاش الدرج');
  await expect(sheet.getByTestId('kpi-total')).toContainText('1,000.25');
  // من غير إخفاء الأصفار: كل الخزن، والترتيب بالاسم
  await sheet.getByRole('checkbox', { name: 'إخفاء الأرصدة الصفرية' }).click();
  const all = await sheet.getByTestId('kpi-row').count();
  expect(all).toBeGreaterThan(1);
  await expect(sheet.getByTestId('kpi-row').first()).toContainText('كاش الدرج'); // الأكبر أولًا
  await sheet.getByTestId('kpi-sort').selectOption('amount_asc');
  await expect(sheet.getByTestId('kpi-row').last()).toContainText('كاش الدرج');
  // البحث
  await sheet.getByTestId('kpi-search').fill('الدرج');
  await expect(sheet.getByTestId('kpi-row')).toHaveCount(1);
  // التصدير: نفس السطور الظاهرة والإجمالي
  await sheet.getByTestId('kpi-export').click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByTestId('kpi-export-xlsx').click()]);
  const x = readXlsx((await dl.path())!);
  const d = dataRows(x, 'البند');
  expect(d.rows).toHaveLength(1);
  expect(d.rows[0][0]).toContain('كاش الدرج');
  expect(d.total?.[d.head.indexOf('المبلغ')]).toBe(1000.25);
  expect(x.rows.some((r) => String(r[0] ?? '') === 'البحث: الدرج')).toBe(true);
  await page.keyboard.press('Escape');
  await expect(sheet).toHaveCount(0);

  // التقارير الجاهزة
  const ready = page.getByTestId('ready-reports');
  await expect(ready.getByRole('link')).toHaveCount(8);
  await ready.getByTestId('ready-pl').click();
  await expect(page.getByTestId('pl-profit')).toBeVisible();
});
