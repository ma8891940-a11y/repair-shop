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
    - generic [ref=e4]:
      - banner [ref=e5]:
        - button "بحث" [ref=e12]:
          - generic [ref=e16]: رقم الطلب، الموبايل، الاسم، IMEI
        - generic [ref=e22]:
          - button "Switch to English" [ref=e23]:
            - generic [ref=e28]: EN
          - button "الوضع الفاتح" [ref=e29]
      - main [ref=e37]:
        - generic [ref=e39]:
          - generic [ref=e41]:
            - heading "استلام جهاز" [level=1] [ref=e42]
            - generic [ref=e43]: سجّل الجهاز قدام العميل. كل حاجة هنا بتتطبع على الإيصال.
          - generic [ref=e44]:
            - generic [ref=e45]:
              - generic [ref=e46]:
                - generic [ref=e48]:
                  - generic [ref=e49]: "01"
                  - heading "العميل" [level=2] [ref=e50]
                - generic [ref=e51]:
                  - generic [ref=e52]:
                    - generic [ref=e53]: رقم الموبايل (واتساب)*
                    - textbox "رقم الموبايل (واتساب)" [ref=e55]:
                      - /placeholder: 01xxxxxxxxx
                      - text: "01122334455"
                  - generic [ref=e57]:
                    - generic [ref=e58]:
                      - generic [ref=e59]:
                        - generic [ref=e60]: اسم العميل*
                        - generic [ref=e61]: عميل جديد
                      - textbox "اسم العميل" [ref=e62]: سارة محمود
                    - generic [ref=e63]:
                      - generic [ref=e64]: المنطقة
                      - textbox "المنطقة" [ref=e66]
              - generic [ref=e67]:
                - generic [ref=e69]:
                  - generic [ref=e70]: "02"
                  - heading "الجهاز" [level=2] [ref=e71]
                - generic [ref=e72]:
                  - group "اختيار سريع للنوع" [ref=e73]:
                    - button "Samsung" [ref=e74]
                    - button "iPhone" [pressed] [ref=e77]
                    - button "Xiaomi" [ref=e80]
                    - button "Oppo" [ref=e83]
                    - button "Realme" [ref=e86]
                    - button "Infinix" [ref=e89]
                    - button "Vivo" [ref=e92]
                    - button "Honor" [ref=e95]
                    - button "Huawei" [ref=e98]
                    - button "Tecno" [ref=e101]
                  - generic [ref=e104]:
                    - generic [ref=e105]:
                      - generic [ref=e106]: النوع*
                      - textbox "النوع" [ref=e108]: iPhone
                    - generic [ref=e109]:
                      - generic [ref=e110]: الموديل*
                      - textbox "الموديل" [ref=e112]:
                        - /placeholder: A54، 13 Pro...
                        - text: 12 Pro
                    - generic [ref=e113]:
                      - generic [ref=e114]: اللون
                      - textbox "اللون" [ref=e116]
                  - generic [ref=e117]:
                    - generic [ref=e118]:
                      - generic [ref=e119]: IMEI
                      - textbox "IMEI" [ref=e121]:
                        - /placeholder: "*#06#"
                      - paragraph [ref=e122]: اطلب *#06# من الجهاز
                    - generic [ref=e123]:
                      - generic [ref=e124]: قفل الجهاز
                      - generic [ref=e129]:
                        - radiogroup "نوع القفل" [ref=e130]:
                          - radio "بدون" [checked] [ref=e131]
                          - radio "رقم" [ref=e133]
                          - radio "نمط" [ref=e134]
                        - textbox "قفل الجهاز" [disabled] [ref=e136]:
                          - /placeholder: —
                      - paragraph [ref=e137]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e138]:
                    - generic [ref=e139]: الملحقات المستلمة
                    - generic [ref=e140]:
                      - button "شريحة" [ref=e141]
                      - button "جراب" [ref=e143]
                      - button "كارت ذاكرة" [ref=e145]
                      - button "شاحن" [ref=e147]
                      - button "سماعة" [ref=e149]
                      - button "علبة" [ref=e151]
              - generic [ref=e153]:
                - generic [ref=e155]:
                  - generic [ref=e156]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e157]
                - generic [ref=e158]:
                  - generic [ref=e159]:
                    - generic [ref=e160]:
                      - generic [ref=e161]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e163]: شاشة مكسورة
                    - generic [ref=e164]:
                      - button "+ شاشة مكسورة" [active] [ref=e165]
                      - button "+ بطارية" [ref=e166]
                      - button "+ مش بيشحن" [ref=e167]
                      - button "+ سوفت وير" [ref=e168]
                      - button "+ دخل مية" [ref=e169]
                      - button "+ السماعة" [ref=e170]
                      - button "+ المايك" [ref=e171]
                      - button "+ الكاميرا" [ref=e172]
                      - button "+ مش بيفتح" [ref=e173]
                  - generic [ref=e174]:
                    - generic [ref=e175]:
                      - generic [ref=e176]: الأولوية
                      - radiogroup "الأولوية" [ref=e177]:
                        - radio "عادي" [checked] [ref=e178]
                        - radio "عاجل" [ref=e179]
                    - generic [ref=e180]:
                      - generic [ref=e181]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e184]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e185]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e186]:
                      - generic [ref=e187]: المدة المتوقعة
                      - generic [ref=e189]:
                        - textbox "المدة المتوقعة" [ref=e190]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e192]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e193]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e194]:
                    - generic [ref=e195]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e197]
                    - paragraph [ref=e198]: خدوش، كسر، انحناء...
                  - generic [ref=e199]:
                    - generic [ref=e200]: التكلفة التقديرية
                    - generic [ref=e202]:
                      - textbox "التكلفة التقديرية" [ref=e203]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e204]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e205]:
                - generic [ref=e206]:
                  - generic [ref=e207]:
                    - generic [ref=e208]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e209]
                  - generic [ref=e210]: اختياري
                - generic [ref=e212]:
                  - generic [ref=e213]:
                    - paragraph [ref=e214]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e215]
                  - list [ref=e219]:
                    - listitem [ref=e220]:
                      - generic [ref=e221]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e222]:
                        - radio "شغال" [ref=e223]
                        - radio "عطلان" [ref=e224]
                        - radio "مش متاح" [ref=e225]
                    - listitem [ref=e226]:
                      - generic [ref=e227]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e228]:
                        - radio "شغال" [ref=e229]
                        - radio "عطلان" [ref=e230]
                        - radio "مش متاح" [ref=e231]
                    - listitem [ref=e232]:
                      - generic [ref=e233]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e234]:
                        - radio "شغال" [ref=e235]
                        - radio "عطلان" [ref=e236]
                        - radio "مش متاح" [ref=e237]
                    - listitem [ref=e238]:
                      - generic [ref=e239]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e240]:
                        - radio "شغال" [ref=e241]
                        - radio "عطلان" [ref=e242]
                        - radio "مش متاح" [ref=e243]
                    - listitem [ref=e244]:
                      - generic [ref=e245]: البصمة
                      - radiogroup "البصمة" [ref=e246]:
                        - radio "شغال" [ref=e247]
                        - radio "عطلان" [ref=e248]
                        - radio "مش متاح" [ref=e249]
                    - listitem [ref=e250]:
                      - generic [ref=e251]: الصوت
                      - radiogroup "الصوت" [ref=e252]:
                        - radio "شغال" [ref=e253]
                        - radio "عطلان" [ref=e254]
                        - radio "مش متاح" [ref=e255]
                    - listitem [ref=e256]:
                      - generic [ref=e257]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e258]:
                        - radio "شغال" [ref=e259]
                        - radio "عطلان" [ref=e260]
                        - radio "مش متاح" [ref=e261]
                    - listitem [ref=e262]:
                      - generic [ref=e263]: الشحن
                      - radiogroup "الشحن" [ref=e264]:
                        - radio "شغال" [ref=e265]
                        - radio "عطلان" [ref=e266]
                        - radio "مش متاح" [ref=e267]
                    - listitem [ref=e268]:
                      - generic [ref=e269]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e270]:
                        - radio "شغال" [ref=e271]
                        - radio "عطلان" [ref=e272]
                        - radio "مش متاح" [ref=e273]
                    - listitem [ref=e274]:
                      - generic [ref=e275]: الشبكة
                      - radiogroup "الشبكة" [ref=e276]:
                        - radio "شغال" [ref=e277]
                        - radio "عطلان" [ref=e278]
                        - radio "مش متاح" [ref=e279]
              - generic [ref=e280]:
                - generic [ref=e281]:
                  - generic [ref=e282]:
                    - generic [ref=e283]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e284]
                  - generic [ref=e285]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e288]
              - generic [ref=e294]:
                - generic [ref=e295]:
                  - generic [ref=e296]:
                    - generic [ref=e297]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e298]
                  - generic [ref=e299]: اختياري
                - generic [ref=e300]:
                  - paragraph [ref=e301]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e302]:
                    - generic [ref=e303]:
                      - img "مكان التوقيع" [ref=e304]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e305]
            - complementary [ref=e309]:
              - generic [ref=e310]:
                - generic [ref=e311]:
                  - generic [ref=e312]: رقم الطلب
                  - generic [ref=e313]: 2026-····
                  - generic [ref=e314]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e315]:
                  - generic [ref=e316]:
                    - term [ref=e317]: العميل
                    - definition [ref=e318]: سارة محمود
                  - generic [ref=e319]:
                    - term [ref=e320]: رقم الموبايل (واتساب)
                    - definition [ref=e321]: "01122334455"
                  - generic [ref=e322]:
                    - term [ref=e323]: الجهاز
                    - definition [ref=e324]: iPhone 12 Pro
                  - generic [ref=e325]:
                    - term [ref=e326]: IMEI
                    - definition [ref=e327]: —
                  - generic [ref=e328]:
                    - term [ref=e329]: الملحقات المستلمة
                    - definition [ref=e330]: —
                  - generic [ref=e331]:
                    - term [ref=e332]: قفل
                    - definition [ref=e333]: بدون
                  - generic [ref=e334]:
                    - term [ref=e335]: صور الجهاز
                    - definition [ref=e336]: 0 من 6
                - generic [ref=e337]:
                  - generic [ref=e338]: التكلفة التقديرية
                  - generic [ref=e339]: — ج.م
                - generic [ref=e340]:
                  - button "حفظ الاستلام" [ref=e341]
                  - button "إلغاء" [ref=e342]
    - navigation "القائمة الرئيسية" [ref=e343]:
      - link "لوحة التحكم" [ref=e344] [cursor=pointer]:
        - /url: "#/"
      - link "الأجهزة" [ref=e348] [cursor=pointer]:
        - /url: "#/devices"
      - link "استلام جهاز" [ref=e352] [cursor=pointer]:
        - /url: "#/intake"
      - link "العملاء" [ref=e357] [cursor=pointer]:
        - /url: "#/customers"
      - button "خروج" [ref=e362]
  - generic:
    - status [ref=e366]:
      - generic [ref=e371]:
        - generic [ref=e372]: المحل جاهز
        - generic [ref=e373]: كل حاجة اتظبطت. يلا نبدأ.
      - button "إغلاق" [ref=e374]
    - status [ref=e378]:
      - generic [ref=e383]: اتحفظت الإعدادات
      - button "إغلاق" [ref=e385]
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
> 34  |   await page.getByLabel('التكلفة التقديرية').fill('850');
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