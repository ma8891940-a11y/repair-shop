import { describe, expect, it } from 'vitest';
import { daysLeft, reorderQty, shareBp, urgency } from './forecast';

describe('C6: توقع نفاد المخزون', () => {
  it('عدد الأيام من صرف آخر 30 يوم، بحساب يدوي', () => {
    // 10 قطع، اتصرف 15 في 30 يوم (نص قطعة في اليوم) ← 20 يوم
    expect(daysLeft(10, 15)).toBe(20);
    // 3 قطع، اتصرف 30 (قطعة في اليوم) ← 3 أيام
    expect(daysLeft(3, 30)).toBe(3);
    // كسور بتتقرّب لتحت: 7 × 30 ÷ 9 = 23.3 ← 23
    expect(daysLeft(7, 9)).toBe(23);
    expect(daysLeft(5, 0)).toBeNull();
    expect(daysLeft(0, 10)).toBe(0);
    expect(daysLeft(-2, 10)).toBe(0);
    expect(daysLeft(NaN, 1)).toBeNull();
  });
  it('درجة الاستعجال والكمية المقترحة', () => {
    expect([urgency(0), urgency(3), urgency(20), urgency(45), urgency(null)]).toEqual(['out', 'soon', 'month', 'ok', 'ok']);
    // بيصرف 15 في الشهر وعنده 4 ← يشتري 11 عشان يكفي شهر
    expect(reorderQty(4, 15)).toBe(11);
    expect(reorderQty(40, 15)).toBe(0);
    expect(reorderQty(-3, 10)).toBe(10);
    expect(reorderQty(5, 0)).toBe(0);
  });
  it('نسبة تكلفة القطع من الإيراد', () => {
    // قطعة كلفت 300 في أجهزة دخلها 1,000 ← 30%
    expect(shareBp(30000, 100000)).toBe(3000);
    expect(shareBp(1, 3)).toBe(3333);
    expect(shareBp(100, 0)).toBeNull();
  });
});
