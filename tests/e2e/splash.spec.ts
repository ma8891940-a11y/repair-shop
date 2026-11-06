import { expect, test, type Page } from '@playwright/test';
import { prefs } from './helpers';

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
        scan: !!q('splash-scan'),
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
type Frame = { t: number; boot?: boolean; splash?: boolean; glow?: boolean; scan?: boolean; flight?: boolean; sameCanvas?: boolean | null; hero?: { cx: number; cy: number } | null; landed?: DOMRect | null; converge?: boolean };
const frames = (page: Page) => page.evaluate(() => (window as unknown as { __splash: unknown[] }).__splash) as Promise<Frame[]>;

test('الافتتاحية: اللوجو ثابت من أول لحظة ← في النص بالظبط ← تجمّع وتوهج وسكان ← بيطير لمكانه، والخلفية نفس الخلفية، وأقل من ثانية ونص', async ({ page }, info) => {
  await prefs(page, info);
  // قبل ما الكود يحمّل: نأخّر الكود ونتأكد إن الخلفية واللوجو الثابت ظاهرين (مفيش شاشة بيضا)
  let release: () => void = () => undefined;
  const gate = new Promise<void>((ok) => (release = ok));
  await page.route(/\/src\/main\.tsx/, async (route) => {
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
  expect(heroes.length).toBeGreaterThan(5);
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
});

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
