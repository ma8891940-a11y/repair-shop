import { describe, expect, it } from 'vitest';
import { parsePercent, remainingBp, shareOf } from './partners';

describe('الشركاء', () => {
  it('قراءة النسبة: أرقام عربي، ونسبة بكسر، والحدود', () => {
    expect(parsePercent('60')).toBe(6000);
    expect(parsePercent('٣٣٫٥')).toBe(3350);
    expect(parsePercent('12.25%')).toBe(1225);
    expect(parsePercent('100')).toBe(10000);
    expect(parsePercent('100.01')).toBeNull();
    expect(parsePercent('12.345')).toBeNull();
    expect(parsePercent('abc')).toBeNull();
  });
  it('النصيب بالقروش من غير كسور، والخسارة بالسالب', () => {
    expect(shareOf(100000, 6000)).toBe(60000);
    expect(shareOf(100001, 3333)).toBe(33330); // 33330.33 ← 33330
    expect(shareOf(-20000, 6000)).toBe(-12000);
    expect(shareOf(-1, 3333)).toBe(0);
    expect(remainingBp([6000, 3000])).toBe(1000);
  });
});
