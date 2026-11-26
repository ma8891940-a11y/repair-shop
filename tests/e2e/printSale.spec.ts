import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, pickItem, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** بيانات البيع بنفس دوال البرنامج (record_purchase وrecord_sale) وكأن صاحب المحل هو اللي بيعمل */
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
    const sup = randomUUID();
    const part = randomUUID();
    const acc = randomUUID();
    const srv = randomUUID();
    await as(`insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الفاتورة')`, [sup]);
    // سعر الصنف المسجل غير سعر البيع: الفاتورة لازم تطلع بسعر البيع الفعلي
    await as(`insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'part', 'شاشة الفاتورة', 99900), ($2, gen_random_uuid(), 'accessory', 'جراب الفاتورة', 11100), ($3, gen_random_uuid(), 'service', 'تنظيف الفاتورة', 22200)`, [part, acc, srv]);
    await as(`select owner_capital($1, $2, 1000000)`, [randomUUID(), cash]);
    await as(`select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: part, qty: 3, unit_cost: 60000 }, { item: acc, qty: 5, unit_cost: 3000 }]), cash]);
    const lines = [
      { item: part, qty: 2, price: 150000 },
      { item: acc, qty: 1, price: 8050 },
      { item: srv, qty: 1, price: 5000 },
    ];
    const entry = (await as(`select record_sale($1, $2::jsonb, $3, null, 'فاتورة تجربة') e`, [randomUUID(), JSON.stringify(lines), cash])).rows[0].e as string;
    return { entry };
  } finally {
    await db.end();
  }
}

// 6ب: فاتورة البيع: كل صنف بسعره الفعلي، والإجمالي من الدفتر = مجموع السطور، ومن المصمم، ومن رسالة البيع على طول
test('فاتورة البيع: 3 أصناف بأسعارها الفعلية ← الإجمالي = المجموع ← إخفاء "المدفوع" من المصمم ← اطبع من رسالة البيع', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('sale-inv');
  await registerShop(page, email, 'محل الفواتير');
  const { entry } = await seedSale(email);

  // 1) الفاتورة من شاشة القيد
  await page.goto(`/#/finance/entry/${entry}`);
  await afterSplash(page);
  await page.getByTestId('entry-sale-invoice').click();
  const inv = page.getByTestId('print-sale');
  await expect(inv).toHaveAttribute('data-legacy', 'false');
  await expect(page.getByTestId('shop-header-color')).toContainText('فاتورة بيع');
  await expect(inv.getByTestId('sale-line')).toHaveCount(3);
  await expect(inv.getByTestId('sale-line').nth(0)).toContainText('شاشة الفاتورة');
  await expect(inv.getByTestId('sale-line-amount')).toHaveText(['3,000', '80.50', '50']);
  await expect(inv.getByTestId('sale-total')).toContainText('3,130.50');
  await expect(inv.getByTestId('sale-paid')).toContainText('3,130.50');
  await expect(inv.getByTestId('sale-due')).toHaveCount(0);
  await expect(inv).toContainText('فاتورة تجربة');

  // 2) المصمم: إخفاء "المدفوع" ← الفاتورة من غيره، والإجمالي زي ما هو
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  const d = page.getByTestId('print-designer');
  await d.getByTestId('tpl-doc').selectOption('sale');
  await d.locator('[data-testid="tpl-block"][data-key="paid"]').getByTestId('tpl-toggle').click();
  await expect(d.getByTestId('tpl-preview')).toBeVisible();
  await d.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظ القالب')).toBeVisible();
  // 50.4: الفاتورة اللي اتطبعت قبل كده بشكلها الأول (تعديل القالب ما يغيّرش المطبوع)
  await page.goto(`/#/print/sale/${entry}?preview=0`);
  await expect(page.getByTestId('print-sale')).toBeVisible();
  await expect(page.getByTestId('sale-paid')).toContainText('3,130.50');
  await expect(page.getByTestId('sale-total')).toContainText('3,130.50');

  // 3) بيع من شاشة المخزون ← "اطبع الفاتورة" من رسالة البيع على طول
  await page.goto('/#/inventory');
  await afterSplash(page);
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  const dlg = page.getByRole('dialog');
  await pickItem(dlg, 'جراب الفاتورة');
  await dlg.getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجل البيع')).toBeVisible();
  await page.getByRole('button', { name: 'اطبع الفاتورة' }).click();
  await expect(page.getByTestId('print-sale')).toBeVisible();
  await expect(page.getByTestId('sale-line')).toHaveCount(1);
  await expect(page.getByTestId('sale-line')).toContainText('جراب الفاتورة');
  // سعر البيع = سعر الصنف المسجل (111)، والإجمالي من الدفتر نفس المجموع
  await expect(page.getByTestId('sale-line-amount')).toHaveText('111');
  await expect(page.getByTestId('sale-total')).toContainText('111');
  // الفاتورة الجديدة بالقالب الجديد: من غير "المدفوع"
  await expect(page.getByTestId('sale-paid')).toHaveCount(0);
});
