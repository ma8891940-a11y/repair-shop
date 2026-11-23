import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

// بند 7 (qa-37): مفيش سحب أفقي على الموبايل (360 و390 و414)، بالعربي والإنجليزي، والوضعين (مشروعي mobile-dark وmobile-light).
// ممنوع نخفي العيب بـ overflow-x:hidden: الاختبار بيقيس document.documentElement.scrollWidth نفسه، وبيطبع العناصر اللي طالعة بره.

const DB = process.env.E2E_DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
const WIDTHS = [360, 390, 414];
const LONG_MODEL = 'Galaxy Z Fold6 Ultra Thom Browne Limited Edition 1TB';

/** العناصر اللي طالعة بره الشاشة (لتشخيص الفشل) */
async function measure(page: Page) {
  return page.evaluate(() => {
    const de = document.documentElement;
    const w = de.clientWidth;
    const out: string[] = [];
    if (de.scrollWidth > w) {
      for (const el of Array.from(document.querySelectorAll<HTMLElement>('body *'))) {
        const r = el.getBoundingClientRect();
        if (r.width === 0 || (r.right <= w + 1 && r.left >= -1)) continue;
        // العنصر اللي جوه حاوية بتتسحب لوحدها (جدول عريض مثلًا) مش مشكلة
        let p = el.parentElement;
        let scrolls = false;
        while (p && p !== document.body) {
          const o = getComputedStyle(p).overflowX;
          if (o === 'auto' || o === 'scroll' || o === 'hidden' || o === 'clip') {
            scrolls = true;
            break;
          }
          p = p.parentElement;
        }
        if (scrolls) continue;
        const id = el.dataset.testid ? `[data-testid=${el.dataset.testid}]` : '';
        out.push(`${el.tagName.toLowerCase()}${id}.${String(el.className).split(' ').slice(0, 4).join('.')} (${Math.round(r.left)}..${Math.round(r.right)})`);
        if (out.length >= 6) break;
      }
    }
    return { scroll: de.scrollWidth, client: w, out };
  });
}

async function seed(email: string, deviceUrl: string) {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  try {
    const { id: uid } = (await db.query(`select id from profiles where email = $1`, [email])).rows[0];
    const dev = deviceUrl.split('/').pop()!;
    // اسم جهاز طويل جدًا: لازم يلف، مش يختفي ولا يزق الصفحة
    await db.query(`update devices set model = $1 where id = $2`, [LONG_MODEL, dev]);
    await db.query('begin');
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: uid, role: 'authenticated' })]);
    await db.query('set local role authenticated');
    await db.query(`insert into items(id, shop_id, kind, name, sale_price) values ($1, gen_random_uuid(), 'service', 'خدمة باسم طويل جدًا عشان نختبر اللف في نافذة البيع على الموبايل', 15025)`, [randomUUID()]);
    await db.query('commit');
  } finally {
    await db.end();
  }
}

for (const lang of ['ar', 'en'] as const) {
  test(`الموبايل (${lang}): مفيش سحب أفقي في الصفحات والنوافذ على 360 و390 و414`, async ({ page }, info) => {
    test.skip(!info.project.name.startsWith('mobile'), 'مقاسات الموبايل بس');
    test.setTimeout(300_000);
    await prefs(page, info);
    const email = uniq(`mw-${lang}`);
    await registerShop(page, email, 'محل اختبار عرض الموبايل الطويل');
    const device = await quickIntake(page, '01012345678', 'عميل باسم طويل شوية عشان الاختبار');
    await seed(email, device);
    if (lang === 'en') await page.evaluate(() => localStorage.setItem('lang', 'en'));

    const fails: string[] = [];
    const check = async (what: string) => {
      await page.waitForTimeout(300);
      const m = await measure(page);
      if (m.scroll > m.client) fails.push(`${what}: scrollWidth ${m.scroll} > ${m.client}\n    ${m.out.join('\n    ')}`);
    };
    const pages = ['/#/', '/#/devices', device, '/#/intake', '/#/customers', '/#/inventory', '/#/finance', '/#/settings'];
    for (const w of WIDTHS) {
      await page.setViewportSize({ width: w, height: 800 });
      for (const p of pages) {
        await page.goto(p);
        await afterSplash(page);
        await check(`${w}px ${p}`);
        if (p === device) {
          // اسم الجهاز الطويل ظاهر كله (بيلف)، مش مقصوص بـ "..."
          const name = page.getByText(LONG_MODEL).first();
          await expect(name).toBeVisible();
          const cut = await name.evaluate((el) => el.scrollWidth > el.clientWidth + 1);
          if (cut) fails.push(`${w}px ${p}: اسم الجهاز مقصوص`);
        }
        if (p === '/#/inventory') {
          await page.getByTestId('op-sale').click();
          const dlg = page.getByRole('dialog');
          await expect(dlg).toBeVisible();
          await check(`${w}px نافذة البيع`);
          // زرار الحفظ ظاهر جوه الشاشة من غير سحب أفقي
          const save = dlg.locator('button[type=submit]').last();
          await save.scrollIntoViewIfNeeded();
          const b = await save.boundingBox();
          if (!b || b.x < 0 || b.x + b.width > w + 1) fails.push(`${w}px نافذة البيع: زرار الحفظ بره الشاشة (${JSON.stringify(b)})`);
          await page.keyboard.press('Escape');
        }
      }
    }
    expect(fails, fails.join('\n')).toEqual([]);
  });
}
