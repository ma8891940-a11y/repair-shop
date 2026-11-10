import { expect, test, type Page } from '@playwright/test';
import { afterSplash, prefs, quickIntake, registerShop, uniq, fillAmount } from './helpers';
import { readFileSync } from 'node:fs';

// التواريخ: يوم/شهر/سنة في العربي (07/11/2026 أو 7 نوفمبر 2026)، و7 Nov 2026 في الإنجليزي،
// ومن غير ما تتقلب على الشاشة أو في الطباعة، والتصدير نص عادي.

/** النهارده بتوقيت القاهرة */
function today() {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Cairo', day: '2-digit', month: '2-digit', year: 'numeric' }).formatToParts(new Date()).map((x) => [x.type, x.value]));
  const mon = new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Cairo', month: 'short' }).format(new Date());
  return { num: `${p.day}/${p.month}/${p.year}`, en: `${Number(p.day)} ${mon} ${p.year}`, day: p.day, year: p.year };
}

/**
 * كل تاريخ بالأرقام ظاهر في الصفحة: اليوم على الشمال والسنة على اليمين (مش مقلوب)،
 * وكل تاريخ بأسماء الشهور في العربي: اليوم على اليمين (أول الكلام) والسنة على الشمال.
 */
async function dateLayout(page: Page) {
  return page.evaluate(() => {
    const out: { text: string; ok: boolean }[] = [];
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const box = (n: Node, a: number, b: number) => {
      const r = document.createRange();
      r.setStart(n, a);
      r.setEnd(n, b);
      return r.getBoundingClientRect();
    };
    let n: Node | null;
    while ((n = walker.nextNode())) {
      const txt = n.textContent ?? '';
      for (const m of txt.matchAll(/(\d{2})\/(\d{2})\/(\d{4})/g)) {
        const d = box(n, m.index!, m.index! + 2);
        const y = box(n, m.index! + 6, m.index! + 10);
        if (d.width === 0 || y.width === 0) continue;
        out.push({ text: m[0], ok: Math.abs(d.top - y.top) > 4 || d.left < y.left });
      }
      for (const m of txt.matchAll(/(\d{1,2}) ([؀-ۿ]+) (\d{4})/g)) {
        const d = box(n, m.index!, m.index! + m[1].length);
        const y = box(n, m.index! + m[0].length - 4, m.index! + m[0].length);
        if (d.width === 0 || y.width === 0) continue;
        out.push({ text: m[0], ok: Math.abs(d.top - y.top) > 4 || d.left > y.left });
      }
    }
    return out;
  });
}
async function expectDatesOk(page: Page, where: string, must: string) {
  await expect(page.locator('body')).toContainText(must);
  const found = await dateLayout(page);
  expect(found.length, `${where}: مفيش تاريخ ظاهر`).toBeGreaterThan(0);
  expect(found.filter((f) => !f.ok), where).toEqual([]);
  // ومفيش تاريخ مقلوب (سنة/شهر/يوم)
  expect(await page.locator('body').innerText(), where).not.toMatch(/\b\d{4}\/\d{2}\/\d{2}\b/);
}

test('التواريخ في العربي (الشاشات، والإيصال، والفاتورة، وصفحة التتبع، وكشف الحساب، والطباعة، والتصدير) وفي الإنجليزي', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const { num, en } = today();
  await registerShop(page, uniq('dates'), 'محل التواريخ');
  const dev = await quickIntake(page, '01048484848', 'عميل التواريخ');
  // صفحة الجهاز
  await expectDatesOk(page, 'صفحة الجهاز', num);
  // دفعة عشان كشف الحساب يبقى فيه حركة
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '100');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();

  // الإيصال والفاتورة (على الشاشة وفي الطباعة)
  for (const kind of ['receipt', 'invoice']) {
    await page.goto(dev.replace('/devices/', `/print/${kind}/`));
    await expect(page.getByText('محل التواريخ').first()).toBeVisible();
    await expectDatesOk(page, kind, num);
    await page.emulateMedia({ media: 'print' });
    await expectDatesOk(page, `${kind} (طباعة)`, num);
    await page.emulateMedia({ media: 'screen' });
  }

  // صفحة التتبع (العميل)
  await page.goto(dev);
  await afterSplash(page);
  await page.getByRole('button', { name: 'واتساب' }).first().click();
  const msg = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  const token = (msg.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  await page.keyboard.press('Escape');
  const ctx = await browser.newContext(info.project.use);
  const cust = await ctx.newPage();
  await prefs(cust, info);
  await cust.goto(`/#/t/${token}`);
  await expect(cust.getByText('محل التواريخ').first()).toBeVisible();
  await expectDatesOk(cust, 'صفحة التتبع', num);
  await ctx.close();

  // كشف حساب العميل، والتصدير (نص عادي يوم/شهر/سنة من غير علامات)
  await page.goto('/#/customers');
  await page.getByText('عميل التواريخ').filter({ visible: true }).first().click();
  await page.getByRole('link', { name: 'كشف حساب' }).click();
  await expectDatesOk(page, 'كشف الحساب', num);
  // تصدير ← CSV (نفس الملف القديم بالظبط)
  await page.getByTestId('statement-export').click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByTestId('statement-export-csv').click()]);
  const csv = readFileSync((await dl.path())!, 'utf8');
  expect(csv).toContain(num);
  expect(csv).not.toMatch(/[‎‏⁦-⁩]/);
  expect(csv).not.toMatch(/\d{4}\/\d{2}\/\d{2}/);

  // الإنجليزي: 7 Nov 2026
  await page.goto('/#/settings');
  await page.getByRole('button', { name: 'Switch to English' }).first().click();
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');
  await page.goto(dev);
  await expect(page.locator('body')).toContainText(en);
  await page.goto(dev.replace('/devices/', '/print/receipt/'));
  await expect(page.locator('body')).toContainText(en);
  expect(await page.locator('body').innerText()).not.toMatch(/\b\d{4}\/\d{2}\/\d{2}\b/);
});
