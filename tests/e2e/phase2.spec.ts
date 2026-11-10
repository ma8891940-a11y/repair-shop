import { expect, test } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

test('المرحلة 2: قالب رسالة ← استلام بفحص ← واتساب ← تتبع بالـ QR وموافقة ← فحص التسليم ← ملصق ← ملف العميل', async ({ page, browser }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  // بنمسك الرابط اللي بيتفتح لواتساب بدل ما يفتح فعلًا
  await page.addInitScript(() => {
    (window as unknown as { __opened: string[] }).__opened = [];
    window.open = ((u: string) => {
      (window as unknown as { __opened: string[] }).__opened.push(String(u));
      return null;
    }) as typeof window.open;
  });
  await registerShop(page, uniq('owner2'));

  // 1) صاحب المحل بيعدّل قالب رسالة الاستلام، والمعاينة بتتملى
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الرسائل' }).click();
  await page.getByRole('tab', { name: 'استلام الجهاز' }).click();
  await page.locator('#tpl-body').fill('أهلًا {name}، ورشتنا استلمت {device} رقم {order}. تابع: {link}');
  await expect(page.getByTestId('tpl-preview')).toContainText('أهلًا أحمد، ورشتنا استلمت iPhone 13 رقم 2026-0042');
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await noHorizontalScroll(page);

  // 2) استلام بفحص سريع: الواي فاي عطلان والشحن شغال
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill('٠١١٢٢٣٣٤٤٥٥');
  await page.getByLabel('اسم العميل').fill('سارة محمود');
  await page.getByRole('button', { name: 'iPhone', exact: true }).click();
  await page.getByLabel('الموديل').fill('12 Pro');
  await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
  await page.getByLabel('التكلفة التقديرية').fill('850');
  await page.getByRole('radiogroup', { name: 'الواي فاي' }).getByRole('radio', { name: 'عطلان' }).click();
  await page.getByRole('radiogroup', { name: 'الشحن' }).getByRole('radio', { name: 'شغال' }).click();
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await expect(page.getByText('12 Pro').first()).toBeVisible();
  const deviceHash = page.url().replace(/^.*#/, '/#');

  // 3) واتساب بالقالب المعدّل: الرابط wa.me برقم دولي والنص فيه رابط التتبع
  await page.getByRole('button', { name: 'واتساب', exact: true }).first().click();
  const dlg = page.getByRole('dialog');
  await dlg.getByLabel('الرسالة').selectOption('received');
  const text = await dlg.getByLabel('معاينة').inputValue();
  expect(text).toContain('أهلًا سارة، ورشتنا استلمت iPhone 12 Pro');
  const token = (text.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  expect(token).toBeTruthy();
  await dlg.getByRole('button', { name: 'افتح واتساب' }).click();
  await expect(page.getByText('اتسجلت الرسالة')).toBeVisible();
  const opened = await page.evaluate(() => (window as unknown as { __opened: string[] }).__opened);
  expect(opened[0]).toMatch(/^https:\/\/wa\.me\/201122334455\?text=/);
  expect(decodeURIComponent(opened[0].split('text=')[1])).toContain(`#/t/${token}`);

  // 4) الفحص ← في انتظار الموافقة
  for (const s of ['جاري الفحص', 'في انتظار موافقة العميل']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }

  // 5) العميل (من غير تسجيل دخول، على الموبايل) بيمسح الـ QR ويوافق
  const ctx = await browser.newContext({ ...info.project.use, storageState: undefined });
  const cust = await ctx.newPage();
  await prefs(cust, info);
  await cust.goto(`/#/t/${token}`);
  await expect(cust.getByText('محتاجين موافقتك')).toBeVisible();
  await expect(cust.getByText('سارة')).toHaveCount(0); // من غير أي بيانات شخصية
  await expect(cust.getByText('01122334455')).toHaveCount(0);
  await expect(cust.getByText('850').first()).toBeVisible();
  await noHorizontalScroll(cust);
  await cust.getByRole('button', { name: 'موافق، ابدأ الإصلاح' }).click();
  await expect(cust.getByText('شكرًا! اتسجلت موافقتك')).toBeVisible();
  // رقم طلب غلط من الفورم = مش لاقيين
  await cust.goto('/#/t');
  await cust.getByLabel('رقم الطلب').fill('2020-9999');
  await cust.getByLabel('آخر 4 أرقام من الموبايل').fill('٤٤٥٥');
  await cust.getByRole('button', { name: 'تتبع', exact: true }).click();
  await expect(cust.getByText('مش لاقيين جهاز بالبيانات دي')).toBeVisible();
  await ctx.close();

  // 6) الموافقة نقلت الجهاز لجاري الصيانة، وبعدين فحص التسليم والمقارنة
  await page.goto('/#/');
  await page.goto(deviceHash);
  await expect(page.getByText('جاري الصيانة').first()).toBeVisible();
  for (const s of ['تم الإصلاح', 'جاهز للاستلام']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }
  await page.reload();
  await afterSplash(page);
  await expect(page.getByRole('tab', { name: 'عند التسليم' })).toHaveAttribute('aria-selected', 'true');
  await page.getByRole('radiogroup', { name: 'الواي فاي' }).getByRole('radio', { name: 'شغال' }).click();
  await page.getByRole('radiogroup', { name: 'الشحن' }).getByRole('radio', { name: 'عطلان' }).click();
  await page.getByRole('button', { name: 'حفظ الفحص' }).click();
  await expect(page.getByText('اتحفظ الفحص')).toBeVisible();
  await expect(page.getByText('كان شغال وقت الاستلام').first()).toBeVisible();
  await expect(page.getByText('اتصلح').first()).toBeVisible();

  // 7) ملصق 80مم فيه QR ورقم الطلب
  await page.goto(deviceHash.replace('/devices/', '/print/label/'));
  await expect(page.getByRole('article', { name: 'ملصق الجهاز' })).toBeVisible();
  await expect(page.locator('article img[src^="data:image/png"]')).toHaveCount(1);
  await expect(page.getByText(`${new Date().getFullYear()}-0001`)).toBeVisible();

  // 8) ملف العميل: جهاز واحد، وتغيير التصنيف
  await page.goto('/#/customers');
  await afterSplash(page);
  await page.getByText('سارة محمود').filter({ visible: true }).first().click();
  await expect(page.getByRole('heading', { name: 'سارة محمود' })).toBeVisible();
  await expect(page.getByText('12 Pro')).toBeVisible();
  await page.getByLabel('التصنيف').selectOption('vip');
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await noHorizontalScroll(page);
});
