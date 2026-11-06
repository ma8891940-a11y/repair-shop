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
          - button "الوضع الداكن" [ref=e29]
      - main [ref=e33]:
        - generic [ref=e35]:
          - generic [ref=e37]:
            - heading "استلام جهاز" [level=1] [ref=e38]
            - generic [ref=e39]: سجّل الجهاز قدام العميل. كل حاجة هنا بتتطبع على الإيصال.
          - generic [ref=e40]:
            - generic [ref=e41]:
              - generic [ref=e42]:
                - generic [ref=e44]:
                  - generic [ref=e45]: "01"
                  - heading "العميل" [level=2] [ref=e46]
                - generic [ref=e47]:
                  - generic [ref=e48]:
                    - generic [ref=e49]: رقم الموبايل (واتساب)*
                    - textbox "رقم الموبايل (واتساب)" [ref=e51]:
                      - /placeholder: 01xxxxxxxxx
                      - text: "01012345678"
                  - generic [ref=e53]:
                    - generic [ref=e54]:
                      - generic [ref=e55]:
                        - generic [ref=e56]: اسم العميل*
                        - generic [ref=e57]: عميل جديد
                      - textbox "اسم العميل" [ref=e58]: أحمد علي
                    - generic [ref=e59]:
                      - generic [ref=e60]: المنطقة
                      - textbox "المنطقة" [ref=e62]
              - generic [ref=e63]:
                - generic [ref=e65]:
                  - generic [ref=e66]: "02"
                  - heading "الجهاز" [level=2] [ref=e67]
                - generic [ref=e68]:
                  - group "اختيار سريع للنوع" [ref=e69]:
                    - button "Samsung" [pressed] [ref=e70]
                    - button "iPhone" [ref=e73]
                    - button "Xiaomi" [ref=e76]
                    - button "Oppo" [ref=e79]
                    - button "Realme" [ref=e82]
                    - button "Infinix" [ref=e85]
                    - button "Vivo" [ref=e88]
                    - button "Honor" [ref=e91]
                    - button "Huawei" [ref=e94]
                    - button "Tecno" [ref=e97]
                  - generic [ref=e100]:
                    - generic [ref=e101]:
                      - generic [ref=e102]: النوع*
                      - textbox "النوع" [ref=e104]: Samsung
                    - generic [ref=e105]:
                      - generic [ref=e106]: الموديل*
                      - textbox "الموديل" [ref=e108]:
                        - /placeholder: A54، 13 Pro...
                        - text: Galaxy A54
                    - generic [ref=e109]:
                      - generic [ref=e110]: اللون
                      - textbox "اللون" [ref=e112]
                  - generic [ref=e113]:
                    - generic [ref=e114]:
                      - generic [ref=e115]:
                        - generic [ref=e116]: IMEI
                        - generic [ref=e117]: صحيح
                      - textbox "IMEI" [ref=e121]:
                        - /placeholder: "*#06#"
                        - text: "490154203237518"
                      - paragraph [ref=e122]: اطلب *#06# من الجهاز
                    - generic [ref=e123]:
                      - generic [ref=e124]: قفل الجهاز
                      - generic [ref=e129]:
                        - radiogroup "نوع القفل" [ref=e130]:
                          - radio "بدون" [ref=e131]
                          - radio "رقم" [ref=e132]
                          - radio "نمط" [checked] [ref=e133]
                        - textbox "قفل الجهاز" [ref=e136]:
                          - /placeholder: 1-5-9-6
                          - text: 1-5-9-6
                      - paragraph [ref=e137]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e138]:
                    - generic [ref=e139]: الملحقات المستلمة
                    - generic [ref=e140]:
                      - button "شريحة" [pressed] [ref=e141]
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
                    - definition [ref=e318]: أحمد علي
                  - generic [ref=e319]:
                    - term [ref=e320]: رقم الموبايل (واتساب)
                    - definition [ref=e321]: "01012345678"
                  - generic [ref=e322]:
                    - term [ref=e323]: الجهاز
                    - definition [ref=e324]: Samsung Galaxy A54
                  - generic [ref=e325]:
                    - term [ref=e326]: IMEI
                    - definition [ref=e327]: "490154203237518"
                  - generic [ref=e328]:
                    - term [ref=e329]: الملحقات المستلمة
                    - definition [ref=e330]: —
                  - generic [ref=e331]:
                    - term [ref=e332]: قفل
                    - definition [ref=e333]: نمط
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
  - status [ref=e366]:
    - generic [ref=e371]:
      - generic [ref=e372]: المحل جاهز
      - generic [ref=e373]: كل حاجة اتظبطت. يلا نبدأ.
    - button "إغلاق" [ref=e374]
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
> 22  |   await page.getByLabel('التكلفة التقديرية').fill('1250.5');
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