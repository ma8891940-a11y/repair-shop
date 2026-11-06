# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: phase3.spec.ts >> المرحلة 3: رأس مال ← مصروف ← تحويل ← الوضع المالي ← كشف الخزنة وExcel ← تقفيل بعجز ← مخزون ← كسر التوازن والتنبيه الأحمر
- Location: tests/e2e/phase3.spec.ts:19:1

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByText('اتسجل البيع')
Expected: visible
Timeout: 10000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" getByText('اتسجل البيع') with timeout 10000ms
  - waiting for getByText('اتسجل البيع')

```

```yaml
- dialog "بيع":
  - heading "بيع" [level=2]
  - paragraph: "بيع على الكاونتر: الفلوس بتدخل الخزنة والصنف بيخرج من المخزون بتكلفته."
  - button "إغلاق"
  - text: الخزنة
  - combobox "الخزنة":
    - option "كاش الدرج" [selected]
    - option "فودافون كاش"
    - option "InstaPay"
    - option "حساب البنك"
    - option "الكارت (POS)"
  - text: باركود
  - textbox "باركود"
  - paragraph: امسح الباركود أو اكتب الكود ودوس Enter
  - group "الأصناف":
    - text: الصنف
    - combobox "الصنف":
      - option "اختار..." [selected]
      - option "جراب سيليكون (10)"
    - text: الكمية
    - textbox "الكمية": "1"
    - text: سعر البيع
    - textbox "سعر البيع":
      - /placeholder: "0"
    - button "شيل السطر"
    - button "سطر تاني"
  - alert: كمّل بيانات كل سطر (الصنف والكمية والسعر)
  - text: "الإجمالي: 0"
  - button "إلغاء"
  - button "سجّل"
