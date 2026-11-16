import { expect, test } from '@playwright/test';
import { prefs, registerShop, uniq } from './helpers';

test('C6-C8: بيانات تجريبية ← تحليلات الصيانة ← الكتالوج العام ← بوابة الجملة وطلبية ← مسح بيانات التجربة', async ({ page, browser }, info) => {
  test.setTimeout(200_000);
  await prefs(page, info);
  await registerShop(page, uniq('grow'), 'محل النمو');

  // C7: جرّب ببيانات تجريبية
  await page.goto('/#/settings?tab=backup');
  await page.getByTestId('demo-load').click();
  await expect(page.getByText('اتحمّلت البيانات التجريبية').first()).toBeVisible();
  await expect(page.getByTestId('demo-clear')).toBeVisible();
  await page.goto('/#/devices');
  await expect(page.getByText('Galaxy A52').first()).toBeVisible();

  // C6: تحليلات الصيانة
  await page.goto('/#/analytics');
  const ins = page.getByTestId('repair-insights');
  await expect(ins).toBeVisible();
  await expect(ins.getByTestId('in-faults')).toContainText('Galaxy A52');
  await expect(ins.getByTestId('in-part').first()).toContainText('شاشة Samsung A52');

  // C8: الكتالوج: افتحه واختار الجراب
  await page.goto('/#/settings?tab=catalog');
  await page.getByTestId('catalog-on').click();
  const link = await page.getByTestId('catalog-link').inputValue();
  expect(link).toMatch(/#\/c\/[0-9a-f]{32}$/);
  await page.getByTestId('catalog-pick').filter({ hasText: 'جراب سيليكون' }).getByRole('checkbox').check();
  await expect(page.getByTestId('catalog-pick').filter({ hasText: 'جراب سيليكون' }).getByRole('checkbox')).toBeChecked();
  const ctx = await browser.newContext({ ...info.project.use, storageState: undefined });
  const pub = await ctx.newPage();
  await prefs(pub, info);
  await pub.goto(link.replace(/^.*#/, '/#'));
  await expect(pub.getByTestId('catalog-item')).toHaveCount(1);
  await expect(pub.getByTestId('catalog-item')).toContainText('جراب سيليكون');
  await expect(pub.getByTestId('catalog-price')).toContainText('150');

  // C8: بوابة عميل جملة
  await page.goto('/#/customers');
  await page.getByText('أحمد التجربة').first().click();
  await page.getByTestId('portal-on').click();
  const plink = await page.getByTestId('portal-link').inputValue();
  await pub.goto(plink.replace(/^.*#/, '/#'));
  await expect(pub.getByText('أهلًا أحمد التجربة')).toBeVisible();
  await expect(pub.getByTestId('portal-entries')).toBeVisible();
  await expect(pub.locator('body')).not.toContainText('منى التجربة');
  const row = pub.getByTestId('portal-item').filter({ hasText: 'جراب سيليكون' });
  await row.getByRole('button', { name: /زوّد/ }).click();
  await row.getByRole('button', { name: /زوّد/ }).click();
  await expect(row.getByTestId('portal-qty')).toHaveText('2');
  await pub.getByTestId('portal-send').click();
  await expect(pub.getByText('الطلبية وصلت للمحل')).toBeVisible();
  await ctx.close();
  await page.reload();
  await expect(page.getByTestId('portal-order')).toContainText('جراب سيليكون (تجربة) × 2');

  // C7: امسح بيانات التجربة ← مفيش أجهزة
  await page.goto('/#/settings?tab=backup');
  await page.getByTestId('demo-clear').click();
  await page.getByTestId('demo-clear-confirm').click();
  await expect(page.getByText('اتمسحت بيانات التجربة').first()).toBeVisible();
  await expect(page.getByTestId('demo-done')).toBeVisible();
  await page.goto('/#/devices');
  await expect(page.getByText('Galaxy A52')).toHaveCount(0);
});
