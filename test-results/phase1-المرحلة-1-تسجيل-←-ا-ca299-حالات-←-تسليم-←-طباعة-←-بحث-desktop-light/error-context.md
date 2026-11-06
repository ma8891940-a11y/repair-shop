# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase1.spec.ts >> المرحلة 1: تسجيل ← استلام ← فني ← حالات ← تسليم ← طباعة ← بحث
- Location: tests/e2e/phase1.spec.ts:4:1

# Error details

```
Error: locator.fill: Error: strict mode violation: locator('input[placeholder="0"]') resolved to 2 elements:
    1) <input value="" dir="ltr" placeholder="0" inputmode="numeric" aria-label="المدة المتوقعة" class="w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60 h-9 px-3 text-base num w-20 text-start"/> aka getByRole('textbox', { name: 'المدة المتوقعة' })
    2) <input value="" dir="ltr" id="_r_29_" placeholder="0" inputmode="decimal" aria-describedby="_r_29_-desc" class="w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60 h-9 px-3 text-base num ps-12 tex…/> aka getByRole('textbox', { name: 'التكلفة التقديرية' })

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
          - button "الوضع الداكن" [ref=e80]
          - button "Switch to English" [ref=e84]:
            - generic [ref=e89]: EN
          - button "المؤثرات الكاملة" [ref=e90]
        - generic [ref=e93]:
          - generic [ref=e94]: م
          - generic [ref=e95]:
            - generic [ref=e96]: محمود حسن
            - generic [ref=e97]: صاحب المحل
          - button "خروج" [ref=e98]
    - generic [ref=e102]:
      - banner [ref=e103]:
        - button "بحث" [ref=e104]:
          - generic [ref=e108]: رقم الطلب، الموبايل، الاسم، IMEI
          - generic [ref=e109]:
            - generic [ref=e110]: Ctrl
            - generic [ref=e111]: K
        - generic [ref=e112]: مباشر
      - main [ref=e118]:
        - generic [ref=e120]:
          - generic [ref=e121]:
            - generic [ref=e122]:
              - heading "استلام جهاز" [level=1] [ref=e123]
              - generic [ref=e124]: سجّل الجهاز قدام العميل. كل حاجة هنا بتتطبع على الإيصال.
            - generic [ref=e126]:
              - text: حفظ
              - generic [ref=e127]: Ctrl
              - generic [ref=e128]: Enter
          - generic [ref=e129]:
            - generic [ref=e130]:
              - generic [ref=e131]:
                - generic [ref=e133]:
                  - generic [ref=e134]: "01"
                  - heading "العميل" [level=2] [ref=e135]
                - generic [ref=e136]:
                  - generic [ref=e137]:
                    - generic [ref=e138]: رقم الموبايل (واتساب)*
                    - textbox "رقم الموبايل (واتساب)" [ref=e140]:
                      - /placeholder: 01xxxxxxxxx
                      - text: "01012345678"
                  - generic [ref=e142]:
                    - generic [ref=e143]:
                      - generic [ref=e144]:
                        - generic [ref=e145]: اسم العميل*
                        - generic [ref=e146]: عميل جديد
                      - textbox "اسم العميل" [ref=e147]: أحمد علي
                    - generic [ref=e148]:
                      - generic [ref=e149]: المنطقة
                      - textbox "المنطقة" [ref=e151]
              - generic [ref=e152]:
                - generic [ref=e154]:
                  - generic [ref=e155]: "02"
                  - heading "الجهاز" [level=2] [ref=e156]
                - generic [ref=e157]:
                  - group "اختيار سريع للنوع" [ref=e158]:
                    - button "Samsung" [pressed] [ref=e159]
                    - button "iPhone" [ref=e162]
                    - button "Xiaomi" [ref=e165]
                    - button "Oppo" [ref=e168]
                    - button "Realme" [ref=e171]
                    - button "Infinix" [ref=e174]
                    - button "Vivo" [ref=e177]
                    - button "Honor" [ref=e180]
                    - button "Huawei" [ref=e183]
                    - button "Tecno" [ref=e186]
                  - generic [ref=e189]:
                    - generic [ref=e190]:
                      - generic [ref=e191]: النوع*
                      - textbox "النوع" [ref=e193]: Samsung
                    - generic [ref=e194]:
                      - generic [ref=e195]: الموديل*
                      - textbox "الموديل" [ref=e197]:
                        - /placeholder: A54، 13 Pro...
                        - text: Galaxy A54
                    - generic [ref=e198]:
                      - generic [ref=e199]: اللون
                      - textbox "اللون" [ref=e201]
                  - generic [ref=e202]:
                    - generic [ref=e203]:
                      - generic [ref=e204]:
                        - generic [ref=e205]: IMEI
                        - generic [ref=e206]: صحيح
                      - textbox "IMEI" [ref=e210]:
                        - /placeholder: "*#06#"
                        - text: "490154203237518"
                      - paragraph [ref=e211]: اطلب *#06# من الجهاز
                    - generic [ref=e212]:
                      - generic [ref=e213]: قفل الجهاز
                      - generic [ref=e218]:
                        - radiogroup "نوع القفل" [ref=e219]:
                          - radio "بدون" [ref=e220]
                          - radio "رقم" [ref=e221]
                          - radio "نمط" [checked] [ref=e222]
                        - textbox "قفل الجهاز" [ref=e225]:
                          - /placeholder: 1-5-9-6
                          - text: 1-5-9-6
                      - paragraph [ref=e226]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e227]:
                    - generic [ref=e228]: الملحقات المستلمة
                    - generic [ref=e229]:
                      - button "شريحة" [pressed] [ref=e230]
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
                    - definition [ref=e407]: أحمد علي
                  - generic [ref=e408]:
                    - term [ref=e409]: رقم الموبايل (واتساب)
                    - definition [ref=e410]: "01012345678"
                  - generic [ref=e411]:
                    - term [ref=e412]: الجهاز
                    - definition [ref=e413]: Samsung Galaxy A54
                  - generic [ref=e414]:
                    - term [ref=e415]: IMEI
                    - definition [ref=e416]: "490154203237518"
                  - generic [ref=e417]:
                    - term [ref=e418]: الملحقات المستلمة
                    - definition [ref=e419]: شريحة
                  - generic [ref=e420]:
                    - term [ref=e421]: قفل
                    - definition [ref=e422]: نمط
                  - generic [ref=e423]:
                    - term [ref=e424]: صور الجهاز
                    - definition [ref=e425]: 0 من 6
                - generic [ref=e426]:
                  - generic [ref=e427]: التكلفة التقديرية
                  - generic [ref=e428]: — ج.م
                - generic [ref=e429]:
                  - button "حفظ الاستلام" [ref=e430]
                  - button "إلغاء" [ref=e431]
  - status [ref=e432]:
    - generic [ref=e437]:
      - generic [ref=e438]: المحل جاهز
      - generic [ref=e439]: كل حاجة اتظبطت. يلا نبدأ.
    - button "إغلاق" [ref=e440]
```

