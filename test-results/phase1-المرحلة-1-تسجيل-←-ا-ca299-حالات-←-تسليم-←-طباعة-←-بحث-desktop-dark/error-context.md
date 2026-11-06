# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase1.spec.ts >> المرحلة 1: تسجيل ← استلام ← فني ← حالات ← تسليم ← طباعة ← بحث
- Location: tests/e2e/phase1.spec.ts:4:1

# Error details

```
Test timeout of 180000ms exceeded.
```

```
Error: locator.fill: Test timeout of 180000ms exceeded.
Call log:
  - waiting for locator('#intake-phone')

```

# Page snapshot

```yaml
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
      - link "الفريق" [ref=e56] [cursor=pointer]:
        - /url: "#/users"
      - link "سجل النشاط" [ref=e63] [cursor=pointer]:
        - /url: "#/audit"
      - link "الإعدادات" [ref=e69] [cursor=pointer]:
        - /url: "#/settings"
    - generic [ref=e74]:
      - generic [ref=e75]:
        - button "الوضع الفاتح" [ref=e76]
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
            - heading "لوحة التحكم" [level=1] [ref=e123]
            - generic [ref=e124]: الجمعة، 6 نوفمبر 2026
          - button "استلام جهاز" [ref=e126]
        - generic [ref=e131]:
          - link "أصناف وصلت للحد الأدنى (النواقص) 0" [ref=e132] [cursor=pointer]:
            - /url: "#/inventory"
            - generic [ref=e135]: أصناف وصلت للحد الأدنى (النواقص)
            - generic [ref=e136]: "0"
          - link "ديون مستحقة على 0 عميل 0 ج.م" [ref=e137] [cursor=pointer]:
            - /url: "#/finance/balances/customers"
            - generic [ref=e144]: ديون مستحقة على 0 عميل
            - generic [ref=e145]: 0 ج.م
        - generic [ref=e146]:
          - 'link "أجهزة اليوم: 0" [ref=e147] [cursor=pointer]':
            - /url: "#/devices?filter=today"
            - generic [ref=e148]:
              - generic [ref=e149]: أجهزة اليوم
              - generic [ref=e155]: "0"
              - generic [ref=e160]: اتسلّمت النهارده
          - 'link "تحت الصيانة: 0" [ref=e164] [cursor=pointer]':
            - /url: "#/devices?filter=under_repair"
            - generic [ref=e165]:
              - generic [ref=e166]: تحت الصيانة
              - generic [ref=e171]: "0"
              - generic [ref=e176]: جوه المحل دلوقتي
          - 'link "جاهزة للاستلام: 0" [ref=e180] [cursor=pointer]':
            - /url: "#/devices?status=ready"
            - generic [ref=e181]:
              - generic [ref=e182]: جاهزة للاستلام
              - generic [ref=e188]: "0"
              - generic [ref=e193]: مستنية العميل
          - 'link "متأخرة: 0" [ref=e197] [cursor=pointer]':
            - /url: "#/devices?filter=late"
            - generic [ref=e198]:
              - generic [ref=e199]: متأخرة
              - generic [ref=e209]: "0"
              - generic [ref=e214]: أكتر من 7 أيام
          - generic [ref=e219]:
            - generic [ref=e220]: إيراد اليوم
            - generic [ref=e226]:
              - generic [ref=e227]: "0"
              - generic [ref=e228]: ج.م
            - generic [ref=e232]: التكلفة النهائية للأجهزة المسلّمة
        - generic [ref=e234]:
          - generic [ref=e235]:
            - generic [ref=e236]:
              - generic [ref=e237]:
                - generic [ref=e238]: "01"
                - heading "توزيع الأجهزة في المحل" [level=2] [ref=e239]
              - generic [ref=e240]: 0 جهاز
            - generic [ref=e242]:
              - generic [ref=e246]: المحل فاضي
              - paragraph [ref=e247]: مفيش أجهزة جوه المحل دلوقتي.
          - generic [ref=e248]:
            - generic [ref=e249]:
              - generic [ref=e250]:
                - generic [ref=e251]: "02"
                - heading "متأخرة — الأقدم الأول" [level=2] [ref=e252]
              - link "عرض الكل" [ref=e253] [cursor=pointer]:
                - /url: "#/devices?filter=late"
            - generic [ref=e254]: مفيش أجهزة متأخرة. كله ماشي في وقته.
        - generic [ref=e259]:
          - generic [ref=e260]:
            - generic [ref=e261]:
              - generic [ref=e262]:
                - generic [ref=e263]: "03"
                - heading "جاهزة ومستنية العميل" [level=2] [ref=e264]
              - link "عرض الكل" [ref=e265] [cursor=pointer]:
                - /url: "#/devices?status=ready"
            - generic [ref=e266]: مفيش أجهزة جاهزة دلوقتي.
          - generic [ref=e270]:
            - generic [ref=e272]:
              - generic [ref=e273]: "04"
              - heading "جاهزة من 10 أيام أو أكتر" [level=2] [ref=e274]
            - generic [ref=e275]: مفيش أجهزة جاهزة من أكتر من 10 أيام.
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
> 13  |   await page.locator('#intake-phone').fill('٠١٠١٢٣٤٥٦٧٨');
      |                                       ^ Error: locator.fill: Test timeout of 180000ms exceeded.
  14  |   await page.getByLabel('اسم العميل').fill('أحمد علي');
  15  |   await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  16  |   await page.getByLabel('الموديل').fill('Galaxy A54');
  17  |   await page.locator('input[placeholder="*#06#"]').fill('490154203237518');
  18  |   await page.getByRole('radio', { name: 'نمط' }).click();
  19  |   await page.locator('input[placeholder="1-5-9-6"]').fill('1-5-9-6');
  20  |   await page.getByRole('button', { name: 'شريحة', exact: true }).click();
  21  |   await page.getByRole('button', { name: '+ شاشة مكسورة' }).click();
  22  |   await page.locator('input[placeholder="0"]').fill('1250.5');
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