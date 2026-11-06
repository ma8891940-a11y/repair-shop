# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase2.spec.ts >> المرحلة 2: قالب رسالة ← استلام بفحص ← واتساب ← تتبع بالـ QR وموافقة ← فحص التسليم ← ملصق ← ملف العميل
- Location: tests/e2e/phase2.spec.ts:4:1

# Error details

```
Error: locator.fill: Error: strict mode violation: locator('input[placeholder="0"]') resolved to 2 elements:
    1) <input value="" dir="ltr" placeholder="0" inputmode="numeric" aria-label="المدة المتوقعة" class="w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60 h-9 px-3 text-base num w-20 text-start"/> aka getByRole('textbox', { name: 'المدة المتوقعة' })
    2) <input value="" dir="ltr" id="_r_2p_" placeholder="0" inputmode="decimal" aria-describedby="_r_2p_-desc" class="w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60 h-9 px-3 text-base num ps-12 tex…/> aka getByRole('textbox', { name: 'التكلفة التقديرية' })

Call log:
  - waiting for locator('input[placeholder="0"]')

```

# Page snapshot

```yaml
- generic [ref=e2]:
  - generic [ref=e3]:
    - complementary [ref=e4]:
      - generic [ref=e11]:
        - generic [ref=e12]: مركز الاختبار
        - generic [ref=e13]: إدارة صيانة الموبايل
      - navigation "القائمة الرئيسية" [ref=e15]:
        - link "لوحة التحكم" [ref=e16] [cursor=pointer]:
          - /url: "#/"
        - link "الأجهزة" [ref=e21] [cursor=pointer]:
          - /url: "#/devices"
        - link "استلام جهاز" [ref=e26] [cursor=pointer]:
          - /url: "#/intake"
        - link "العملاء" [ref=e34] [cursor=pointer]:
          - /url: "#/customers"
        - link "الوضع المالي" [ref=e40] [cursor=pointer]:
          - /url: "#/finance"
        - link "المخزون" [ref=e44] [cursor=pointer]:
          - /url: "#/inventory"
        - link "التقارير" [ref=e56] [cursor=pointer]:
          - /url: "#/reports"
        - link "الفريق" [ref=e60] [cursor=pointer]:
          - /url: "#/users"
        - link "سجل النشاط" [ref=e67] [cursor=pointer]:
          - /url: "#/audit"
        - link "الإعدادات" [ref=e73] [cursor=pointer]:
          - /url: "#/settings"
      - generic [ref=e78]:
        - generic [ref=e79]:
          - button "الوضع الفاتح" [ref=e80]
          - button "Switch to English" [ref=e88]:
            - generic [ref=e93]: EN
          - button "المؤثرات الكاملة" [ref=e94]
        - generic [ref=e97]:
          - generic [ref=e98]: م
          - generic [ref=e99]:
            - generic [ref=e100]: محمود حسن
            - generic [ref=e101]: صاحب المحل
          - button "خروج" [ref=e102]
    - generic [ref=e106]:
      - banner [ref=e107]:
        - button "بحث" [ref=e108]:
          - generic [ref=e112]: رقم الطلب، الموبايل، الاسم، IMEI
          - generic [ref=e113]:
            - generic [ref=e114]: Ctrl
            - generic [ref=e115]: K
        - generic [ref=e116]: مباشر
      - main [ref=e122]:
        - generic [ref=e124]:
          - generic [ref=e125]:
            - generic [ref=e126]:
              - heading "استلام جهاز" [level=1] [ref=e127]
              - generic [ref=e128]: سجّل الجهاز قدام العميل. كل حاجة هنا بتتطبع على الإيصال.
            - generic [ref=e130]:
              - text: حفظ
              - generic [ref=e131]: Ctrl
              - generic [ref=e132]: Enter
          - generic [ref=e133]:
            - generic [ref=e134]:
              - generic [ref=e135]:
                - generic [ref=e137]:
                  - generic [ref=e138]: "01"
                  - heading "العميل" [level=2] [ref=e139]
                - generic [ref=e140]:
                  - generic [ref=e141]:
                    - generic [ref=e142]: رقم الموبايل (واتساب)*
                    - textbox "رقم الموبايل (واتساب)" [ref=e144]:
                      - /placeholder: 01xxxxxxxxx
                      - text: "01122334455"
                  - generic [ref=e146]:
                    - generic [ref=e147]:
                      - generic [ref=e148]:
                        - generic [ref=e149]: اسم العميل*
                        - generic [ref=e150]: عميل جديد
                      - textbox "اسم العميل" [ref=e151]: سارة محمود
                    - generic [ref=e152]:
                      - generic [ref=e153]: المنطقة
                      - textbox "المنطقة" [ref=e155]
              - generic [ref=e156]:
                - generic [ref=e158]:
                  - generic [ref=e159]: "02"
                  - heading "الجهاز" [level=2] [ref=e160]
                - generic [ref=e161]:
                  - group "اختيار سريع للنوع" [ref=e162]:
                    - button "Samsung" [ref=e163]
                    - button "iPhone" [pressed] [ref=e166]
                    - button "Xiaomi" [ref=e169]
                    - button "Oppo" [ref=e172]
                    - button "Realme" [ref=e175]
                    - button "Infinix" [ref=e178]
                    - button "Vivo" [ref=e181]
                    - button "Honor" [ref=e184]
                    - button "Huawei" [ref=e187]
                    - button "Tecno" [ref=e190]
                  - generic [ref=e193]:
                    - generic [ref=e194]:
                      - generic [ref=e195]: النوع*
                      - textbox "النوع" [ref=e197]: iPhone
                    - generic [ref=e198]:
                      - generic [ref=e199]: الموديل*
                      - textbox "الموديل" [ref=e201]:
                        - /placeholder: A54، 13 Pro...
                        - text: 12 Pro
                    - generic [ref=e202]:
                      - generic [ref=e203]: اللون
                      - textbox "اللون" [ref=e205]
                  - generic [ref=e206]:
                    - generic [ref=e207]:
                      - generic [ref=e208]: IMEI
                      - textbox "IMEI" [ref=e210]:
                        - /placeholder: "*#06#"
                      - paragraph [ref=e211]: اطلب *#06# من الجهاز
                    - generic [ref=e212]:
                      - generic [ref=e213]: قفل الجهاز
                      - generic [ref=e218]:
                        - radiogroup "نوع القفل" [ref=e219]:
                          - radio "بدون" [checked] [ref=e220]
                          - radio "رقم" [ref=e222]
                          - radio "نمط" [ref=e223]
                        - textbox "قفل الجهاز" [disabled] [ref=e225]:
                          - /placeholder: —
                      - paragraph [ref=e226]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e227]:
                    - generic [ref=e228]: الملحقات المستلمة
                    - generic [ref=e229]:
                      - button "شريحة" [ref=e230]
                      - button "جراب" [ref=e232]
                      - button "كارت ذاكرة" [ref=e234]
                      - button "شاحن" [ref=e236]
                      - button "سماعة" [ref=e238]
                      - button "علبة" [ref=e240]
              - generic [ref=e242]:
                - generic [ref=e244]:
                  - generic [ref=e245]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e246]
                - generic [ref=e247]:
                  - generic [ref=e248]:
                    - generic [ref=e249]:
                      - generic [ref=e250]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e252]: شاشة مكسورة
                    - generic [ref=e253]:
                      - button "+ شاشة مكسورة" [active] [ref=e254]
                      - button "+ بطارية" [ref=e255]
                      - button "+ مش بيشحن" [ref=e256]
                      - button "+ سوفت وير" [ref=e257]
                      - button "+ دخل مية" [ref=e258]
                      - button "+ السماعة" [ref=e259]
                      - button "+ المايك" [ref=e260]
                      - button "+ الكاميرا" [ref=e261]
                      - button "+ مش بيفتح" [ref=e262]
                  - generic [ref=e263]:
                    - generic [ref=e264]:
                      - generic [ref=e265]: الأولوية
                      - radiogroup "الأولوية" [ref=e266]:
                        - radio "عادي" [checked] [ref=e267]
                        - radio "عاجل" [ref=e268]
                    - generic [ref=e269]:
                      - generic [ref=e270]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e273]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e274]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e275]:
                      - generic [ref=e276]: المدة المتوقعة
                      - generic [ref=e278]:
                        - textbox "المدة المتوقعة" [ref=e279]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e281]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e282]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e283]:
                    - generic [ref=e284]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e286]
                    - paragraph [ref=e287]: خدوش، كسر، انحناء...
                  - generic [ref=e288]:
                    - generic [ref=e289]: التكلفة التقديرية
                    - generic [ref=e291]:
                      - textbox "التكلفة التقديرية" [ref=e292]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e293]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e294]:
                - generic [ref=e295]:
                  - generic [ref=e296]:
                    - generic [ref=e297]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e298]
                  - generic [ref=e299]: اختياري
                - generic [ref=e301]:
                  - generic [ref=e302]:
                    - paragraph [ref=e303]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e304]
                  - list [ref=e308]:
                    - listitem [ref=e309]:
                      - generic [ref=e310]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e311]:
                        - radio "شغال" [ref=e312]
                        - radio "عطلان" [ref=e313]
                        - radio "مش متاح" [ref=e314]
                    - listitem [ref=e315]:
                      - generic [ref=e316]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e317]:
                        - radio "شغال" [ref=e318]
                        - radio "عطلان" [ref=e319]
                        - radio "مش متاح" [ref=e320]
                    - listitem [ref=e321]:
                      - generic [ref=e322]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e323]:
                        - radio "شغال" [ref=e324]
                        - radio "عطلان" [ref=e325]
                        - radio "مش متاح" [ref=e326]
                    - listitem [ref=e327]:
                      - generic [ref=e328]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e329]:
                        - radio "شغال" [ref=e330]
                        - radio "عطلان" [ref=e331]
                        - radio "مش متاح" [ref=e332]
                    - listitem [ref=e333]:
                      - generic [ref=e334]: البصمة
                      - radiogroup "البصمة" [ref=e335]:
                        - radio "شغال" [ref=e336]
                        - radio "عطلان" [ref=e337]
                        - radio "مش متاح" [ref=e338]
                    - listitem [ref=e339]:
                      - generic [ref=e340]: الصوت
                      - radiogroup "الصوت" [ref=e341]:
                        - radio "شغال" [ref=e342]
                        - radio "عطلان" [ref=e343]
                        - radio "مش متاح" [ref=e344]
                    - listitem [ref=e345]:
                      - generic [ref=e346]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e347]:
                        - radio "شغال" [ref=e348]
                        - radio "عطلان" [ref=e349]
                        - radio "مش متاح" [ref=e350]
                    - listitem [ref=e351]:
                      - generic [ref=e352]: الشحن
                      - radiogroup "الشحن" [ref=e353]:
                        - radio "شغال" [ref=e354]
                        - radio "عطلان" [ref=e355]
                        - radio "مش متاح" [ref=e356]
                    - listitem [ref=e357]:
                      - generic [ref=e358]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e359]:
                        - radio "شغال" [ref=e360]
                        - radio "عطلان" [ref=e361]
                        - radio "مش متاح" [ref=e362]
                    - listitem [ref=e363]:
                      - generic [ref=e364]: الشبكة
                      - radiogroup "الشبكة" [ref=e365]:
                        - radio "شغال" [ref=e366]
                        - radio "عطلان" [ref=e367]
                        - radio "مش متاح" [ref=e368]
              - generic [ref=e369]:
                - generic [ref=e370]:
                  - generic [ref=e371]:
                    - generic [ref=e372]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e373]
                  - generic [ref=e374]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e377]
              - generic [ref=e383]:
                - generic [ref=e384]:
                  - generic [ref=e385]:
                    - generic [ref=e386]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e387]
                  - generic [ref=e388]: اختياري
                - generic [ref=e389]:
                  - paragraph [ref=e390]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e391]:
                    - generic [ref=e392]:
                      - img "مكان التوقيع" [ref=e393]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e394]
            - complementary [ref=e398]:
              - generic [ref=e399]:
                - generic [ref=e400]:
                  - generic [ref=e401]: رقم الطلب
                  - generic [ref=e402]: 2026-····
                  - generic [ref=e403]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e404]:
                  - generic [ref=e405]:
                    - term [ref=e406]: العميل
                    - definition [ref=e407]: سارة محمود
                  - generic [ref=e408]:
                    - term [ref=e409]: رقم الموبايل (واتساب)
                    - definition [ref=e410]: "01122334455"
                  - generic [ref=e411]:
                    - term [ref=e412]: الجهاز
                    - definition [ref=e413]: iPhone 12 Pro
                  - generic [ref=e414]:
                    - term [ref=e415]: IMEI
                    - definition [ref=e416]: —
                  - generic [ref=e417]:
                    - term [ref=e418]: الملحقات المستلمة
                    - definition [ref=e419]: —
                  - generic [ref=e420]:
                    - term [ref=e421]: قفل
                    - definition [ref=e422]: بدون
                  - generic [ref=e423]:
                    - term [ref=e424]: صور الجهاز
                    - definition [ref=e425]: 0 من 6
                - generic [ref=e426]:
                  - generic [ref=e427]: التكلفة التقديرية
                  - generic [ref=e428]: — ج.م
                - generic [ref=e429]:
                  - button "حفظ الاستلام" [ref=e430]
                  - button "إلغاء" [ref=e431]
  - generic:
    - status [ref=e432]:
      - generic [ref=e437]:
        - generic [ref=e438]: المحل جاهز
        - generic [ref=e439]: كل حاجة اتظبطت. يلا نبدأ.
      - button "إغلاق" [ref=e440]
    - status [ref=e444]:
      - generic [ref=e449]: اتحفظت الإعدادات
      - button "إغلاق" [ref=e451]
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
  19  |   await page.getByRole('tab', { name: 'الرسائل' }).click();
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
> 34  |   await page.locator('input[placeholder="0"]').fill('850');
      |                                                ^ Error: locator.fill: Error: strict mode violation: locator('input[placeholder="0"]') resolved to 2 elements:
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