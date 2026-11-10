import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, noHorizontalScroll, prefs, quickIntake, registerShop, uniq, fillAmount } from './helpers';

// البند 2: تعديل وحذف في كل حاجة، بقيد عكسي، وبسبب، وبتأكيد و"تراجع"، والصلاحية بإذن من صاحب المحل
test('التعديل والإلغاء والحذف: دفعة بتتعدل وبتتلغي، والتراجع بيمنع الحذف، والاستقبال بإذن بس', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('edit'), 'محل التعديل');
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل التعديل');
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '100');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();

  // تعديل الدفعة: 100 ← 150 (السبب إجباري)
  await page.getByTestId('payment-edit').first().click();
  const dlg = page.getByRole('dialog');
  await expect(dlg.getByLabel('المبلغ')).toHaveValue('100');
  await fillAmount(dlg, '150');
  await dlg.getByRole('button', { name: 'احفظ التعديل' }).click();
  await expect(dlg.getByText('اكتب سبب التصحيح')).toBeVisible();
  await dlg.getByLabel('السبب').fill('المبلغ اتكتب غلط');
  await dlg.getByRole('button', { name: 'احفظ التعديل' }).click();
  await expect(page.getByText(/اتعدلت العملية رقم/)).toBeVisible();
  // الأصل لسه ظاهر متشطب ومكتوب عليه "ملغاة"، والجديد ساري
  await expect(page.getByTestId('payment-cancelled')).toHaveCount(1);
  await expect(page.getByTestId('payment-edit')).toHaveCount(1);

  // حذف الجهاز ممنوع وعليه دفعة (الرسالة بتقول ليه)
  await page.getByTestId('device-delete').click();
  await page.getByTestId('delete-confirm').click();
  await expect(page.getByText(/ما ينفعش يتحذف: الجهاز عليه دفعات/)).toBeVisible({ timeout: 15_000 });

  // إلغاء الدفعة، وبعدين "تراجع" قبل ما يتنفذ: ولا حاجة بتتغير
  await page.goto(dev);
  await afterSplash(page);
  await page.getByTestId('payment-cancel').first().click();
  await page.getByRole('dialog').getByLabel('السبب').fill('غلط');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل القيد العكسي' }).click();
  await page.getByRole('button', { name: 'تراجع' }).click();
  await expect(page.getByText('اتلغى، ومفيش حاجة اتغيرت')).toBeVisible();
  await page.waitForTimeout(6000);
  await page.reload();
  await afterSplash(page);
  await expect(page.getByTestId('payment-cancelled')).toHaveCount(1);
  await expect(page.getByTestId('payment-edit')).toHaveCount(1);
  await noHorizontalScroll(page);

  // الاستقبال: من غير إذن مفيش أزرار تعديل ولا حذف. وبالإذن بتظهر
  await page.goto('/#/users');
  const recEmail = uniq('recedit');
  await page.getByLabel('الاسم').fill('منى');
  await page.getByLabel('الإيميل').fill(recEmail);
  await page.getByLabel('الدور').selectOption('reception');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const rec = await activateInvite(browser, info, recEmail);
  const r = rec.page;
  await r.goto(dev);
  await afterSplash(r);
  await expect(r.getByRole('button', { name: 'تسجيل دفعة' }).or(r.getByRole('button', { name: 'عربون' }))).toBeVisible();
  await expect(r.getByTestId('payment-edit')).toHaveCount(0);
  await expect(r.getByTestId('device-delete')).toHaveCount(0);

  await page.reload();
  await afterSplash(page);
  await page.getByTestId('can-correct').getByRole('checkbox').click();
  await expect(page.getByText('اتدّى إذن التصحيح لـ منى')).toBeVisible();
  await r.reload();
  await afterSplash(r);
  await expect(r.getByTestId('payment-edit')).toHaveCount(1);
  await r.getByTestId('payment-cancel').click();
  await r.getByRole('dialog').getByLabel('السبب').fill('العميل استرد الفلوس');
  await r.getByRole('dialog').getByRole('button', { name: 'سجّل القيد العكسي' }).click();
  await expect(r.getByText('اتسجل القيد العكسي')).toBeVisible();
  await expect(r.getByTestId('payment-cancelled')).toHaveCount(2);
  // دلوقتي الجهاز ملوش فلوس: الحذف بيتم، والجهاز بيختفي من القايمة
  await r.getByTestId('device-delete').click();
  await r.getByRole('dialog').getByLabel('السبب (اختياري)').fill('اتسجل مرتين');
  await r.getByTestId('delete-confirm').click();
  await expect(r.getByText(/اتحذف/)).toBeVisible();
  await rec.ctx.close();

  // سجل النشاط فيه التعديل والإلغاء والحذف
  await page.goto('/#/audit');
  await afterSplash(page);
  await expect(page.locator('body')).toContainText('منى');
});