```

# Test source

```ts
  2   | import pg from 'pg';
  3   | import { readFileSync } from 'node:fs';
  4   | import { activateInvite, afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';
  5   | 
  6   | const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
  7   | 
  8   | async function op(page: Page, name: string, fill: { amount: string; selects?: Record<string, string>; note?: string }) {
  9   |   await page.getByRole('button', { name, exact: true }).click();
  10  |   const dlg = page.getByRole('dialog');
  11  |   for (const [label, value] of Object.entries(fill.selects ?? {})) await dlg.getByLabel(label).selectOption({ label: value });
  12  |   await dlg.getByLabel('المبلغ').fill(fill.amount);
  13  |   if (fill.note) await dlg.getByLabel('البيان (اختياري)').fill(fill.note);
  14  |   await dlg.getByRole('button', { name: 'سجّل' }).click();
  15  |   await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  16  |   await expect(dlg).toHaveCount(0);
  17  | }
  18  | 
  19  | test('المرحلة 3: رأس مال ← مصروف ← تحويل ← الوضع المالي ← كشف الخزنة وExcel ← تقفيل بعجز ← مخزون ← كسر التوازن والتنبيه الأحمر', async ({ page }, info) => {
  20  |   test.setTimeout(180_000);
  21  |   await prefs(page, info);
  22  |   const email = uniq('owner3');
  23  |   await registerShop(page, email);
  24  | 
  25  |   await page.goto('/#/finance');
  26  |   await afterSplash(page);
  27  |   await expect(page.getByRole('heading', { name: 'الوضع المالي' })).toBeVisible();
  28  |   await expect(page.getByTestId('cashbox-card')).toHaveCount(5); // الخزن الخمسة الأساسية
  29  | 
  30  |   // العمليات (بأرقام عربية ومبالغ فيها قروش)
  31  |   await op(page, 'إضافة رأس مال', { amount: '١٠٠٠٠', selects: { الخزنة: 'كاش الدرج' } });
  32  |   await op(page, 'مصروف', { amount: '1500.25', selects: { 'بند المصروف': 'إيجار', الخزنة: 'كاش الدرج' }, note: 'إيجار مارس' });
  33  |   await op(page, 'تحويل بين خزنتين', { amount: '2000', selects: { 'من خزنة': 'كاش الدرج', 'لخزنة': 'فودافون كاش' } });
  34  | 
  35  |   // الأرقام: الفلوس 8499.75، والربح −1500.25، والدفتر متوازن
  36  |   await expect(page.getByTestId('kpi-cash')).toContainText('8,499.75');
  37  |   await expect(page.getByTestId('kpi-profit')).toContainText('-1,500.25');
  38  |   await expect(page.getByTestId('kpi-net_worth')).toContainText('8,499.75');
  39  |   await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  40  |   await noHorizontalScroll(page);
  41  | 
  42  |   // الربح بيتفتح لتفاصيله
  43  |   await page.getByTestId('kpi-profit').click();
  44  |   await expect(page.getByTestId('pl-profit')).toContainText('-1,500.25');
  45  |   await page.goBack();
  46  | 
  47  |   // كشف خزنة الدرج: 3 حركات والرصيد بعد كل حركة، والبحث، والتصدير
  48  |   await page.getByTestId('cashbox-card').filter({ hasText: 'كاش الدرج' }).click();
  49  |   await expect(page.getByTestId('statement-balance')).toContainText('6,499.75');
  50  |   await expect(page.getByTestId('move-row')).toHaveCount(3);
  51  |   await page.getByLabel('بحث في البيان أو رقم الطلب أو الموظف').fill('مارس');
  52  |   await expect(page.getByTestId('move-row')).toHaveCount(1);
  53  |   await page.getByLabel('بحث في البيان أو رقم الطلب أو الموظف').fill('');
  54  |   const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Excel' }).click()]);
  55  |   const csv = readFileSync(await dl.path(), 'utf8');
  56  |   expect(csv.charCodeAt(0)).toBe(0xfeff);
  57  |   expect(csv).toContain('-1500.25');
  58  |   expect(csv).toContain('6499.75');
  59  | 
  60  |   // تقفيل الدرج: معدود 6490 ← عجز 9.75
  61  |   await page.getByRole('button', { name: 'تقفيل الدرج' }).click();
  62  |   await page.getByRole('dialog').getByLabel('المعدود فعلًا').fill('6490');
  63  |   await page.getByRole('dialog').getByRole('button', { name: 'قفّل الدرج' }).click();
  64  |   await expect(page.getByTestId('drawer-result')).toContainText('-9.75');
  65  |   await page.getByRole('dialog').getByRole('button', { name: 'إغلاق' }).last().click();
  66  |   await expect(page.getByTestId('statement-balance')).toContainText('6,490');
  67  | 
  68  |   // تصحيح بقيد عكسي: المصروف بيرجع
  69  |   await page.getByTestId('move-row').filter({ hasText: 'إيجار مارس' }).getByRole('button', { name: 'تصحيح بقيد عكسي' }).click();
  70  |   await page.getByRole('dialog').getByLabel('السبب').fill('اتسجل بالغلط');
  71  |   await page.getByRole('dialog').getByRole('button', { name: 'سجّل القيد العكسي' }).click();
  72  |   await expect(page.getByText('اتسجل القيد العكسي')).toBeVisible();
  73  |   await expect(page.getByTestId('statement-balance')).toContainText('7,990.25');
  74  |   await noHorizontalScroll(page);
  75  | 
  76  |   // المخزون: صنف، وشراء آجل، وبيع نقدي
  77  |   await page.goto('/#/inventory');
  78  |   await page.getByRole('button', { name: 'صنف جديد' }).click();
  79  |   await page.getByRole('dialog').getByLabel('الصنف').fill('جراب سيليكون');
  80  |   await page.getByRole('dialog').getByLabel('النوع').selectOption('accessory');
  81  |   await page.getByRole('dialog').getByLabel('سعر البيع').fill('75');
  82  |   await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  83  |   await expect(page.getByText('اتضاف الصنف')).toBeVisible();
  84  |   await page.getByRole('tab', { name: 'الموردين' }).click();
  85  |   await page.getByRole('button', { name: 'مورد جديد' }).click();
  86  |   await page.getByRole('dialog').getByLabel('اسم المورد').fill('مورد الإكسسوارات');
  87  |   await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  88  |   await expect(page.getByText('اتضاف المورد')).toBeVisible();
  89  |   await page.getByRole('tab', { name: 'الأصناف' }).click();
  90  |   await page.getByRole('button', { name: 'شراء', exact: true }).click();
  91  |   let dlg = page.getByRole('dialog');
  92  |   await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  93  |   await dlg.getByLabel('الكمية').fill('10');
  94  |   await dlg.getByLabel('سعر الوحدة').fill('30');
  95  |   await dlg.getByRole('button', { name: 'سجّل' }).click();
  96  |   await expect(page.getByText('اتسجل الشراء')).toBeVisible();
  97  |   await page.getByRole('button', { name: 'بيع', exact: true }).click();
  98  |   dlg = page.getByRole('dialog');
  99  |   await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  100 |   await dlg.getByLabel('الكمية').fill('2');
  101 |   await dlg.getByRole('button', { name: 'سجّل' }).click();
> 102 |   await expect(page.getByText('اتسجل البيع')).toBeVisible();
      |                                               ^ Error: expect(locator).toBeVisible() failed
  103 |   // البيع النقدي دخل كاش الدرج (الخزنة الأولى)، مش أي خزنة تانية
  104 |   await expect(page.getByTestId('item-row')).toContainText('8');
  105 |   await page.goto('/#/finance');
  106 |   await expect(page.getByTestId('kpi-inventory')).toContainText('240');
  107 |   await expect(page.getByTestId('kpi-payables')).toContainText('300');
  108 |   await expect(page.getByTestId('cashbox-card').filter({ hasText: 'كاش الدرج' })).toContainText('8,140.25');
  109 |   await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  110 |   // صور للمراجعة بالعين (بس لو اتطلبت)
  111 |   if (process.env.SHOTS) await page.screenshot({ path: `${process.env.SHOTS}/finance-${info.project.name}.png`, fullPage: true });
  112 | 
  113 |   // كسر التوازن عن قصد (من ورا كل الحماية في قاعدة البيانات) والتنبيه الأحمر لازم يظهر
  114 |   const db = new pg.Client({ connectionString: DB });
  115 |   await db.connect();
  116 |   try {
  117 |     const shop = (await db.query(`select shop_id from profiles where email = $1`, [email])).rows[0].shop_id;
  118 |     const e = (await db.query(`select e.id, l.account_id from journal_entries e join journal_lines l on l.entry_id = e.id where e.shop_id = $1 limit 1`, [shop])).rows[0];
  119 |     await db.query('begin');
  120 |     await db.query('alter table journal_lines disable trigger entry_balanced');
  121 |     await db.query(`insert into journal_lines(shop_id, entry_id, account_id, debit) values ($1, $2, $3, 1)`, [shop, e.id, e.account_id]);
  122 |     await db.query('alter table journal_lines enable trigger entry_balanced');
  123 |     await db.query('commit');
  124 |   } finally {
  125 |     await db.end();
  126 |   }
  127 |   await page.reload();
  128 |   await afterSplash(page);
  129 |   await expect(page.getByTestId('ledger-unbalanced')).toBeVisible();
  130 |   await expect(page.getByText('الدفتر مش متوازن!').first()).toBeInViewport();
  131 |   await expect(page.getByTestId('ledger-balanced')).toHaveCount(0);
  132 |   if (process.env.SHOTS) await page.screenshot({ path: `${process.env.SHOTS}/finance-red-${info.project.name}.png` });
  133 | });
  134 | 
  135 | test('المرحلة 3: الاستقبال ما تشوفش الوضع المالي ولا الأرصدة، وبتقفل الدرج بتاعها بس من غير ما تشوف المتوقع', async ({ page, browser }, info) => {
  136 |   test.setTimeout(150_000);
  137 |   await prefs(page, info);
  138 |   await registerShop(page, uniq('owner3b'));
  139 |   await page.goto('/#/users');
  140 |   const recEmail = uniq('rec3');
  141 |   await page.getByLabel('الاسم').fill('سارة');
  142 |   await page.getByLabel('الإيميل').fill(recEmail);
  143 |   await page.getByLabel('الدور').selectOption('reception');
  144 |   await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  145 |   await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  146 |   const rec = await activateInvite(browser, info, recEmail);
  147 |   // صاحب المحل بيخلّيها مسؤولة عن الدرج
  148 |   await page.goto('/#/settings');
  149 |   await page.getByRole('tab', { name: 'الخزن والمصروفات' }).click();
  150 |   await page.getByLabel('المسؤول كاش الدرج').selectOption({ label: 'سارة' });
  151 |   await expect(page.getByText('اتحفظ').first()).toBeVisible();
  152 | 
  153 |   const r = rec.page;
  154 |   await expect(r.getByRole('link', { name: 'الوضع المالي' })).toHaveCount(0);
  155 |   await r.goto('/#/finance');
  156 |   await expect(r.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible(); // الرابط المباشر بيرجّعها
  157 |   await r.goto('/#/drawer');
  158 |   await expect(r.getByTestId('drawer-card')).toHaveCount(1);
  159 |   await expect(r.getByTestId('drawer-card')).not.toContainText('0.00');
  160 |   await r.getByRole('button', { name: 'تقفيل الدرج' }).click();
  161 |   await r.getByRole('dialog').getByLabel('المعدود فعلًا').fill('0');
  162 |   await r.getByRole('dialog').getByRole('button', { name: 'قفّل الدرج' }).click();
  163 |   await expect(r.getByTestId('drawer-result')).toBeVisible();
  164 |   await noHorizontalScroll(r);
  165 |   await rec.ctx.close();
  166 | });
  167 | 
```