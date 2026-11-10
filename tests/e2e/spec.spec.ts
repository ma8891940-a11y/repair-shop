import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq, fillAmount } from './helpers';

test('استكمال المواصفات: أجرة العطل والسعر المقترح، النواقص والباركود، التوقيع على الإيصال، والمتبقي في صفحة التتبع', async ({ page, browser }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    window.open = (() => null) as typeof window.open;
  });
  await registerShop(page, uniq('owner-spec'));

  // الإعدادات: أجرة "شاشة" 150، والهامش 20%
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الخزن والمصروفات' }).click();
  await page.getByLabel('العطل (كلمة في الوصف)').fill('شاشة');
  await page.getByLabel('الأجرة').fill('150');
  await page.getByRole('button', { name: 'إضافة' }).first().click();
  await expect(page.getByTestId('labor-rate')).toContainText('150');

  // المخزون: صنف بحد أدنى 2 وكود باركود، وشراء 3، ومورد
  await page.goto('/#/inventory');
  await page.getByRole('tab', { name: 'الموردين' }).click();
  await page.getByRole('button', { name: 'مورد جديد' }).click();
  await page.getByRole('dialog').getByLabel('اسم المورد').fill('مورد الشاشات');
  await page.getByRole('dialog').getByLabel('الموبايل').fill('01222222222');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await page.getByRole('tab', { name: 'الأصناف' }).click();
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  let dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').fill('شاشة A54');
  await dlg.getByLabel('الكود (اختياري)').fill('٦٢٢٠٠١');
  await dlg.getByLabel('سعر البيع').fill('900');
  await dlg.getByLabel('الحد الأدنى').fill('2');
  await dlg.getByLabel('المورد الأساسي').selectOption({ label: 'مورد الشاشات' });
  await dlg.getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف الصنف')).toBeVisible();
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  await dlg.getByLabel('الكمية').fill('3');
  await dlg.getByLabel('سعر الوحدة').fill('500');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل الشراء')).toBeVisible();
  // بيع بالباركود (أرقام عربية) ← الكمية 2 وده الحد الأدنى فالصنف يبقى ناقص
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('باركود').fill('622001');
  await dlg.getByLabel('باركود').press('Enter');
  await expect(dlg.getByLabel('الكمية')).toHaveValue('1');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل البيع')).toBeVisible();
  await expect(page.getByTestId('shortages')).toBeVisible();
  await expect(page.getByTestId('order-link')).toHaveAttribute('href', /^https:\/\/wa\.me\/201222222222\?text=.*A54/);
  // مقارنة أسعار الموردين
  await page.getByRole('button', { name: 'شاشة A54' }).click();
  await expect(page.getByTestId('supplier-prices')).toContainText('500');
  await page.keyboard.press('Escape');

  // استلام بتوقيع
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01155556666');
  await page.getByLabel('اسم العميل').fill('حسن محمود');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A54');
  await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
  const pad = page.getByRole('img', { name: 'مكان التوقيع' });
  const b = (await pad.boundingBox())!;
  await page.mouse.move(b.x + 30, b.y + 40);
  await page.mouse.down();
  await page.mouse.move(b.x + 150, b.y + 90, { steps: 8 });
  await page.mouse.move(b.x + 260, b.y + 50, { steps: 8 });
  await page.mouse.up();
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  const deviceHash = page.url().replace(/^.*#/, '/#');

  // القطعة اتركبت ← السعر المقترح = 500 + 150 + 20% من 500 = 750
  await page.getByLabel('القطعة').selectOption({ index: 1 });
  await page.getByRole('button', { name: 'ركّبت' }).click();
  await expect(page.getByText('اتسجلت القطعة')).toBeVisible();
  await expect(page.getByTestId('auto-suggested')).toHaveText('750');
  await page.getByRole('button', { name: 'استخدمه كتكلفة نهائية' }).first().click();
  await expect(page.getByTestId('device-due')).toHaveText('750');
  // دفعة جزئية 200 ← المتبقي 550
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByTestId('device-due')).toHaveText('550');

  // الإيصال فيه التوقيع، والفاتورة فيها القطعة المستبدلة وزرار واتساب
  await page.goto(deviceHash.replace('/devices/', '/print/receipt/'));
  await expect(page.locator('img[src^="data:image/png"]').first()).toBeVisible();
  await expect(page.getByText('توقيع العميل')).toBeVisible();
  await page.goto(deviceHash.replace('/devices/', '/print/invoice/'));
  await expect(page.getByText('شاشة A54 × 1')).toBeVisible();
  await expect(page.getByTestId('invoice-wa')).toHaveAttribute('href', /^https:\/\/wa\.me\/201155556666/);

  // صفحة التتبع (من غير دخول) بتعرض المتبقي
  await page.goto(deviceHash);
  await afterSplash(page);
  await page.getByRole('button', { name: 'واتساب' }).first().click();
  const text = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  const token = (text.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  const ctx = await browser.newContext(info.project.use);
  const cust = await ctx.newPage();
  await prefs(cust, info);
  await cust.goto(`/#/t/${token}`);
  await expect(cust.getByText('المتبقي')).toBeVisible();
  await expect(cust.getByText('550').first()).toBeVisible();
  await noHorizontalScroll(cust);
  await ctx.close();

  // لوحة التحكم: النواقص
  await page.keyboard.press('Escape');
  await page.goto('/#/');
  await expect(page.getByTestId('alert-short')).toContainText('1');
  await noHorizontalScroll(page);
});
