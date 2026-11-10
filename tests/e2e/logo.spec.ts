import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

// شعار المحل: من أول الرفع في الإعدادات لحد ما يظهر على الإيصال والفاتورة وصفحة التتبع
const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** صورة JPEG كبيرة زي صورة الموبايل (حوالي 3 ميجا)، بلون معيّن */
async function bigJpeg(page: Page, color: string) {
  return Buffer.from(
    await page.evaluate(async (c) => {
      const cv = document.createElement('canvas');
      cv.width = 1800;
      cv.height = 1800;
      const x = cv.getContext('2d')!;
      const d = x.createImageData(1800, 1800);
      for (let i = 0; i < d.data.length; i += 4) {
        d.data[i] = Math.random() * 255;
        d.data[i + 1] = Math.random() * 255;
        d.data[i + 2] = Math.random() * 255;
        d.data[i + 3] = 255;
      }
      x.putImageData(d, 0, 0);
      x.fillStyle = c;
      x.fillRect(300, 600, 1200, 600);
      const b = await new Promise<Blob>((ok) => cv.toBlob((v) => ok(v!), 'image/jpeg', 0.92));
      return Array.from(new Uint8Array(await b.arrayBuffer()));
    }, color),
  );
}
const src = (page: Page, testid: string) => page.getByTestId(testid).first().getAttribute('src');

test('شعار المحل: صورة موبايل كبيرة ← معاينة على طول ← حفظ ← بيظهر في الإيصال والفاتورة وصفحة التتبع ← تغييره بيظهر على طول ← الأخطاء بالعربي', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('logo');
  await registerShop(page, email, 'محل الشعار');
  const dev = await quickIntake(page, '01049494949', 'عميل الشعار');

  // نوع ملف غلط: رسالة واضحة جنب الزرار
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'هوية المحل' }).click();
  await page.getByLabel('لوجو المحل').setInputFiles({ name: 'logo.gif', mimeType: 'image/gif', buffer: Buffer.from('GIF89a') });
  await expect(page.getByTestId('logo-error')).toContainText('نوع الملف مش مدعوم');

  // صورة موبايل كبيرة (أكبر من 2 ميجا): بتتقبل والمعاينة على طول
  const first = await bigJpeg(page, '#0a7');
  expect(first.length).toBeGreaterThan(2 * 1024 * 1024);
  await page.getByLabel('لوجو المحل').setInputFiles({ name: 'logo.jpg', mimeType: 'image/jpeg', buffer: first });
  await expect(page.getByTestId('logo-error')).toHaveCount(0);
  await expect(page.getByTestId('logo-crop')).toBeVisible();
  await expect(page.getByTestId('preview-receipt').getByTestId('shop-logo-thermal')).toBeVisible();
  await expect(page.getByTestId('preview-invoice').getByTestId('shop-logo-color')).toBeVisible();
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await expect(page.getByTestId('logo-error')).toHaveCount(0);
  // الأصل اترفع على Storage تحت فولدر المحل، ومتصغّر (أقل من 2 ميجا)
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const o = (await db.query(`select o.name, (o.metadata->>'size')::int size from storage.objects o join shop_branding b on b.logo_path = o.name join shops s on s.id = b.shop_id where o.bucket_id = 'shop-logos' and s.name = 'محل الشعار' order by o.created_at desc limit 1`)).rows[0];
    expect(o?.name).toMatch(/^[0-9a-f-]{36}\/logo-.+\.jpg$/);
    expect(o.size).toBeLessThan(2 * 1024 * 1024);
  } finally {
    await db.end();
  }

  // الإيصال والفاتورة
  await page.goto(dev.replace('/devices/', '/print/receipt/'));
  await expect(page.getByTestId('shop-logo-thermal')).toBeVisible();
  await page.goto(dev.replace('/devices/', '/print/invoice/'));
  await expect(page.getByTestId('shop-logo-color')).toBeVisible();
  const i1 = await src(page, 'shop-logo-color');

  // صفحة التتبع (والرسالة على واتساب فيها رابطها، باسم المحل)
  await page.goto(dev);
  await afterSplash(page);
  await page.getByRole('button', { name: 'واتساب', exact: true }).first().click();
  const msg = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  expect(msg).toContain('محل الشعار');
  const token = (msg.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  await page.keyboard.press('Escape');
  const ctx = await browser.newContext(info.project.use);
  const cust = await ctx.newPage();
  await prefs(cust, info);
  await cust.goto(`/#/t/${token}`);
  await expect(cust.getByTestId('shop-logo-color')).toBeVisible();
  const t1 = await src(cust, 'shop-logo-color');

  // تغيير الشعار: الجديد بيظهر على طول (مش القديم من الكاش)
  await expect(page.getByText('اتحفظ')).toHaveCount(0, { timeout: 15_000 });
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'هوية المحل' }).click();
  await page.getByLabel('لوجو المحل').setInputFiles({ name: 'logo2.jpg', mimeType: 'image/jpeg', buffer: await bigJpeg(page, '#c20') });
  // "حفظ" على طول (قبل ما الصورة الكبيرة تخلص قراية): الحفظ بيستنى، والجديد هو اللي بيتحفظ
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  // (النسخة الحرارية أبيض وأسود بس، فممكن تطلع زي القديمة لصورتين متشابهين. الملونة لازم تتغير)
  await page.goto(dev.replace('/devices/', '/print/invoice/'));
  await expect(page.getByTestId('shop-logo-color')).toBeVisible();
  expect(await src(page, 'shop-logo-color')).not.toBe(i1);
  await page.goto(dev.replace('/devices/', '/print/receipt/'));
  await expect(page.getByTestId('shop-logo-thermal')).toBeVisible();
  await cust.reload();
  await expect(cust.getByTestId('shop-logo-color')).toBeVisible();
  expect(await src(cust, 'shop-logo-color')).not.toBe(t1);
  await ctx.close();

  // الرفع على التخزين فشل (صلاحيات): الشعار بيتحفظ وبيظهر، والسبب مكتوب بالعربي
  await expect(page.getByText('اتحفظ')).toHaveCount(0, { timeout: 15_000 });
  await page.route('**/storage/v1/object/shop-logos/**', (r) => r.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ statusCode: '403', error: 'Unauthorized', message: 'new row violates row-level security policy' }) }));
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'هوية المحل' }).click();
  await page.getByLabel('لوجو المحل').setInputFiles('public/icon-512.png');
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByTestId('logo-error')).toContainText('اللوجو اتحفظ وبيظهر');
  await expect(page.getByTestId('logo-error')).toContainText('مش مسموح بالرفع');
  await page.unroute('**/storage/v1/object/shop-logos/**');
  await page.goto(dev.replace('/devices/', '/print/receipt/'));
  await expect(page.getByTestId('shop-logo-thermal')).toBeVisible();
});
