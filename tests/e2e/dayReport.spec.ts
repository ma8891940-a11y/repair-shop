import { expect, test } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

// اليوم بتوقيت القاهرة (YYYY-MM-DD)
const cairoDay = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(d);
const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/** نفس أرقام تجربة 22/11 بدوال البرنامج: صيانة 2500 + 500، وبيع كاش 600 + 150.25 */
async function seedDay(email: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const { id: uid, shop_id: shop } = (await db.query(`select id, shop_id from profiles where email = $1`, [email])).rows[0];
    const as = async (sql: string, params: unknown[] = []) => {
      await db.query('begin');
      try {
        await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
        await db.query('set local role authenticated');
        const r = await db.query(sql, params);
        await db.query('commit');
        return r;
      } catch (e) {
        await db.query('rollback');
        throw e;
      }
    };
    const cash = (await db.query(`select id from accounts where shop_id = $1 and kind = 'cash' and method = 'cash' order by created_at limit 1`, [shop])).rows[0].id;
    const cust = randomUUID();
    const srv = randomUUID();
    await as(`insert into customers(id, shop_id, name, phone) values ($1, gen_random_uuid(), 'عميل التقرير', '01055558888')`, [cust]);
    await as(`insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'خدمة التقرير', 1000)`, [srv]);
    for (const a of [250000, 50000]) await as(`select record_payment($1, $2, $3, $4)`, [randomUUID(), cust, cash, a]);
    for (const p of [60000, 15025]) await as(`select record_sale($1, $2::jsonb, $3)`, [randomUUID(), JSON.stringify([{ item: srv, qty: 1, price: p }]), cash]);
  } finally {
    await db.end();
  }
}

// بند 1 (qa-37): الكاش في التقرير اليومي = 3750.25 (صيانة + بيع)، والتسوية بروابط للقيود
test('التقرير اليومي: التحصيل كله 3750.25 وتسوية الخزنة بتفتح القيد', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  const email = uniq('day-rep');
  await registerShop(page, email, 'محل التقرير');
  await seedDay(email);
  await page.addInitScript(() => {
    window.print = () => {};
  });
  await page.goto(`/#/print/day/${cairoDay(new Date())}`);
  await afterSplash(page);
  const cashRow = page.getByTestId('day-collections').locator('tr[data-method="cash"]');
  await expect(cashRow.locator('[data-col="total"]')).toHaveText(/3,750\.25|3٬750٫25/);
  const box = page.getByTestId('day-box').first();
  await expect(box).toContainText(/3,750\.25|3٬750٫25/);
  const links = box.locator('a[href^="#/finance/entry/"]');
  await expect(links).toHaveCount(4);
  await links.first().click();
  await expect(page).toHaveURL(/#\/finance\/entry\//);
});
