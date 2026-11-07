import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { activateInvite, afterSplash, noHorizontalScroll, prefs, quickIntake, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

async function invite(page: Page, name: string, email: string, role: string) {
  await page.goto('/#/users');
  await page.getByLabel('الاسم').fill(name);
  await page.getByLabel('الإيميل').fill(email);
  await page.getByLabel('الدور').selectOption(role);
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
}

test('المرحلة 6: فيديو من الفني ← مراجعة التسويق بالنقاط ← المجتمع من غير بيانات عملاء ← المساعد بالدليل المدمج ← تقييم العميل ← الخطة ← لوحة المشرف والإيقاف', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const ownerEmail = uniq('owner6');
  const shopName = `محل النمو ${Date.now().toString(36)}`;
  await registerShop(page, ownerEmail, shopName);
  const emT = uniq('tech6');
  const emM = uniq('mkt6');
  await invite(page, 'فني الفيديو', emT, 'technician');
  await invite(page, 'مسوق المحل', emM, 'marketing');
  const T = await activateInvite(browser, info, emT);
  const M = await activateInvite(browser, info, emM, 'فيديوهات الإصلاح');

  // 1) الفني بيرفع فيديو
  await T.page.goto('/#/videos');
  await T.page.getByLabel('عنوان الفيديو').fill('تغيير شاشة A35');
  await T.page.getByLabel('اختار ملف الفيديو').setInputFiles({ name: 'fix.mp4', mimeType: 'video/mp4', buffer: Buffer.alloc(2048, 1) });
  await T.page.getByRole('button', { name: 'ارفع', exact: true }).click();
  await expect(T.page.getByText('الفيديو اترفع، ومستني المراجعة')).toBeVisible();
  await expect(T.page.getByTestId('video-item')).toContainText('مستني المراجعة');

  // 2) مدير التسويق: الفيديوهات بس، ويقبل بالنقاط
  await M.page.reload();
  await afterSplash(M.page);
  await expect(M.page.getByRole('heading', { name: 'فيديوهات الإصلاح' })).toBeVisible();
  await expect(M.page.getByRole('link', { name: 'الأجهزة' })).toHaveCount(0);
  await expect(M.page.getByRole('link', { name: 'العملاء' })).toHaveCount(0);
  await expect(M.page.getByTestId('video-item')).toContainText('تغيير شاشة A35');
  await M.page.getByRole('button', { name: 'اقبل' }).click();
  await expect(M.page.getByTestId('video-item')).toContainText('مقبول · +10');
  // مفيش طريق للأجهزة حتى بالرابط المباشر
  await M.page.goto('/#/devices');
  await expect(M.page.getByRole('heading', { name: 'فيديوهات الإصلاح' })).toBeVisible();
  await noHorizontalScroll(M.page);

  // 3) المجتمع: رقم الموبايل بيترفض، والكلام العادي بيتنشر
  await T.page.goto('/#/community');
  await T.page.getByLabel('السؤال أو الخبرة').fill('العميل رقمه 01012345678 والجهاز مش بيشحن');
  await T.page.getByRole('button', { name: 'انشر' }).click();
  await expect(T.page.getByText('النص فيه رقم موبايل أو IMEI')).toBeVisible();
  await T.page.getByLabel('السؤال أو الخبرة').fill('A35 مش بيشحن بعد تغيير السوكت، أبدأ بإيه؟');
  await T.page.getByRole('button', { name: 'انشر' }).click();
  await expect(T.page.getByText('اتنشر')).toBeVisible();
  await expect(T.page.getByTestId('community-post').first()).toContainText('أبدأ بإيه');
  await noHorizontalScroll(T.page);

  // 4) المساعد: من غير مفتاح Gemini على السيرفر بيبقى مقفول برسالة واضحة، والدليل المدمج متاح
  const devicePath = await quickIntake(page, '01088889999', 'عميل التقييم');
  await expect(page.getByTestId('assistant-disabled')).toContainText('محتاج مفتاح Gemini المجاني');
  await expect(page.getByRole('button', { name: 'اقترح الأسباب وخطوات الفحص' })).toHaveCount(0);
  await page.getByRole('button', { name: 'دليل الأعطال المدمج' }).click();
  await expect(page.getByTestId('assistant-guide')).toContainText('مشكلة في الشاشة');

  // 5) تقييم العميل بعد التسليم (التسليم نفسه متجرّب في المراحل اللي فاتت، هنا بنجهّزه مباشرة في قاعدة الاختبار)
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const id = devicePath.split('/').pop()!;
    const token = (await db.query('select tracking_token from devices where id = $1', [id])).rows[0].tracking_token as string;
    await db.query('begin');
    await db.query('set local session_replication_role = replica');
    await db.query(`update devices set status = 'delivered', delivered_at = now() where id = $1`, [id]);
    await db.query('commit');
    const cust = await (await browser.newContext(info.project.use)).newPage();
    await prefs(cust, info);
    await cust.goto(`/#/t/${token}`);
    await expect(cust.getByTestId('rating-box')).toBeVisible();
    await cust.getByRole('radio', { name: '5 من 5' }).click();
    await cust.getByRole('button', { name: 'ابعت التقييم' }).click();
    await expect(cust.getByText('قيّمت الخدمة 5 من 5')).toBeVisible();
    await cust.reload();
    await expect(cust.getByText('قيّمت الخدمة 5 من 5')).toBeVisible();
    await expect(cust.getByTestId('rating-box')).toHaveCount(0);
    await noHorizontalScroll(cust);

    // 6) الخطة والاستخدام
    await page.goto('/#/settings');
    await expect(page.getByTestId('plan-usage')).toContainText('المجانية');
    await expect(page.getByTestId('plan-usage')).toContainText('من 300');

    // 7) لوحة المشرف (صاحب المنصة): بنضيف صاحب المحل ده كمشرف في قاعدة الاختبار
    await db.query(`insert into platform_admins(user_id) select id from auth.users where email = $1`, [ownerEmail]);
    await page.reload();
    await afterSplash(page);
    await page.goto('/#/admin');
    // المشرف بيدوّر باسم المحل (المحلات على صفحات، 50 في المرة)
    await page.getByLabel('دوّر باسم المحل').fill(shopName);
    await expect(page.getByTestId('admin-shop')).toHaveCount(1);
    const row = page.getByTestId('admin-shop').filter({ hasText: shopName });
    await expect(row).toBeVisible();
    await row.getByRole('button', { name: 'إيقاف' }).click();
    await expect(row.getByRole('button', { name: 'تشغيل' })).toBeVisible();
    // الفني بيشوف رسالة الإيقاف، والبيانات محفوظة
    await T.page.reload();
    await expect(T.page.getByRole('heading', { name: 'المحل موقوف مؤقتًا' })).toBeVisible();
    await row.getByRole('button', { name: 'تشغيل' }).click();
    await expect(row.getByRole('button', { name: 'إيقاف' })).toBeVisible();
    await T.page.reload();
    await afterSplash(T.page);
    await expect(T.page.getByRole('heading', { name: 'مجتمع الفنيين' })).toBeVisible();
  } finally {
    await db.end();
  }
});
