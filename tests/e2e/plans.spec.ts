import { expect, test } from '@playwright/test';
import pg from 'pg';
import { afterSplash, fillAmount, fillField, prefs, quickIntake, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
const iso = (days: number) => new Date(Date.now() + days * 86400_000).toISOString().slice(0, 10);

// N: ميعاد تحصيل وخطة تقسيط ← متأخر بالأحمر ← الجرس ← الدفع بيغطي بالترتيب ← مستحقات قادمة ← بتتقفل لوحدها
test('الأقساط: خطة 3 أقساط ← متأخر ← الجرس ← دفعة بتغطي بالترتيب ← مستحقات قادمة ← الخطة بتتقفل', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('plans');
  await registerShop(page, email, 'محل الأقساط');
  await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل الأقساط');
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const cust = (await db.query(`select c.id from customers c join profiles p on p.shop_id = c.shop_id where p.email = $1 limit 1`, [email]).finally(() => db.end())).rows[0].id;

  // 1) كشف حساب العميل ← خطة تقسيط: 300 على 3 أقساط، أولها امبارح
  await page.goto(`/#/finance/customer/${cust}`);
  await afterSplash(page);
  const panel = page.getByTestId('plans-panel');
  await expect(panel).toContainText('مفيش مواعيد ولا أقساط');
  await panel.getByTestId('plan-new').click();
  const dlg = page.getByRole('dialog');
  await fillField(dlg.getByTestId('plan-total'), '300');
  await fillField(dlg.getByTestId('plan-count'), '3');
  await dlg.getByTestId('plan-first').fill(iso(-1));
  await expect(dlg.getByTestId('plan-row-edit')).toHaveCount(3);
  await expect(dlg.getByTestId('plan-sum')).toHaveText('300');
  await dlg.getByTestId('plan-save').click();
  await expect(page.getByText('اتحفظت الخطة')).toBeVisible();
  const plan = panel.getByTestId('plan-row');
  await expect(plan).toHaveAttribute('data-status', 'overdue');
  await expect(plan.getByTestId('plan-overdue')).toContainText('متأخر 100');
  await expect(plan.getByTestId('plan-inst').first()).toHaveAttribute('data-status', 'overdue');

  // 2) الجرس: القسط المتأخر باسم العميل، والدوسة بتفتح الكشف وبتعلّمه اتقرا
  await page.reload();
  await afterSplash(page);
  await expect(page.getByTestId('bell-count')).toBeVisible();
  await page.getByTestId('bell').click();
  const item = page.getByTestId('bell-item').filter({ hasText: 'عميل الأقساط' }).first();
  await expect(item).toContainText('قسط متأخر');
  await item.click();
  await expect(page).toHaveURL(new RegExp(`/finance/customer/${cust}`));
  await page.getByTestId('bell').click();
  await expect(page.getByTestId('bell-item').filter({ hasText: 'عميل الأقساط' }).first()).toHaveAttribute('data-read', 'true');
  await page.keyboard.press('Escape');

  // 3) دفعة 150: الأول اتقفل، والتاني اتدفع منه 50، والمتأخر راح
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '150');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  await expect(plan).toContainText('اتدفع 150 من 300');
  await expect(plan.getByTestId('plan-inst').nth(0)).toHaveAttribute('data-status', 'paid');
  await expect(plan.getByTestId('plan-inst').nth(1)).toContainText('اتدفع 50');
  await expect(plan.getByTestId('plan-overdue')).toHaveCount(0);

  // 4) الوضع المالي ← مستحقات قادمة
  await page.goto('/#/finance');
  await afterSplash(page);
  await expect(page.getByTestId('upcoming-dues')).toBeVisible();

  // 5) الباقي كله: الخطة اتقفلت لوحدها
  await page.goto(`/#/finance/customer/${cust}`);
  await afterSplash(page);
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '150');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل', exact: true }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  await expect(panel.getByTestId('plan-row')).toHaveAttribute('data-status', 'done');
  await expect(panel.getByTestId('plan-status')).toHaveText('اتقفلت (اتدفعت كلها)');
});
