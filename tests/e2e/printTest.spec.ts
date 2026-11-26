import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// 50.6: الطباعة التجريبية بخطوط إرشاد بالمقاس الحقيقي، وإزاحة الطابعة، والقالب الحر بحقوله في أماكنها بالمللي
test('الطباعة التجريبية: إيصال من غير قالب بمقاسه ← ملصق حر 50×30 بطابعة مزاحة: الحقول في أماكنها', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('testprint');
  await registerShop(page, email, 'محل التجربة');

  await page.goto('/#/print/test/receipt');
  await afterSplash(page);
  await expect(page.getByTestId('test-print')).toHaveAttribute('data-size', '80xauto');
  await expect(page.getByTestId('print-guides')).toBeVisible();
  await expect(page.getByTestId('test-no-template')).toBeVisible();

  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const uid = (await db.query('select id from profiles where email = $1', [email])).rows[0].id as string;
    const printer = randomUUID();
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query(`insert into printers(id, shop_id, name, kind, width_mm, height_mm, margin_mm, offset_x, offset_y) values ($1, $1, 'ملصقات', 'label', 50, 30, 0, 1.5, -2)`, [printer]);
    const layout = {
      paper: { kind: 'custom', w: 50, h: 30 },
      fields: [
        { key: 'customer', x: 2, y: 3, w: 30, h: 5, font: 'sans', pt: 9, align: 'start', bold: true },
        { key: 'text', x: 2, y: 20, w: 40, h: 5, font: 'mono', pt: 7, align: 'center', bold: false, text: 'سطر ثابت' },
      ],
    };
    await db.query(`insert into print_templates(id, shop_id, doc, name, mode, blocks, layout, is_default, printer_id) values ($1, $1, 'label', 'ملصق', 'free', '[]', $2, true, $3)`, [randomUUID(), JSON.stringify(layout), printer]);
    await db.query('commit');
  } finally {
    await db.end();
  }

  await page.goto('/#/print/test/label');
  await afterSplash(page);
  await expect(page.getByTestId('test-print')).toHaveAttribute('data-size', '50x30');
  const free = page.getByTestId('print-free');
  await expect(free.locator('[data-field=customer]')).toHaveText('أحمد محمود');
  await expect(free.locator('[data-field=text]')).toHaveText('سطر ثابت');
  expect(await free.locator('[data-field=customer]').evaluate((e) => [e.style.left, e.style.top, e.style.width, e.style.fontSize])).toEqual(['2mm', '3mm', '30mm', '9pt']);
  // الإزاحة على الصفحة كلها
  expect(await free.evaluate((e) => (e.parentElement as HTMLElement).style.transform)).toBe('translate(1.5mm, -2mm)');
  // المقاس الحقيقي: 50 مللي عرض
  const box = await free.boundingBox();
  expect(Math.round(box!.width)).toBe(Math.round((50 * 96) / 25.4));
  await expect(page.getByTestId('print-guides')).toBeVisible();
});
