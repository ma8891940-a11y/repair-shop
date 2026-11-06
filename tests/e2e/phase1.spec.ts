import { expect, test } from '@playwright/test';
import { activateInvite, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

test('المرحلة 1: تسجيل ← استلام ← فني ← حالات ← تسليم ← طباعة ← بحث', async ({ page, browser }, info) => {
  test.setTimeout(180_000);
  const mobile = info.project.name.startsWith('mobile');
  await prefs(page, info);
  await registerShop(page, uniq('owner'));
  await noHorizontalScroll(page);

  // الاستلام (رقم بالأرقام العربية، وقفل، وصور، وتكلفة)
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('٠١٠١٢٣٤٥٦٧٨');
  await page.getByLabel('اسم العميل').fill('أحمد علي');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('Galaxy A54');
  await page.locator('input[placeholder="*#06#"]').fill('490154203237518');
  await page.getByRole('radio', { name: 'نمط' }).click();
  await page.locator('input[placeholder="1-5-9-6"]').fill('1-5-9-6');
  await page.getByRole('button', { name: 'شريحة', exact: true }).click();
  await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
  await page.getByLabel('التكلفة التقديرية').fill('1250.5');
  await page.locator('input[type=file]').setInputFiles(['public/icon-192.png']);
  // حفظ فاضي الأول؟ لأ: كل الحقول المطلوبة متملية
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  const year = new Date().getFullYear();
  await expect(page.getByText(`${year}-0001`)).toBeVisible();
  await noHorizontalScroll(page);
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByText('Galaxy A54').first()).toBeVisible();
  const deviceUrl = page.url();

  // دعوة فني، وهو بيفعّل حسابه ويفتح الجهاز
  await page.goto('/#/users');
  const techEmail = uniq('tech');
  await page.getByLabel('الاسم').fill('كريم');
  await page.getByLabel('الإيميل').fill(techEmail);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const tech = await activateInvite(browser, info, techEmail);
  await tech.page.goto(deviceUrl.replace(/^.*#/, '/#'));
  await expect(tech.page.getByText('Galaxy A54').first()).toBeVisible();
  await expect(tech.page.getByText('التكلفة التقديرية')).toHaveCount(0); // الفني ما يشوفش أسعار
  await expect(tech.page.getByText('أحمد علي')).toHaveCount(0); // ولا بيانات العميل
  await tech.page.getByRole('button', { name: 'عرض القفل' }).click();
  await expect(tech.page.getByText('1-5-9-6')).toBeVisible();
  await tech.page.getByRole('button', { name: 'جاري الفحص' }).click();
  await expect(tech.page.getByText('الحالة اتغيّرت').first()).toBeVisible();
  await expect(tech.page.getByRole('link', { name: 'سجل النشاط' })).toHaveCount(0);
  await tech.ctx.close();

  // صاحب المحل: الحالات والتسليم
  await page.goto(deviceUrl.replace(/^.*#/, '/#'));
  for (const s of ['جاري الصيانة', 'تم الإصلاح', 'جاهز للاستلام']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  await page.getByRole('button', { name: 'تأكيد' }).click();
  await expect(page.getByText('لازم تكتب التكلفة النهائية قبل التسليم')).toBeVisible();
  await page.getByLabel('التكلفة النهائية').fill('1,400.75');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  // المرحلة 3: التسليم قبل السداد ممنوع، والدفعة بتتسجل من فلوس الجهاز
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  await page.getByRole('button', { name: 'تأكيد' }).click();
  await expect(page.getByText('لازم الجهاز يتدفع بالكامل قبل التسليم').first()).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await expect(page.getByTestId('device-due')).toHaveText('0');
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  await page.getByRole('button', { name: 'تأكيد' }).click();
  await expect(page.getByText('القفل اتمسح بعد التسليم.')).toBeVisible();

  // لوحة التحكم: إيراد اليوم
  await page.goto('/#/');
  await expect(page.locator('a, div').filter({ hasText: 'إيراد اليوم' }).getByText('1,400.75').first()).toBeVisible();
  await noHorizontalScroll(page);

  // الطباعة: إيصال فيه الشروط ورقم الطلب
  await page.goto(deviceUrl.replace(/^.*#/, '/#').replace('/devices/', '/print/receipt/'));
  await expect(page.getByText('إيصال استلام جهاز')).toBeVisible();
  await expect(page.getByText(`${year}-0001`)).toBeVisible();
  await expect(page.getByText('شروط الاستلام')).toBeVisible();

  // البحث في القائمة
  await page.goto('/#/devices');
  await page.getByRole('textbox', { name: 'بحث' }).fill(`${year}-0001`);
  // الجدول (كمبيوتر) والكروت (موبايل) الاتنين في الصفحة، وواحد بس ظاهر
  await expect(page.getByText('Galaxy A54').filter({ visible: true }).first()).toBeVisible();
  if (!mobile) await expect(page.locator('tbody tr')).toHaveCount(1);
  await noHorizontalScroll(page);

  // سجل النشاط فيه مشاهدة القفل وتعديل التكلفة
  await page.goto('/#/audit');
  await expect(page.getByText('عرض القفل').first()).toBeVisible();
  await expect(page.getByText('التكلفة النهائية').first()).toBeVisible();
});
