import { expect, test } from '@playwright/test';
import pg from 'pg';
import { afterSplash, fillAmount, prefs, quickIntake, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// U5 (مهمة codex-001): قالب "كشف الحساب" في مصمم الطباعة: الافتراضي زي الكشف القديم ← إخفاء "الرصيد الافتتاحي" ←
// الكشف من غيره، والرصيد الختامي نفس الرقم بالظبط ← "رجّع الافتراضي" يرجّعه
test('مصمم الطباعة: كشف الحساب ← إخفاء الرصيد الافتتاحي ← الختامي زي ما هو ← رجّع الافتراضي', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('pstatement');
  await registerShop(page, email, 'محل الكشف');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل الكشف');
  // تكلفة 700 ودفعة 200 = حركة على حساب العميل
  await page.getByLabel('التكلفة النهائية').fill('700');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();

  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const cust = (await db.query(`select c.id from customers c join profiles p on p.shop_id = c.shop_id where p.email = $1 limit 1`, [email]).finally(() => db.end())).rows[0].id as string;
  // preview=1: من غير نافذة الطباعة
  const url = `/#/print/statement/customer/${cust}?preview=1`;

  // 1) الافتراضي: نفس الكشف القديم (الافتتاحي والحركات والختامي واسم العميل)
  await page.goto(url);
  const sheet = page.getByTestId('print-statement');
  await expect(sheet).toBeVisible();
  await expect(sheet.getByTestId('statement-opening')).toBeVisible();
  await expect(sheet.getByTestId('statement-moves').first()).toBeVisible();
  await expect(sheet.getByTestId('statement-party')).toHaveText('عميل الكشف');
  await expect(page.getByTestId('shop-header-color')).toContainText('عميل الكشف');
  const closing = (await sheet.getByTestId('statement-closing').innerText()).trim();
  expect(closing).toMatch(/\d/);

  // 2) المصمم ← كشف الحساب ← إخفاء "الرصيد الافتتاحي" ← حفظ
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  const d = page.getByTestId('print-designer');
  await d.getByTestId('tpl-doc').selectOption('statement');
  await expect(d.locator('[data-testid="tpl-block"][data-key="opening"]')).toBeVisible();
  await d.locator('[data-testid="tpl-block"][data-key="opening"]').getByTestId('tpl-toggle').click();
  await expect(d.getByTestId('tpl-preview')).toBeVisible();
  await d.getByTestId('tpl-save').click();
  await expect(page.getByText('اتحفظ القالب')).toBeVisible();

  // 3) الكشف من غير الافتتاحي، والختامي نفس الرقم بالظبط
  await page.goto(url.replace('?preview=1', '?preview=0'));
  await expect(page.getByTestId('print-statement')).toBeVisible();
  await expect(page.getByTestId('statement-opening')).toHaveCount(0);
  await expect(page.getByTestId('statement-closing')).toHaveText(closing);
  await expect(page.getByTestId('statement-moves').first()).toBeVisible();

  // 4) رجّع الافتراضي: الافتتاحي رجع
  await page.goto('/#/settings?tab=printers');
  await afterSplash(page);
  await page.getByRole('tab', { name: 'الطابعات ومصمم الطباعة' }).click();
  await page.getByTestId('print-designer').getByTestId('tpl-doc').selectOption('statement');
  await page.getByTestId('print-designer').getByTestId('tpl-reset').click();
  await expect(page.getByText('رجع القالب الافتراضي')).toBeVisible();
  await page.goto(url);
  await expect(page.getByTestId('statement-opening')).toBeVisible();
  await expect(page.getByTestId('statement-closing')).toHaveText(closing);
});
