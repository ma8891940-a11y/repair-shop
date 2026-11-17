import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
// مفتاح عام شكله سليم (65 بايت) — الإرسال الحقيقي محتاج خدمة إشعارات المتصفح، فالمتصفح هنا بديل وهمي
const KEY = 'B' + 'A'.repeat(86);

/** بديل لخدمة الإشعارات في المتصفح (الاختبار ما يقدرش يوصل لخدمة Google)، والباقي كله حقيقي: الواجهة وقاعدة البيانات */
async function fakePush(page: Page, opts: { configured: boolean }) {
  // المتصفح من غير شاشة بيقفل الإشعارات افتراضيًا (وده اللي بيظهر "مقفولة من إعدادات المتصفح")
  await page.context().grantPermissions(['notifications']);
  await page.addInitScript(() => {
    const bytes = (n: number) => {
      const b = new Uint8Array(n);
      crypto.getRandomValues(b);
      return b.buffer;
    };
    const w = window as unknown as { __sub: unknown };
    w.__sub = null;
    const make = (key: ArrayBuffer | null) => ({
      endpoint: `https://push.example.com/e2e/${Math.random().toString(36).slice(2)}`,
      options: { applicationServerKey: key },
      getKey: (n: string) => (n === 'p256dh' ? bytes(65) : bytes(16)),
      unsubscribe: async () => {
        w.__sub = null;
        return true;
      },
    });
    const reg = {
      active: {},
      pushManager: {
        getSubscription: async () => w.__sub,
        subscribe: async (o: { applicationServerKey: Uint8Array }) => (w.__sub = make(o.applicationServerKey.slice().buffer)),
      },
    };
    Object.defineProperty(navigator.serviceWorker, 'getRegistration', { value: async () => reg, configurable: true });
    // المتصفح من غير شاشة بيرجّع "مقفولة" دايمًا، فبنمثّل إن المستخدم لسه ما اختارش، وبعدين وافق
    let perm: NotificationPermission = 'default';
    Object.defineProperty(Notification, 'permission', { get: () => perm, configurable: true });
    Notification.requestPermission = async () => (perm = 'granted');
  });
  await page.route('**/functions/v1/push', (route) => {
    if (!opts.configured) return route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"E_PUSH_DISABLED"}' });
    if (route.request().method() === 'GET') return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ publicKey: KEY }) });
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 200, body: 'ok' });
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ sent: 1, devices: 1 }) });
  });
}

// N المرحلة التانية: الإعدادات ← التنبيهات ← فعّل على الجهاز ← اتحفظ في قاعدة البيانات ← تجربة ← الوقت ← اقفل
test('إشعارات الجهاز: تفعيل ← تجربة ← وقت الإشعارات ← قفل، والاشتراك في قاعدة البيانات لصاحبه', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await fakePush(page, { configured: true });
  const email = uniq('push');
  await registerShop(page, email, 'محل الإشعارات');
  await page.goto('/#/settings?tab=alerts');
  await afterSplash(page);
  const panel = page.getByTestId('push-settings');
  await expect(panel.getByTestId('push-state')).toHaveAttribute('data-state', 'off');
  await panel.getByTestId('push-enable').click();
  await expect(page.getByText('الإشعارات اتفعّلت على الجهاز ده')).toBeVisible();
  await expect(panel.getByTestId('push-state')).toHaveAttribute('data-state', 'on');

  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const rows = async () =>
      (await db.query(`select s.endpoint, s.locale, s.deleted_at is null alive from push_subscriptions s join profiles p on p.id = s.profile_id where p.email = $1`, [email])).rows;
    await expect.poll(async () => (await rows()).filter((r) => r.alive).length).toBe(1);
    expect((await rows())[0]).toMatchObject({ locale: 'ar', alive: true });
    expect((await rows())[0].endpoint).toMatch(/^https:\/\/push\.example\.com\/e2e\//);

    // إشعار تجربة
    await panel.getByTestId('push-test').click();
    await expect(panel).toContainText('اتبعت. لو ما وصلش في دقيقة');

    // وقت الإشعارات (لصاحب المحل): من 8 الصبح لـ 10 بالليل
    await panel.getByTestId('push-from').selectOption('8');
    await panel.getByTestId('push-to').selectOption('22');
    await panel.getByTestId('push-window-save').click();
    await expect(page.getByText('اتحفظ').first()).toBeVisible();
    await expect
      .poll(async () => (await db.query(`select s.extras -> 'reminders' r from shops s join profiles p on p.shop_id = s.id where p.email = $1`, [email])).rows[0].r)
      .toMatchObject({ push_from: 8, push_to: 22 });

    // اقفل على الجهاز ده: الاشتراك بيتشال من قاعدة البيانات
    await panel.getByTestId('push-disable').click();
    await expect(page.getByText('الإشعارات اتقفلت على الجهاز ده')).toBeVisible();
    await expect(panel.getByTestId('push-state')).toHaveAttribute('data-state', 'off');
    await expect.poll(async () => (await rows()).filter((r) => r.alive).length).toBe(0);

    // بعد إعادة التحميل: الوقت المحفوظ ظاهر
    await page.reload();
    await afterSplash(page);
    await expect(page.getByTestId('push-from')).toHaveValue('8');
    await expect(page.getByTestId('push-to')).toHaveValue('22');
  } finally {
    await db.end();
  }
});

test('إشعارات الجهاز: لو السيرفر لسه مش متجهّز، رسالة واضحة ومفيش اشتراك', async ({ page }, info) => {
  test.setTimeout(120_000);
  await prefs(page, info);
  await fakePush(page, { configured: false });
  await registerShop(page, uniq('push-off'), 'محل من غير مفاتيح');
  await page.goto('/#/settings?tab=alerts');
  await afterSplash(page);
  const panel = page.getByTestId('push-settings');
  await panel.getByTestId('push-enable').click();
  await expect(panel).toContainText('لسه مش متجهّزة على السيرفر');
  await expect(panel.getByTestId('push-state')).toHaveAttribute('data-state', 'off');
});
