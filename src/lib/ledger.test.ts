import { describe, expect, it } from 'vitest';
import { fillDaily, matchMove, periodRange, plainPounds, suggestPrice, toCsv } from './ledger';

describe('فترات الوضع المالي (بتوقيت القاهرة)', () => {
  const now = new Date('2026-03-18T23:30:00Z'); // 19 مارس الساعة 1:30 بالليل في القاهرة
  it('النهارده', () => {
    const r = periodRange({ kind: 'today' }, now);
    expect(r.days).toEqual(['2026-03-19']);
    expect(r.from.toISOString()).toBe('2026-03-18T22:00:00.000Z');
    expect(r.to.toISOString()).toBe('2026-03-19T22:00:00.000Z');
  });
  it('الأسبوع = آخر 7 أيام، والشهر من أوله', () => {
    expect(periodRange({ kind: 'week' }, now).days).toHaveLength(7);
    expect(periodRange({ kind: 'week' }, now).days[0]).toBe('2026-03-13');
    const m = periodRange({ kind: 'month' }, now);
    expect(m.days[0]).toBe('2026-03-01');
    expect(m.days.at(-1)).toBe('2026-03-19');
  });
  it('من تاريخ لتاريخ (ولو اتكتبوا بالعكس) والفاضي = النهارده', () => {
    expect(periodRange({ kind: 'custom', from: '2026-02-27', to: '2026-03-02' }, now).days).toEqual(['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02']);
    expect(periodRange({ kind: 'custom', from: '2026-03-02', to: '2026-02-27' }, now).days).toHaveLength(4);
    expect(periodRange({ kind: 'custom' }, now).days).toEqual(['2026-03-19']);
  });
  it('الأيام الفاضية بتتملى بصفر', () => {
    const r = fillDaily(['2026-03-01', '2026-03-02'], [{ day: '2026-03-02', v: 5 }], (day) => ({ day, v: 0 }));
    expect(r).toEqual([{ day: '2026-03-01', v: 0 }, { day: '2026-03-02', v: 5 }]);
  });
});

describe('حاسبة التسعير', () => {
  it('قطع 350 + مصنعية 150 + 20% على القطع = 570 (متقرّبة لأقرب 5)', () => {
    expect(suggestPrice({ parts: 35000, labor: 15000, marginPct: 20 })).toEqual({ price: 57000, profit: 22000, markup: 7000 });
  });
  it('بتقرّب لفوق لأقرب خطوة ومن غير كسور', () => {
    expect(suggestPrice({ parts: 33333, labor: 0, marginPct: 15 }).markup).toBe(5000); // 4999.95 لفوق
    expect(suggestPrice({ parts: 33333, labor: 0, marginPct: 15 }).price).toBe(38500);
    expect(suggestPrice({ parts: 101, labor: 0, marginPct: 0, step: 0 }).price).toBe(101);
  });
  it('مبالغ كبيرة وقيم غلط', () => {
    expect(suggestPrice({ parts: 1_500_000_00, labor: 0, marginPct: 10 }).price).toBe(1_650_000_00);
    expect(() => suggestPrice({ parts: -1, labor: 0, marginPct: 10 })).toThrow();
    expect(() => suggestPrice({ parts: 1.5, labor: 0, marginPct: 10 })).toThrow();
    expect(() => suggestPrice({ parts: 100, labor: 0, marginPct: 2.5 })).toThrow();
  });
});

describe('التصدير لـ Excel', () => {
  it('BOM وعربي وفواصل وعلامات تنصيص', () => {
    const csv = toCsv([['البيان', 'المبلغ'], ['دفعة، عربون', '1500.50'], ['قال "تمام"', '-20.00']]);
    expect(csv.startsWith('﻿')).toBe(true);
    expect(csv).toBe('﻿البيان,المبلغ\r\n"دفعة، عربون",1500.50\r\n"قال ""تمام""",-20.00'.replace('"دفعة، عربون"', 'دفعة، عربون'));
  });
  it('بيمنع الصيغ اللي ممكن تشتغل في Excel', () => {
    expect(toCsv([['=HYPERLINK("x")']])).toBe('﻿"\'=HYPERLINK(""x"")"');
    expect(toCsv([['@SUM(A1)']])).toBe("﻿'@SUM(A1)");
    expect(toCsv([['-5.00']])).toBe('﻿-5.00');
  });
  it('المبالغ بالجنيه من غير فواصل ومن غير ما قرش يضيع', () => {
    expect(plainPounds(123456789123)).toBe('1234567891.23');
    expect(plainPounds(-5)).toBe('-0.05');
    expect(plainPounds(0)).toBe('0.00');
  });
  it('البحث في الحركات', () => {
    const m = { memo: 'إيجار الشهر', order_no: '2026-0004', by: 'سارة', entry_no: 17 };
    expect(matchMove(m, 'إيجار', '')).toBe(true);
    expect(matchMove(m, '0004', '')).toBe(true);
    expect(matchMove(m, '17', '')).toBe(true);
    expect(matchMove(m, 'دفعة', 'مصروف')).toBe(false);
    expect(matchMove(m, '', '')).toBe(true);
  });
});
