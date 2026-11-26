import { describe, expect, it } from 'vitest';
import { DEFAULT_PRINT, pageSize, printUrl, readPrint, readSticker, remaining, STICKER_LINES, STICKER_PAD_MM, STICKER_PRESETS, LINE_HEIGHT, stickerFont } from './printPlan';

// S5 (تعديل): الاستيكر الصغير، والمقاسات، واللي بيتعمل تلقائي بعد الاستلام
describe('إعدادات الطباعة', () => {
  it('الافتراضي: استيكر 40×30 من غير إطار ولا إزاحة، ونسخة واحدة، ومفيش حاجة تلقائي', () => {
    expect(readPrint({})).toEqual(DEFAULT_PRINT);
    expect(DEFAULT_PRINT.sticker).toEqual({ w: 40, h: 30, frame: false, dx: 0, dy: 0, copies: 1 });
    expect(STICKER_PRESETS.map(([w, h]) => `${w}x${h}`)).toEqual(['30x20', '38x25', '40x30', '50x25', '50x30', '58x40', '60x40']);
  });
  it('الإعدادات القديمة ("اطبع تلقائي") بتتنقل من غير ما حاجة تضيع', () => {
    expect(readPrint({ auto_print: true }).auto).toEqual({ thermal: false, paper: true, sticker: true, qr: false, whatsapp: false });
    expect(readPrint({ print: { autoAfterIntake: true, intakeSticker: false, intakeThermal: true } }).auto).toMatchObject({ sticker: false, thermal: true, paper: true });
    expect(readPrint({ print: { auto: { whatsapp: true, qr: true } } }).auto).toEqual({ thermal: false, paper: false, sticker: false, qr: true, whatsapp: true });
  });
  it('المقاس اللي بيتكتب باليد: أرقام في حدود معقولة', () => {
    expect(readSticker({ w: 200, h: 5, dx: -30, dy: 2.345, copies: 0 })).toEqual({ w: 120, h: 10, frame: false, dx: -10, dy: 2.3, copies: 1 });
    expect(readSticker({ w: '40' })).toMatchObject({ w: 40 });
    expect(pageSize('sticker', readSticker({ w: 38, h: 25 }))).toBe('38mm 25mm');
  });
  it('الباقي = التكلفة − المقدم، بأعداد صحيحة ومش أقل من صفر', () => {
    expect(remaining(50_000, 20_000)).toBe(30_000);
    expect(remaining(50_000, 60_000)).toBe(0);
    expect(remaining(null, 100)).toBeNull();
  });
  it('الخط بيتظبط عشان السطور كلها تدخل في الارتفاع، في المقاسات السبعة', () => {
    for (const [w, h] of STICKER_PRESETS) {
      const f = stickerFont({ w, h });
      const used = STICKER_LINES.reduce((a, l) => a + f[l.key] * LINE_HEIGHT, 0);
      expect(used, `${w}x${h}`).toBeLessThanOrEqual(h - STICKER_PAD_MM * 2 + 0.05);
      expect(f.order).toBeGreaterThan(f.name);
      expect(f.date).toBeGreaterThan(0.9);
    }
  });
  it('رابط الطباعة جوه الإطار المخفي', () => {
    expect(printUrl('sticker', 'd1', { embed: true, no: '77' })).toBe('/print/sticker/d1?embed=1&no=77');
    expect(printUrl('receipt-a4', 'd1')).toBe('/print/receipt-a4/d1');
  });
});

describe('قالب الستيكر من الإعدادات (50.8)', () => {
  it('كل مقاس جاهز بيطلع قالب سليم بنفس سطور الاستيكر', async () => {
    const { stickerLayout, STICKER_PRESETS, DEFAULT_STICKER } = await import('./printPlan');
    const { templateError } = await import('./printLayout');
    for (const [w, h] of [...STICKER_PRESETS, [DEFAULT_STICKER.w, DEFAULT_STICKER.h], [37.5, 24.6]]) {
      const l = stickerLayout({ w, h });
      expect(templateError('sticker', 'free', [], l), `${w}x${h}`).toBeNull();
      expect(l.fields!.map((f) => f.key)).toEqual(['orderNo', 'customer', 'phone', 'device', 'issue', 'price', 'paid', 'remaining', 'date']);
    }
  });
  it('40×30: رقم الصيانة أكبر سطر، والفلوس باسمها', async () => {
    const { stickerLayout } = await import('./printPlan');
    const f = Object.fromEntries(stickerLayout({ w: 40, h: 30 }).fields!.map((x) => [x.key, x]));
    expect(f.orderNo).toMatchObject({ x: 1.2, y: 1.2, w: 37.6, font: 'mono', bold: true });
    expect(f.orderNo.pt).toBeGreaterThan(f.customer.pt);
    expect([f.price.cap, f.paid.cap, f.remaining.cap]).toEqual([true, true, true]);
    expect(f.customer.cap).toBeUndefined();
  });
});
