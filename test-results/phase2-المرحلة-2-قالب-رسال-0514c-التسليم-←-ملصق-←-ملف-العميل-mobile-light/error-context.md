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
                      - text: "01122334455"
                  - generic [ref=e53]:
                    - generic [ref=e54]:
                      - generic [ref=e55]:
                        - generic [ref=e56]: اسم العميل*
                        - generic [ref=e57]: عميل جديد
                      - textbox "اسم العميل" [ref=e58]: سارة محمود
                    - generic [ref=e59]:
                      - generic [ref=e60]: المنطقة
                      - textbox "المنطقة" [ref=e62]
              - generic [ref=e63]:
                - generic [ref=e65]:
                  - generic [ref=e66]: "02"
                  - heading "الجهاز" [level=2] [ref=e67]
                - generic [ref=e68]:
                  - group "اختيار سريع للنوع" [ref=e69]:
                    - button "Samsung" [ref=e70]
                    - button "iPhone" [pressed] [ref=e73]
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
                      - textbox "النوع" [ref=e104]: iPhone
                    - generic [ref=e105]:
                      - generic [ref=e106]: الموديل*
                      - textbox "الموديل" [ref=e108]:
                        - /placeholder: A54، 13 Pro...
                        - text: 12 Pro
                    - generic [ref=e109]:
                      - generic [ref=e110]: اللون
                      - textbox "اللون" [ref=e112]
                  - generic [ref=e113]:
                    - generic [ref=e114]:
                      - generic [ref=e115]: IMEI
                      - textbox "IMEI" [ref=e117]:
                        - /placeholder: "*#06#"
                      - paragraph [ref=e118]: اطلب *#06# من الجهاز
                    - generic [ref=e119]:
                      - generic [ref=e120]: قفل الجهاز
                      - generic [ref=e125]:
                        - radiogroup "نوع القفل" [ref=e126]:
                          - radio "بدون" [checked] [ref=e127]
                          - radio "رقم" [ref=e129]
                          - radio "نمط" [ref=e130]
                        - textbox "قفل الجهاز" [disabled] [ref=e132]:
                          - /placeholder: —
                      - paragraph [ref=e133]: متشفّر. الفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم.
                  - generic [ref=e134]:
                    - generic [ref=e135]: الملحقات المستلمة
                    - generic [ref=e136]:
                      - button "شريحة" [ref=e137]
                      - button "جراب" [ref=e139]
                      - button "كارت ذاكرة" [ref=e141]
                      - button "شاحن" [ref=e143]
                      - button "سماعة" [ref=e145]
                      - button "علبة" [ref=e147]
              - generic [ref=e149]:
                - generic [ref=e151]:
                  - generic [ref=e152]: "03"
                  - heading "العطل والحالة" [level=2] [ref=e153]
                - generic [ref=e154]:
                  - generic [ref=e155]:
                    - generic [ref=e156]:
                      - generic [ref=e157]: العطل زي ما العميل وصفه*
                      - textbox "العطل زي ما العميل وصفه" [ref=e159]: شاشة مكسورة
                    - generic [ref=e160]:
                      - button "+ شاشة مكسورة" [active] [ref=e161]
                      - button "+ بطارية" [ref=e162]
                      - button "+ مش بيشحن" [ref=e163]
                      - button "+ سوفت وير" [ref=e164]
                      - button "+ دخل مية" [ref=e165]
                      - button "+ السماعة" [ref=e166]
                      - button "+ المايك" [ref=e167]
                      - button "+ الكاميرا" [ref=e168]
                      - button "+ مش بيفتح" [ref=e169]
                  - generic [ref=e170]:
                    - generic [ref=e171]:
                      - generic [ref=e172]: الأولوية
                      - radiogroup "الأولوية" [ref=e173]:
                        - radio "عادي" [checked] [ref=e174]
                        - radio "عاجل" [ref=e175]
                    - generic [ref=e176]:
                      - generic [ref=e177]: نوع العطل (المسار)
                      - combobox "نوع العطل (المسار)" [ref=e180]:
                        - option "تغيير شاشة أو بطارية"
                        - option "شحن أو IC أو شبكة"
                        - option "سوفت وير وفلاشة"
                        - option "عطل غير معروف" [selected]
                      - paragraph [ref=e181]: اتحدد من وصف العطل، وتقدر تغيّره
                    - generic [ref=e182]:
                      - generic [ref=e183]: المدة المتوقعة
                      - generic [ref=e185]:
                        - textbox "المدة المتوقعة" [ref=e186]:
                          - /placeholder: "0"
                        - combobox "الوحدة" [ref=e188]:
                          - option "دقيقة"
                          - option "ساعة" [selected]
                          - option "يوم"
                      - paragraph [ref=e189]: مفيش أجهزة مشابهة كفاية (0 من 5)، اكتبها بإيدك
                  - generic [ref=e190]:
                    - generic [ref=e191]: الحالة الشكلية
                    - textbox "الحالة الشكلية" [ref=e193]
                    - paragraph [ref=e194]: خدوش، كسر، انحناء...
                  - generic [ref=e195]:
                    - generic [ref=e196]: التكلفة التقديرية
                    - generic [ref=e198]:
                      - textbox "التكلفة التقديرية" [ref=e199]:
                        - /placeholder: "0"
                      - generic: ج.م
                    - paragraph [ref=e200]: اختياري. تقدر تحدّدها بعد الفحص.
              - generic [ref=e201]:
                - generic [ref=e202]:
                  - generic [ref=e203]:
                    - generic [ref=e204]: "04"
                    - heading "الفحص السريع" [level=2] [ref=e205]
                  - generic [ref=e206]: اختياري
                - generic [ref=e208]:
                  - generic [ref=e209]:
                    - paragraph [ref=e210]: اختار حالة كل بند. لو العميل قال بعدين إن حاجة باظت، المقارنة بتبيّن كانت شغالة ولا لأ.
                    - button "كله شغال" [ref=e211]
                  - list [ref=e215]:
                    - listitem [ref=e216]:
                      - generic [ref=e217]: الواي فاي
                      - radiogroup "الواي فاي" [ref=e218]:
                        - radio "شغال" [ref=e219]
                        - radio "عطلان" [ref=e220]
                        - radio "مش متاح" [ref=e221]
                    - listitem [ref=e222]:
                      - generic [ref=e223]: البلوتوث
                      - radiogroup "البلوتوث" [ref=e224]:
                        - radio "شغال" [ref=e225]
                        - radio "عطلان" [ref=e226]
                        - radio "مش متاح" [ref=e227]
                    - listitem [ref=e228]:
                      - generic [ref=e229]: الكاميرا الأمامية
                      - radiogroup "الكاميرا الأمامية" [ref=e230]:
                        - radio "شغال" [ref=e231]
                        - radio "عطلان" [ref=e232]
                        - radio "مش متاح" [ref=e233]
                    - listitem [ref=e234]:
                      - generic [ref=e235]: الكاميرا الخلفية
                      - radiogroup "الكاميرا الخلفية" [ref=e236]:
                        - radio "شغال" [ref=e237]
                        - radio "عطلان" [ref=e238]
                        - radio "مش متاح" [ref=e239]
                    - listitem [ref=e240]:
                      - generic [ref=e241]: البصمة
                      - radiogroup "البصمة" [ref=e242]:
                        - radio "شغال" [ref=e243]
                        - radio "عطلان" [ref=e244]
                        - radio "مش متاح" [ref=e245]
                    - listitem [ref=e246]:
                      - generic [ref=e247]: الصوت
                      - radiogroup "الصوت" [ref=e248]:
                        - radio "شغال" [ref=e249]
                        - radio "عطلان" [ref=e250]
                        - radio "مش متاح" [ref=e251]
                    - listitem [ref=e252]:
                      - generic [ref=e253]: الميكروفون
                      - radiogroup "الميكروفون" [ref=e254]:
                        - radio "شغال" [ref=e255]
                        - radio "عطلان" [ref=e256]
                        - radio "مش متاح" [ref=e257]
                    - listitem [ref=e258]:
                      - generic [ref=e259]: الشحن
                      - radiogroup "الشحن" [ref=e260]:
                        - radio "شغال" [ref=e261]
                        - radio "عطلان" [ref=e262]
                        - radio "مش متاح" [ref=e263]
                    - listitem [ref=e264]:
                      - generic [ref=e265]: الشاشة واللمس
                      - radiogroup "الشاشة واللمس" [ref=e266]:
                        - radio "شغال" [ref=e267]
                        - radio "عطلان" [ref=e268]
                        - radio "مش متاح" [ref=e269]
                    - listitem [ref=e270]:
                      - generic [ref=e271]: الشبكة
                      - radiogroup "الشبكة" [ref=e272]:
                        - radio "شغال" [ref=e273]
                        - radio "عطلان" [ref=e274]
                        - radio "مش متاح" [ref=e275]
              - generic [ref=e276]:
                - generic [ref=e277]:
                  - generic [ref=e278]:
                    - generic [ref=e279]: "05"
                    - heading "صور الجهاز" [level=2] [ref=e280]
                  - generic [ref=e281]: 0/6
                - button "صوّر الجهاز من كل الجهات، أو اسحب الصور هنا" [ref=e284]
              - generic [ref=e290]:
                - generic [ref=e291]:
                  - generic [ref=e292]:
                    - generic [ref=e293]: "06"
                    - heading "توقيع العميل" [level=2] [ref=e294]
                  - generic [ref=e295]: اختياري
                - generic [ref=e296]:
                  - paragraph [ref=e297]: العميل بيوقّع إنه موافق على حالة الجهاز وشروط الاستلام. التوقيع بيظهر على الإيصال.
                  - generic [ref=e298]:
                    - generic [ref=e299]:
                      - img "مكان التوقيع" [ref=e300]
                      - generic: وقّع هنا بالماوس أو بصباعك
                    - button "امسح التوقيع" [ref=e301]
            - complementary [ref=e305]:
              - generic [ref=e306]:
                - generic [ref=e307]:
                  - generic [ref=e308]: رقم الطلب
                  - generic [ref=e309]: 2026-····
                  - generic [ref=e310]: بيتحدد تلقائيًا عند الحفظ
                - generic [ref=e311]:
                  - generic [ref=e312]:
                    - term [ref=e313]: العميل
                    - definition [ref=e314]: سارة محمود
                  - generic [ref=e315]:
                    - term [ref=e316]: رقم الموبايل (واتساب)
                    - definition [ref=e317]: "01122334455"
                  - generic [ref=e318]:
                    - term [ref=e319]: الجهاز
                    - definition [ref=e320]: iPhone 12 Pro
                  - generic [ref=e321]:
                    - term [ref=e322]: IMEI
                    - definition [ref=e323]: —
                  - generic [ref=e324]:
                    - term [ref=e325]: الملحقات المستلمة
                    - definition [ref=e326]: —
                  - generic [ref=e327]:
                    - term [ref=e328]: قفل
                    - definition [ref=e329]: بدون
                  - generic [ref=e330]:
                    - term [ref=e331]: صور الجهاز
                    - definition [ref=e332]: 0 من 6
                - generic [ref=e333]:
                  - generic [ref=e334]: التكلفة التقديرية
                  - generic [ref=e335]: — ج.م
                - generic [ref=e336]:
                  - button "حفظ الاستلام" [ref=e337]
                  - button "إلغاء" [ref=e338]
    - navigation "القائمة الرئيسية" [ref=e339]:
      - link "لوحة التحكم" [ref=e340] [cursor=pointer]:
        - /url: "#/"
      - link "الأجهزة" [ref=e344] [cursor=pointer]:
        - /url: "#/devices"
      - link "استلام جهاز" [ref=e348] [cursor=pointer]:
        - /url: "#/intake"
      - link "العملاء" [ref=e353] [cursor=pointer]:
        - /url: "#/customers"
      - button "خروج" [ref=e358]
  - generic:
    - status [ref=e362]:
      - generic [ref=e367]:
        - generic [ref=e368]: المحل جاهز
        - generic [ref=e369]: كل حاجة اتظبطت. يلا نبدأ.
      - button "إغلاق" [ref=e370]
    - status [ref=e374]:
      - generic [ref=e379]: اتحفظت الإعدادات
      - button "إغلاق" [ref=e381]
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