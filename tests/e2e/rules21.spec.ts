import { expect, test } from '@playwright/test';
import pg from 'pg';
import { prefs, quickIntake, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// قواعد اتكمّلت من المواصفات في المراجعة الشاملة: رسالة للعميل مع كل تغيير حالة، وضمان لكل نوع عطل، وتذكيرات تسويقية بموافقة العميل
test('المواصفات: "ابعت للعميل" بعد تغيير الحالة، ومدة ضمان لكل نوع عطل، وأقصى خصم، وتذكيرات بموافقة العميل', async ({ page }, info) => {
  test.setTimeout(150_000);
  await prefs(page, info);
  const email = uniq('rules21');
  await registerShop(page, email, 'محل القواعد');

  // تذكيرات بموافقة العميل في لوحة التحكم (فاضية في محل جديد)
  await expect(page.getByTestId('marketing-due')).toContainText('مفيش عملاء عليهم تذكير دلوقتي');

  // تغيير الحالة: التنبيه فيه "ابعت للعميل" بيفتح رسالة واتساب
  // (quickIntake بيكتب الوصف "شاشة مكسورة" ويحفظ على طول: المسار لازم يتحسب من الوصف النهائي، مش "عطل غير معروف")
  const devPath = await quickIntake(page, '01033332222', 'عميل الرسالة');
  await page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await page.getByRole('button', { name: 'ابعت للعميل' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.getByRole('dialog')).toContainText('عميل الرسالة');
  await page.keyboard.press('Escape');

  // مدة ضمان لنوع عطل (أول مسار)، وأقصى خصم للاستقبال
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'الفنيين والمسارات' }).click();
  const editor = page.getByTestId('route-editor').first();
  await editor.getByLabel('مدة الضمان').fill('٩٠');
  await editor.getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  // التنبيه اللي فات يختفي الأول، عشان "اتحفظ" الجاي يبقى بتاع الخصم
  await expect(page.getByText('اتحفظ')).toHaveCount(0, { timeout: 15_000 });
  await page.getByRole('tab', { name: 'الخزن والمصروفات' }).click();
  await page.getByLabel('أقصى خصم للاستقبال').fill('15');
  await page.getByLabel('أقصى خصم للاستقبال').locator('xpath=ancestor::div[contains(@class,"items-end")][1]').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const r = (await db.query(`select s.max_discount_pct, (select max(warranty_days) from routes r where r.shop_id = s.id) w from shops s join profiles p on p.shop_id = s.id where p.email = $1`, [email])).rows[0];
    expect(r).toEqual({ max_discount_pct: 15, w: 90 });
    const route = (await db.query(`select r.code from devices d join routes r on r.id = d.route_id where d.id = $1`, [devPath.split('/').pop()])).rows[0]?.code;
    expect(route).toBe('screen_battery');
  } finally {
    await db.end();
  }
});
