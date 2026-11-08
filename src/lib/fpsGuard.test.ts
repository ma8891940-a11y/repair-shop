import { describe, expect, it } from 'vitest';
import { BG_GUARD, FpsGuard } from './fpsGuard';

/** تكلفة الإطار: جهاز بطيء فعلًا (كل إطار تقيل) لما الإطارات تحت 50، وجهاز عادي غير كده */
const cost = (fps: number) => (fps < 50 ? 25 : 3);

/** بيشغّل الحارس بمعدل إطارات ثابت لمدة معيّنة، ويرجّع وقت القفل (لو حصل) */
function run(g: FpsGuard, segments: Array<[fps: number, ms: number, work?: number]>, start = 0): number | null {
  let t = start;
  g.start(t);
  for (const [fps, ms, work] of segments) {
    const step = 1000 / fps;
    const end = t + ms;
    while (t < end) {
      t += step;
      if (g.frame(t, work ?? cost(fps))) return t;
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
    for (let t = 0; t < 15_000; t += 1000 / 20) if (g.frame(t, 45)) trips++;
    expect(trips).toBe(1);
  });

  it('المتصفح أو الشاشة مقفولين على 30 أو 48 إطار (توفير الطاقة) والجهاز فاضي: ده مش بطء، ما بيقفلش', () => {
    expect(run(new FpsGuard(), [[30, 20_000, 2]])).toBeNull();
    expect(run(new FpsGuard(), [[48, 20_000, 3]])).toBeNull();
    const g = new FpsGuard();
    run(g, [[30, 4_000, 2]]);
    expect(g.last_).toMatchObject({ capped: true, slow: false });
  });

  it('توفير الطاقة على جهاز رسمه أبطأ (كل إطار 10 لـ 20 مللي من 33): عنده وقت فاضي، فمش بطء', () => {
    expect(run(new FpsGuard(), [[30, 20_000, 12]])).toBeNull();
    expect(run(new FpsGuard(), [[27, 20_000, 18]])).toBeNull();
    // ولو الشغل مالي أغلب الإطار (25 من 33): ده بطء
    expect(run(new FpsGuard(), [[30, 20_000, 25]])).not.toBeNull();
  });

  it('توفير الطاقة مع ضغط لحظي (إطار طويل كل شوية): لسه مش بطء', () => {
    const g = new FpsGuard();
    g.start(0);
    let t = 0;
    let tripped = false;
    // 30 إطار تقريبًا، وكل عاشر إطار متأخر (زي جهاز عليه شغل تاني لحظة)
    for (let i = 0; i < 1_200 && !tripped; i++) {
      t += i % 10 === 9 ? 75 : 30 + (i % 3);
      tripped = g.frame(t, 2);
    }
    expect(tripped).toBe(false);
  });

  it('إطارات مش منتظمة (تقطيع) حتى لو كل إطار خفيف: ده بطء، بيقفل', () => {
    const g = new FpsGuard();
    g.start(0);
    let t = 0;
    let at: number | null = null;
    // إطار بعد 16 مللي وإطار بعد 70: حوالي 23 إطار في الثانية ومتقطع
    for (let i = 0; i < 2_000 && at === null; i++) {
      t += i % 2 ? 70 : 16;
      if (g.frame(t, 2)) at = t;
    }
    expect(at).not.toBeNull();
    expect(g.last_?.slow).toBe(true);
  });
});

describe('حارس الخلفية الحية (الافتتاحية والدخول)', () => {
  /** بيشغّل الحارس بمعدل إطارات معيّن لفترة، وبيرجّع وقت ما وقف الحركة (أو null) */
  const run = (g: FpsGuard, from: number, to: number, fps: number, work = cost(fps)) => {
    const step = 1000 / fps;
    for (let t = from; t <= to; t += step) if (g.frame(t, work)) return t;
    return null;
  };
  it('تحت 50 إطار لمدة 2 ثانية متواصلة (بعد 0.8 ثانية من الفتح) بيثبّت الخلفية، ومش قبل كده', () => {
    const g = new FpsGuard(BG_GUARD);
    g.start(0);
    const at = run(g, 0, 6000, 30);
    expect(at).not.toBeNull();
    expect(at!).toBeGreaterThanOrEqual(800 + 2000);
    expect(at!).toBeLessThan(800 + 2000 + 700);
  });
  it('بطء أقل من 2 ثانية وبعدين الأداء رجع: الخلفية بتفضل شغالة', () => {
    const g = new FpsGuard(BG_GUARD);
    g.start(0);
    // 1.6 ثانية بطء بعد فترة السماح (القياس على نوافذ نص ثانية، فبنسيب هامش نافذة)
    expect(run(g, 0, 2400, 30)).toBeNull();
    expect(run(g, 2400, 8000, 60)).toBeNull();
  });
  it('توفير الطاقة (المتصفح مقفول على 30 إطار) والجهاز فاضي: الخلفية بتفضل شغالة', () => {
    const g = new FpsGuard(BG_GUARD);
    g.start(0);
    expect(run(g, 0, 20_000, 30, 2)).toBeNull();
    expect(run(g, 20_000, 40_000, 48, 3)).toBeNull();
  });
  it('بطء أول 0.8 ثانية بس (تحميل الكود) ما بيتحسبش', () => {
    const g = new FpsGuard(BG_GUARD);
    g.start(0);
    expect(run(g, 0, 790, 10)).toBeNull();
    expect(run(g, 790, 8000, 60)).toBeNull();
  });
});
