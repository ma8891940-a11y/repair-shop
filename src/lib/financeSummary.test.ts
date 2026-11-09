import { describe, expect, it } from 'vitest';
import { compare, previousRange, resultSentence } from './financeSummary';

// البند 8: جملة النتيجة والمقارنة بالفترة اللي قبلها
const at = (iso: string) => new Date(iso);

describe('الفترة اللي قبلها', () => {
  it('النهارده ← امبارح، والأسبوع ← الـ 7 اللي قبله', () => {
    expect(previousRange({ kind: 'today' }, at('2026-11-09T10:00:00Z')).days).toEqual(['2026-11-08']);
    const w = previousRange({ kind: 'week' }, at('2026-11-09T10:00:00Z')).days;
    expect(w).toHaveLength(7);
    expect(w[0]).toBe('2026-10-27');
    expect(w.at(-1)).toBe('2026-11-02');
  });
  it('الشهر ← نفس الأيام من الشهر اللي فات (ويناير ← ديسمبر اللي قبله، و31 مارس ← لحد آخر فبراير)', () => {
    expect(previousRange({ kind: 'month' }, at('2026-11-09T10:00:00Z')).days).toEqual(Array.from({ length: 9 }, (_, i) => `2026-10-0${i + 1}`));
    const jan = previousRange({ kind: 'month' }, at('2027-01-05T10:00:00Z')).days;
    expect([jan[0], jan.at(-1)]).toEqual(['2026-12-01', '2026-12-05']);
    const mar = previousRange({ kind: 'month' }, at('2026-03-31T10:00:00Z')).days;
    expect(mar.at(-1)).toBe('2026-02-28');
  });
  it('المخصص ← نفس عدد الأيام قبله', () => {
    const r = previousRange({ kind: 'custom', from: '2026-11-05', to: '2026-11-07' }, at('2026-11-09T10:00:00Z')).days;
    expect(r).toEqual(['2026-11-02', '2026-11-03', '2026-11-04']);
  });
});

describe('المقارنة وجملة النتيجة', () => {
  it('النسبة عدد صحيح مقرّب، ومن غير نسبة لو اللي فات صفر أو الإشارة اتغيّرت', () => {
    expect(compare(150_000, 100_000)).toEqual({ trend: 'up', pct: 50 });
    expect(compare(100_000, 300_000)).toEqual({ trend: 'down', pct: 67 });
    expect(compare(-50_000, -100_000)).toEqual({ trend: 'up', pct: 50 });
    expect(compare(10, 0)).toEqual({ trend: 'up', pct: null });
    expect(compare(-10, 20)).toEqual({ trend: 'down', pct: null });
    expect(compare(7, 7)).toEqual({ trend: 'same', pct: 0 });
    expect(() => compare(1.5, 1)).toThrow();
  });
  it('ربح أو خسارة أو تعادل، ومعاها المقارنة', () => {
    expect(resultSentence({ profit: 150_000, revenue: 400_000, expenses: 250_000 }, { profit: 100_000 })).toMatchObject({ main: 'profit', cmp: 'up', pct: 50 });
    expect(resultSentence({ profit: -5_000, revenue: 0, expenses: 5_000 }, { profit: 10_000 })).toMatchObject({ main: 'loss', cmp: 'downNoPct', pct: null });
    expect(resultSentence({ profit: 0, revenue: 0, expenses: 0 }, null)).toMatchObject({ main: 'even', cmp: 'none' });
    expect(resultSentence({ profit: '200' as unknown as number, revenue: 1, expenses: 1 }, { profit: '200' as unknown as number })).toMatchObject({ cmp: 'same', profit: 200 });
  });
});
