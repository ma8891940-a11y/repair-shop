import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { prefs, registerShop, uniq } from './helpers';

// الخروج لما الجلسة تكون منتهية أو المستخدم اتحذف: الجلسة بتتمسح من الجهاز ويرجع للدخول، من غير أي خطأ
const DB = process.env.E2E_DB_URL ?? 'postgres://postgres:postgres@127.0.0.1:54322/postgres';

function watch(page: Page) {
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  const failed: string[] = [];
  page.on('response', (r) => r.status() >= 400 && failed.push(`${r.status()} ${r.url().replace(/^.*\/(auth|rest)\/v1\//, '$1/')}`));
  return { errors, failed };
}
async function signOut(page: Page) {
  const direct = page.getByRole('button', { name: 'خروج' }).filter({ visible: true });
  if (await direct.count()) return direct.first().click();
  // الموبايل: الخروج جوه "المزيد"
  await page.getByRole('button', { name: 'المزيد' }).filter({ visible: true }).first().click();
  await page.getByRole('dialog').getByRole('button', { name: 'خروج' }).click();
}
const storedSession = (page: Page) => page.evaluate(() => Object.keys(localStorage).filter((k) => /^sb-.+-auth-token/.test(k)));

for (const kind of ['المستخدم اتحذف', 'الجلسة اتلغت من السيرفر'] as const) {
  test(`الخروج لما ${kind}: يمسح الجلسة ويرجع للدخول من غير أخطاء`, async ({ page }, info) => {
    test.setTimeout(180_000);
    await prefs(page, info);
    const email = uniq('signout');
    await registerShop(page, email);
    const w = watch(page);
    const db = new pg.Client({ connectionString: DB });
    await db.connect();
    try {
      if (kind === 'المستخدم اتحذف') await db.query(`delete from auth.users where email = $1`, [email]);
      else await db.query(`delete from auth.sessions where user_id = (select id from auth.users where email = $1)`, [email]);
    } finally {
      await db.end();
    }
    await signOut(page);
    await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
    expect(await storedSession(page)).toEqual([]);
    expect(w.errors, w.errors.join('\n')).toEqual([]);
    expect(w.failed, w.failed.join('\n')).toEqual([]);
    // بعد تحديث الصفحة: لسه في الدخول
    await page.reload();
    await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
  });
}
