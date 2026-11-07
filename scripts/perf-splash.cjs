// قياس الافتتاحية على نسخة الإنتاج، على جهاز عادي وعلى جهاز ضعيف (معالج أبطأ 4 مرات).
// الاستخدام: npm run build && npm run preview (في Terminal تاني)، وبعدين: npm run perf:splash
// بيقيس من لحظة فتح البرنامج لحد ما اللوجو يستقر في مكانه، "أول مرة" (من غير أي حاجة محفوظة) و"مرة تانية".
const { chromium } = require('@playwright/test');
const BASE = process.argv[2] || 'http://localhost:5173';
const RUNS = Number(process.argv[3] || 5);

async function once(browser, cpu, warm) {
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 768 }, colorScheme: 'dark' });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  if (warm) {
    await page.goto(BASE + '/');
    await page.waitForTimeout(3000);
  }
  await page.addInitScript(() => {
    const T = (window.__T = {});
    let last = null;
    const tick = () => {
      const f = document.querySelector('[data-testid="logo-flight"]');
      if (f && f.style.transform !== last) {
        last = f.style.transform;
        T.landed = performance.now();
      }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
  await page.goto(BASE + '/');
  await page.waitForTimeout(4000);
  const t = await page.evaluate(() => window.__T.landed ?? null);
  await ctx.close();
  return t === null ? null : Math.round(t);
}

(async () => {
  const browser = await chromium.launch();
  for (const cpu of [1, 4]) {
    for (const warm of [false, true]) {
      const r = [];
      for (let i = 0; i < RUNS; i++) r.push(await once(browser, cpu, warm));
      const ok = r.filter((x) => x !== null).sort((a, b) => a - b);
      const med = ok[Math.floor(ok.length / 2)];
      console.log(`${cpu === 1 ? 'جهاز عادي' : 'جهاز ضعيف (×4)'} · ${warm ? 'مرة تانية' : 'أول مرة'}: ${r.join(' / ')} مللي ثانية (المتوسط ${med}، الأبطأ ${ok[ok.length - 1]})`);
    }
  }
  await browser.close();
})();
