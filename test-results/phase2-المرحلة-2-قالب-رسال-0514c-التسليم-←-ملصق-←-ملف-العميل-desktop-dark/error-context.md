# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase2.spec.ts >> المرحلة 2: قالب رسالة ← استلام بفحص ← واتساب ← تتبع بالـ QR وموافقة ← فحص التسليم ← ملصق ← ملف العميل
- Location: tests/e2e/phase2.spec.ts:4:1

# Error details

```
Test timeout of 180000ms exceeded.
```

```
Error: locator.click: Test timeout of 180000ms exceeded.
Call log:
  - waiting for getByRole('tab', { name: 'الرسائل' })

```

# Test source

```ts
  1   | import { expect, test } from '@playwright/test';
  2   | import { afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';
  3   | 
  4   | test('المرحلة 2: قالب رسالة ← استلام بفحص ← واتساب ← تتبع بالـ QR وموافقة ← فحص التسليم ← ملصق ← ملف العميل', async ({ page, browser }, info) => {
  5   |   test.setTimeout(180_000);
  6   |   await prefs(page, info);
  7   |   // بنمسك الرابط اللي بيتفتح لواتساب بدل ما يفتح فعلًا
  8   |   await page.addInitScript(() => {
  9   |     (window as unknown as { __opened: string[] }).__opened = [];
  10  |     window.open = ((u: string) => {
  11  |       (window as unknown as { __opened: string[] }).__opened.push(String(u));
  12  |       return null;
  13  |     }) as typeof window.open;
  14  |   });
  15  |   await registerShop(page, uniq('owner2'));
  16  | 
  17  |   // 1) صاحب المحل بيعدّل قالب رسالة الاستلام، والمعاينة بتتملى
  18  |   await page.goto('/#/settings');
> 19  |   await page.getByRole('tab', { name: 'الرسائل' }).click();
      |                                                    ^ Error: locator.click: Test timeout of 180000ms exceeded.
  20  |   await page.getByRole('tab', { name: 'استلام الجهاز' }).click();
  21  |   await page.locator('#tpl-body').fill('أهلًا {name}، ورشتنا استلمت {device} رقم {order}. تابع: {link}');
  22  |   await expect(page.getByTestId('tpl-preview')).toContainText('أهلًا أحمد، ورشتنا استلمت iPhone 13 رقم 2026-0042');
  23  |   await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  24  |   await expect(page.getByText('اتحفظ').first()).toBeVisible();
  25  |   await noHorizontalScroll(page);
  26  | 
  27  |   // 2) استلام بفحص سريع: الواي فاي عطلان والشحن شغال
  28  |   await page.goto('/#/intake');
  29  |   await page.locator('#intake-phone').fill('٠١١٢٢٣٣٤٤٥٥');
  30  |   await page.getByLabel('اسم العميل').fill('سارة محمود');
  31  |   await page.getByRole('button', { name: 'iPhone', exact: true }).click();
  32  |   await page.getByLabel('الموديل').fill('12 Pro');
  33  |   await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
  34  |   await page.locator('input[placeholder="0"]').fill('850');
  35  |   await page.getByRole('radiogroup', { name: 'الواي فاي' }).getByRole('radio', { name: 'عطلان' }).click();
  36  |   await page.getByRole('radiogroup', { name: 'الشحن' }).getByRole('radio', { name: 'شغال' }).click();
  37  |   await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  38  |   await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  39  |   await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  40  |   await expect(page.getByText('12 Pro').first()).toBeVisible();
  41  |   const deviceHash = page.url().replace(/^.*#/, '/#');
  42  | 
  43  |   // 3) واتساب بالقالب المعدّل: الرابط wa.me برقم دولي والنص فيه رابط التتبع
  44  |   await page.getByRole('button', { name: 'واتساب' }).first().click();
  45  |   const dlg = page.getByRole('dialog');
  46  |   await dlg.getByLabel('الرسالة').selectOption('received');
  47  |   const text = await dlg.getByLabel('معاينة').inputValue();
  48  |   expect(text).toContain('أهلًا سارة، ورشتنا استلمت iPhone 12 Pro');
  49  |   const token = (text.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  50  |   expect(token).toBeTruthy();
  51  |   await dlg.getByRole('button', { name: 'افتح واتساب' }).click();
  52  |   await expect(page.getByText('اتسجلت الرسالة')).toBeVisible();
  53  |   const opened = await page.evaluate(() => (window as unknown as { __opened: string[] }).__opened);
  54  |   expect(opened[0]).toMatch(/^https:\/\/wa\.me\/201122334455\?text=/);
  55  |   expect(decodeURIComponent(opened[0].split('text=')[1])).toContain(`#/t/${token}`);
  56  | 
  57  |   // 4) الفحص ← في انتظار الموافقة
  58  |   for (const s of ['جاري الفحص', 'في انتظار موافقة العميل']) {
  59  |     await page.getByRole('button', { name: s, exact: true }).click();
  60  |     await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  61  |   }
  62  | 
  63  |   // 5) العميل (من غير تسجيل دخول، على الموبايل) بيمسح الـ QR ويوافق
  64  |   const ctx = await browser.newContext({ ...info.project.use, storageState: undefined });
  65  |   const cust = await ctx.newPage();
  66  |   await prefs(cust, info);
  67  |   await cust.goto(`/#/t/${token}`);
  68  |   await expect(cust.getByText('محتاجين موافقتك')).toBeVisible();
  69  |   await expect(cust.getByText('سارة')).toHaveCount(0); // من غير أي بيانات شخصية
  70  |   await expect(cust.getByText('01122334455')).toHaveCount(0);
  71  |   await expect(cust.getByText('850').first()).toBeVisible();
  72  |   await noHorizontalScroll(cust);
  73  |   await cust.getByRole('button', { name: 'موافق، ابدأ الإصلاح' }).click();
  74  |   await expect(cust.getByText('شكرًا! اتسجلت موافقتك')).toBeVisible();
  75  |   // رقم طلب غلط من الفورم = مش لاقيين
  76  |   await cust.goto('/#/t');
  77  |   await cust.getByLabel('رقم الطلب').fill('2020-9999');
  78  |   await cust.getByLabel('آخر 4 أرقام من الموبايل').fill('٤٤٥٥');
  79  |   await cust.getByRole('button', { name: 'تتبع', exact: true }).click();
  80  |   await expect(cust.getByText('مش لاقيين جهاز بالبيانات دي')).toBeVisible();
  81  |   await ctx.close();
  82  | 
  83  |   // 6) الموافقة نقلت الجهاز لجاري الصيانة، وبعدين فحص التسليم والمقارنة
  84  |   await page.goto('/#/');
  85  |   await page.goto(deviceHash);
  86  |   await expect(page.getByText('جاري الصيانة').first()).toBeVisible();
  87  |   for (const s of ['تم الإصلاح', 'جاهز للاستلام']) {
  88  |     await page.getByRole('button', { name: s, exact: true }).click();
  89  |     await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  90  |   }
  91  |   await page.reload();
  92  |   await afterSplash(page);
  93  |   await expect(page.getByRole('tab', { name: 'عند التسليم' })).toHaveAttribute('aria-selected', 'true');
  94  |   await page.getByRole('radiogroup', { name: 'الواي فاي' }).getByRole('radio', { name: 'شغال' }).click();
  95  |   await page.getByRole('radiogroup', { name: 'الشحن' }).getByRole('radio', { name: 'عطلان' }).click();
  96  |   await page.getByRole('button', { name: 'حفظ الفحص' }).click();
  97  |   await expect(page.getByText('اتحفظ الفحص')).toBeVisible();
  98  |   await expect(page.getByText('كان شغال وقت الاستلام').first()).toBeVisible();
  99  |   await expect(page.getByText('اتصلح').first()).toBeVisible();
  100 | 
  101 |   // 7) ملصق 80مم فيه QR ورقم الطلب
  102 |   await page.goto(deviceHash.replace('/devices/', '/print/label/'));
  103 |   await expect(page.getByRole('article', { name: 'ملصق الجهاز' })).toBeVisible();
  104 |   await expect(page.locator('article img[src^="data:image/png"]')).toHaveCount(1);
  105 |   await expect(page.getByText(`${new Date().getFullYear()}-0001`)).toBeVisible();
  106 | 
  107 |   // 8) ملف العميل: جهاز واحد، وتغيير التصنيف
  108 |   await page.goto('/#/customers');
  109 |   await afterSplash(page);
  110 |   await page.getByText('سارة محمود').filter({ visible: true }).first().click();
  111 |   await expect(page.getByRole('heading', { name: 'سارة محمود' })).toBeVisible();
  112 |   await expect(page.getByText('12 Pro')).toBeVisible();
  113 |   await page.getByLabel('التصنيف').selectOption('vip');
  114 |   await expect(page.getByText('اتحفظ').first()).toBeVisible();
  115 |   await noHorizontalScroll(page);
  116 | });
  117 | 
```