import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { readFileSync } from 'node:fs';
import { activateInvite, afterSplash, noHorizontalScroll, prefs, registerShop, uniq, fillAmount, fillField } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

async function op(page: Page, name: string, fill: { amount: string; selects?: Record<string, string>; note?: string }) {
  await page.getByRole('button', { name, exact: true }).click();
  const dlg = page.getByRole('dialog');
  for (const [label, value] of Object.entries(fill.selects ?? {})) await dlg.getByLabel(label).selectOption({ label: value });
  await fillAmount(dlg, fill.amount);
  if (fill.note) await fillField(dlg.getByLabel('البيان (اختياري)'), fill.note);
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  await expect(dlg).toHaveCount(0);
}

test('المرحلة 3: رأس مال ← مصروف ← تحويل ← الوضع المالي ← كشف الخزنة وExcel ← تقفيل بعجز ← مخزون ← كسر التوازن والتنبيه الأحمر', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('owner3');
  await registerShop(page, email);

  await page.goto('/#/finance');
  await afterSplash(page);
  await expect(page.getByRole('heading', { name: 'الوضع المالي' })).toBeVisible();
  await expect(page.getByTestId('cashbox-card')).toHaveCount(5); // الخزن الخمسة الأساسية

  // العمليات (بأرقام عربية ومبالغ فيها قروش)
  await op(page, 'إضافة رأس مال', { amount: '١٠٠٠٠', selects: { الخزنة: 'كاش الدرج' } });
  await op(page, 'مصروف', { amount: '1500.25', selects: { 'بند المصروف': 'إيجار', الخزنة: 'كاش الدرج' }, note: 'إيجار مارس' });
  await op(page, 'تحويل بين خزنتين', { amount: '2000', selects: { 'من خزنة': 'كاش الدرج', 'لخزنة': 'فودافون كاش' } });

  // الأرقام: الفلوس 8499.75، والربح −1500.25، والدفتر متوازن
  await expect(page.getByTestId('kpi-cash')).toContainText('8,499.75');
  await expect(page.getByTestId('kpi-profit')).toContainText('-1,500.25');
  await expect(page.getByTestId('kpi-net_worth')).toContainText('8,499.75');
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  await noHorizontalScroll(page);

  // الربح بيتفتح لتفاصيله (لوح جانبي، ومنه الصفحة كاملة)
  await page.getByTestId('kpi-profit').click();
  await expect(page.getByTestId('kpi-total')).toContainText('-1,500.25');
  await page.getByTestId('kpi-open-page').click();
  await expect(page.getByTestId('pl-profit')).toContainText('-1,500.25');
  await page.goBack();

  // كشف خزنة الدرج: 3 حركات والرصيد بعد كل حركة، والبحث، والتصدير
  await page.getByTestId('cashbox-card').filter({ hasText: 'كاش الدرج' }).click();
  await expect(page.getByTestId('statement-balance')).toContainText('6,499.75');
  await expect(page.getByTestId('move-row')).toHaveCount(3);
  await page.getByLabel('بحث في البيان أو رقم الطلب أو الموظف').fill('مارس');
  await expect(page.getByTestId('move-row')).toHaveCount(1);
  await page.getByLabel('بحث في البيان أو رقم الطلب أو الموظف').fill('');
  await page.getByTestId('statement-export').click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByTestId('statement-export-csv').click()]);
  const csv = readFileSync(await dl.path(), 'utf8');
  expect(csv.charCodeAt(0)).toBe(0xfeff);
  expect(csv).toContain('-1500.25');
  expect(csv).toContain('6499.75');

  // تقفيل الدرج: معدود 6490 ← عجز 9.75
  await page.getByRole('button', { name: 'تقفيل الدرج' }).click();
  await fillField(page.getByRole('dialog').getByLabel('المعدود فعلًا'), '6490');
  await page.getByRole('dialog').getByRole('button', { name: 'قفّل الدرج' }).click();
  await expect(page.getByTestId('drawer-result')).toContainText('-9.75');
  await page.getByRole('dialog').getByRole('button', { name: 'إغلاق' }).last().click();
  await expect(page.getByTestId('statement-balance')).toContainText('6,490');

  // تصحيح بقيد عكسي: المصروف بيرجع
  await page.getByTestId('move-row').filter({ hasText: 'إيجار مارس' }).getByRole('button', { name: 'تصحيح بقيد عكسي' }).click();
  await fillField(page.getByRole('dialog').getByLabel('السبب'), 'اتسجل بالغلط');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل القيد العكسي' }).click();
  // تراجع لثواني قبل ما يتنفذ، وبعدها الحركة الأصلية بتفضل ظاهرة متشطبة ومكتوب عليها "ملغاة"
  await expect(page.getByTestId('undo-countdown')).toBeVisible();
  await expect(page.getByText('اتسجل القيد العكسي')).toBeVisible();
  await expect(page.getByTestId('statement-balance')).toContainText('7,990.25');
  await expect(page.getByTestId('move-row').filter({ hasText: 'إيجار مارس' }).getByTestId('move-cancelled')).toBeVisible();
  await noHorizontalScroll(page);

  // المخزون: صنف، وشراء آجل، وبيع نقدي
  await page.goto('/#/inventory');
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  await fillField(page.getByRole('dialog').getByLabel('الصنف'), 'جراب سيليكون');
  await page.getByRole('dialog').getByLabel('النوع').selectOption('accessory');
  await fillField(page.getByRole('dialog').getByLabel('سعر البيع'), '75');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف الصنف')).toBeVisible();
  await page.getByRole('tab', { name: 'الموردين' }).click();
  await page.getByRole('button', { name: 'مورد جديد' }).click();
  await fillField(page.getByRole('dialog').getByLabel('اسم المورد'), 'مورد الإكسسوارات');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف المورد')).toBeVisible();
  await page.getByRole('tab', { name: 'الأصناف' }).click();
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  let dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  await fillField(dlg.getByLabel('الكمية'), '10');
  await fillField(dlg.getByLabel('سعر الوحدة'), '30');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل الشراء')).toBeVisible();
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  dlg = page.getByRole('dialog');
  await dlg.getByLabel('الصنف').selectOption({ index: 1 });
  await fillField(dlg.getByLabel('الكمية'), '2');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل البيع')).toBeVisible();
  // البيع النقدي دخل كاش الدرج (الخزنة الأولى)، مش أي خزنة تانية
  await expect(page.getByTestId('item-row')).toContainText('8');
  await page.goto('/#/finance');
  await expect(page.getByTestId('kpi-inventory')).toContainText('240');
  await expect(page.getByTestId('kpi-payables')).toContainText('300');
  await expect(page.getByTestId('cashbox-card').filter({ hasText: 'كاش الدرج' })).toContainText('8,140.25');
  await expect(page.getByTestId('ledger-balanced')).toBeVisible();
  // صور للمراجعة بالعين (بس لو اتطلبت)
  if (process.env.SHOTS) await page.screenshot({ path: `${process.env.SHOTS}/finance-${info.project.name}.png`, fullPage: true });

  // كسر التوازن عن قصد (من ورا كل الحماية في قاعدة البيانات) والتنبيه الأحمر لازم يظهر
  const broken = { id: '', no: '' };
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const shop = (await db.query(`select shop_id from profiles where email = $1`, [email])).rows[0].shop_id;
    const e = (await db.query(`select e.id, e.entry_no, l.account_id from journal_entries e join journal_lines l on l.entry_id = e.id where e.shop_id = $1 limit 1`, [shop])).rows[0];
    broken.id = e.id;
    broken.no = String(e.entry_no);
    await db.query('begin');
    await db.query('alter table journal_lines disable trigger entry_balanced');
    await db.query(`insert into journal_lines(shop_id, entry_id, account_id, debit) values ($1, $2, $3, 1)`, [shop, e.id, e.account_id]);
    await db.query('alter table journal_lines enable trigger entry_balanced');
    await db.query('commit');
  } finally {
    await db.end();
  }
  await page.reload();
  await afterSplash(page);
  await expect(page.getByTestId('ledger-unbalanced')).toBeVisible();
  await expect(page.getByText('الدفتر مش متوازن!').first()).toBeInViewport();
  await expect(page.getByTestId('ledger-balanced')).toHaveCount(0);
  // فحص السلامة: المكان (رقم القيد) والمبلغ بالظبط (قرش واحد)، وزرار بيفتح القيد نفسه
  const issue = page.getByTestId('integrity-issue').first();
  await expect(issue).toContainText(`القيد رقم ${broken.no}`);
  await expect(issue).toContainText('0.01');
  if (process.env.SHOTS) await page.screenshot({ path: `${process.env.SHOTS}/finance-red-${info.project.name}.png` });
  await page.getByTestId('integrity-open').first().click();
  await expect(page).toHaveURL(new RegExp(`#/finance/entry/${broken.id}`));
  await expect(page.getByTestId('entry-balance')).toContainText('مش متوازن');
  await expect(page.getByTestId('entry-balance')).toContainText('0.01');
  // ولوحة التحكم بتنبّه صاحب المحل برضه
  await page.goto('/#/');
  await expect(page.getByTestId('integrity-issue').first()).toContainText(`القيد رقم ${broken.no}`);
});

