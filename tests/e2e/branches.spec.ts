import { expect, test, type Page } from '@playwright/test';
import { activateInvite, afterSplash, fillAmount, noHorizontalScroll, prefs, registerShop, uniq, fillField } from './helpers';

// B. الفروع: محل بفرع واحد بسيط زي ما هو، وفرع جديد ببادئة، ومبدّل الفروع، والجهاز في الطريق لفرع،
// وخزن الفرع في الدفعة، ومقارنة الفروع، والموظف بيشوف فرعه بس
const year = new Date().getFullYear();

async function intake(page: Page, name: string, phone: string) {
  await page.goto('/#/intake');
  await afterSplash(page);
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill(name);
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A15');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاحن');
  await page.getByLabel('التكلفة التقديرية').fill('300');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByRole('button', { name: 'جاري الفحص', exact: true })).toBeVisible();
  return { url: page.url().replace(/^.*#/, '/#') };
}

test('الفروع: فرع جديد ببادئة ← مبدّل الفروع ← جهاز بأرقام الفرع ← ابعت لفرع واستلام ← خزن الفرع ← مقارنة ← موظف بفرعه بس', async ({ page, browser }, info) => {
  test.setTimeout(300_000);
  await prefs(page, info);
  const email = uniq('branches');
  await registerShop(page, email, 'محل الفروع');

  // 1) فرع واحد: مفيش مبدّل، والاستلام زي الأول
  await expect(page.getByTestId('branch-switcher')).toHaveCount(0);
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.getByTestId('intake-branch')).toHaveCount(0);

  // 2) الإعدادات ← الفروع: فرع جديد ببادئة B2
  await page.goto('/#/settings?tab=branches');
  const bs = page.getByTestId('branches-settings');
  await expect(bs.getByTestId('branch-row')).toHaveCount(1);
  await bs.getByTestId('branch-add').click();
  const dlg = page.getByRole('dialog');
  await fillField(dlg.getByTestId('branch-name'), 'فرع المعادي');
  // الخانة بتكبّر الحروف لوحدها (b2 ← B2)، فهنا بنكتب عادي ونستنى القيمة الكبيرة
  await dlg.getByTestId('branch-prefix').fill('b2');
  await expect(dlg.getByTestId('branch-prefix')).toHaveValue('B2');
  await dlg.getByTestId('branch-save').click();
  await expect(page.getByText('اتحفظ الفرع')).toBeVisible();
  await expect(bs.getByTestId('branch-row')).toHaveCount(2);
  await expect(bs.getByTestId('branch-row').filter({ hasText: 'فرع المعادي' })).toContainText(`B2-${year}-0001`);
  // نفس البادئة تاني ← رسالة واضحة
  await bs.getByTestId('branch-add').click();
  await fillField(dlg.getByTestId('branch-name'), 'فرع تاني');
  await fillField(dlg.getByTestId('branch-prefix'), 'B2');
  await dlg.getByTestId('branch-save').click();
  await expect(dlg.getByText('البادئة دي مستخدمة لفرع تاني')).toBeVisible();
  await dlg.getByRole('button', { name: 'إلغاء' }).click();

  // 3) المبدّل ظهر: كل الفروع + الفرعين
  const sw = page.getByTestId('branch-switcher');
  await expect(sw).toBeVisible();
  await expect(sw.locator('option')).toHaveText(['كل الفروع', 'الفرع الرئيسي', 'فرع المعادي']);
  await noHorizontalScroll(page);

  // 4) استلام في المعادي ← رقم الطلب ببادئة الفرع
  await sw.selectOption({ label: 'فرع المعادي' });
  const phone2 = `011${String(Date.now()).slice(-8)}`;
  const d2 = await intake(page, 'عميل المعادي', phone2);
  await expect(page.getByTestId('device-branch')).toContainText('فرع المعادي');
  await expect(page.getByText(new RegExp(`B2-${year}-0001`)).first()).toBeVisible();
  // والرئيسي أرقامه زي الأول
  await page.getByTestId('branch-switcher').selectOption({ label: 'الفرع الرئيسي' });
  const phone1 = `012${String(Date.now()).slice(-8)}`;
  await intake(page, 'عميل الرئيسي', phone1);
  await expect(page.getByText(new RegExp(`(^|[^-])${year}-0001`)).first()).toBeVisible();

  // 5) قايمة الأجهزة بالفرع: الرئيسي بيشوف جهازه بس، و"كل الفروع" بيشوف الاتنين باسم الفرع
  await page.goto('/#/devices');
  await afterSplash(page);
  const list = page.locator('main');
  await expect(list.getByText('عميل الرئيسي').filter({ visible: true }).first()).toBeVisible();
  await expect(list.getByText('عميل المعادي').filter({ visible: true })).toHaveCount(0);
  await page.getByTestId('branch-switcher').selectOption({ label: 'كل الفروع' });
  await expect(list.getByText('عميل المعادي').filter({ visible: true }).first()).toBeVisible();
  await expect(list.getByTestId('branch-tag').filter({ visible: true }).filter({ hasText: 'فرع المعادي' }).first()).toBeVisible();

  // 6) دفعة على جهاز المعادي: الخزن اللي بتظهر خزن المعادي بس
  await page.goto(d2.url);
  await afterSplash(page);
  await page.getByLabel('التكلفة النهائية').fill('300');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  const pay = page.getByRole('dialog');
  await fillAmount(pay, '100');
  const opts = await pay.getByLabel('الخزنة').locator('option').allTextContents();
  expect(opts.length).toBeGreaterThan(0);
  for (const o of opts) expect(o).toContain('فرع المعادي');
  await pay.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();

  // 7) ابعت الجهاز للرئيسي ← "في الطريق" ← الرئيسي يستلمه
  await page.getByTestId('device-send').click();
  await page.getByTestId('device-send-to').selectOption({ label: 'الفرع الرئيسي' });
  await page.getByTestId('device-send-confirm').click();
  await expect(page.getByTestId('device-branch').getByTestId('device-in-transit')).toContainText('في الطريق لـ الفرع الرئيسي');
  await page.getByTestId('device-receive').click();
  await expect(page.getByText('اتسلّم الجهاز في الفرع الرئيسي')).toBeVisible();
  await expect(page.getByTestId('device-branch')).toContainText('الفرع الرئيسي');
  await expect(page.getByTestId('device-in-transit')).toHaveCount(0);

  // 8) الوضع المالي في "كل الفروع": مقارنة بين الفرعين (المعادي استلم 100 في خزنته)
  await page.goto('/#/finance');
  await afterSplash(page);
  const cmp = page.getByTestId('branch-compare');
  await expect(cmp.getByTestId('branch-compare-row')).toHaveCount(2);
  await expect(cmp.locator('[data-branch="فرع المعادي"] [data-col="cash"]')).toContainText('100');
  // فلتر فرع واحد: المقارنة بتختفي، والخزن خزن الفرع ده بس
  await page.getByTestId('branch-switcher').selectOption({ label: 'فرع المعادي' });
  await expect(cmp).toHaveCount(0);

  // 9) موظف استقبال بفرع المعادي بس: ما يشوفش أجهزة الرئيسي، ومفيش "كل الفروع"
  await page.goto('/#/users');
  const em = uniq('br-rec');
  await page.getByLabel('الاسم').fill('استقبال المعادي');
  await page.getByLabel('الإيميل').fill(em);
  const inv = page.getByTestId('invite-branches');
  await inv.getByRole('checkbox', { name: 'فرع المعادي' }).click();
  await expect(inv.getByRole('checkbox', { name: 'فرع المعادي' })).toHaveAttribute('data-state', 'checked');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const { ctx, page: rec } = await activateInvite(browser, info, em);
  await rec.goto('/#/devices');
  await afterSplash(rec);
  await expect(rec.locator('main').getByText('عميل الرئيسي').filter({ visible: true })).toHaveCount(0);
  // جهاز المعادي اتنقل للرئيسي، فهو كمان مش ظاهر للموظف ده
  await expect(rec.locator('main').getByText('عميل المعادي').filter({ visible: true })).toHaveCount(0);
  await expect(rec.getByTestId('branch-switcher')).toHaveCount(0);
  await ctx.close();
});
