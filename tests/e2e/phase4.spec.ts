import { expect, test, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { activateInvite, afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

async function invite(page: Page, name: string, email: string) {
  await page.goto('/#/users');
  await page.getByLabel('الاسم').fill(name);
  await page.getByLabel('الإيميل').fill(email);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
}

test('المرحلة 4: مسار IC بين فنيين بالترتيب ← نفس الفني يركّب ويقفل بفحص نهائي ← جاهز ← تقرير الفنيين', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('owner4'));
  const emA = uniq('techA');
  const emM = uniq('techM');
  await invite(page, 'أحمد الفك', emA);
  await invite(page, 'محمد الميكرو', emM);
  const A = await activateInvite(browser, info, emA);
  const M = await activateInvite(browser, info, emM);

  // التخصصات
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الفنيين والمسارات' }).click();
  await page.getByRole('checkbox', { name: 'أحمد الفك فك وتركيب' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await page.getByRole('checkbox', { name: 'محمد الميكرو ميكروسكوب' }).click();
  await expect(page.getByRole('checkbox', { name: 'محمد الميكرو ميكروسكوب' })).toHaveAttribute('data-state', 'checked');

  // الاستلام: الوصف بيحدد المسار، وعاجل، ومدة يدوي (مفيش أجهزة مشابهة)
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('01277778888');
  await page.getByLabel('اسم العميل').fill('عميل المسار');
  await page.getByRole('button', { name: 'Oppo', exact: true }).click();
  await page.getByLabel('الموديل').fill('A78');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('مش بيشحن خالص');
  await expect(page.getByLabel('نوع العطل (المسار)')).toHaveValue(/.+/);
  await expect(page.getByLabel('نوع العطل (المسار)').locator('option:checked')).toHaveText('شحن أو IC أو شبكة');
  await page.getByRole('radio', { name: 'عاجل' }).click();
  await page.getByLabel('المدة المتوقعة').fill('٢');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByTestId('steps').locator('li')).toHaveCount(3);
  const deviceHash = page.url().replace(/^.*#/, '/#');

  // الفني التاني لسه ما يشوفش الجهاز
  await M.page.goto('/#/work');
  await afterSplash(M.page);
  await expect(M.page.getByText('مفيش شغل دلوقتي')).toBeVisible();

  // فني الفك: يبدأ ويخلّص ← الجهاز يروح للميكروسكوب
  await A.page.goto('/#/work');
  await afterSplash(A.page);
  const itemA = A.page.getByTestId('work-item');
  await expect(itemA).toHaveCount(1);
  await expect(itemA).toContainText('عاجل');
  await expect(itemA).toContainText('خطوة 1 من 3: فك وتركيب');
  await A.page.getByRole('button', { name: 'ابدأ' }).click();
  await expect(A.page.getByRole('button', { name: 'خلّصت' })).toBeVisible();
  await A.page.getByRole('button', { name: 'خلّصت' }).click();
  await expect(A.page.getByText('مع محمد')).toBeVisible();
  await expect(A.page.getByText('مفيش شغل دلوقتي')).toBeVisible();

  // الميكروسكوب
  await M.page.reload();
  await afterSplash(M.page);
  await expect(M.page.getByTestId('work-item')).toContainText('خطوة 2 من 3: ميكروسكوب');
  await M.page.getByRole('button', { name: 'ابدأ' }).click();
  await expect(M.page.getByRole('button', { name: 'خلّصت' })).toBeVisible();
  await M.page.getByRole('button', { name: 'خلّصت' }).click();
  await expect(M.page.getByText('مع أحمد')).toBeVisible();
  await noHorizontalScroll(M.page);

  // نفس فني الفك يركّب ويقفل: الفحص النهائي إجباري
  await A.page.reload();
  await afterSplash(A.page);
  await expect(A.page.getByTestId('work-item')).toContainText('خطوة 3 من 3');
  await A.page.getByRole('button', { name: 'ابدأ' }).click();
  await expect(A.page.getByRole('button', { name: 'خلّصت' })).toBeVisible();
  await A.page.getByRole('button', { name: 'خلّصت' }).click();
  const dlg = A.page.getByRole('dialog');
  await expect(dlg.getByRole('heading', { name: 'الفحص النهائي' })).toBeVisible();
  await dlg.getByRole('button', { name: 'الجهاز سليم، خلّصت' }).click();
  await expect(dlg.getByText('افحص بند واحد على الأقل')).toBeVisible();
  await dlg.getByRole('radiogroup', { name: 'الشحن' }).getByRole('radio', { name: 'شغال' }).click();
  await dlg.getByRole('button', { name: 'الجهاز سليم، خلّصت' }).click();
  await expect(A.page.getByText(/بقى جاهز للاستلام/)).toBeVisible();
  await A.ctx.close();
  await M.ctx.close();

  // صاحب المحل: الجهاز جاهز، والخطوات خلصت
  await page.goto(deviceHash);
  await afterSplash(page);
  await expect(page.getByText('جاهز للاستلام').first()).toBeVisible();
  await expect(page.getByTestId('steps')).toContainText('خلصت');

  // التقارير: أداء الفنيين والتصدير
  await page.goto('/#/reports');
  await expect(page.getByTestId('report-tech')).toContainText('أحمد الفك');
  await expect(page.getByTestId('report-tech')).toContainText('محمد الميكرو');
  await page.getByTestId('report-tech-export').click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByTestId('report-tech-export-csv').click()]);
  const csv = readFileSync(await dl.path(), 'utf8');
  expect(csv).toContain('أحمد الفك');
  await noHorizontalScroll(page);
});
