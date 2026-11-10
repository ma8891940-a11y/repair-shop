import { expect, test, type Page } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq, withMotionDiag } from './helpers';

// الخلفية المتحركة: ما تثبتش بالغلط، وترجع لوحدها، وأسباب وقوفها واضحة، وشاشة التشخيص

/** الخلفية بتتحرك فعلًا؟ (الصورة بتتغير بين لحظتين) */
async function moving(page: Page) {
  const snap = () => page.evaluate(() => document.querySelector<HTMLCanvasElement>('[data-testid="stage-bg"] canvas')?.toDataURL() ?? '');
  const a = await snap();
  await page.waitForTimeout(600);
  const b = await snap();
  return a !== '' && a !== b;
}
const expectMoving = (page: Page, v = true) => withMotionDiag(page, `moving=${v}`, () => expect.poll(() => moving(page), { timeout: 10_000 }).toBe(v));
/** الحارس شغال في الاختبار حتى في npm run dev (بالمفتاح بتاع الاختبار) */
const guardOn = (page: Page) => page.addInitScript(() => localStorage.setItem('bg-guard-dev', '1'));
async function setHidden(page: Page, h: boolean) {
  await page.evaluate((hidden) => {
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (hidden ? 'hidden' : 'visible') });
    document.dispatchEvent(new Event('visibilitychange'));
  }, h);
}

test('توفير الطاقة (المتصفح مقفول على 30 إطار) والجهاز فاضي: الخلفية ما بتثبتش بالغلط', async ({ page }, info) => {
  test.setTimeout(60_000);
  await prefs(page, info);
  await guardOn(page);
  // requestAnimationFrame كل 33 مللي، والجهاز مش مشغول
  await page.addInitScript(() => {
    const q: FrameRequestCallback[] = [];
    let t: number | null = null;
    window.requestAnimationFrame = (cb) => {
      q.push(cb);
      if (t === null)
        t = window.setTimeout(() => {
          t = null;
          const now = performance.now();
          for (const c of q.splice(0)) c(now);
        }, 33);
      return q.length;
    };
    window.cancelAnimationFrame = () => undefined;
  });
  await page.goto('/');
  await afterSplash(page);
  await page.waitForTimeout(9_000);
  const still = await page.evaluate(() => localStorage.getItem('bg-still-v3'));
  if (still) console.log('GUARD-LOG', JSON.stringify(await page.evaluate(() => (window as unknown as { __motionDiag: { log: unknown[] } }).__motionDiag.log)));
  expect(still).toBeNull();
  await expect(page.getByTestId('stage-bg')).not.toHaveAttribute('data-auto-still', '');
});

test('التنقل بين الدخول والتسجيل والافتتاحية، وإخفاء التبويب ورجوعه: الخلفية بتكمّل من غير ما تتقفل', async ({ page }, info) => {
  test.setTimeout(90_000);
  await prefs(page, info);
  await guardOn(page);
  await page.goto('/');
  await afterSplash(page);
  await expectMoving(page);
  for (let i = 0; i < 3; i++) {
    await page.getByRole('link', { name: 'تسجيل محل جديد' }).click();
    await expect(page.getByRole('heading', { name: 'بيانات المحل' })).toBeVisible();
    await expectMoving(page);
    await page.getByRole('link', { name: 'سجّل دخول' }).click();
    await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
    await expectMoving(page);
  }
  // التبويب اتخفى (أو الشاشة اتصغّرت) ورجع: الحركة بترجع لوحدها
  await setHidden(page, true);
  await page.waitForTimeout(1_500);
  await setHidden(page, false);
  await expectMoving(page);
  // من الأول (الافتتاحية تاني)
  await page.reload();
  await afterSplash(page);
  await expectMoving(page);
  expect(await page.evaluate(() => localStorage.getItem('bg-still-v3'))).toBeNull();
});

