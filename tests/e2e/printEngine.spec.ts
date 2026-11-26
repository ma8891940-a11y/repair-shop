import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// 50.6: الشاشات الفعلية بالمحرّك: القالب الحر بأماكنه وإزاحة الطابعة، وخط وحجم الخانة، ومن غير قالب زي ما هي
test('المحرّك في الإيصالات: A4 حر بطابعة مزاحة ← حراري بخانة بخط وحجم ← من غير قالب زي ما هو', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const email = uniq('engine');
  await registerShop(page, email, 'محل المحرّك');
  const url = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل المحرّك');
  const id = url.split('/').pop()!;

  // من غير قالب: نفس الإيصال
  await page.goto(`/#/print/receipt/${id}?preview=1`);
  await afterSplash(page);
  await expect(page.getByTestId('print-receipt')).toBeVisible();
  await expect(page.locator('[data-block=customer]')).toContainText('عميل المحرّك');
  expect(await page.locator('[data-block=customer]').evaluate((e) => (e as HTMLElement).style.fontSize)).toBe('');

  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const uid = (await db.query('select id from profiles where email = $1', [email])).rows[0].id as string;
    const printer = randomUUID();
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query(`insert into printers(id, shop_id, name, kind, width_mm, height_mm, margin_mm, offset_x, offset_y) values ($1, $1, 'ليزر', 'a4', 210, 297, 12, 1, 1)`, [printer]);
    const a4 = {
      paper: { kind: 'a4' },
      fields: [
        { key: 'customer', x: 20, y: 30, w: 80, h: 8, font: 'sans', pt: 12, align: 'start', bold: true },
        { key: 'device', x: 20, y: 40, w: 80, h: 8, font: 'sans', pt: 11, align: 'start', bold: false },
      ],
    };
    await db.query(`insert into print_templates(id, shop_id, doc, name, mode, blocks, layout, is_default, printer_id) values ($1, $1, 'receipt-a4', 'A4', 'free', '[]', $2, true, $3)`, [randomUUID(), JSON.stringify(a4), printer]);
    const blocks = [{ key: 'customer', show: true, size: 'md', align: 'start', bold: false, font: 'mono', pt: 14 }];
    await db.query(`insert into print_templates(id, shop_id, doc, name, mode, blocks, layout, is_default) values ($1, $1, 'receipt', 'حراري', 'flow', $2, '{}', true)`, [randomUUID(), JSON.stringify(blocks)]);
    await db.query('commit');
  } finally {
    await db.end();
  }

  await page.goto(`/#/print/receipt-a4/${id}`);
  await afterSplash(page);
  const free = page.getByTestId('print-receipt-a4');
  await expect(free.locator('[data-field=customer]')).toHaveText('عميل المحرّك');
  await expect(free.locator('[data-field=device]')).toHaveText('Samsung A35');
  expect(await free.locator('[data-field=customer]').evaluate((e) => [e.style.left, e.style.top])).toEqual(['20mm', '30mm']);
  expect(await free.evaluate((e) => (e.parentElement as HTMLElement).style.transform)).toBe('translate(1mm, 1mm)');

  await page.goto(`/#/print/receipt/${id}`);
  await afterSplash(page);
  const cust = page.getByTestId('print-receipt').locator('[data-block=customer]');
  await expect(cust).toContainText('عميل المحرّك');
  expect(await cust.evaluate((e) => [(e as HTMLElement).style.fontSize, (e as HTMLElement).style.fontFamily])).toEqual(['14pt', 'var(--font-mono)']);
});
