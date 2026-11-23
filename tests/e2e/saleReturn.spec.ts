import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, fillField, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// (3) مرتجع بسطر من الفاتورة: رقم بأرقام عربية ← السطر ← كمية زيادة بتترفض ← المبلغ من البيع ← الفاضل بيقل
test('مرتجع من عميل بفاتورة: السطر بسعره، وما يزيدش عن اللي اتباع', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('sale-ret');
  await registerShop(page, email, 'محل المرتجع');
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  let no = 0;
  try {
    const { id: uid, shop_id: shop } = (await db.query(`select id, shop_id from profiles where email = $1`, [email])).rows[0];
    const as = async (sql: string, params: unknown[] = []) => {
      await db.query('begin');
      await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
      await db.query('set local role authenticated');
      const r = await db.query(sql, params);
      await db.query('commit');
      return r;
    };
    const cash = (await db.query(`select id from accounts where shop_id = $1 and kind = 'cash' and method = 'cash' order by created_at limit 1`, [shop])).rows[0].id;
    const [sup, a, b] = [randomUUID(), randomUUID(), randomUUID()];
    await as(`insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد')`, [sup]);
    await as(`insert into items(id, shop_id, kind, name) values ($1, gen_random_uuid(), 'accessory', 'جراب المرتجع'), ($2, gen_random_uuid(), 'accessory', 'شاحن المرتجع')`, [a, b]);
    await as(`select owner_capital($1, $2, 1000000)`, [randomUUID(), cash]);
    await as(`select record_purchase($1, $2, $3::jsonb, $4)`, [randomUUID(), sup, JSON.stringify([{ item: a, qty: 5, unit_cost: 3000 }, { item: b, qty: 5, unit_cost: 5000 }]), cash]);
    const e = (await as(`select record_sale($1, $2::jsonb, $3) e`, [randomUUID(), JSON.stringify([{ item: a, qty: 3, price: 8050 }, { item: b, qty: 1, price: 12000 }]), cash])).rows[0].e;
    no = Number((await db.query(`select entry_no from journal_entries where id = $1`, [e])).rows[0].entry_no);
  } finally {
    await db.end();
  }

  await page.goto('/#/inventory');
  await afterSplash(page);
  const open = async () => {
    await page.getByTestId('op-sale_return').click();
    const dlg = page.getByRole('dialog');
    await fillField(dlg.getByTestId('ret-no'), String(no).replace(/\d/g, (x) => '٠١٢٣٤٥٦٧٨٩'[Number(x)]));
    await dlg.getByTestId('ret-load').click();
    await expect(dlg.getByTestId('ret-line')).toHaveCount(2);
    return dlg;
  };
  let dlg = await open();
  await dlg.getByTestId('ret-line').filter({ hasText: 'جراب المرتجع' }).click();
  await fillField(dlg.getByTestId('ret-qty'), '٤');
  await fillField(dlg.getByLabel('السبب'), 'غيّر رأيه');
  await dlg.getByTestId('invop-submit').click();
  await expect(dlg.getByText('الكمية أكتر من اللي فاضل من السطر ده')).toBeVisible();
  await fillField(dlg.getByTestId('ret-qty'), '2');
  await expect(dlg.getByTestId('ret-total')).toContainText('161');
  await noHorizontalScroll(page);
  await dlg.getByTestId('invop-submit').click();
  await expect(page.getByText('اتسجل المرتجع من العميل')).toBeVisible();
  await expect(page.getByTestId('item-row').filter({ hasText: 'جراب المرتجع' })).toContainText('4');

  dlg = await open();
  await expect(dlg.getByTestId('ret-line').filter({ hasText: 'جراب المرتجع' })).toContainText('فاضل 1 من 3');
  // رقم مش موجود
  await fillField(dlg.getByTestId('ret-no'), '999999999');
  await dlg.getByTestId('ret-load').click();
  await expect(dlg.getByRole('alert')).toBeVisible();
  await expect(dlg.getByTestId('ret-line')).toHaveCount(0);
});