test('"تقليل الحركة" من الويندوز: الخلفية بتقف، ولما يتقفل بترجع لوحدها من غير تحديث الصفحة', async ({ page }, info) => {
  await prefs(page, info);
  await page.goto('/');
  await afterSplash(page);
  await expectMoving(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expectMoving(page, false);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expectMoving(page);
});

test('شاشة التشخيص (Ctrl+Alt+Shift+M، مش المحجوز في Chrome): عدد الإطارات، والخلفية شغالة ولا واقفة، وسبب الوقوف', async ({ page }, info) => {
  await prefs(page, info);
  await page.goto('/');
  await afterSplash(page);
  await expect(page.getByTestId('motion-diag')).toHaveCount(0);
  // الاختصار القديم (محجوز في Chrome لحفظ التبويبات في المفضلة) ما بقاش بيفتحها
  await page.keyboard.press('Control+Shift+D');
  await expect(page.getByTestId('motion-diag')).toHaveCount(0);
  await page.keyboard.press('Control+Alt+Shift+M');
  const d = page.getByTestId('motion-diag');
  await expect(d).toBeVisible();
  await expect.poll(async () => Number(await page.getByTestId('diag-fps').innerText())).toBeGreaterThan(5);
  await expect(page.getByTestId('diag-state')).toHaveText('شغالة');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.getByTestId('diag-state')).toHaveText('واقفة');
  await expect(page.getByTestId('diag-reason')).toHaveText('الويندوز طالب تقليل الحركة');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.keyboard.press('Control+Alt+Shift+M');
  await expect(d).toHaveCount(0);
});

test('الإعدادات ← المظهر: سبب الوقوف بوضوح وخطوات الحل لويندوز 10 و11، و"رجّع الحركة" بترجّعها', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('motion'));
  // اتثبتت قبل كده عشان البطء
  await page.evaluate(() => {
    localStorage.setItem('bg-still-v3', '1');
    window.dispatchEvent(new CustomEvent('bg-still', { detail: true }));
  });
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'المظهر' }).click();
  await expect(page.getByTestId('motion-state')).toHaveAttribute('data-state', 'still');
  const auto = page.getByTestId('motion-reason-auto');
  await expect(auto).toContainText('اتثبتت تلقائيًا عشان البطء');
  await expect(auto).toContainText('Energy saver');
  await expect(auto).toContainText('الويندوز 10 و11');
  // "تقليل الحركة": السبب وخطوات ويندوز 10 و11
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const red = page.getByTestId('motion-reason-reduced');
  await expect(red).toContainText('"تقليل الحركة" شغال في الجهاز');
  await expect(red).toContainText('الويندوز 11');
  await expect(red).toContainText('الويندوز 10');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expect(red).toHaveCount(0);
  // جوه البرنامج: الخلفية ثابتة بالتصميم، والإعدادات بتقول كده صريح، وزرار "تشخيص الحركة" بيفتح الشاشة من غير اختصار
  await expect(page.getByTestId('motion-inside-note')).toContainText('ثابتة بالتصميم');
  await page.getByTestId('open-motion-diag').click();
  await expect(page.getByTestId('motion-diag')).toBeVisible();
  await expect(page.getByTestId('diag-reason')).toContainText('اتثبتت عشان البطء');
  // حركة لوجو البرنامج: 3 أشكال بمعاينة، والاختيار بيتحفظ وبيشتغل من أول فتحة جاية
  const picker = page.getByTestId('logo-anim-picker');
  await expect(picker.getByRole('radio')).toHaveCount(3);
  await expect(page.getByTestId('logo-anim-draw')).toHaveAttribute('aria-checked', 'true');
  await page.getByTestId('logo-anim-assemble').click();
  await expect(page.getByTestId('logo-anim-assemble')).toHaveAttribute('aria-checked', 'true');
  expect(await page.evaluate(() => [localStorage.getItem('logo-anim'), document.documentElement.getAttribute('data-logo-anim')])).toEqual(['assemble', 'assemble']);
  await page.reload();
  await expect(page.getByTestId('logo-intro-assemble')).toHaveCount(1, { timeout: 5_000 }).catch(() => undefined);
  await page.getByRole('tab', { name: 'المظهر' }).click().catch(() => undefined);
  await expect(page.getByTestId('logo-anim-assemble')).toHaveAttribute('aria-checked', 'true');
  await page.getByTestId('logo-anim-draw').click();
  await auto.getByRole('button', { name: 'رجّع الحركة' }).click();
  await expect(page.getByTestId('motion-state')).toHaveAttribute('data-state', 'live');
  expect(await page.evaluate(() => localStorage.getItem('bg-still-v3'))).toBeNull();
});

test('تثبيت قديم اتسجل بقواعد الحارس القديمة (قبل تصليح الـ 30 إطار) بيتمسح بعد التحديث، والحركة بترجع', async ({ page }, info) => {
  await prefs(page, info);
  await page.addInitScript(() => {
    if (!sessionStorage.getItem('seeded')) {
      localStorage.setItem('bg-still-v2', '1');
      sessionStorage.setItem('seeded', '1');
    }
  });
  await page.goto('/');
  await afterSplash(page);
  expect(await page.evaluate(() => [localStorage.getItem('bg-still-v2'), localStorage.getItem('bg-still-v3')])).toEqual([null, null]);
  await expectMoving(page);
});
