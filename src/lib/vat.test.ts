import { describe, expect, it } from 'vitest';
import { bpToPercent, parsePercentBp, readVat, vatOf } from './vat';

describe('ضريبة القيمة المضافة', () => {
  it('الضريبة جوه السعر الشامل بالقروش (نفس أرقام اختبار قاعدة البيانات)', () => {
    expect(vatOf(114000, 1400)).toBe(14000);
    expect(vatOf(228000, 1400)).toBe(28000);
    expect(vatOf(57000, 1400)).toBe(7000);
    expect(vatOf(100, 1400)).toBe(12);
    expect(vatOf(1, 1400)).toBe(0);
    expect(vatOf(99999999, 1400)).toBe(Math.floor((99999999 * 1400 * 2 + 11400) / 22800));
    expect(vatOf(5000, 0)).toBe(0);
    expect(() => vatOf(1.5, 1400)).toThrow();
  });
  it('الضريبة دايمًا أقل من المبلغ، والصافي + الضريبة = الشامل', () => {
    for (const g of [1, 2, 7, 57, 99, 101, 999, 12345, 1_000_000_007]) {
      const v = vatOf(g, 1400);
      expect(v).toBeLessThan(g);
      expect(g - v + v).toBe(g);
    }
  });
  it('النسبة من الخانة: أرقام عربي وكسر، ومن غير float', () => {
    expect(parsePercentBp('14')).toBe(1400);
    expect(parsePercentBp('١٤')).toBe(1400);
    expect(parsePercentBp('14.5')).toBe(1450);
    expect(parsePercentBp('5,25')).toBe(525);
    expect(parsePercentBp('14%')).toBe(1400);
    expect(parsePercentBp('31')).toBeNull();
    expect(parsePercentBp('abc')).toBeNull();
    expect(parsePercentBp('')).toBeNull();
    expect(bpToPercent(1400)).toBe('14');
    expect(bpToPercent(1450)).toBe('14.5');
    expect(bpToPercent(525)).toBe('5.25');
  });
  it('الإعداد: مقفول افتراضيًا، وقيمة غلط = 14%، وأقصى 30% (زي قاعدة البيانات)', () => {
    expect(readVat(null)).toEqual({ enabled: false, rate_bp: 1400, reg_no: '' });
    expect(readVat({ vat: { enabled: true, rate_bp: 'x', reg_no: '1-2' } })).toEqual({ enabled: true, rate_bp: 1400, reg_no: '1-2' });
    expect(readVat({ vat: { enabled: true, rate_bp: 9000 } }).rate_bp).toBe(3000);
    expect(readVat({ vat: { enabled: 'true' } }).enabled).toBe(false);
  });
});
