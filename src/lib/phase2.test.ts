import { describe, expect, it } from 'vitest';
import { fillTemplate, trackingUrl, waLink } from './messages';
import { checkSummary, compareChecks } from './checks';
import { inWarranty, suggestCategory } from './customers';

describe('قوالب واتساب', () => {
  it('بيملا المتغيرات ويشيل اللي مش موجود', () => {
    expect(fillTemplate('أهلًا {name}، جهازك {device} ({order}) {unknown}', { name: 'منى', device: 'iPhone 13', order: '2026-0004' })).toBe('أهلًا منى، جهازك iPhone 13 (2026-0004)');
    expect(fillTemplate('{name}', {})).toBe('');
  });
  it('رابط wa.me بالصيغة الدولية والرسالة متشفرة', () => {
    expect(waLink('٠١٠١٢٣٤٥٦٧٨', 'جهازك جاهز & شكرًا')).toBe(`https://wa.me/201012345678?text=${encodeURIComponent('جهازك جاهز & شكرًا')}`);
    expect(waLink('123', 'x')).toBeNull();
  });
  it('رابط التتبع', () => {
    expect(trackingUrl('https://shop.app/index.html#/devices/1', 'abc')).toBe('https://shop.app/index.html/#/t/abc');
    expect(trackingUrl('http://localhost:5173/', 'abc')).toBe('http://localhost:5173/#/t/abc');
  });
});

describe('الفحص السريع', () => {
  it('بيمسك اللي كان شغال وباظ، واللي اتصلح', () => {
    const d = compareChecks({ wifi: 'ok', mic: 'fail', camera_x: 'ok' } as never, { wifi: 'fail', mic: 'ok' });
    expect(d.find((x) => x.item === 'wifi')).toMatchObject({ regressed: true, fixed: false });
    expect(d.find((x) => x.item === 'mic')).toMatchObject({ regressed: false, fixed: true });
    expect(d).toHaveLength(10);
  });
  it('الملخص', () => {
    expect(checkSummary({ wifi: 'ok', mic: 'fail', network: 'na' })).toEqual({ ok: 1, fail: 1, na: 1, total: 10 });
    expect(checkSummary(null)).toEqual({ ok: 0, fail: 0, na: 0, total: 10 });
  });
});

describe('تصنيف العملاء والضمان', () => {
  it('اقتراح التصنيف', () => {
    expect(suggestCategory({ devices: 1, spentMinor: 0 })).toBe('new');
    expect(suggestCategory({ devices: 2, spentMinor: 0 })).toBe('regular');
    expect(suggestCategory({ devices: 6, spentMinor: 0 })).toBe('vip');
    expect(suggestCategory({ devices: 1, spentMinor: 500_000 })).toBe('vip');
    expect(suggestCategory({ devices: 9, spentMinor: 9_000_000, overdueDays: 20 })).toBe('late');
  });
  it('الضمان', () => {
    const now = new Date('2026-11-06T12:00:00Z');
    expect(inWarranty('2026-11-07T00:00:00Z', now)).toBe(true);
    expect(inWarranty('2026-11-05T00:00:00Z', now)).toBe(false);
    expect(inWarranty(null, now)).toBe(false);
  });
});
