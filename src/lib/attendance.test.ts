import { describe, expect, it } from 'vitest';
import { hm, totalsByPerson, type AttendanceRow } from './attendance';

const row = (o: Partial<AttendanceRow>): AttendanceRow => ({ id: 'x', profile_id: 'p1', full_name: 'أحمد', branch_id: null, clock_in: '2026-11-18T07:00:00Z', clock_out: null, minutes: null, late_minutes: 0, note: null, fix_reason: null, ...o });

describe('الحضور: العرض والإجمالي', () => {
  it('الدقايق لساعات ودقايق من غير كسور', () => {
    expect(hm(450)).toEqual({ h: 7, m: 30 });
    expect(hm(0)).toEqual({ h: 0, m: 0 });
    expect(hm(59)).toEqual({ h: 0, m: 59 });
    expect(hm(null)).toBeNull();
    expect(hm(-5)).toBeNull();
  });
  it('إجمالي كل موظف: الأيام بتوقيت القاهرة، والمفتوح ما بيتحسبش في الدقايق', () => {
    const t = totalsByPerson([
      row({ id: 'a', minutes: 480, late_minutes: 10 }),
      // نفس اليوم في القاهرة (وردية تانية)
      row({ id: 'b', clock_in: '2026-11-18T15:00:00Z', minutes: 60 }),
      // يوم تاني: 23:30 UTC = 01:30 القاهرة يوم 19
      row({ id: 'c', clock_in: '2026-11-18T23:30:00Z', minutes: null }),
      row({ id: 'd', profile_id: 'p2', full_name: 'منى', minutes: 600, late_minutes: 0 }),
    ]);
    expect(t).toEqual([
      { profile_id: 'p2', full_name: 'منى', days: 1, minutes: 600, late_minutes: 0, open: 0 },
      { profile_id: 'p1', full_name: 'أحمد', days: 2, minutes: 540, late_minutes: 10, open: 1 },
    ]);
  });
});
