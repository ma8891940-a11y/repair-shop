import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { afterSplash, fillAmount, fillField, prefs, quickIntake, registerShop, uniq } from './helpers';

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

// U5 (مهمة 6أ): سند قبض (دفعة عميل) وسند صرف (مصروف) من شاشة القيد، والمبلغ نفس القيد بالظبط، والقالب من المصمم
test('السندات: سند قبض لدفعة العميل وسند صرف للمصروف بنفس المبلغ ← إخفاء "الخزنة" من المصمم ← رجّع الافتراضي', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('voucher');
  await registerShop(page, email, 'محل السندات');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل السند');
  await page.getByLabel('التكلفة النهائية').fill('700');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '250.50');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  await page.goto('/#/finance');
  await afterSplash(page);
  await op(page, 'إضافة رأس مال', { amount: '5000', selects: { الخزنة: 'كاش الدرج' } });
  await op(page, 'مصروف', { amount: '1500.25', selects: { 'بند المصروف': 'إيجار', الخزنة: 'كاش الدرج' }, note: 'إيجار مارس' });

  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const entry = async (src: string) =>
    (await db.query(`select e.id from journal_entries e join profiles p on p.shop_id = e.shop_id where p.email = $1 and e.source_type = $2 order by e.created_at desc limit 1`, [email, src])).rows[0].id as string;
  const payE = await entry('payment');
  const expE = await entry('expense');
  await db.end();

  // سند القبض: من شاشة القيد
  await page.goto(`/#/finance/entry/${payE}`);
  await afterSplash(page);
  await page.getByTestId('entry-voucher').click();
  const v = page.getByTestId('print-voucher');
  await expect(v).toHaveAttribute('data-kind', 'receipt');
  await expect(page.getByTestId('shop-header-color')).toContainText('سند قبض');
  await expect(v.getByTestId('voucher-amount')).toContainText('250.50');
  await expect(v.getByTestId('voucher-party')).toHaveText('عميل السند');
  await expect(v.getByTestId('voucher-cashbox')).toBeVisible();

  // سند الصرف: المصروف بالقروش، والبيان
  await page.goto(`/#/print/voucher/${expE}?preview=0`);
  await expect(page.getByTestId('print-voucher')).toHaveAttribute('data-kind', 'payment');
  await expect(page.getByTestId('shop-header-color')).toContainText('سند صرف');
  await expect(page.getByTestId('voucher-amount')).toContainText('1,500.25');
  await expect(page.getByTestId('print-voucher')).toContainText('إيجار مارس');

  // المصمم: إخفاء "الخزنة" من السند ← السند من غيرها، والمبلغ زي ما هو
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  const d = page.getByTestId('print-designer');
  await d.getByTestId('tpl-doc').selectOption('voucher');
  await d.locator('[data-testid="tpl-block"][data-key="cashbox"]').getByTestId('tpl-toggle').click();
  await expect(d.getByTestId('tpl-preview')).toBeVisible();
  await d.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظ القالب')).toBeVisible();
  await page.goto(`/#/print/voucher/${expE}?preview=0`);
  await expect(page.getByTestId('print-voucher')).toBeVisible();
  await expect(page.getByTestId('voucher-cashbox')).toHaveCount(0);
  await expect(page.getByTestId('voucher-amount')).toContainText('1,500.25');

  // رجّع الافتراضي (المحفوظ في قاعدة البيانات)
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('print-designer').getByTestId('tpl-doc').selectOption('voucher');
  await page.getByTestId('print-designer').getByTestId('tpl-reset').click();
  await expect(page.getByText('رجع القالب الافتراضي')).toBeVisible();
  await page.goto(`/#/print/voucher/${expE}?preview=0`);
  await expect(page.getByTestId('voucher-cashbox')).toBeVisible();
  await expect(page.getByTestId('voucher-cancelled')).toHaveCount(0);

  // المصروف اتلغى بقيد عكسي: زرار السند اختفى، والرابط القديم بيطبع "ملغي" برقم القيد العكسي
  await page.goto(`/#/finance/entry/${expE}`);
  await afterSplash(page);
  await page.getByTestId('entry-cancel').click();
  await fillField(page.getByRole('dialog').getByRole('textbox'), 'غلط في المبلغ');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل القيد العكسي' }).click();
  await expect(page.getByTestId('entry-voucher')).toHaveCount(0);
  await page.goto(`/#/print/voucher/${expE}?preview=0`);
  await expect(page.getByTestId('print-voucher')).toHaveAttribute('data-cancelled', 'true');
  await expect(page.getByTestId('voucher-cancelled')).toContainText('ملغي');
  await expect(page.getByTestId('voucher-amount')).toContainText('1,500.25');
});
