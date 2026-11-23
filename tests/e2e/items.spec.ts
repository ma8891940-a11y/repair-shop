import { expect, test, type Locator, type Page } from '@playwright/test';
import pg from 'pg';
import { afterSplash, fillField, pickItem, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** خانة قايمة ملء سريع: نكتب ونسيبها (Tab) من غير ما نختار حاجة تانية */
async function combo(scope: Locator, testid: string, v: string) {
  const x = scope.getByTestId(testid);
  await fillField(x, v);
  await x.press('Tab');
}

async function money(email: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const shop = (await db.query(`select shop_id from profiles where email = $1`, [email])).rows[0].shop_id;
    const acc = async (code: string) =>
      Number((await db.query(`select coalesce(sum(l.debit - l.credit), 0) b from journal_lines l join accounts a on a.id = l.account_id where a.shop_id = $1 and a.code = $2`, [shop, code])).rows[0].b);
    const moves = (await db.query(`select coalesce(sum(value), 0)::bigint v from stock_moves where shop_id = $1`, [shop])).rows[0].v;
    const open = (await db.query(`select count(*)::int n from uncosted_sales where shop_id = $1 and settled < qty and deleted_at is null`, [shop])).rows[0].n;
    const unbalanced = (await db.query(`select count(*)::int n from (select entry_id from journal_lines where shop_id = $1 group by entry_id having sum(debit) <> sum(credit)) x`, [shop])).rows[0].n;
    return { inventory: await acc('inventory'), cogs: await acc('cogs'), rev: -(await acc('rev_parts')), moves: Number(moves), open, unbalanced };
  } finally {
    await db.end();
  }
}

async function openSale(page: Page) {
  await page.getByRole('button', { name: 'بيع', exact: true }).click();
  const dlg = page.getByRole('dialog');
  await expect(dlg.getByRole('button', { name: 'سجّل', exact: true })).toBeEnabled();
  return dlg;
}

