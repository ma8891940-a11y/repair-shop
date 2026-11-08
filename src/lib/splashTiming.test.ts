import { describe, expect, it } from 'vitest';
import { HANDOFF_MS, handoffDuration, LAND_BY_MS, MIN_HANDOFF_MS, MIN_SPEED, SPLASH_ANIM_MS, SPLASH_BUDGET_MS, splashSpeed } from './splashTiming';

describe('ميزانية الافتتاحية من لحظة فتح البرنامج', () => {
  it('جهاز عادي (الكود حمّل بسرعة): المواعيد زي التصميم تقريبًا', () => {
    // حتى أسرع جهاز: الفرق عن التصميم أقل من 5%
    expect(splashSpeed(0)).toBeGreaterThan(0.95);
    expect(splashSpeed(0)).toBeLessThanOrEqual(1);
    // تحميل عادي (0.1 ثانية): الفرق حوالي 10%، ما بيبانش
    expect(splashSpeed(100)).toBeGreaterThan(0.85);
    expect(SPLASH_ANIM_MS).toBe(850);
    expect(SPLASH_ANIM_MS).toBeLessThan(1200);
    expect(HANDOFF_MS).toBe(400);
  });
  it('جهاز ضعيف: نفس التسلسل أسرع، والمجموع جوه الميزانية (أقل من 1.5 ثانية)', () => {
    for (const t0 of [200, 400, 550, 575]) {
      const f = splashSpeed(t0);
      expect(f).toBeLessThan(1);
      expect(t0 + f * (SPLASH_ANIM_MS + HANDOFF_MS)).toBeLessThanOrEqual(SPLASH_BUDGET_MS + 1e-9);
    }
    expect(SPLASH_BUDGET_MS).toBeLessThan(1500);
    // حتى لو التحميل خد 0.8 ثانية (ووصلنا لأسرع حد)، المجموع لسه أقل من ثانية ونص
    expect(800 + splashSpeed(800) * (SPLASH_ANIM_MS + HANDOFF_MS)).toBeLessThan(1500);
  });
  it('مهما الجهاز اتأخر: ما يسرعش أكتر من الحد (عشان الحركة ما تبقاش خطفة)', () => {
    expect(splashSpeed(5000)).toBe(MIN_SPEED);
    expect(splashSpeed(-5)).toBe(splashSpeed(0));
  });
});

describe('مدة طيران اللوجو', () => {
  it('في الميعاد: نفس مدة التصميم (مضروبة في معامل السرعة)', () => {
    expect(handoffDuration(800, 1)).toBe(HANDOFF_MS);
    expect(handoffDuration(900, 0.6)).toBe(240);
  });
  it('لو الرسم اتأخر: الطيران بياخد الوقت الباقي بس، فاللوجو بيستقر في الميعاد', () => {
    expect(handoffDuration(1150, 1)).toBe(LAND_BY_MS - 1150);
    expect(LAND_BY_MS).toBeLessThan(1500);
  });
  it('مهما اتأخر: الطيران ما يقلّش عن الحد (عشان يفضل باين)', () => {
    expect(handoffDuration(1390, 1)).toBe(MIN_HANDOFF_MS);
    expect(handoffDuration(3000, 0.5)).toBe(MIN_HANDOFF_MS);
  });
});
