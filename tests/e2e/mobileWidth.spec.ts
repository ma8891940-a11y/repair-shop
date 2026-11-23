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
    // بنفحص كل عنصر دايمًا (مش بس لو scrollWidth زاد): في RTL اللي طالع ناحية اليمين ما بيبانش في scrollWidth،
    // واللي جوه حاوية overflow-hidden بيتقص من غير ما الصفحة تتسحب
    for (const el of Array.from(document.querySelectorAll<HTMLElement>('body *'))) {
      const r = el.getBoundingClientRect();
      if (r.width <= 1 || r.height <= 1 || (r.right <= w + 1 && r.left >= -1)) continue;
      // الزخرفة (الخلفية والتوهج) aria-hidden، ومش محتوى
      if (el.closest('[aria-hidden="true"]') || getComputedStyle(el).visibility === 'hidden') continue;
      // جوه حاوية بتتسحب لوحدها (جدول عريض مثلًا): مقصود. النوافذ بتتفحص لوحدها
      let p = el.parentElement;
      let scrolls = false;
      while (p && p !== document.body) {
        const o = getComputedStyle(p).overflowX;
        if (o === 'auto' || o === 'scroll') {
          scrolls = true;
          break;
        }
        p = p.parentElement;
      }
      if (scrolls) continue;
      const id = el.dataset.testid ? `[data-testid=${el.dataset.testid}]` : '';
      out.push(`${el.tagName.toLowerCase()}${id}.${String(el.className).split(' ').slice(0, 4).join('.')} (${Math.round(r.left)}..${Math.round(r.right)})`);
      if (out.length >= 8) break;
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
    if (lang === 'en') {
      // اللغة بتتقري مرة واحدة وقت تحميل الصفحة، والتنقل بالـ hash ما بيعيدش التحميل
      await page.evaluate(() => localStorage.setItem('lang', 'en'));
      await page.reload();
      await afterSplash(page);
    }
    expect(await page.evaluate(() => document.documentElement.dir)).toBe(lang === 'en' ? 'ltr' : 'rtl');

    const fails: string[] = [];
    // كل مشكلة بتتطبع على طول، عشان لو الاختبار وقف في النص يبان اللي اتقاس
    const note = (x: string) => {
      fails.push(x);
      console.log(`[mobileWidth ${lang}] ${x}`);
    };
    const check = async (what: string) => {
      await page.waitForTimeout(300);
      const m = await measure(page);
      if (m.scroll > m.client || m.out.length) note(`${what}: scrollWidth ${m.scroll} / ${m.client}\n    ${m.out.join('\n    ')}`);
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
          const name = page.getByTestId('device-title');
          if (!(await name.isVisible()) || !(await name.innerText()).includes(LONG_MODEL)) note(`${w}px ${p}: اسم الجهاز مش ظاهر كله`);
          else if (await name.evaluate((el) => el.scrollWidth > el.clientWidth + 1)) note(`${w}px ${p}: اسم الجهاز مقصوص`);
        }
        if (p === '/#/inventory') {
          await page.getByTestId('op-sale').click();
          const dlg = page.getByRole('dialog');
          await expect(dlg).toBeVisible();
          await check(`${w}px نافذة البيع`);
          // جسم النافذة بيتسحب لوحده (overflow auto)، فبنقيسه هو نفسه
          const body = await dlg.evaluate((el) =>
            Array.from(el.querySelectorAll<HTMLElement>('*'))
              .filter((x) => getComputedStyle(x).overflowY === 'auto' && x.scrollWidth > x.clientWidth + 1)
              .map((x) => `${x.scrollWidth} > ${x.clientWidth} ${String(x.className).split(' ').slice(0, 3).join('.')}`),
          );
          if (body.length) note(`${w}px نافذة البيع: المحتوى أعرض من النافذة ${body.join(' | ')}`);
          // زرار الحفظ ظاهر جوه الشاشة من غير سحب أفقي
          const save = dlg.getByTestId('lines-save');
          // الزرار بيبقى disabled (pointer-events none) لحد ما الخزن توصل، وelementFromPoint بيعدّيه
          await expect(save).toBeEnabled();
          await save.scrollIntoViewIfNeeded({ timeout: 5000 }).catch(() => {});
          const b = await save.boundingBox({ timeout: 5000 }).catch(() => null);
          if (!b || b.x < 0 || b.x + b.width > w + 1) note(`${w}px نافذة البيع: زرار الحفظ بره الشاشة (${JSON.stringify(b)})`);
          // ومش متغطي (بالشريط اللي تحت مثلًا): أول عنصر في نص الزرار هو الزرار نفسه
          else if (!(await save.evaluate((el) => { const r = el.getBoundingClientRect(); const top = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2); return !!top && el.contains(top); }))) note(`${w}px نافذة البيع: زرار الحفظ متغطي`);
          await page.keyboard.press('Escape');
        }
      }
    }
    expect(fails, fails.join('\n')).toEqual([]);
  });
}
