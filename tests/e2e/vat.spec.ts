import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, fillField, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** بيع بنفس دوال البرنامج وكأن صاحب المحل هو اللي بيبيع: 2 جراب × 114 جنيه (شامل) */
async function seedSale(email: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const { id: uid, shop_id: shop } = (await db.query(`select id, shop_id from profiles where email = $1`, [email])).rows[0];
    const as = async (sql: string, params: unknown[] = []) => {
      await db.query('begin');
      try {
        await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
        await db.query('set local role authenticated');
        const r = await db.query(sql, params);
        await db.query('commit');
        return r;
      } catch (e) {
        await db.query('rollback');
        throw e;
      }
    };
    const cash = (await db.query(`select id from accounts where shop_id = $1 and kind = 'cash' and method = 'cash' order by created_at limit 1`, [shop])).rows[0].id;
    const acc = randomUUID();
    await as(`insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'خدمة الضريبة', 11400)`, [acc]);
    const entry = (await as(`select record_sale($1, $2::jsonb, $3) e`, [randomUUID(), JSON.stringify([{ item: acc, qty: 2, price: 11400 }]), cash])).rows[0].e as string;
    return { entry };
  } finally {
    await db.end();
  }
}

// R5 وR6: ضريبة القيمة المضافة: الإعداد ← بيع شامل ← الفاتورة بالصافي والضريبة ورقم التسجيل ← المستحقة في الوضع المالي ← السداد
test('ضريبة القيمة المضافة: الإعداد ← الفاتورة بالصافي والضريبة ← المستحق ← السداد', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('vat');
  await registerShop(page, email, 'محل الضريبة');

  // 1) الإعداد: النسبة غلط بتترفض، ومن غير رقم تسجيل بيترفض، وبعدين يتحفظ
  await page.goto('/#/settings?tab=ledger');
  await afterSplash(page);
  const vs = page.getByTestId('vat-settings');
  await vs.getByRole('checkbox', { name: 'المحل مسجّل في ضريبة القيمة المضافة' }).click();
  await fillField(vs.getByTestId('vat-rate'), '45');
  await vs.getByTestId('vat-save').click();
  await expect(vs.getByText('النسبة لازم رقم من 0.01 لـ 30')).toBeVisible();
  await fillField(vs.getByTestId('vat-rate'), '١٤');
  await vs.getByTestId('vat-save').click();
  await expect(vs.getByText('اكتب رقم التسجيل الضريبي')).toBeVisible();
  await fillField(vs.getByTestId('vat-reg'), '100-200-300');
  await vs.getByTestId('vat-save').click();
  await expect(page.getByText('اتحفظت الإعدادات')).toBeVisible();
  await noHorizontalScroll(page);

  // 2) بيع 228 جنيه شامل ← الفاتورة: صافي 200 + ضريبة 28 = 228، ورقم التسجيل
  const { entry } = await seedSale(email);
  await page.goto(`/#/print/sale/${entry}`);
  const inv = page.getByTestId('print-sale');
  await expect(inv.getByTestId('sale-net')).toContainText('200');
  await expect(inv.getByTestId('sale-vat')).toContainText('28');
  await expect(inv.getByTestId('sale-total')).toContainText('228');
  await expect(inv.getByTestId('sale-paid')).toContainText('228');
  await expect(inv.getByTestId('sale-vat-no')).toContainText('100-200-300');

  // 3) الوضع المالي: الضريبة المستحقة 28، والسداد بيصفّرها
  await page.goto('/#/finance');
  await afterSplash(page);
  const due = page.getByTestId('vat-due');
  await expect(due.getByTestId('vat-due-amount')).toContainText('28');
  await due.getByTestId('vat-pay').click();
  const dlg = page.getByRole('dialog');
  await expect(dlg.getByTestId('vat-pay-amount')).toHaveValue('28.00');
  await dlg.getByTestId('vat-pay-save').click();
  await expect(page.getByText('اتسجل سداد الضريبة')).toBeVisible();
  await expect(due.getByTestId('vat-due-amount')).toContainText('0');
  await expect(due.getByTestId('vat-pay')).toHaveCount(0);

  // 4) R6: تقرير الضريبة للفترة: الصافي 200، والضريبة 28، والمدفوع 28، والمستحق 0
  await due.getByTestId('vat-report-link').click();
  const rep = page.getByTestId('vat-report');
  await expect(rep.getByTestId('vat-row-salesNet')).toContainText('200');
  await expect(rep.getByTestId('vat-row-salesVat')).toContainText('28');
  await expect(rep.getByTestId('vat-row-collected')).toContainText('28');
  await expect(rep.getByTestId('vat-row-paid')).toContainText('-28');
  // المبلغ نفسه (مش أي رقم فيه صفر)
  await expect(rep.getByTestId('vat-val-reversed')).toHaveText(/^-?0(\.00)?\s/);
  await expect(rep.getByTestId('vat-val-due')).toHaveText(/^0(\.00)?\s/);
  await expect(rep).toContainText('النسبة الحالية 14%');
  await noHorizontalScroll(page);
});
