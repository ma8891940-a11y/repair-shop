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
- generic [ref=f1e3]:
  - generic [ref=f1e4]:
    - banner [ref=f1e5]:
      - button "بحث" [ref=f1e12]:
        - generic [ref=f1e16]: رقم الطلب، الموبايل، الاسم، IMEI
      - generic [ref=f1e22]:
        - button "Switch to English" [ref=f1e23]:
          - generic [ref=f1e28]: EN
        - button "الوضع الفاتح" [ref=f1e29]
    - main [ref=f1e37]:
      - generic [ref=f1e39]:
        - generic [ref=f1e40]:
          - generic [ref=f1e41]:
            - heading "الأجهزة" [level=1] [ref=f1e42]
            - generic [ref=f1e43]: كل الأجهزة في المحل. دوس على أي جهاز عشان تفتحه.
          - button "استلام جهاز" [ref=f1e45]
        - generic [ref=f1e50]:
          - generic [ref=f1e51]:
            - textbox "بحث" [active] [ref=f1e53]:
              - /placeholder: ابحث برقم الطلب أو الموبايل أو الاسم أو IMEI
            - button "اليوم" [ref=f1e54]
            - button "تحت الصيانة" [ref=f1e55]
            - button "المتأخرة" [ref=f1e56]
          - tablist "الحالة" [ref=f1e57]:
            - tab "الكل 0" [selected] [ref=f1e58]:
              - generic [ref=f1e60]: الكل
              - generic [ref=f1e61]: "0"
            - tab "تم الاستلام 0" [ref=f1e62]:
              - generic [ref=f1e64]: تم الاستلام
              - generic [ref=f1e65]: "0"
            - tab "جاري الفحص 0" [ref=f1e66]:
              - generic [ref=f1e68]: جاري الفحص
              - generic [ref=f1e69]: "0"
            - tab "في انتظار موافقة العميل 0" [ref=f1e70]:
              - generic [ref=f1e72]: في انتظار موافقة العميل
              - generic [ref=f1e73]: "0"
            - tab "في انتظار قطعة غيار 0" [ref=f1e74]:
              - generic [ref=f1e76]: في انتظار قطعة غيار
              - generic [ref=f1e77]: "0"
            - tab "جاري الصيانة 0" [ref=f1e78]:
              - generic [ref=f1e80]: جاري الصيانة
              - generic [ref=f1e81]: "0"
            - tab "تم الإصلاح 0" [ref=f1e82]:
              - generic [ref=f1e84]: تم الإصلاح
              - generic [ref=f1e85]: "0"
            - tab "جاهز للاستلام 0" [ref=f1e86]:
              - generic [ref=f1e88]: جاهز للاستلام
              - generic [ref=f1e89]: "0"
            - tab "تم التسليم 0" [ref=f1e90]:
              - generic [ref=f1e92]: تم التسليم
              - generic [ref=f1e93]: "0"
            - tab "مرتجع (ضمان) 0" [ref=f1e94]:
              - generic [ref=f1e96]: مرتجع (ضمان)
              - generic [ref=f1e97]: "0"
            - tab "لم يُصلَّح 0" [ref=f1e98]:
              - generic [ref=f1e100]: لم يُصلَّح
              - generic [ref=f1e101]: "0"
        - generic [ref=f1e103]:
          - generic [ref=f1e107]: لسه مفيش أجهزة
          - paragraph [ref=f1e108]: استلم أول جهاز وهيظهر هنا.
          - button "استلام جهاز" [ref=f1e110]
  - navigation "القائمة الرئيسية" [ref=f1e111]:
    - link "لوحة التحكم" [ref=f1e112] [cursor=pointer]:
      - /url: "#/"
    - link "الأجهزة" [ref=f1e116] [cursor=pointer]:
      - /url: "#/devices"
    - link "استلام جهاز" [ref=f1e120] [cursor=pointer]:
      - /url: "#/intake"
    - link "العملاء" [ref=f1e125] [cursor=pointer]:
      - /url: "#/customers"
    - button "خروج" [ref=f1e130]
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