import { expect, test, type Locator, type Page } from '@playwright/test';
import { prefs, quickIntake, registerShop, uniq } from './helpers';

async function sign(page: Page, area: Locator) {
  await area.scrollIntoViewIfNeeded();
  const box = (await area.boundingBox())!;
  await page.mouse.move(box.x + 20, box.y + 20);
  await page.mouse.down();
  for (let i = 1; i <= 8; i++) await page.mouse.move(box.x + 20 + i * 15, box.y + 20 + (i % 2) * 25);
  await page.mouse.up();
}

test('C2: قالب فحص Samsung فيه بند جديد ← الجهاز بياخده لوحده ← ورقة الفحص المطبوعة بالبند ← توقيع التسليم على الفاتورة وورقة الفحص', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await registerShop(page, uniq('chk'), 'محل الفحص');

  // صاحب المحل بيعدّل قالب Samsung: بند جديد
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'قوايم الفحص' }).click();
  await page.getByTestId('tpl-brand-samsung').click();
  // (بنستنى قالب Samsung نفسه يترسم قبل ما نعد)
  await expect(page.getByTestId('tpl-items')).toContainText('S Pen');
  const before = await page.getByTestId('tpl-item').count();
  await page.getByTestId('tpl-new').fill('فتحة الكارت');
  await page.getByTestId('tpl-new-add').click();
  await expect(page.getByTestId('tpl-item')).toHaveCount(before + 1);
  await page.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظت الإعدادات').first()).toBeVisible();

  // جهاز Samsung: الفحص فيه البند الجديد وبنود Samsung (S Pen)، ومن غير Face ID
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`);
  await page.goto(dev);
  await expect(page.getByRole('radiogroup', { name: 'فتحة الكارت' })).toBeVisible();
  await expect(page.getByRole('radiogroup', { name: 'القلم S Pen' })).toBeVisible();
  await expect(page.getByRole('radiogroup', { name: 'Face ID' })).toHaveCount(0);
  await page.getByRole('button', { name: 'كله شغال' }).click();
  await page.getByRole('radiogroup', { name: 'فتحة الكارت' }).getByRole('radio', { name: 'عطلان' }).click();
  await page.getByRole('button', { name: 'حفظ الفحص' }).click();
  await expect(page.getByText('اتحفظ الفحص').first()).toBeVisible();

  // ورقة الفحص المطبوعة: كل بنود القالب، والبند الجديد باسمه
  await page.getByTestId('print-checklist').click();
  const sheet = page.getByTestId('print-checklist-sheet');
  await expect(sheet).toBeVisible();
  await expect(sheet.getByTestId('checklist-row')).toHaveCount(before + 1);
  await expect(sheet.getByTestId('checklist-row').filter({ hasText: 'فتحة الكارت' })).toContainText('عطلان');
  await expect(sheet.getByText('محل الفحص').first()).toBeVisible();
  await expect(sheet.getByTestId('checklist-sign-delivery')).toContainText('......');

  // التسليم بتوقيع العميل
  await page.goto(dev);
  for (const s of ['جاري الفحص', 'جاري الصيانة', 'تم الإصلاح', 'جاهز للاستلام']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  const dlg = page.getByRole('dialog');
  await expect(dlg.getByTestId('deliver-signature')).toBeVisible();
  await sign(page, dlg.getByLabel('مكان التوقيع'));
  await dlg.getByRole('button', { name: 'تأكيد' }).click();
  // (رسايل "الحالة اتغيّرت" القديمة لسه ظاهرة: بنستنى رسالة التسليم نفسها)
  await expect(page.getByText('الحالة اتغيّرت: تم التسليم').first()).toBeVisible();

  // الفاتورة وورقة الفحص فيهم توقيع التسليم
  await page.goto(dev.replace('/devices/', '/print/invoice/'));
  await expect(page.getByTestId('invoice-signature').locator('img')).toBeVisible();
  await page.goto(dev.replace('/devices/', '/print/checklist/'));
  await expect(page.getByTestId('checklist-sign-delivery').locator('img')).toBeVisible();
});
