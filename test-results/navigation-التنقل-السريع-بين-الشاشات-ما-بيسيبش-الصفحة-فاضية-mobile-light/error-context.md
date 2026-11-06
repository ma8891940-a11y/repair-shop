# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: navigation.spec.ts >> التنقل السريع بين الشاشات ما بيسيبش الصفحة فاضية
- Location: tests/e2e/navigation.spec.ts:5:1

# Error details

```
Test timeout of 90000ms exceeded.
```

```
Error: locator.click: Test timeout of 90000ms exceeded.
Call log:
  - waiting for getByRole('link', { name: 'الفريق' }).visible().first()

```

# Page snapshot

```yaml
- generic [ref=f2e3]:
  - generic [ref=f2e4]:
    - banner [ref=f2e5]:
      - button "بحث" [ref=f2e12]:
        - generic [ref=f2e16]: رقم الطلب، الموبايل، الاسم، IMEI
      - generic [ref=f2e22]:
        - button "Switch to English" [ref=f2e23]:
          - generic [ref=f2e28]: EN
        - button "الوضع الداكن" [ref=f2e29]
    - main [ref=f2e33]:
      - generic [ref=f2e35]:
        - generic [ref=f2e36]:
          - generic [ref=f2e37]:
            - heading "الأجهزة" [level=1] [ref=f2e38]
            - generic [ref=f2e39]: كل الأجهزة في المحل. دوس على أي جهاز عشان تفتحه.
          - button "استلام جهاز" [ref=f2e41]
        - generic [ref=f2e46]:
          - generic [ref=f2e47]:
            - textbox "بحث" [active] [ref=f2e49]:
              - /placeholder: ابحث برقم الطلب أو الموبايل أو الاسم أو IMEI
            - button "اليوم" [ref=f2e50]
            - button "تحت الصيانة" [ref=f2e51]
            - button "المتأخرة" [ref=f2e52]
          - tablist "الحالة" [ref=f2e53]:
            - tab "الكل 0" [selected] [ref=f2e54]:
              - generic [ref=f2e56]: الكل
              - generic [ref=f2e57]: "0"
            - tab "تم الاستلام 0" [ref=f2e58]:
              - generic [ref=f2e60]: تم الاستلام
              - generic [ref=f2e61]: "0"
            - tab "جاري الفحص 0" [ref=f2e62]:
              - generic [ref=f2e64]: جاري الفحص
              - generic [ref=f2e65]: "0"
            - tab "في انتظار موافقة العميل 0" [ref=f2e66]:
              - generic [ref=f2e68]: في انتظار موافقة العميل
              - generic [ref=f2e69]: "0"
            - tab "في انتظار قطعة غيار 0" [ref=f2e70]:
              - generic [ref=f2e72]: في انتظار قطعة غيار
              - generic [ref=f2e73]: "0"
            - tab "جاري الصيانة 0" [ref=f2e74]:
              - generic [ref=f2e76]: جاري الصيانة
              - generic [ref=f2e77]: "0"
            - tab "تم الإصلاح 0" [ref=f2e78]:
              - generic [ref=f2e80]: تم الإصلاح
              - generic [ref=f2e81]: "0"
            - tab "جاهز للاستلام 0" [ref=f2e82]:
              - generic [ref=f2e84]: جاهز للاستلام
              - generic [ref=f2e85]: "0"
            - tab "تم التسليم 0" [ref=f2e86]:
              - generic [ref=f2e88]: تم التسليم
              - generic [ref=f2e89]: "0"
            - tab "مرتجع (ضمان) 0" [ref=f2e90]:
              - generic [ref=f2e92]: مرتجع (ضمان)
              - generic [ref=f2e93]: "0"
            - tab "لم يُصلَّح 0" [ref=f2e94]:
              - generic [ref=f2e96]: لم يُصلَّح
              - generic [ref=f2e97]: "0"
        - generic [ref=f2e99]:
          - generic [ref=f2e103]: لسه مفيش أجهزة
          - paragraph [ref=f2e104]: استلم أول جهاز وهيظهر هنا.
          - button "استلام جهاز" [ref=f2e106]
  - navigation "القائمة الرئيسية" [ref=f2e107]:
    - link "لوحة التحكم" [ref=f2e108] [cursor=pointer]:
      - /url: "#/"
    - link "الأجهزة" [ref=f2e112] [cursor=pointer]:
      - /url: "#/devices"
    - link "استلام جهاز" [ref=f2e116] [cursor=pointer]:
      - /url: "#/intake"
    - link "العملاء" [ref=f2e121] [cursor=pointer]:
      - /url: "#/customers"
    - button "خروج" [ref=f2e126]
```

# Test source

```ts
  1  | import { expect, test } from '@playwright/test';
  2  | import { prefs, registerShop, uniq } from './helpers';
  3  | 
  4  | // خطأ اتصلح: التنقل السريع بين الشاشات (قبل ما حركة الشاشة اللي قبلها تخلص) كان ممكن يسيب الصفحة فاضية
  5  | test('التنقل السريع بين الشاشات ما بيسيبش الصفحة فاضية', async ({ page }, info) => {
  6  |   await prefs(page, info);
  7  |   await registerShop(page, uniq('nav'));
  8  |   for (const [path, label] of [
  9  |     ['/#/users', 'الاسم'],
  10 |     ['/#/devices', 'بحث'],
  11 |     ['/#/users', 'الاسم'],
  12 |     ['/#/settings', null],
  13 |     ['/#/users', 'الاسم'],
  14 |   ] as const) {
  15 |     await page.goto(path);
  16 |     if (label) await expect(page.getByLabel(label).first()).toBeVisible();
  17 |   }
  18 |   // ضغط متتالي سريع على القائمة
> 19 |   for (const n of ['الأجهزة', 'الفريق', 'العملاء', 'الفريق']) await page.getByRole('link', { name: n }).filter({ visible: true }).first().click();
     |                                                                                                                                           ^ Error: locator.click: Test timeout of 90000ms exceeded.
  20 |   await expect(page.getByLabel('الاسم')).toBeVisible();
  21 | });
  22 | 
```