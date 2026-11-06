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
                      - text: "01012345678"
                  - generic [ref=e57]:
                    - generic [ref=e58]:
                      - generic [ref=e59]:
                        - generic [ref=e60]: اسم العميل*
                        - generic [ref=e61]: عميل جديد
                      - textbox "اسم العميل" [ref=e62]: أحمد علي
                    - generic [ref=e63]:
                      - generic [ref=e64]: المنطقة
                      - textbox "المنطقة" [ref=e66]
              - generic [ref=e67]:
                - generic [ref=e69]:
                  - generic [ref=e70]: "02"
                  - heading "الجهاز" [level=2] [ref=e71]
                - generic [ref=e72]:
                  - group "اختيار سريع للنوع" [ref=e73]:
                    - button "Samsung" [pressed] [ref=e74]
                    - button "iPhone" [ref=e77]
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
                      - textbox "النوع" [ref=e108]: Samsung
                    - generic [ref=e109]:
                      - generic [ref=e110]: الموديل*
                      - textbox "الموديل" [ref=e112]:
                        - /placeholder: A54، 13 Pro...
                        - text: Galaxy A54
                    - generic [ref=e113]:
                      - generic [ref=e114]: اللون
                      - textbox "اللون" [ref=e116]
                  - generic [ref=e117]:
                    - generic [ref=e118]:
                      - generic [ref=e119]:
                        - generic [ref=e120]: IMEI
                        - generic [ref=e121]: صحيح
                      - textbox "IMEI" [ref=e125]:
                        - /placeholder: "*#06#"
                        - text: "490154203237518"
                      - paragraph [ref=e126]: اطلب *#06# من الجهاز
                    - generic [ref=e127]:
                      - generic [ref=e128]: قفل الجهاز
                      - generic [ref=e133]:
                        - radiogroup "نوع القفل" [ref=e134]:
                          - radio "بدون" [ref=e135]
                          - radio "رقم" [ref=e136]
                          - radio "نمط" [checked] [ref=e137]
                        - textbox "قفل الجهاز" [ref=e140]:
                          - /placeholder: 1-5-9-6
                          - text: 1-5-9-6
                      - paragraph [ref=e141]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e142]:
                    - generic [ref=e143]: الملحقات المستلمة
                    - generic [ref=e144]:
                      - button "شريحة" [pressed] [ref=e145]
                      - button "جراب" [ref=e147]
                      - button "كارت ذاكرة" [ref=e149]
                      - button "شاحن" [ref=e151]
                      - button "سماعة" [ref=e153]
                      - button "علبة" [ref=e155]
              - generic [ref=e157]:
                - generic [ref=e159]:
                  - generic [ref=e160]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e161]
                - generic [ref=e162]:
                  - generic [ref=e163]:
                    - generic [ref=e164]:
                      - generic [ref=e165]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e167]: شاشة مكسورة
                    - generic [ref=e168]:
                      - button "+ شاشة مكسورة" [active] [ref=e169]
                      - button "+ بطارية" [ref=e170]
                      - button "+ مش بيشحن" [ref=e171]
                      - button "+ سوفت وير" [ref=e172]
                      - button "+ دخل مية" [ref=e173]
                      - button "+ السماعة" [ref=e174]
                      - button "+ المايك" [ref=e175]
                      - button "+ الكاميرا" [ref=e176]
                      - button "+ مش بيفتح" [ref=e177]
                  - generic [ref=e178]:
                    - generic [ref=e179]:
                      - generic [ref=e180]: الأولوية
                      - radiogroup "الأولوية" [ref=e181]:
                        - radio "عادي" [checked] [ref=e182]
                        - radio "عاجل" [ref=e183]
                    - generic [ref=e184]:
                      - generic [ref=e185]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e188]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e189]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e190]:
                      - generic [ref=e191]: المدة المتوقعة
                      - generic [ref=e193]:
                        - textbox "المدة المتوقعة" [ref=e194]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e196]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e197]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e198]:
                    - generic [ref=e199]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e201]
                    - paragraph [ref=e202]: خدوش، كسر، انحناء...
                  - generic [ref=e203]:
                    - generic [ref=e204]: التكلفة التقديرية
                    - generic [ref=e206]:
                      - textbox "التكلفة التقديرية" [ref=e207]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e208]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e209]:
                - generic [ref=e210]:
                  - generic [ref=e211]:
                    - generic [ref=e212]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e213]
                  - generic [ref=e214]: اختياري
                - generic [ref=e216]:
                  - generic [ref=e217]:
                    - paragraph [ref=e218]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e219]
                  - list [ref=e223]:
                    - listitem [ref=e224]:
                      - generic [ref=e225]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e226]:
                        - radio "شغال" [ref=e227]
                        - radio "عطلان" [ref=e228]
                        - radio "مش متاح" [ref=e229]
                    - listitem [ref=e230]:
                      - generic [ref=e231]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e232]:
                        - radio "شغال" [ref=e233]
                        - radio "عطلان" [ref=e234]
                        - radio "مش متاح" [ref=e235]
                    - listitem [ref=e236]:
                      - generic [ref=e237]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e238]:
                        - radio "شغال" [ref=e239]
                        - radio "عطلان" [ref=e240]
                        - radio "مش متاح" [ref=e241]
                    - listitem [ref=e242]:
                      - generic [ref=e243]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e244]:
                        - radio "شغال" [ref=e245]
                        - radio "عطلان" [ref=e246]
                        - radio "مش متاح" [ref=e247]
                    - listitem [ref=e248]:
                      - generic [ref=e249]: البصمة
                      - radiogroup "البصمة" [ref=e250]:
                        - radio "شغال" [ref=e251]
                        - radio "عطلان" [ref=e252]
                        - radio "مش متاح" [ref=e253]
                    - listitem [ref=e254]:
                      - generic [ref=e255]: الصوت
                      - radiogroup "الصوت" [ref=e256]:
                        - radio "شغال" [ref=e257]
                        - radio "عطلان" [ref=e258]
                        - radio "مش متاح" [ref=e259]
                    - listitem [ref=e260]:
                      - generic [ref=e261]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e262]:
                        - radio "شغال" [ref=e263]
                        - radio "عطلان" [ref=e264]
                        - radio "مش متاح" [ref=e265]
                    - listitem [ref=e266]:
                      - generic [ref=e267]: الشحن
                      - radiogroup "الشحن" [ref=e268]:
                        - radio "شغال" [ref=e269]
                        - radio "عطلان" [ref=e270]
                        - radio "مش متاح" [ref=e271]
                    - listitem [ref=e272]:
                      - generic [ref=e273]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e274]:
                        - radio "شغال" [ref=e275]
                        - radio "عطلان" [ref=e276]
                        - radio "مش متاح" [ref=e277]
                    - listitem [ref=e278]:
                      - generic [ref=e279]: الشبكة
                      - radiogroup "الشبكة" [ref=e280]:
                        - radio "شغال" [ref=e281]
                        - radio "عطلان" [ref=e282]
                        - radio "مش متاح" [ref=e283]
              - generic [ref=e284]:
                - generic [ref=e285]:
                  - generic [ref=e286]:
                    - generic [ref=e287]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e288]
                  - generic [ref=e289]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e292]
              - generic [ref=e298]:
                - generic [ref=e299]:
                  - generic [ref=e300]:
                    - generic [ref=e301]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e302]
                  - generic [ref=e303]: اختياري
                - generic [ref=e304]:
                  - paragraph [ref=e305]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e306]:
                    - generic [ref=e307]:
                      - img "مكان التوقيع" [ref=e308]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e309]
            - complementary [ref=e313]:
              - generic [ref=e314]:
                - generic [ref=e315]:
                  - generic [ref=e316]: رقم الطلب
                  - generic [ref=e317]: 2026-····
                  - generic [ref=e318]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e319]:
                  - generic [ref=e320]:
                    - term [ref=e321]: العميل
                    - definition [ref=e322]: أحمد علي
                  - generic [ref=e323]:
                    - term [ref=e324]: رقم الموبايل (واتساب)
                    - definition [ref=e325]: "01012345678"
                  - generic [ref=e326]:
                    - term [ref=e327]: الجهاز
                    - definition [ref=e328]: Samsung Galaxy A54
                  - generic [ref=e329]:
                    - term [ref=e330]: IMEI
                    - definition [ref=e331]: "490154203237518"
                  - generic [ref=e332]:
                    - term [ref=e333]: الملحقات المستلمة
                    - definition [ref=e334]: —
                  - generic [ref=e335]:
                    - term [ref=e336]: قفل
                    - definition [ref=e337]: نمط
                  - generic [ref=e338]:
                    - term [ref=e339]: صور الجهاز
                    - definition [ref=e340]: 0 من 6
                - generic [ref=e341]:
                  - generic [ref=e342]: التكلفة التقديرية
                  - generic [ref=e343]: — ج.م
                - generic [ref=e344]:
                  - button "حفظ الاستلام" [ref=e345]
                  - button "إلغاء" [ref=e346]
    - navigation "القائمة الرئيسية" [ref=e347]:
      - link "لوحة التحكم" [ref=e348] [cursor=pointer]:
        - /url: "#/"
      - link "الأجهزة" [ref=e352] [cursor=pointer]:
        - /url: "#/devices"
      - link "استلام جهاز" [ref=e356] [cursor=pointer]:
        - /url: "#/intake"
      - link "العملاء" [ref=e361] [cursor=pointer]:
        - /url: "#/customers"
      - button "خروج" [ref=e366]
  - status [ref=e370]:
    - generic [ref=e375]:
      - generic [ref=e376]: المحل جاهز
      - generic [ref=e377]: كل حاجة اتظبطت. يلا نبدأ.
    - button "إغلاق" [ref=e378]
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