# Test source

```ts
  1   | import { expect, test } from '@playwright/test';
  2   | import { activateInvite, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';
  3   | 
  4   | test('المرحلة 1: تسجيل ← استلام ← فني ← حالات ← تسليم ← طباعة ← بحث', async ({ page, browser }, info) => {
  5   |   test.setTimeout(180_000);
  6   |   const mobile = info.project.name.startsWith('mobile');
  7   |   await prefs(page, info);
  8   |   await registerShop(page, uniq('owner'));
  9   |   await noHorizontalScroll(page);
  10  | 
  11  |   // الاستلام (رقم بالأرقام العربية، وقفل، وصور، وتكلفة)
  12  |   await page.goto('/#/intake');
  13  |   await page.locator('#intake-phone').fill('٠١٠١٢٣٤٥٦٧٨');
  14  |   await page.getByLabel('اسم العميل').fill('أحمد علي');
  15  |   await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  16  |   await page.getByLabel('الموديل').fill('Galaxy A54');
  17  |   await page.locator('input[placeholder="*#06#"]').fill('490154203237518');
  18  |   await page.getByRole('radio', { name: 'نمط' }).click();
  19  |   await page.locator('input[placeholder="1-5-9-6"]').fill('1-5-9-6');
  20  |   await page.getByRole('button', { name: 'شريحة', exact: true }).click();
  21  |   await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
> 22  |   await page.locator('input[placeholder="0"]').fill('1250.5');
      |                                                ^ Error: locator.fill: Error: strict mode violation: locator('input[placeholder="0"]') resolved to 2 elements:
  23  |   await page.locator('input[type=file]').setInputFiles(['public/icon-192.png']);
  24  |   // حفظ فاضي الأول؟ لأ: كل الحقول المطلوبة متملية
  25  |   await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  26  |   await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  27  |   const year = new Date().getFullYear();
  28  |   await expect(page.getByText(`${year}-0001`)).toBeVisible();
  29  |   await noHorizontalScroll(page);
  30  |   await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  31  |   await expect(page.getByText('Galaxy A54').first()).toBeVisible();
  32  |   const deviceUrl = page.url();
  33  | 
  34  |   // دعوة فني، وهو بيفعّل حسابه ويفتح الجهاز
  35  |   await page.goto('/#/users');
  36  |   const techEmail = uniq('tech');
  37  |   await page.getByLabel('الاسم').fill('كريم');
  38  |   await page.getByLabel('الإيميل').fill(techEmail);
  39  |   await page.getByLabel('الدور').selectOption('technician');
  40  |   await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  41  |   await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  42  |   const tech = await activateInvite(browser, info, techEmail);
  43  |   await tech.page.goto(deviceUrl.replace(/^.*#/, '/#'));
  44  |   await expect(tech.page.getByText('Galaxy A54').first()).toBeVisible();
  45  |   await expect(tech.page.getByText('التكلفة التقديرية')).toHaveCount(0); // الفني ما يشوفش أسعار
  46  |   await expect(tech.page.getByText('أحمد علي')).toHaveCount(0); // ولا بيانات العميل
  47  |   await tech.page.getByRole('button', { name: 'عرض القفل' }).click();
  48  |   await expect(tech.page.getByText('1-5-9-6')).toBeVisible();
  49  |   await tech.page.getByRole('button', { name: 'جاري الفحص' }).click();
  50  |   await expect(tech.page.getByText('الحالة اتغيّرت').first()).toBeVisible();
  51  |   await expect(tech.page.getByRole('link', { name: 'سجل النشاط' })).toHaveCount(0);
  52  |   await tech.ctx.close();
  53  | 
  54  |   // صاحب المحل: الحالات والتسليم
  55  |   await page.goto(deviceUrl.replace(/^.*#/, '/#'));
  56  |   for (const s of ['جاري الصيانة', 'تم الإصلاح', 'جاهز للاستلام']) {
  57  |     await page.getByRole('button', { name: s, exact: true }).click();
  58  |     await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  59  |   }
  60  |   await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  61  |   await page.getByRole('button', { name: 'تأكيد' }).click();
  62  |   await expect(page.getByText('لازم تكتب التكلفة النهائية قبل التسليم')).toBeVisible();
  63  |   await page.getByLabel('التكلفة النهائية').fill('1,400.75');
  64  |   await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  65  |   await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  66  |   // المرحلة 3: التسليم قبل السداد ممنوع، والدفعة بتتسجل من فلوس الجهاز
  67  |   await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  68  |   await page.getByRole('button', { name: 'تأكيد' }).click();
  69  |   await expect(page.getByText('لازم الجهاز يتدفع بالكامل قبل التسليم').first()).toBeVisible();
  70  |   await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  71  |   await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  72  |   await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  73  |   await expect(page.getByTestId('device-due')).toHaveText('0');
  74  |   await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  75  |   await page.getByRole('button', { name: 'تأكيد' }).click();
  76  |   await expect(page.getByText('القفل اتمسح بعد التسليم.')).toBeVisible();
  77  | 
  78  |   // لوحة التحكم: إيراد اليوم
  79  |   await page.goto('/#/');
  80  |   await expect(page.locator('a, div').filter({ hasText: 'إيراد اليوم' }).getByText('1,400.75').first()).toBeVisible();
  81  |   await noHorizontalScroll(page);
  82  | 
  83  |   // الطباعة: إيصال فيه الشروط ورقم الطلب
  84  |   await page.goto(deviceUrl.replace(/^.*#/, '/#').replace('/devices/', '/print/receipt/'));
  85  |   await expect(page.getByText('إيصال استلام جهاز')).toBeVisible();
  86  |   await expect(page.getByText(`${year}-0001`)).toBeVisible();
  87  |   await expect(page.getByText('شروط الاستلام')).toBeVisible();
  88  | 
  89  |   // البحث في القائمة
  90  |   await page.goto('/#/devices');
  91  |   await page.getByRole('textbox', { name: 'بحث' }).fill(`${year}-0001`);
  92  |   // الجدول (كمبيوتر) والكروت (موبايل) الاتنين في الصفحة، وواحد بس ظاهر
  93  |   await expect(page.getByText('Galaxy A54').filter({ visible: true }).first()).toBeVisible();
  94  |   if (!mobile) await expect(page.locator('tbody tr')).toHaveCount(1);
  95  |   await noHorizontalScroll(page);
  96  | 
  97  |   // سجل النشاط فيه مشاهدة القفل وتعديل التكلفة
  98  |   await page.goto('/#/audit');
  99  |   await expect(page.getByText('عرض القفل').first()).toBeVisible();
  100 |   await expect(page.getByText('التكلفة النهائية').first()).toBeVisible();
  101 | });
  102 | 
```