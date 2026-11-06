import { describe, expect, it } from 'vitest';
import { durationParts, queueOrder, toMinutes } from './tech';

describe('المدة المتوقعة', () => {
  it('بتتعرض بأنسب وحدة', () => {
    expect(durationParts(45)).toEqual({ value: 45, unit: 'minute' });
    expect(durationParts(90)).toEqual({ value: 2, unit: 'hour' });
    expect(durationParts(60 * 30)).toEqual({ value: 1, unit: 'day' });
    expect(durationParts(0)).toEqual({ value: 0, unit: 'minute' });
    expect(durationParts(NaN)).toEqual({ value: 0, unit: 'minute' });
  });
  it('التحويل لدقايق وحدودها', () => {
    expect(toMinutes(2, 'hour')).toBe(120);
    expect(toMinutes(1.5, 'day')).toBe(2160);
    expect(toMinutes(0, 'hour')).toBeNull();
    expect(toMinutes(-1, 'minute')).toBeNull();
    expect(toMinutes(1000, 'day')).toBeNull();
  });
});

describe('ترتيب قائمة الفني', () => {
  it('عاجل ثم ضمان ثم عادي، وجوه كل واحد الأقدم الأول', () => {
    const r = queueOrder([
      { id: 'a', priority: 'normal', received_at: '2026-01-01T10:00:00Z' },
      { id: 'b', priority: 'urgent', received_at: '2026-01-03T10:00:00Z' },
      { id: 'c', priority: 'warranty', received_at: '2026-01-02T10:00:00Z' },
      { id: 'd', priority: 'normal', received_at: '2025-12-31T10:00:00Z' },
    ]);
    expect(r.map((x) => x.id)).toEqual(['b', 'c', 'd', 'a']);
  });
});
