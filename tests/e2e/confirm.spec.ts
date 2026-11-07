import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASS, afterSplash, finishWizard, linkFor, prefs, startRegister, uniq } from './helpers';

// إيميل التأكيد: الإيميل الافتراضي بتاع Supabase فيه رابط، والقالب المتعدّل فيه كود. الاتنين لازم يدخّلوا صح.
// (الكود متجرّب في كل اختبارات التسجيل التانية، هنا الرابط)

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
/** المحلات والأسماء اللي اتعملت لإيميل ده (عشان نتأكد إن الاسم صح ومفيش محل اتعمل مرتين) */
async function shopsOf(email: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    return (await db.query(`select s.name as shop, p.full_name as owner from profiles p join shops s on s.id = p.shop_id where p.email = $1`, [email])).rows as { shop: string; owner: string }[];
  } finally {
    await db.end();
  }
}

test('رابط التأكيد في تبويب تاني بنفس المتصفح: التسجيل بيكمّل باسم المحل والاسم اللي اتكتبوا', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  const email = uniq('link-tab');
  const shop = `محل الرابط ${Date.now().toString(36)}`;
  await startRegister(page, email, shop, 'سعيد الرابط');
  await expect(page.getByTestId('verify-link-hint')).toBeVisible();
  const tab = await page.context().newPage();
  await tab.goto(await linkFor(email));
  await afterSplash(tab);
  // التبويب الجديد: داخل متأكد، والتسجيل كمّل لوحده لحد البلد والعملة
  await expect(tab.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  // العنوان اتنضف من بيانات الدخول
  expect(tab.url()).not.toContain('access_token');
  // التبويب الأصلي كمان كمّل (نفس الحساب)، ومن غير ما يتعمل محل تاني
  await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible({ timeout: 20_000 });
  await finishWizard(tab);
  expect(await shopsOf(email)).toEqual([{ shop, owner: 'سعيد الرابط' }]);
});

test('رابط التأكيد على جهاز تاني: الجهاز التاني بيدخل ويكمّل، والجهاز الأول بيكمّل بزرار "أكدت"، والرابط ما يتستخدمش مرتين', async ({ page, browser }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  const email = uniq('link-dev');
  const shop = `محل الجهاز ${Date.now().toString(36)}`;
  await startRegister(page, email, shop);
  const link = await linkFor(email);
  // جهاز تاني (متصفح منفصل): بيانات المحل جاية من الحساب نفسه
  const other = await (await browser.newContext(info.project.use)).newPage();
  await prefs(other, info);
  await other.goto(link);
  await afterSplash(other);
  await expect(other.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
  // الجهاز الأول: قبل التأكيد كان بيقول "لسه"، ودلوقتي "أكدت" بيدخّله
  await page.getByRole('button', { name: 'أكدت من الرابط، كمّل' }).click();
  await expect(page.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible({ timeout: 20_000 });
  await finishWizard(page);
  expect(await shopsOf(email)).toEqual([{ shop, owner: 'محمود حسن' }]);
  // نفس الرابط تاني: انتهى، ورسالة واضحة في شاشة الدخول
  const third = await (await browser.newContext(info.project.use)).newPage();
  await prefs(third, info);
  await third.goto(link);
  await afterSplash(third);
  await expect(third.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
  await expect(third.getByText('رابط التأكيد انتهت صلاحيته أو اتستخدم قبل كده')).toBeVisible();
  expect(third.url()).not.toContain('error_code');
});

test('الدخول قبل التأكيد: رسالة واضحة وإعادة إرسال رسالة التأكيد، وبعد الضغط على الرابط الدخول بيكمّل التسجيل', async ({ page, browser }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  const email = uniq('unconf');
  await startRegister(page, email, 'محل قبل التأكيد');
  const login = await (await browser.newContext(info.project.use)).newPage();
  await prefs(login, info);
  await login.goto('/');
  await afterSplash(login);
  await login.locator('input[type=email]').fill(email);
  await login.locator('input[type=password]').fill(PASS);
  await login.getByRole('button', { name: 'دخول' }).click();
  await expect(login.getByTestId('unconfirmed')).toBeVisible();
  await login.getByRole('button', { name: 'ابعت رسالة التأكيد تاني' }).click();
  await expect(login.getByText('اتبعتت رسالة تأكيد جديدة')).toBeVisible();
  // بعد التأكيد (من الرابط في متصفح تالت)، الدخول العادي بيكمّل تسجيل المحل من غير ما يسأل تاني
  const confirm = await (await browser.newContext(info.project.use)).newPage();
  await confirm.goto(await linkFor(email));
  await afterSplash(confirm);
  await login.getByRole('button', { name: 'دخول' }).click();
  await expect(login.getByRole('heading', { name: 'البلد والعملة' })).toBeVisible();
});
