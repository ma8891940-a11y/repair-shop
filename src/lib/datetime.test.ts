import { describe, expect, it } from 'vitest';
import { formatDate, plainText } from './datetime';

// 7 نوفمبر 2026 الساعة 12:30 الضهر بتوقيت القاهرة (10:30 UTC)
const at = '2026-11-07T10:30:00Z';

describe('تنسيق التاريخ والوقت (دالة واحدة للبرنامج كله)', () => {
  it('العربي: يوم/شهر/سنة، وبأسماء الشهور، وبأرقام لاتيني', () => {
    expect(plainText(formatDate(at, 'ar', 'numeric'))).toBe('07/11/2026');
    expect(plainText(formatDate(at, 'ar', 'date'))).toBe('7 نوفمبر 2026');
    expect(plainText(formatDate(at, 'ar', 'dateLong'))).toBe('السبت، 7 نوفمبر 2026');
    expect(plainText(formatDate(at, 'ar', 'dateTime'))).toBe('07/11/2026 12:30 م');
    expect(plainText(formatDate('2026-11-07T05:05:00Z', 'ar', 'time'))).toBe('07:05 ص');
  });
  it('الإنجليزي: 7 Nov 2026', () => {
    expect(plainText(formatDate(at, 'en', 'date'))).toBe('7 Nov 2026');
    expect(plainText(formatDate(at, 'en', 'dateLong'))).toBe('Saturday, 7 November 2026');
    expect(plainText(formatDate(at, 'en', 'dateTime'))).toBe('7 Nov 2026, 12:30');
    expect(plainText(formatDate(at, 'en', 'numeric'))).toBe('07/11/2026');
  });
  it('من غير علامات RLM اللي بتقلب الترتيب، والتاريخ بالأرقام معزول من اليسار لليمين', () => {
    for (const lang of ['ar', 'en'] as const)
      for (const style of ['date', 'dateLong', 'numeric', 'dateTime', 'time'] as const) expect(formatDate(at, lang, style)).not.toMatch(/[‎‏؜]/);
    expect(formatDate(at, 'ar', 'numeric')).toBe('⁦07/11/2026⁩');
    // جوه الوقت والتاريخ العربي: التاريخ بالأرقام معزول لوحده
    expect(formatDate(at, 'ar', 'dateTime')).toContain('⁦07/11/2026⁩');
  });
  it('التصدير (plain): نص عادي من غير أي علامات', () => {
    expect(formatDate(at, 'ar', 'dateTime', { plain: true })).toBe('07/11/2026 12:30 م');
    expect(formatDate(at, 'ar', 'numeric', { plain: true })).toBe('07/11/2026');
    expect(formatDate(at, 'en', 'date', { plain: true })).toBe('7 Nov 2026');
  });
  it('بتوقيت القاهرة: 11 بالليل UTC = اليوم اللي بعده في القاهرة، واليوم من غير وقت بيفضل نفس اليوم', () => {
    expect(plainText(formatDate('2026-11-07T23:30:00Z', 'ar', 'numeric'))).toBe('08/11/2026');
    expect(plainText(formatDate('2026-11-07', 'ar', 'numeric'))).toBe('07/11/2026');
    expect(plainText(formatDate('2026-01-31', 'en', 'date'))).toBe('31 Jan 2026');
  });
  it('اليوم والشهر ما بيتلخبطوش (يوم أكبر من 12)', () => {
    expect(plainText(formatDate('2026-03-25T12:00:00Z', 'ar', 'numeric'))).toBe('25/03/2026');
    expect(plainText(formatDate('2026-03-25T12:00:00Z', 'en', 'date'))).toBe('25 Mar 2026');
  });
  it('تاريخ مش صحيح: نص فاضي (مش "Invalid Date")', () => {
    expect(formatDate('x', 'ar')).toBe('');
  });
});
