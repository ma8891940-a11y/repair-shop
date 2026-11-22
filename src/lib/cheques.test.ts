import { describe, expect, it } from 'vitest';
import { chequeUrgency } from './cheques';

describe('ميعاد الشيك', () => {
  // 2026-11-20 الساعة 23:30 بتوقيت القاهرة (21:30 UTC): لسه يوم 20 في القاهرة
  const now = new Date('2026-11-20T21:30:00Z');
  it('فات ميعاده، والنهارده وخلال 3 أيام قريب، وبعدها بدري', () => {
    expect(chequeUrgency('pending', '2026-11-19', now)).toBe('overdue');
    expect(chequeUrgency('pending', '2026-11-20', now)).toBe('soon');
    expect(chequeUrgency('pending', '2026-11-23', now)).toBe('soon');
    expect(chequeUrgency('pending', '2026-11-24', now)).toBe('later');
  });
  it('اليوم بتوقيت القاهرة مش UTC (بعد نص الليل في القاهرة اليوم اتغير)', () => {
    const afterMidnightCairo = new Date('2026-11-20T22:30:00Z'); // 00:30 يوم 21 في القاهرة
    expect(chequeUrgency('pending', '2026-11-20', afterMidnightCairo)).toBe('overdue');
  });
  it('اللي اتصرف أو اترفض خلص، وعبر الشهور والسنين صح', () => {
    expect(chequeUrgency('cleared', '2020-01-01', now)).toBe('done');
    expect(chequeUrgency('bounced', '2020-01-01', now)).toBe('done');
    expect(chequeUrgency('pending', '2026-12-01', new Date('2026-11-29T10:00:00Z'))).toBe('soon');
    expect(chequeUrgency('pending', '2027-01-02', new Date('2026-12-31T10:00:00Z'))).toBe('soon');
  });
});
