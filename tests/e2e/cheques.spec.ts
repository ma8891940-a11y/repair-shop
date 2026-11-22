import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, fillField, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** عميل ومورد للمحل (بنفس صلاحيات صاحب المحل) */
async function seedParties(email: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const uid = (await db.query(`select id from profiles where email = $1`, [email])).rows[0].id;
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    await db.query(`insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل الشيكات', '01044445555')`, [randomUUID()]);
    await db.query(`insert into suppliers(id, shop_id, name) values ($1, gen_random_uuid(), 'مورد الشيكات')`, [randomUUID()]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}

// R7: الشيكات: شيك من عميل ← اتصرف في البنك. شيك لمورد ← اترفض بسبب. والمبالغ والحالات صح
test('الشيكات: استلام من عميل ← اتصرف، وشيك لمورد ← اترفض بسبب', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('chq');
  await registerShop(page, email, 'محل الشيكات');
  await seedParties(email);
  await page.goto('/#/finance/cheques');
  await afterSplash(page);
  const scr = page.getByTestId('cheques-screen');

  // 1) شيك من عميل
  await scr.getByTestId('cheque-add-in').click();
  let dlg = page.getByRole('dialog');
  await dlg.getByTestId('cheque-save').click();
  await expect(dlg.getByText('اختار الطرف')).toBeVisible();
  await dlg.getByTestId('cheque-party').selectOption({ label: 'عميل الشيكات' });
  await fillField(dlg.getByTestId('cheque-no'), '100200');
  await fillField(dlg.getByTestId('cheque-bank'), 'البنك الأهلي');
  await dlg.getByTestId('cheque-due').fill('2030-01-15');
  await fillField(dlg.getByTestId('cheque-amount'), '1500');
  await dlg.getByTestId('cheque-save').click();
  await expect(page.getByText('اتسجّل الشيك')).toBeVisible();
  await expect(scr.getByTestId('cheques-sum-in')).toContainText('1,500');

  // 2) شيك لمورد
  await scr.getByTestId('cheque-add-out').click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('cheque-party').selectOption({ label: 'مورد الشيكات' });
  await fillField(dlg.getByTestId('cheque-no'), '777');
  await dlg.getByTestId('cheque-due').fill('2030-02-01');
  await fillField(dlg.getByTestId('cheque-amount'), '800');
  await dlg.getByTestId('cheque-save').click();
  // رسالة الشيك الأول ممكن تكون لسه ظاهرة
  await expect(page.getByText('اتسجّل الشيك').first()).toBeVisible();
  await expect(scr.getByTestId('cheques-sum-out')).toContainText('800');
  await expect(scr.getByTestId('cheque-row')).toHaveCount(2);
  await noHorizontalScroll(page);

  // 3) شيك العميل اتصرف في البنك
  await scr.getByTestId('cheque-row').filter({ hasText: '100200' }).getByTestId('cheque-clear').click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('cheque-act-save').click();
  await expect(page.getByText('اتسجّل صرف الشيك')).toBeVisible();
  await expect(scr.getByTestId('cheque-row')).toHaveCount(1);
  await expect(scr.getByTestId('cheques-sum-in')).toContainText('0');

  // 4) شيك المورد اترفض: من غير سبب مرفوض
  await scr.getByTestId('cheque-row').filter({ hasText: '777' }).getByTestId('cheque-bounce').click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('cheque-act-save').click();
  await expect(dlg.getByText('لازم تكتب السبب')).toBeVisible();
  await fillField(dlg.getByTestId('cheque-reason'), 'اتلغى قبل الصرف');
  await dlg.getByTestId('cheque-act-save').click();
  await expect(page.getByText('اتسجّل رفض الشيك')).toBeVisible();
  await expect(scr.getByTestId('cheque-row')).toHaveCount(0);

  // 5) "الكل": الاتنين بحالاتهم
  await scr.getByTestId('cheques-filter').selectOption('all');
  await expect(scr.locator('[data-testid=cheque-row][data-status=cleared]')).toHaveCount(1);
  await expect(scr.locator('[data-testid=cheque-row][data-status=bounced]')).toHaveCount(1);
});
