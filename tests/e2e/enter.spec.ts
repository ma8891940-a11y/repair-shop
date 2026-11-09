import { expect, test } from '@playwright/test';
import { afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

// البند 10: Enter بينقل للخانة اللي بعدها، والحفظ في الآخر، وCtrl+Enter في الكتابة الكبيرة
test('Enter: الخانة اللي بعدها من غير ما يحفظ بدري، وفي الكتابة الكبيرة سطر جديد، وCtrl+Enter بيحفظ مرة واحدة', async ({ page }, info) => {
  test.skip(info.project.name.startsWith('mobile'), 'الكيبورد للكمبيوتر');
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('enter'), 'محل الكيبورد');

  // 1) الاستلام: Enter في الموبايل بينقل لاسم العميل (قبل كده كان بيحاول يحفظ الفورم كله)
  await page.goto('/#/intake');
  await afterSplash(page);
  const phone = page.locator('#intake-phone');
  await phone.fill(`010${String(Date.now()).slice(-8)}`);
  await phone.press('Enter');
  await expect(page.getByLabel('اسم العميل')).toBeFocused();
  await page.getByLabel('اسم العميل').fill('عميل الكيبورد');
  await page.getByLabel('اسم العميل').press('Enter');
  await expect(page.getByLabel('اسم العميل')).not.toBeFocused();
  await expect(page.locator('[aria-invalid="true"]')).toHaveCount(0); // ما حاولش يحفظ
  // العطل (كتابة كبيرة): Enter سطر جديد
  const issue = page.getByLabel('العطل زي ما العميل وصفه');
  await issue.fill('شاشة');
  await issue.press('Enter');
  await issue.pressSequentially('مكسورة');
  await expect(issue).toHaveValue('شاشة\nمكسورة');
  await expect(page.locator('[aria-invalid="true"]')).toHaveCount(0);

  // 2) نافذة الدفعة: Enter في المبلغ بينقل للبيان، وفي البيان Enter سطر جديد، وCtrl+Enter بيسجّل مرة واحدة
  await quickIntake(page, `011${String(Date.now()).slice(-8)}`, 'عميل الدفعة');
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  const dlg = page.getByRole('dialog');
  await dlg.getByLabel('المبلغ').fill('200');
  await dlg.getByLabel('المبلغ').press('Enter');
  const note = dlg.getByLabel('البيان (اختياري)');
  await expect(note).toBeFocused();
  await expect(dlg).toBeVisible();
  await note.pressSequentially('دفعة أولى');
  await note.press('Enter');
  await expect(dlg).toBeVisible();
  await note.press('Control+Enter');
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  // اتسجلت مرة واحدة بس
  await expect(page.getByTestId('payment-edit')).toHaveCount(1);
});
