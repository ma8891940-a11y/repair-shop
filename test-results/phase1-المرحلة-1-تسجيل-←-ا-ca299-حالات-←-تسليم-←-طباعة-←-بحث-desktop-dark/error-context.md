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
                      - text: "01012345678"
                  - generic [ref=e146]:
                    - generic [ref=e147]:
                      - generic [ref=e148]:
                        - generic [ref=e149]: اسم العميل*
                        - generic [ref=e150]: عميل جديد
                      - textbox "اسم العميل" [ref=e151]: أحمد علي
                    - generic [ref=e152]:
                      - generic [ref=e153]: المنطقة
                      - textbox "المنطقة" [ref=e155]
              - generic [ref=e156]:
                - generic [ref=e158]:
                  - generic [ref=e159]: "02"
                  - heading "الجهاز" [level=2] [ref=e160]
                - generic [ref=e161]:
                  - group "اختيار سريع للنوع" [ref=e162]:
                    - button "Samsung" [pressed] [ref=e163]
                    - button "iPhone" [ref=e166]
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
                      - textbox "النوع" [ref=e197]: Samsung
                    - generic [ref=e198]:
                      - generic [ref=e199]: الموديل*
                      - textbox "الموديل" [ref=e201]:
                        - /placeholder: A54، 13 Pro...
                        - text: Galaxy A54
                    - generic [ref=e202]:
                      - generic [ref=e203]: اللون
                      - textbox "اللون" [ref=e205]
                  - generic [ref=e206]:
                    - generic [ref=e207]:
                      - generic [ref=e208]:
                        - generic [ref=e209]: IMEI
                        - generic [ref=e210]: صحيح
                      - textbox "IMEI" [ref=e214]:
                        - /placeholder: "*#06#"
                        - text: "490154203237518"
                      - paragraph [ref=e215]: اطلب *#06# من الجهاز
                    - generic [ref=e216]:
                      - generic [ref=e217]: قفل الجهاز
                      - generic [ref=e222]:
                        - radiogroup "نوع القفل" [ref=e223]:
                          - radio "بدون" [ref=e224]
                          - radio "رقم" [ref=e225]
                          - radio "نمط" [checked] [ref=e226]
                        - textbox "قفل الجهاز" [ref=e229]:
                          - /placeholder: 1-5-9-6
                          - text: 1-5-9-6
                      - paragraph [ref=e230]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e231]:
                    - generic [ref=e232]: الملحقات المستلمة
                    - generic [ref=e233]:
                      - button "شريحة" [pressed] [ref=e234]
                      - button "جراب" [ref=e236]
                      - button "كارت ذاكرة" [ref=e238]
                      - button "شاحن" [ref=e240]
                      - button "سماعة" [ref=e242]
                      - button "علبة" [ref=e244]
              - generic [ref=e246]:
                - generic [ref=e248]:
                  - generic [ref=e249]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e250]
                - generic [ref=e251]:
                  - generic [ref=e252]:
                    - generic [ref=e253]:
                      - generic [ref=e254]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e256]: شاشة مكسورة
                    - generic [ref=e257]:
                      - button "+ شاشة مكسورة" [active] [ref=e258]
                      - button "+ بطارية" [ref=e259]
                      - button "+ مش بيشحن" [ref=e260]
                      - button "+ سوفت وير" [ref=e261]
                      - button "+ دخل مية" [ref=e262]
                      - button "+ السماعة" [ref=e263]
                      - button "+ المايك" [ref=e264]
                      - button "+ الكاميرا" [ref=e265]
                      - button "+ مش بيفتح" [ref=e266]
                  - generic [ref=e267]:
                    - generic [ref=e268]:
                      - generic [ref=e269]: الأولوية
                      - radiogroup "الأولوية" [ref=e270]:
                        - radio "عادي" [checked] [ref=e271]
                        - radio "عاجل" [ref=e272]
                    - generic [ref=e273]:
                      - generic [ref=e274]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e277]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e278]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e279]:
                      - generic [ref=e280]: المدة المتوقعة
                      - generic [ref=e282]:
                        - textbox "المدة المتوقعة" [ref=e283]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e285]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e286]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e287]:
                    - generic [ref=e288]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e290]
                    - paragraph [ref=e291]: خدوش، كسر، انحناء...
                  - generic [ref=e292]:
                    - generic [ref=e293]: التكلفة التقديرية
                    - generic [ref=e295]:
                      - textbox "التكلفة التقديرية" [ref=e296]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e297]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e298]:
                - generic [ref=e299]:
                  - generic [ref=e300]:
                    - generic [ref=e301]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e302]
                  - generic [ref=e303]: اختياري
                - generic [ref=e305]:
                  - generic [ref=e306]:
                    - paragraph [ref=e307]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e308]
                  - list [ref=e312]:
                    - listitem [ref=e313]:
                      - generic [ref=e314]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e315]:
                        - radio "شغال" [ref=e316]
                        - radio "عطلان" [ref=e317]
                        - radio "مش متاح" [ref=e318]
                    - listitem [ref=e319]:
                      - generic [ref=e320]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e321]:
                        - radio "شغال" [ref=e322]
                        - radio "عطلان" [ref=e323]
                        - radio "مش متاح" [ref=e324]
                    - listitem [ref=e325]:
                      - generic [ref=e326]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e327]:
                        - radio "شغال" [ref=e328]
                        - radio "عطلان" [ref=e329]
                        - radio "مش متاح" [ref=e330]
                    - listitem [ref=e331]:
                      - generic [ref=e332]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e333]:
                        - radio "شغال" [ref=e334]
                        - radio "عطلان" [ref=e335]
                        - radio "مش متاح" [ref=e336]
                    - listitem [ref=e337]:
                      - generic [ref=e338]: البصمة
                      - radiogroup "البصمة" [ref=e339]:
                        - radio "شغال" [ref=e340]
                        - radio "عطلان" [ref=e341]
                        - radio "مش متاح" [ref=e342]
                    - listitem [ref=e343]:
                      - generic [ref=e344]: الصوت
                      - radiogroup "الصوت" [ref=e345]:
                        - radio "شغال" [ref=e346]
                        - radio "عطلان" [ref=e347]
                        - radio "مش متاح" [ref=e348]
                    - listitem [ref=e349]:
                      - generic [ref=e350]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e351]:
                        - radio "شغال" [ref=e352]
                        - radio "عطلان" [ref=e353]
                        - radio "مش متاح" [ref=e354]
                    - listitem [ref=e355]:
                      - generic [ref=e356]: الشحن
                      - radiogroup "الشحن" [ref=e357]:
                        - radio "شغال" [ref=e358]
                        - radio "عطلان" [ref=e359]
                        - radio "مش متاح" [ref=e360]
                    - listitem [ref=e361]:
                      - generic [ref=e362]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e363]:
                        - radio "شغال" [ref=e364]
                        - radio "عطلان" [ref=e365]
                        - radio "مش متاح" [ref=e366]
                    - listitem [ref=e367]:
                      - generic [ref=e368]: الشبكة
                      - radiogroup "الشبكة" [ref=e369]:
                        - radio "شغال" [ref=e370]
                        - radio "عطلان" [ref=e371]
                        - radio "مش متاح" [ref=e372]
              - generic [ref=e373]:
                - generic [ref=e374]:
                  - generic [ref=e375]:
                    - generic [ref=e376]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e377]
                  - generic [ref=e378]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e381]
              - generic [ref=e387]:
                - generic [ref=e388]:
                  - generic [ref=e389]:
                    - generic [ref=e390]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e391]
                  - generic [ref=e392]: اختياري
                - generic [ref=e393]:
                  - paragraph [ref=e394]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e395]:
                    - generic [ref=e396]:
                      - img "مكان التوقيع" [ref=e397]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e398]
            - complementary [ref=e402]:
              - generic [ref=e403]:
                - generic [ref=e404]:
                  - generic [ref=e405]: رقم الطلب
                  - generic [ref=e406]: 2026-····
                  - generic [ref=e407]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e408]:
                  - generic [ref=e409]:
                    - term [ref=e410]: العميل
                    - definition [ref=e411]: أحمد علي
                  - generic [ref=e412]:
                    - term [ref=e413]: رقم الموبايل (واتساب)
                    - definition [ref=e414]: "01012345678"
                  - generic [ref=e415]:
                    - term [ref=e416]: الجهاز
                    - definition [ref=e417]: Samsung Galaxy A54
                  - generic [ref=e418]:
                    - term [ref=e419]: IMEI
                    - definition [ref=e420]: "490154203237518"
                  - generic [ref=e421]:
                    - term [ref=e422]: الملحقات المستلمة
                    - definition [ref=e423]: شريحة
                  - generic [ref=e424]:
                    - term [ref=e425]: قفل
                    - definition [ref=e426]: نمط
                  - generic [ref=e427]:
                    - term [ref=e428]: صور الجهاز
                    - definition [ref=e429]: 0 من 6
                - generic [ref=e430]:
                  - generic [ref=e431]: التكلفة التقديرية
                  - generic [ref=e432]: — ج.م
                - generic [ref=e433]:
                  - button "حفظ الاستلام" [ref=e434]
                  - button "إلغاء" [ref=e435]
  - status [ref=e436]:
    - generic [ref=e441]:
      - generic [ref=e442]: المحل جاهز
      - generic [ref=e443]: كل حاجة اتظبطت. يلا نبدأ.
    - button "إغلاق" [ref=e444]
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