// S6: خانة الصنف بحث وكتابة، و"إضافة صنف جديد" من نافذة البيع، والبيع من غير رصيد والتسوية
test('الأصناف: تفاصيل الصنف ← بحث عربي وإنجليزي ← تسجيل الكمية من نافذة البيع ← صنف جديد من البيع ← بيع من غير رصيد والتسوية', async ({ page }, info) => {
  test.setTimeout(300_000);
  await prefs(page, info);
  const email = uniq('items');
  await registerShop(page, email, 'محل الأصناف');
  await page.goto('/#/inventory');
  await afterSplash(page);

  // 1) صنف جديد بالتفاصيل: الاسم بيتكوّن لوحده
  await page.getByRole('button', { name: 'صنف جديد' }).click();
  let dlg = page.getByRole('dialog');
  await combo(dlg, 'new-item-type', 'شاشة');
  await combo(dlg, 'new-item-brand', 'Apple');
  await combo(dlg, 'new-item-model', 'iPhone 13 Pro');
  await combo(dlg, 'new-item-quality', 'OLED');
  await expect(dlg.getByTestId('new-item-name')).toHaveValue('شاشة iPhone 13 Pro - OLED');
  await fillField(dlg.getByLabel('سعر البيع'), '1500');
  await dlg.getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف الصنف')).toBeVisible();
  await expect(page.getByTestId('item-row').filter({ hasText: 'شاشة iPhone 13 Pro - OLED' })).toHaveCount(1);
  // البحث في المخزون بجزء من الكلام وبالإنجليزي
  await fillField(page.getByTestId('inv-search'), 'screen 13 pro');
  await expect(page.getByTestId('item-row')).toHaveCount(1);
  await page.getByTestId('inv-search').fill('');

  // 2) البيع: "شاشه 13 برو" بتجيب الصنف بكميته وسعره، وسعر البيع بيتملى لوحده
  dlg = await openSale(page);
  await pickItem(dlg, 'شاشه 13 برو', { name: 'شاشة iPhone 13 Pro - OLED', qty: 0 });
  await expect(dlg.getByTestId('line').getByLabel('سعر البيع')).toHaveValue('1500');
  // الإعداد مقفول (الافتراضي): ماعندوش رصيد ← البيع موقوف، وصاحب المحل يعمل تسوية مخزون بسبب (بند 14)
  await expect(dlg.getByTestId('stock-in-inline')).toBeVisible();
  await expect(dlg.getByTestId('stock-in-inline')).toContainText('متاح 0');
  await dlg.getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(dlg.getByText('الكمية مش كفاية').first()).toBeVisible();
  await fillField(dlg.getByTestId('si-qty'), '2');
  await fillField(dlg.getByTestId('si-cost'), '1000');
  await dlg.getByTestId('si-save').click();
  await expect(dlg.getByText('لازم تكتب السبب').first()).toBeVisible();
  await fillField(dlg.getByTestId('si-reason'), 'رصيد أول المدة');
  await dlg.getByTestId('si-save').click();
  await expect(page.getByText('اتسجلت تسوية المخزون')).toBeVisible();
  await expect(dlg.getByTestId('stock-in-inline')).toHaveCount(0);
  await dlg.getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجل البيع').first()).toBeVisible();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByTestId('item-row').filter({ hasText: 'شاشة iPhone' })).toContainText('1');

  // 3) صنف مش موجود: "إضافة صنف جديد «...»" من نافذة البيع، ويتباع على طول
  dlg = await openSale(page);
  const box = dlg.getByRole('combobox', { name: 'الصنف', exact: true });
  await box.click();
  await fillField(box, 'بطارية A52');
  await expect(page.getByTestId('picker-option')).toHaveCount(0);
  await page.getByTestId('picker-create').click();
  const ni = dlg.getByTestId('new-item-inline');
  await expect(ni.getByTestId('ni-name')).toHaveValue('بطارية A52');
  await combo(ni, 'ni-type', 'بطارية');
  await combo(ni, 'ni-brand', 'Samsung');
  await combo(ni, 'ni-model', 'A52');
  await combo(ni, 'ni-quality', 'أصلي');
  await expect(ni.getByTestId('ni-name')).toHaveValue('بطارية A52 - أصلي');
  await fillField(ni.getByTestId('ni-cost'), '100');
  await fillField(ni.getByTestId('ni-price'), '250');
  await fillField(ni.getByTestId('ni-qty'), '2');
  await ni.getByTestId('ni-save').click();
  await expect(page.getByText('اتضاف الصنف «بطارية A52 - أصلي»')).toBeVisible();
  await expect(box).toHaveValue('بطارية A52 - أصلي');
  await expect(dlg.getByTestId('line').getByLabel('سعر البيع')).toHaveValue('250');
  await dlg.getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجل البيع').first()).toBeVisible();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByTestId('item-row').filter({ hasText: 'بطارية A52' })).toContainText('1');

  // الحسابات لحد هنا: مخزون = 2000 - 1000 (الشاشة) + 200 - 100 (البطارية)، وتكلفة المبيعات 1100
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect.poll(() => money(email)).toMatchObject({ inventory: 110000, cogs: 110000, rev: 175000, moves: 110000, open: 0, unbalanced: 0 });

  // 4) "السماح بالبيع بدون رصيد": البيع بيكمّل والصنف بيتعلّم "محتاج تسوية" بالأحمر
  await page.goto('/#/settings?tab=inventory');
  await afterSplash(page);
  const allow = page.getByTestId('inventory-settings').getByRole('checkbox', { name: 'السماح بالبيع بدون رصيد' });
  await expect(allow).toHaveAttribute('aria-checked', 'false');
  await allow.click();
  await expect(allow).toHaveAttribute('aria-checked', 'true');
  await page.goto('/#/inventory');
  await afterSplash(page);
  dlg = await openSale(page);
  await pickItem(dlg, 'iphone 13', { name: 'شاشة iPhone 13 Pro', qty: 1 });
  await fillField(dlg.getByTestId('line').getByLabel('الكمية'), '3');
  await expect(dlg.getByTestId('line-unsettled')).toContainText('محتاج تسوية (2)');
  await expect(dlg.getByTestId('stock-in-inline')).toHaveCount(0);
  await dlg.getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجل البيع').first()).toBeVisible();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  const row = page.getByTestId('item-row').filter({ hasText: 'شاشة iPhone' });
  await expect(row.getByTestId('item-unsettled')).toContainText('محتاج تسوية (2)');
  await expect(page.getByTestId('unsettled-banner')).toBeVisible();
  // اتباعت 3: واحدة بتكلفتها (1000) واتنين لسه من غير تكلفة
  await expect.poll(() => money(email)).toMatchObject({ inventory: 10000, cogs: 210000, rev: 625000, moves: 10000, open: 1, unbalanced: 0 });

  // 5) الكمية والتكلفة اتسجلت بعدين (شراء 2 × 1200): التسوية لوحدها بقيد متوازن، والعلامة بتختفي
  await page.getByRole('tab', { name: 'الموردين' }).click();
  await page.getByRole('button', { name: 'مورد جديد' }).click();
  await fillField(page.getByRole('dialog').getByLabel('اسم المورد'), 'مورد الشاشات');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتضاف المورد')).toBeVisible();
  await page.getByRole('tab', { name: 'الأصناف' }).click();
  await page.getByRole('button', { name: 'شراء', exact: true }).click();
  dlg = page.getByRole('dialog');
  await pickItem(dlg, 'شاشة', { name: 'شاشة iPhone 13 Pro' });
  await fillField(dlg.getByTestId('line').getByLabel('الكمية'), '2');
  await fillField(dlg.getByTestId('line').getByLabel('سعر الوحدة'), '1200');
  await dlg.getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجل الشراء')).toBeVisible();
  await expect(row.getByTestId('item-unsettled')).toHaveCount(0);
  await expect(page.getByTestId('unsettled-banner')).toHaveCount(0);
  await expect(row).toContainText('0');
  // التسوية: الاتنين اللي اتباعوا خدوا تكلفة الشراء (2400) ← المخزون رجع لقيمة البطارية بس
  await expect.poll(() => money(email)).toMatchObject({ inventory: 10000, cogs: 450000, rev: 625000, moves: 10000, open: 0, unbalanced: 0 });
});
