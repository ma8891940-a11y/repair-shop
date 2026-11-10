import { expect, test } from '@playwright/test';
import { afterSplash, prefs, quickIntake, registerShop, uniq, fillAmount } from './helpers';

// البند 9: الفحص السريع بتلات اختيارات وحفظ تلقائي، وتنبيه قبل الخروج من غير حفظ، والمسودات في كل الفورمات
test('من غير حفظ: الاستلام بيسأل قبل الخروج ومسودته بترجع، والنوافذ بتسأل قبل ما تتقفل، والفحص بيرجع زي ما سبته', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('unsaved'), 'محل المسودات');
  const mobile = info.project.name.startsWith('mobile');

  // 0) الاستلام فاضي (القيم الافتراضية بس): الخروج ما بيسألش، ومفيش مسودة
  await page.goto('/#/intake');
  await afterSplash(page);
  await page.waitForTimeout(700);
  if (mobile) await page.getByRole('navigation', { name: 'القائمة' }).getByRole('link').first().click();
  else await page.getByTestId('side-nav').getByTestId('nav-dashboard').click();
  await expect(page.getByRole('dialog', { name: 'فيه بيانات ما اتحفظتش' })).toHaveCount(0);
  await expect(page.getByRole('heading', { name: 'لوحة التحكم', exact: true }).first()).toBeVisible();

  // 1) الاستلام: اكتب ← حاول تخرج من القايمة ← بيسأل ← "ارجع للفورم" البيانات زي ما هي
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.getByTestId('draft-banner')).toHaveCount(0);
  const phone = `010${String(Date.now()).slice(-8)}`;
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill('عميل المسودة');
  await page.getByLabel('الموديل').fill('Note 13');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('مش بيفتح');
  await page.waitForTimeout(700); // الحفظ التلقائي كل نص ثانية
  if (mobile) await page.getByRole('navigation', { name: 'القائمة' }).getByRole('link').first().click();
  else await page.getByTestId('side-nav').getByTestId('nav-dashboard').click();
  await expect(page.getByRole('dialog', { name: 'فيه بيانات ما اتحفظتش' })).toBeVisible();
  await page.getByTestId('leave-stay').click();
  await expect(page.getByLabel('العطل زي ما العميل وصفه')).toHaveValue('مش بيفتح');
  // الاختصار برضه بيسأل، و"اخرج من غير حفظ" بيخرج
  if (!mobile) {
    await page.locator('body').click({ position: { x: 5, y: 5 } });
    await page.keyboard.press('Alt+3');
    await page.getByTestId('leave-go').click();
    await expect(page.getByRole('heading', { name: 'الأجهزة', exact: true }).first()).toBeVisible();
  } else {
    await page.goto('/#/devices');
  }
  // الرجوع للاستلام: المسودة موجودة، ومش بترجع لوحدها، و"رجّعها" بيملا الفورم (من غير كلمة سر الجهاز)
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.getByTestId('draft-banner')).toBeVisible();
  await expect(page.locator('#intake-phone')).toHaveValue('');
  await page.getByTestId('draft-restore').click();
  await expect(page.locator('#intake-phone')).toHaveValue(phone);
  await expect(page.getByLabel('العطل زي ما العميل وصفه')).toHaveValue('مش بيفتح');
  await expect(page.getByTestId('draft-banner')).toHaveCount(0);
  // الحفظ بيمسح المسودة
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.keyboard.press('Escape');
  await page.goto('/#/devices');
  await page.goto('/#/intake');
  await afterSplash(page);
  await expect(page.locator('#intake-phone')).toBeVisible();
  await expect(page.getByTestId('draft-banner')).toHaveCount(0);

  // 2) نافذة فيها حاجة مكتوبة: Esc بيسأل، و"ارجع للفورم" بيرجّعك، و"اقفل من غير حفظ" بيقفل
  const dev = await quickIntake(page, `011${String(Date.now()).slice(-8)}`, 'عميل النافذة');
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  const dlg = page.getByRole('dialog');
  await fillAmount(dlg, '150');
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('dialog-unsaved')).toBeVisible();
  await page.getByTestId('dialog-unsaved-stay').click();
  await expect(dlg.getByLabel('المبلغ')).toHaveValue('150');
  await page.keyboard.press('Escape');
  await page.getByTestId('dialog-unsaved-close').click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  // نافذة من غير كتابة: Esc بيقفل على طول
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);

  // 3) الفحص السريع: تلات اختيارات، وبيتحفظ مسودة مع كل اختيار، ولو رجعت للجهاز بيرجع زي ما سبته
  const screen = page.getByRole('radiogroup', { name: 'الشاشة' }).first();
  await expect(screen.getByRole('radio')).toHaveCount(3);
  await screen.getByRole('radio', { name: 'عطلان' }).click();
  await page.goto('/#/devices');
  await page.goto(dev);
  await afterSplash(page);
  await expect(page.getByTestId('check-draft')).toBeVisible();
  await expect(page.getByRole('radiogroup', { name: 'الشاشة' }).first().getByRole('radio', { name: 'عطلان' })).toHaveAttribute('aria-checked', 'true');
  await page.getByRole('button', { name: 'حفظ الفحص' }).click();
  await expect(page.getByText('اتحفظ الفحص').first()).toBeVisible();
  await expect(page.getByTestId('check-draft')).toHaveCount(0);
});
