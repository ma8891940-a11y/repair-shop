import { expect, test, type Page } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq } from './helpers';

/** بيسجّل كل فريم: الافتتاحية واللوجو والتوهج والسكان والانتقال، وهل الخلفية هي نفس الـ canvas */
async function record(page: Page) {
  await page.addInitScript(() => {
    const log: Record<string, unknown>[] = [];
    (window as unknown as { __splash: unknown }).__splash = log;
    let firstCanvas: Element | null = null;
    const t0 = performance.now();
    window.addEventListener('circuit:converge', () => log.push({ t: performance.now() - t0, converge: true }));
    const tick = () => {
      const q = (s: string) => document.querySelector(`[data-testid="${s}"]`);
      const canvas = document.querySelector('[data-testid="stage-bg"] canvas');
      if (canvas && !firstCanvas) firstCanvas = canvas;
      const hero = document.querySelector('[data-testid="splash"] img');
      const r = hero?.getBoundingClientRect();
      const landed = [...document.querySelectorAll('[data-testid="app-mark"]')].find((el) => !el.closest('[data-testid="splash"]') && getComputedStyle(el).visibility !== 'hidden' && el.getClientRects().length > 0);
      log.push({
        t: performance.now() - t0,
        boot: !!document.getElementById('boot'),
        splash: !!q('splash'),
        glow: !!q('splash-glow'),
        // العنصر الخاص بشكل الحركة: الخط المضيء (رسم)، أو اللمعة (ظهور بلمعة)، أو القطع (تجميع)
        scan: !!(q('splash-outline') || q('splash-sheen') || q('splash-pieces')),
        style: q('logo-intro-draw') ? 'draw' : q('logo-intro-shine') ? 'shine' : q('logo-intro-assemble') ? 'assemble' : null,
        flight: !!q('logo-flight'),
        sameCanvas: canvas ? canvas === firstCanvas : null,
        hero: r ? { cx: r.left + r.width / 2, cy: r.top + r.height / 2 } : null,
        landed: landed ? (landed as HTMLElement).getBoundingClientRect().toJSON() : null,
      });
      if (log.length < 600) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}
type Frame = { t: number; boot?: boolean; splash?: boolean; glow?: boolean; scan?: boolean; style?: string | null; flight?: boolean; sameCanvas?: boolean | null; hero?: { cx: number; cy: number } | null; landed?: DOMRect | null; converge?: boolean };
const frames = (page: Page) => page.evaluate(() => (window as unknown as { __splash: unknown[] }).__splash) as Promise<Frame[]>;

for (const style of ['draw', 'shine', 'assemble'] as const) {
test(`الافتتاحية: اللوجو ثابت من أول لحظة ← في النص بالظبط ← تجمّع وتوهج وسكان ← بيطير لمكانه، والخلفية نفس الخلفية، وأقل من ثانية ونص [${style}]`, async ({ page }, info) => {
  await page.addInitScript((st) => localStorage.setItem('logo-anim', st), style);
  await prefs(page, info);
  // قبل ما الكود يحمّل: نأخّر الكود ونتأكد إن الخلفية واللوجو الثابت ظاهرين (مفيش شاشة بيضا)
  let release: () => void = () => undefined;
  const gate = new Promise<void>((ok) => (release = ok));
  // (في npm run dev الكود هو src/main.tsx، وفي نسخة الإنتاج assets/index-xxxx.js)
  await page.route(/\/src\/main\.tsx|\/assets\/index-[\w-]+\.js/, async (route) => {
    await gate;
    await route.continue();
  });
  await record(page);
  // الكود من نوع module بيأخّر DOMContentLoaded، فبنستنى أول استجابة بس
  await page.goto('/', { waitUntil: 'commit' });
  const boot = page.locator('#boot img');
  await expect(boot).toBeVisible();
  expect(await boot.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0)).toBe(true);
  const bg = await page.evaluate(() => getComputedStyle(document.documentElement).backgroundColor);
  expect(bg).toBe((info.project.metadata as { theme?: string }).theme === 'light' ? 'rgb(238, 243, 249)' : 'rgb(11, 15, 18)');
  release();

  await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
  await expect.poll(async () => (await frames(page)).some((f) => f.landed && !f.splash && !f.flight), { timeout: 10_000 }).toBe(true);
  const fs = await frames(page);
  const vp = page.viewportSize()!;

  // اللوجو في نص الشاشة بالظبط
  const heroes = fs.filter((f) => f.splash && f.hero);
  // لازم فريمات كفاية نتأكد منها (بنتأكد من آخر 3). لو التحميل بطيء الافتتاحية بتبقى أقصر بالتصميم (src/lib/splashTiming.ts)
  expect(heroes.length).toBeGreaterThanOrEqual(3);
  for (const f of heroes.slice(-3)) {
    expect(Math.abs(f.hero!.cx - vp.width / 2)).toBeLessThan(1.5);
    expect(Math.abs(f.hero!.cy - vp.height / 2)).toBeLessThan(1.5);
  }
  // التوهج والسكان والتجمّع حصلوا، والانتقال المشترك حصل
  expect(fs.some((f) => f.glow)).toBe(true);
  expect(fs.some((f) => f.scan)).toBe(true);
  expect(fs.some((f) => f.converge)).toBe(true);
  expect(fs.some((f) => f.flight)).toBe(true);
  // الخلفية نفس الـ canvas طول الوقت (ما اتشالتش ورجعت)
  expect(fs.filter((f) => f.sameCanvas === false)).toHaveLength(0);
  expect(fs.some((f) => f.sameCanvas === true)).toBe(true);
  // اللوجو الثابت اتشال بعد ما الافتتاحية ظهرت (مفيش لحظة من غير لوجو)
  const firstSplash = fs.findIndex((f) => f.splash);
  expect(fs.slice(0, firstSplash).every((f) => f.boot)).toBe(true);
  // المدة: من أول فريم للافتتاحية لحد ما اللوجو استقر في مكانه أقل من ثانية ونص
  const start = fs[firstSplash].t;
  const end = fs.find((f, i) => i > firstSplash && f.landed && !f.splash && !f.flight)!.t;
  expect(end - start).toBeLessThan(1500);
  console.log(`splash-duration ${info.project.name}: ${Math.round(end - start)}ms`);
  // اللوجو استقر في مكانه في شاشة الدخول (فوق)
  const landed = fs.find((f) => f.landed && !f.splash && !f.flight)!.landed!;
  expect(landed.top).toBeLessThan(80);
  // شكل الحركة اللي اتختار هو اللي اشتغل، وعنصره ظهر
  expect(fs.filter((f) => f.style).every((f) => f.style === style)).toBe(true);
});
}

test('الافتتاحية مع "تقليل الحركة": الخلفية ثابتة واللوجو بيظهر ظهور بسيط من غير توهج ولا سكان ولا تجمّع ولا طيران', async ({ browser }, info) => {
  const ctx = await browser.newContext({ ...info.project.use, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  await prefs(page, info);
  await record(page);
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
  await expect.poll(async () => (await frames(page)).some((f) => f.landed && !f.splash), { timeout: 10_000 }).toBe(true);
  const fs = await frames(page);
  expect(fs.some((f) => f.glow || f.scan || f.flight || f.converge)).toBe(false);
  const shot = () => page.evaluate(() => document.querySelector<HTMLCanvasElement>('[data-testid="stage-bg"] canvas')!.toDataURL());
  const a = await shot();
  await page.waitForTimeout(500);
  expect(await shot()).toBe(a);
  await ctx.close();
});

test('شرط الأمان: الأداء تحت 50 إطار لمدة 2 ثانية في الدخول ← الخلفية بتثبت بنعومة من غير ما تختفي، وبتتحفظ للجهاز، و"رجّع الحركة" من الإعدادات', async ({ page, browserName }, info) => {
  test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
  test.setTimeout(150_000);
  await prefs(page, info);
  // الحارس مقفول في npm run dev، فبنشغّله للاختبار ده بس
  await page.addInitScript(() => localStorage.setItem('bg-guard-dev', '1'));
  await page.goto('/');
  await afterSplash(page);
  const stage = page.getByTestId('stage-bg');
  await expect(stage).not.toHaveAttribute('data-auto-still', '');
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  await expect(stage).toHaveAttribute('data-auto-still', '', { timeout: 25_000 });
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  expect(await page.evaluate(() => localStorage.getItem('bg-still-v3'))).toBe('1');
  // ما اختفتش: نفس الخلفية والخطوط لسه مرسومة، وبعد ما الحركة تنطفي بتثبت
  const shot = () => page.evaluate(() => document.querySelector<HTMLCanvasElement>('[data-testid="stage-bg"] canvas')!.toDataURL());
  await page.waitForTimeout(800);
  const a = await shot();
  expect(a.length).toBeGreaterThan(1000);
  await page.waitForTimeout(500);
  expect(await shot()).toBe(a);
  // المرة الجاية بتفتح ثابتة على طول
  await page.reload();
  await expect(page.getByTestId('stage-bg')).toHaveAttribute('data-auto-still', '');
  await afterSplash(page);
  const b = await shot();
  await page.waitForTimeout(600);
  expect(await shot()).toBe(b);
  // "رجّع الحركة" من الإعدادات (المظهر)
  await registerShop(page, uniq('bgstill'));
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'المظهر' }).click();
  // السبب ظاهر بوضوح، ومعاه الحل
  await expect(page.getByTestId('motion-state')).toHaveAttribute('data-state', 'still');
  await expect(page.getByTestId('motion-reason-auto')).toContainText('اتثبتت تلقائيًا عشان البطء');
  await page.getByRole('button', { name: 'رجّع الحركة' }).click();
  expect(await page.evaluate(() => localStorage.getItem('bg-still-v3'))).toBeNull();
  await expect(page.getByRole('button', { name: 'رجّع الحركة' })).toHaveCount(0);
  await expect(page.getByTestId('motion-state')).toHaveAttribute('data-state', 'live');
});

test('شرط الأمان ما بيشتغلش في npm run dev، ولا وقت التحميل، ولا والتبويب في الخلفية، والقيمة القديمة بتتمسح', async ({ page, browserName }, info) => {
  test.skip(browserName !== 'chromium', 'إبطاء المعالج متاح في Chromium بس');
  // الاختبار ده عن سلوك npm run dev نفسه. في تشغيل النسخة النهائية (E2E_PROD) الحارس شغال عادي، واختبار "شرط الأمان" اللي فوق بيغطيه
  test.skip(!!process.env.E2E_PROD, 'سلوك وضع التطوير بس');
  test.setTimeout(90_000);
  await prefs(page, info);
  // قيمة قديمة اتسجلت غلط قبل كده (وقت dev): بتتمسح، والحركة ترجع
  await page.addInitScript(() => localStorage.setItem('bg-still', '1'));
  await page.goto('/');
  await afterSplash(page);
  expect(await page.evaluate(() => localStorage.getItem('bg-still'))).toBeNull();
  const stage = page.getByTestId('stage-bg');
  await expect(stage).not.toHaveAttribute('data-auto-still', '');
  // بطء شديد في npm run dev (من غير مفتاح الاختبار): الحركة ما بتثبتش
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  await page.waitForTimeout(7_000);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await expect(stage).not.toHaveAttribute('data-auto-still', '');
  expect(await page.evaluate(() => localStorage.getItem('bg-still-v3'))).toBeNull();
  // مع الحارس شغال: بطء وقت التحميل بس (أول ثانية بعد ما الصفحة تخلص) ما بيتحسبش
  await page.evaluate(() => localStorage.setItem('bg-guard-dev', '1'));
  await page.reload();
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  await page.waitForTimeout(1_200);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await page.waitForTimeout(5_000);
  await expect(stage).not.toHaveAttribute('data-auto-still', '');
  // والتبويب في الخلفية: الحارس بيقف. (في وضع الاختبار من غير شاشة، فتح تبويب تاني ما بيخفيش الصفحة، فبنبعت نفس الحدث بتاع المتصفح)
  const setHidden = (h: boolean) =>
    page.evaluate((hidden) => {
      Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
      Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (hidden ? 'hidden' : 'visible') });
      document.dispatchEvent(new Event('visibilitychange'));
    }, h);
  await setHidden(true);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 20 });
  await page.waitForTimeout(4_000);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await setHidden(false);
  await page.waitForTimeout(3_000);
  await expect(stage).not.toHaveAttribute('data-auto-still', '');
});

test('"تقليل الحركة" من الجهاز: الإعدادات ← المظهر بتقول السبب والحل', async ({ browser }, info) => {
  test.setTimeout(120_000);
  const ctx = await browser.newContext({ ...info.project.use, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  await prefs(page, info);
  await registerShop(page, uniq('reduced'));
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'المظهر' }).click();
  await expect(page.getByTestId('motion-state')).toHaveAttribute('data-state', 'still');
  await expect(page.getByTestId('motion-reason-reduced')).toContainText('"تقليل الحركة" شغال في الجهاز');
  await expect(page.getByTestId('motion-reason-reduced')).toContainText('تأثيرات الحركة');
  await expect(page.getByTestId('motion-reason-auto')).toHaveCount(0);
  await ctx.close();
});
