import { describe, expect, it } from 'vitest';
import { addPeriod, buildSchedule, splitEven } from './plans';

describe('تقسيم الأقساط بالقروش', () => {
  it('المجموع بالظبط، والكسر على آخر قسط، ومن غير أي عدد عشري', () => {
    expect(splitEven(100000, 3)).toEqual([33333, 33333, 33334]);
    expect(splitEven(1, 3)).toEqual([1]);
    expect(splitEven(99_999_999_999, 7).reduce((a, b) => a + b, 0)).toBe(99_999_999_999);
    expect(splitEven(100000, 3).every(Number.isInteger)).toBe(true);
    expect(splitEven(0, 3)).toEqual([]);
    expect(splitEven(100, 0)).toEqual([]);
    expect(splitEven(10.5, 2)).toEqual([]);
  });
  it('كل شهر نفس اليوم، ولو الشهر أقصر آخر يوم فيه؛ وكل أسبوع', () => {
    expect(addPeriod('2026-01-31', 1, 'month')).toBe('2026-02-28');
    expect(addPeriod('2026-01-31', 2, 'month')).toBe('2026-03-31');
    expect(addPeriod('2026-12-15', 1, 'month')).toBe('2027-01-15');
    expect(addPeriod('2026-11-11', 1, 'week')).toBe('2026-11-18');
    expect(buildSchedule(300000, 3, '2026-11-30', 'month')).toEqual([
      { due: '2026-11-30', amount: 100000 },
      { due: '2026-12-30', amount: 100000 },
      { due: '2027-01-30', amount: 100000 },
    ]);
  });
});
