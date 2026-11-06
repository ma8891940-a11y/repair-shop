import { describe, expect, it } from 'vitest';
import { fillTemplate, trackingUrl, waLink } from './messages';
import { checkSummary, compareChecks } from './checks';
import { inWarranty, overdueReady, suggestCategory } from './customers';

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

describe('متابعة الأجهزة الجاهزة', () => {
  const now = new Date('2026-03-20T10:00:00Z');
  const ago = (d: number) => new Date(now.getTime() - d * 86_400_000).toISOString();
  it('بيطلع الجاهز من 10 أيام أو أكتر بس، والأقدم الأول', () => {
    const devices = [
      { id: 'a', status: 'ready' },
      { id: 'b', status: 'ready' },
      { id: 'c', status: 'ready' },
      { id: 'd', status: 'delivered' },
    ];
    const events = [
      { device_id: 'a', new_status: 'ready', created_at: ago(10) },
      { device_id: 'b', new_status: 'ready', created_at: ago(9.9) },
      { device_id: 'c', new_status: 'ready', created_at: ago(25) },
      { device_id: 'd', new_status: 'ready', created_at: ago(40) },
    ];
    const r = overdueReady(devices, events, now);
    expect(r.map((x) => x.id)).toEqual(['c', 'a']);
    expect(r[0].days).toBe(25);
  });
  it('لو الجهاز رجع للصيانة وجهز تاني، العدّ من آخر مرة', () => {
    const r = overdueReady(
      [{ id: 'a', status: 'ready' }],
      [
        { device_id: 'a', new_status: 'ready', created_at: ago(30) },
        { device_id: 'a', new_status: 'in_repair', created_at: ago(29) },
        { device_id: 'a', new_status: 'ready', created_at: ago(3) },
      ],
      now,
    );
    expect(r).toEqual([]);
  });
  it('من غير أحداث أو قائمة فاضية', () => {
    expect(overdueReady([{ id: 'x', status: 'ready' }], [], now)).toEqual([]);
    expect(overdueReady([], [], now)).toEqual([]);
  });
});
