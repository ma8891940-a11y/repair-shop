import { describe, expect, it } from 'vitest';
import { ean13Bits, ean13Check, isEan13, newInternalEan13 } from './barcode';

describe('باركود EAN-13', () => {
  it('رقم التحقق صح لأرقام معروفة', () => {
    expect(ean13Check('400638133393')).toBe(1); // 4006381333931
    expect(isEan13('4006381333931')).toBe(true);
    expect(isEan13('4006381333932')).toBe(false);
    expect(isEan13('5901234123457')).toBe(true);
  });
  it('الباركود الداخلي بيبدأ بـ 2 وصحيح', () => {
    for (let i = 0; i < 200; i++) {
      const c = newInternalEan13();
      expect(c).toMatch(/^2\d{12}$/);
      expect(isEan13(c)).toBe(true);
    }
  });
  it('الخطوط: 95 وحدة، وبتبدأ وبتنتهي بعلامة الحافة، ونفس النمط المعروف', () => {
    const b = ean13Bits('5901234123457');
    expect(b).toHaveLength(95);
    expect(b.startsWith('101')).toBe(true);
    expect(b.endsWith('101')).toBe(true);
    expect(b.slice(45, 50)).toBe('01010');
    // أول رقم 5 = LGGLLG: الرقم 9 بـ L
    expect(b.slice(3, 10)).toBe('0001011');
    expect(() => ean13Bits('123')).toThrow();
  });
});
