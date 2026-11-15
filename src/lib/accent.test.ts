import { describe, expect, it } from 'vitest';
import { accentCss, accentVars, BG_DARK, BG_LIGHT, contrast, hexToRgb } from './accent';

describe('لون الإبراز بتباين مضمون في الوضعين', () => {
  it('أي لون بيعدّي 4.5:1 على خلفية الوضعين', () => {
    for (const hex of ['#38d6f0', '#ffee00', '#0a0a0a', '#ff0000', '#7c3aed', '#ffffff', '#16a34a']) {
      const v = accentVars(hex)!;
      expect(contrast(hexToRgb(v.dark['--accent'])!, BG_DARK)).toBeGreaterThanOrEqual(4.5);
      expect(contrast(hexToRgb(v.light['--accent'])!, BG_LIGHT)).toBeGreaterThanOrEqual(4.5);
      // الكلام فوق الزرار الملون مقروء
      expect(contrast(hexToRgb(v.dark['--on-accent'])!, hexToRgb(v.dark['--accent'])!)).toBeGreaterThanOrEqual(3);
    }
  });
  it('اللون الكويس أصلًا ما بيتغيرش، واللون الغلط بيترفض', () => {
    expect(accentVars('#38d6f0')!.dark['--accent']).toBe('#38d6f0');
    expect(accentVars('blue')).toBeNull();
    expect(accentCss(accentVars('#7c3aed')!)).toContain("[data-theme='light']");
  });
});