test('المرحلة 3: الاستقبال ما تشوفش الوضع المالي ولا الأرصدة، وبتقفل الدرج بتاعها بس من غير ما تشوف المتوقع', async ({ page, browser }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  await registerShop(page, uniq('owner3b'));
  await page.goto('/#/users');
  const recEmail = uniq('rec3');
  await page.getByLabel('الاسم').fill('سارة');
  await page.getByLabel('الإيميل').fill(recEmail);
  await page.getByLabel('الدور').selectOption('reception');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const rec = await activateInvite(browser, info, recEmail);
  // صاحب المحل بيخلّيها مسؤولة عن الدرج
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الخزن والمصروفات' }).click();
  await page.getByLabel('المسؤول كاش الدرج').selectOption({ label: 'سارة' });
  await expect(page.getByText('اتحفظ').first()).toBeVisible();

  const r = rec.page;
  await expect(r.getByRole('link', { name: 'الوضع المالي' })).toHaveCount(0);
  await r.goto('/#/finance');
  await expect(r.getByRole('heading', { name: 'لوحة التحكم' })).toBeVisible(); // الرابط المباشر بيرجّعها
  await r.goto('/#/drawer');
  await expect(r.getByTestId('drawer-card')).toHaveCount(1);
  await expect(r.getByTestId('drawer-card')).not.toContainText('0.00');
  await r.getByRole('button', { name: 'تقفيل الدرج' }).click();
  await r.getByRole('dialog').getByLabel('المعدود فعلًا').fill('0');
  await r.getByRole('dialog').getByRole('button', { name: 'قفّل الدرج' }).click();
  await expect(r.getByTestId('drawer-result')).toBeVisible();
  await noHorizontalScroll(r);
  await rec.ctx.close();
});
