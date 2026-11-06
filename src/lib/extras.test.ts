import { describe, expect, it } from 'vitest';
import { daySummaryText, readExtras, waShareUrl, DEFAULT_EXTRAS } from './extras';

const L = { title: 'Day', received: 'In', delivered: 'Out', ready: 'Ready', revenue: 'Rev', expenses: 'Exp', profit: 'Profit', collected: 'Collected', currency: 'EGP' };

describe('الميزات الإضافية', () => {
  it('المفاتيح: الناقص أو الغلط بيرجع للافتراضي', () => {
    expect(readExtras(null)).toEqual(DEFAULT_EXTRAS);
    expect(readExtras({ auto_print: true, quick_issues: 'yes' })).toEqual({ quick_issues: true, day_summary: true, auto_print: true });
    expect(readExtras({ quick_issues: false, day_summary: false })).toEqual({ quick_issues: false, day_summary: false, auto_print: false });
  });

  it('ملخص اليوم: المبالغ بالقروش بتتعرض بالجنيه، والربح = الإيراد - المصروف، والطرق الفاضية ما بتظهرش', () => {
    const s = daySummaryText('Shop', '2026-11-06', { received: 7, delivered: 4, ready: 3, revenue: 1_250_050, expenses: 300_000, byMethod: { cash: 900_050, instapay: 0, vodafone_cash: 350_000 } }, L, (m) => m.toUpperCase());
    expect(s).toContain('Day: Shop');
    expect(s).toContain('In: 7');
    expect(s).toContain('Rev: 12,500.50 EGP');
    expect(s).toContain('Profit: 9,500.50 EGP');
    expect(s).toContain('- CASH: 9,000.50 EGP');
    expect(s).toContain('- VODAFONE_CASH: 3,500 EGP');
    expect(s).not.toContain('INSTAPAY');
  });

  it('مبالغ كبيرة وخسارة وكسور ممنوعة', () => {
    const s = daySummaryText('S', 'd', { received: 0, delivered: 0, ready: 0, revenue: 0, expenses: 1_999_999_999, byMethod: {} }, L, (m) => m);
    expect(s).toContain('Profit: -19,999,999.99 EGP');
    expect(s).not.toContain('Collected');
    expect(() => daySummaryText('S', 'd', { received: 0, delivered: 0, ready: 0, revenue: 10.5, expenses: 0, byMethod: {} }, L, (m) => m)).toThrow();
  });

  it('رابط واتساب من غير رقم، والنص العربي متشفّر', () => {
    const u = waShareUrl('ملخص اليوم\n1');
    expect(u.startsWith('https://wa.me/?text=')).toBe(true);
    expect(decodeURIComponent(u.split('text=')[1])).toBe('ملخص اليوم\n1');
  });
});
