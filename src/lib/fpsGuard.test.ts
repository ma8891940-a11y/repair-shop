import { describe, expect, it } from 'vitest';
import { FpsGuard } from './fpsGuard';

/** بيشغّل الحارس بمعدل إطارات ثابت لمدة معيّنة، ويرجّع وقت القفل (لو حصل) */
function run(g: FpsGuard, segments: Array<[fps: number, ms: number]>, start = 0): number | null {
  let t = start;
  g.start(t);
  for (const [fps, ms] of segments) {
    const step = 1000 / fps;
    const end = t + ms;
    while (t < end) {
      t += step;
      if (g.frame(t)) return t;
    }
  }
  return null;
}

describe('حارس أداء المؤثرات الكاملة', () => {
  it('60 إطار طول الوقت: ما بيقفلش', () => {
    expect(run(new FpsGuard(), [[60, 20_000]])).toBeNull();
  });

  it('30 إطار متواصل: بيقفل بعد ثانيتين سماح + 3 ثواني بطء (مش قبلهم)', () => {
    const at = run(new FpsGuard(), [[30, 20_000]])!;
    expect(at).not.toBeNull();
    expect(at).toBeGreaterThanOrEqual(5_000);
    expect(at).toBeLessThan(5_700);
  });

  it('البطء في أول ثانيتين بس (التحميل) ما بيتحسبش', () => {
    expect(run(new FpsGuard(), [[10, 2_000], [60, 10_000]])).toBeNull();
  });

  it('فترة السماح بتتخصم: 4.5 ثانية بطء من أول الشاشة = 2.5 ثانية محسوبة بس، فما بيقفلش', () => {
    expect(run(new FpsGuard(), [[10, 4_500], [60, 8_000]])).toBeNull();
  });

  it('بطء أقل من 3 ثواني وبعدين يتحسن: ما بيقفلش', () => {
    expect(run(new FpsGuard(), [[60, 2_000], [40, 2_500], [60, 5_000], [40, 2_500], [60, 5_000]])).toBeNull();
  });

  it('49 بيقفل و51 ما بيقفلش (الحد 50)', () => {
    expect(run(new FpsGuard(), [[49, 10_000]])).not.toBeNull();
    expect(run(new FpsGuard(), [[51, 10_000]])).toBeNull();
  });

  it('فجوة كبيرة (التبويب اتخفى) مش بطء، وبتبدأ سماح جديد', () => {
    const g = new FpsGuard();
    g.start(0);
    let t = 0;
    for (; t < 3_000; t += 1000 / 60) expect(g.frame(t)).toBe(false);
    t += 30_000; // التبويب اتخفى 30 ثانية
    expect(g.frame(t)).toBe(false);
    // بعد الرجوع: بطء لمدة ثانيتين بس (جوه فترة السماح الجديدة) ما يقفلش
    const back = t;
    for (; t < back + 1_900; t += 1000 / 20) expect(g.frame(t)).toBe(false);
  });

  it('بيقفل مرة واحدة بس لحد ما يبدأ من جديد', () => {
    const g = new FpsGuard();
    g.start(0);
    let trips = 0;
    for (let t = 0; t < 15_000; t += 1000 / 20) if (g.frame(t)) trips++;
    expect(trips).toBe(1);
  });
});
