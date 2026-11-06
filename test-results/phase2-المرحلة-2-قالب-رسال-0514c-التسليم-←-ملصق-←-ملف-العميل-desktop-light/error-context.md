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
    2) <input value="" dir="ltr" id="_r_2r_" placeholder="0" inputmode="decimal" aria-describedby="_r_2r_-desc" class="w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60 h-9 px-3 text-base num ps-12 tex…/> aka getByRole('textbox', { name: 'التكلفة التقديرية' })

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
                      - text: "01122334455"
                  - generic [ref=e142]:
                    - generic [ref=e143]:
                      - generic [ref=e144]:
                        - generic [ref=e145]: اسم العميل*
                        - generic [ref=e146]: عميل جديد
                      - textbox "اسم العميل" [ref=e147]: سارة محمود
                    - generic [ref=e148]:
                      - generic [ref=e149]: المنطقة
                      - textbox "المنطقة" [ref=e151]
              - generic [ref=e152]:
                - generic [ref=e154]:
                  - generic [ref=e155]: "02"
                  - heading "الجهاز" [level=2] [ref=e156]
                - generic [ref=e157]:
                  - group "اختيار سريع للنوع" [ref=e158]:
                    - button "Samsung" [ref=e159]
                    - button "iPhone" [pressed] [ref=e162]
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
                      - textbox "النوع" [ref=e193]: iPhone
                    - generic [ref=e194]:
                      - generic [ref=e195]: الموديل*
                      - textbox "الموديل" [ref=e197]:
                        - /placeholder: A54، 13 Pro...
                        - text: 12 Pro
                    - generic [ref=e198]:
                      - generic [ref=e199]: اللون
                      - textbox "اللون" [ref=e201]
                  - generic [ref=e202]:
                    - generic [ref=e203]:
                      - generic [ref=e204]: IMEI
                      - textbox "IMEI" [ref=e206]:
                        - /placeholder: "*#06#"
                      - paragraph [ref=e207]: اطلب *#06# من الجهاز
                    - generic [ref=e208]:
                      - generic [ref=e209]: قفل الجهاز
                      - generic [ref=e214]:
                        - radiogroup "نوع القفل" [ref=e215]:
                          - radio "بدون" [checked] [ref=e216]
                          - radio "رقم" [ref=e218]
                          - radio "نمط" [ref=e219]
                        - textbox "قفل الجهاز" [disabled] [ref=e221]:
                          - /placeholder: —
                      - paragraph [ref=e222]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e223]:
                    - generic [ref=e224]: الملحقات المستلمة
                    - generic [ref=e225]:
                      - button "شريحة" [ref=e226]
                      - button "جراب" [ref=e228]
                      - button "كارت ذاكرة" [ref=e230]
                      - button "شاحن" [ref=e232]
                      - button "سماعة" [ref=e234]
                      - button "علبة" [ref=e236]
              - generic [ref=e238]:
                - generic [ref=e240]:
                  - generic [ref=e241]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e242]
                - generic [ref=e243]:
                  - generic [ref=e244]:
                    - generic [ref=e245]:
                      - generic [ref=e246]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e248]: شاشة مكسورة
                    - generic [ref=e249]:
                      - button "+ شاشة مكسورة" [active] [ref=e250]
                      - button "+ بطارية" [ref=e251]
                      - button "+ مش بيشحن" [ref=e252]
                      - button "+ سوفت وير" [ref=e253]
                      - button "+ دخل مية" [ref=e254]
                      - button "+ السماعة" [ref=e255]
                      - button "+ المايك" [ref=e256]
                      - button "+ الكاميرا" [ref=e257]
                      - button "+ مش بيفتح" [ref=e258]
                  - generic [ref=e259]:
                    - generic [ref=e260]:
                      - generic [ref=e261]: الأولوية
                      - radiogroup "الأولوية" [ref=e262]:
                        - radio "عادي" [checked] [ref=e263]
                        - radio "عاجل" [ref=e264]
                    - generic [ref=e265]:
                      - generic [ref=e266]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e269]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e270]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e271]:
                      - generic [ref=e272]: المدة المتوقعة
                      - generic [ref=e274]:
                        - textbox "المدة المتوقعة" [ref=e275]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e277]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e278]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e279]:
                    - generic [ref=e280]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e282]
                    - paragraph [ref=e283]: خدوش، كسر، انحناء...
                  - generic [ref=e284]:
                    - generic [ref=e285]: التكلفة التقديرية
                    - generic [ref=e287]:
                      - textbox "التكلفة التقديرية" [ref=e288]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e289]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e290]:
                - generic [ref=e291]:
                  - generic [ref=e292]:
                    - generic [ref=e293]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e294]
                  - generic [ref=e295]: اختياري
                - generic [ref=e297]:
                  - generic [ref=e298]:
                    - paragraph [ref=e299]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e300]
                  - list [ref=e304]:
                    - listitem [ref=e305]:
                      - generic [ref=e306]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e307]:
                        - radio "شغال" [ref=e308]
                        - radio "عطلان" [ref=e309]
                        - radio "مش متاح" [ref=e310]
                    - listitem [ref=e311]:
                      - generic [ref=e312]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e313]:
                        - radio "شغال" [ref=e314]
                        - radio "عطلان" [ref=e315]
                        - radio "مش متاح" [ref=e316]
                    - listitem [ref=e317]:
                      - generic [ref=e318]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e319]:
                        - radio "شغال" [ref=e320]
                        - radio "عطلان" [ref=e321]
                        - radio "مش متاح" [ref=e322]
                    - listitem [ref=e323]:
                      - generic [ref=e324]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e325]:
                        - radio "شغال" [ref=e326]
                        - radio "عطلان" [ref=e327]
                        - radio "مش متاح" [ref=e328]
                    - listitem [ref=e329]:
                      - generic [ref=e330]: البصمة
                      - radiogroup "البصمة" [ref=e331]:
                        - radio "شغال" [ref=e332]
                        - radio "عطلان" [ref=e333]
                        - radio "مش متاح" [ref=e334]
                    - listitem [ref=e335]:
                      - generic [ref=e336]: الصوت
                      - radiogroup "الصوت" [ref=e337]:
                        - radio "شغال" [ref=e338]
                        - radio "عطلان" [ref=e339]
                        - radio "مش متاح" [ref=e340]
                    - listitem [ref=e341]:
                      - generic [ref=e342]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e343]:
                        - radio "شغال" [ref=e344]
                        - radio "عطلان" [ref=e345]
                        - radio "مش متاح" [ref=e346]
                    - listitem [ref=e347]:
                      - generic [ref=e348]: الشحن
                      - radiogroup "الشحن" [ref=e349]:
                        - radio "شغال" [ref=e350]
                        - radio "عطلان" [ref=e351]
                        - radio "مش متاح" [ref=e352]
                    - listitem [ref=e353]:
                      - generic [ref=e354]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e355]:
                        - radio "شغال" [ref=e356]
                        - radio "عطلان" [ref=e357]
                        - radio "مش متاح" [ref=e358]
                    - listitem [ref=e359]:
                      - generic [ref=e360]: الشبكة
                      - radiogroup "الشبكة" [ref=e361]:
                        - radio "شغال" [ref=e362]
                        - radio "عطلان" [ref=e363]
                        - radio "مش متاح" [ref=e364]
              - generic [ref=e365]:
                - generic [ref=e366]:
                  - generic [ref=e367]:
                    - generic [ref=e368]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e369]
                  - generic [ref=e370]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e373]
              - generic [ref=e379]:
                - generic [ref=e380]:
                  - generic [ref=e381]:
                    - generic [ref=e382]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e383]
                  - generic [ref=e384]: اختياري
                - generic [ref=e385]:
                  - paragraph [ref=e386]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e387]:
                    - generic [ref=e388]:
                      - img "مكان التوقيع" [ref=e389]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e390]
            - complementary [ref=e394]:
              - generic [ref=e395]:
                - generic [ref=e396]:
                  - generic [ref=e397]: رقم الطلب
                  - generic [ref=e398]: 2026-····
                  - generic [ref=e399]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e400]:
                  - generic [ref=e401]:
                    - term [ref=e402]: العميل
                    - definition [ref=e403]: سارة محمود
                  - generic [ref=e404]:
                    - term [ref=e405]: رقم الموبايل (واتساب)
                    - definition [ref=e406]: "01122334455"
                  - generic [ref=e407]:
                    - term [ref=e408]: الجهاز
                    - definition [ref=e409]: iPhone 12 Pro
                  - generic [ref=e410]:
                    - term [ref=e411]: IMEI
                    - definition [ref=e412]: —
                  - generic [ref=e413]:
                    - term [ref=e414]: الملحقات المستلمة
                    - definition [ref=e415]: —
                  - generic [ref=e416]:
                    - term [ref=e417]: قفل
                    - definition [ref=e418]: بدون
                  - generic [ref=e419]:
                    - term [ref=e420]: صور الجهاز
                    - definition [ref=e421]: 0 من 6
                - generic [ref=e422]:
                  - generic [ref=e423]: التكلفة التقديرية
                  - generic [ref=e424]: — ج.م
                - generic [ref=e425]:
                  - button "حفظ الاستلام" [ref=e426]
                  - button "إلغاء" [ref=e427]
  - generic:
    - status [ref=e428]:
      - generic [ref=e433]:
        - generic [ref=e434]: المحل جاهز
        - generic [ref=e435]: كل حاجة اتظبطت. يلا نبدأ.
      - button "إغلاق" [ref=e436]
    - status [ref=e440]:
      - generic [ref=e445]: اتحفظت الإعدادات
      - button "إغلاق" [ref=e447]
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