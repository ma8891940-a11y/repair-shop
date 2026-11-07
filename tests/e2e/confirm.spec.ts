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
  // الزرار، أو البرنامج بيلاحظ لوحده (كل 15 ثانية ولما يرجعله) وبيكمّل: الاتنين صح
  await page
    .getByRole('button', { name: 'أكدت من الرابط، كمّل' })
    .click({ timeout: 5_000 })
    .catch(() => undefined);
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

test('تسجيل اتقطع في النص: حساب متأكد ومالوش محل ولا دعوة ← "كمّل تسجيل محلك" على طول، من غير حساب تاني', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  const email = uniq('halfway');
  // حساب اتعمل في Auth بس (زي ما حصل عند صاحب المشروع): متأكد، ومن غير بيانات تسجيل محفوظة، ومن غير محل
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    await db.query(
      `insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
       values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', $1, crypt($2, gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')`,
      [email, PASS],
    );
    await db.query(`insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), 'email', now(), now() from auth.users where email = $1`, [email]);
  } finally {
    await db.end();
  }
  await page.goto('/');
  await afterSplash(page);
  await page.locator('input[type=email]').fill(email);
  await page.locator('input[type=password]').fill(PASS);
  await page.getByRole('button', { name: 'دخول' }).click();
  // بدل "مفيش دعوة": كمّل تسجيل محلك، والحساب ظاهر
  await expect(page.getByRole('heading', { name: 'كمّل تسجيل محلك' })).toBeVisible();
  await expect(page.getByText('مفيش دعوة للإيميل ده')).toHaveCount(0);
  await expect(page.getByTestId('resume-account')).toContainText(email);
  const inputs = page.locator('form input');
  await inputs.nth(0).fill('محل اتكمّل');
  await inputs.nth(1).fill('صاحب المحل');
  await page.getByRole('button', { name: 'التالي' }).click();
  // من غير خطوة حساب ولا تأكيد
  await finishWizard(page);
  expect(await shopsOf(email)).toEqual([{ shop: 'محل اتكمّل', owner: 'صاحب المحل' }]);
});
