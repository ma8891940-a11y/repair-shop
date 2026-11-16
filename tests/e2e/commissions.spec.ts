import { expect, test } from '@playwright/test';
import { activateInvite, prefs, quickIntake, registerShop, uniq } from './helpers';

test('C5: قاعدة عمولة 30% ← الفني يشتغل على الجهاز ← التسليم ← العمولة في تقرير الفنيين ← مكافأة ← كشف حساب الفني', async ({ page, browser }, info) => {
  test.setTimeout(200_000);
  await prefs(page, info);
  await registerShop(page, uniq('comm'), 'محل العمولات');

  // فني
  await page.goto('/#/users');
  const techEmail = uniq('ctech');
  await page.getByLabel('الاسم').fill('كريم العمولة');
  await page.getByLabel('الإيميل').fill(techEmail);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const tech = await activateInvite(browser, info, techEmail);

  // القاعدة: 30% من المصنعية لكل الفنيين
  await page.goto('/#/settings?tab=tech');
  const rules = page.getByTestId('commission-rules');
  await expect(rules).toContainText('مفيش قواعد');
  await rules.getByTestId('comm-value').fill('30');
  await rules.getByTestId('comm-add').click();
  await expect(rules.getByTestId('comm-rule')).toContainText('30%');

  // جهاز: الفني بيبدأ الفحص، وصاحب المحل بيكمّل ويسلّم بتكلفة 1,000
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`);
  await tech.page.goto(dev);
  await tech.page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await expect(tech.page.getByText('الحالة اتغيّرت').first()).toBeVisible();
  await tech.ctx.close();
  await page.goto(dev);
  for (const s of ['جاري الصيانة', 'تم الإصلاح', 'جاهز للاستلام']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }
  await page.getByLabel('التكلفة النهائية').fill('1000');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'تأكيد' }).click();
  await expect(page.getByText('الحالة اتغيّرت: تم التسليم').first()).toBeVisible();

  // التقرير: 1,000 × 30% = 300
  await page.goto('/#/reports');
  const panel = page.getByTestId('report-commissions');
  const row = panel.getByTestId('comm-row').filter({ hasText: 'كريم العمولة' });
  await expect(row.getByTestId('comm-commission')).toHaveText('300');
  // مكافأة 50 ← الرصيد 350
  await row.getByTestId('comm-bonus').click();
  await page.getByTestId('comm-op-amount').fill('50');
  await page.getByTestId('comm-op-save').click();
  await expect(page.getByText('اتسجلت المكافأة').first()).toBeVisible();
  await expect(row.getByTestId('comm-balance')).toContainText('350');
  // جزاء من غير سبب: مرفوض
  await row.getByTestId('comm-penalty').click();
  await page.getByTestId('comm-op-amount').fill('20');
  await page.getByTestId('comm-op-save').click();
  await expect(page.getByRole('dialog').getByText('الجزاء محتاج سبب')).toBeVisible();
  await page.getByRole('dialog').getByRole('button', { name: 'إلغاء' }).click();
  // كشف حساب الفني من نفس الدفتر
  await row.getByRole('link', { name: 'كريم العمولة' }).click();
  await expect(page.getByText('عمولة فني').first()).toBeVisible();
  await expect(page.getByText('مكافأة').first()).toBeVisible();
});
