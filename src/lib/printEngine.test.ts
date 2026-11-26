import { describe, expect, it } from 'vitest';
import { blockStyle, freeStyle, pagePlan, planCss, rulerTicks } from './printEngine';

const A4 = { w: 210, h: 297, margin: 14 };
const bg = { file: '0b9e2b6c-1c1a-4c1e-9a5e-2f6d9b1c3a4e.png', w: 400, h: 300 };

describe('محرّك الطباعة (50.6)', () => {
  it('قالب قديم من غير ورقة ولا طابعة: مقاس المستند الافتراضي وهامشه', () => {
    expect(pagePlan('flow', {}, null, A4, 'ar')).toEqual({ w: 210, h: 297, margin: 14, dx: 0, dy: 0, bg: null, lang: 'ar' });
    expect(blockStyle({})).toEqual({});
  });
  it('الطابعة تكسب الافتراضي، وورقة القالب تكسب الطابعة', () => {
    const pr = { width_mm: 72, height_mm: null, margin_mm: 3, offset_x: '1.5', offset_y: -2 };
    expect(pagePlan('flow', {}, pr, A4, 'ar')).toMatchObject({ w: 72, h: null, margin: 3, dx: 1.5, dy: -2 });
    expect(pagePlan('flow', { paper: { kind: '58' } }, pr, A4, 'ar')).toMatchObject({ w: 58, h: null, margin: 3 });
    expect(planCss(pagePlan('flow', { paper: { kind: '58' } }, pr, A4, 'ar'))).toBe('@page { size: 58mm auto; margin: 3mm; }');
  });
  it('القالب الحر هامشه صفر، والإزاحة من الطابعة بس', () => {
    const p = pagePlan('free', { paper: { kind: '40x30' } }, { width_mm: 40, height_mm: 30, margin_mm: 2, offset_x: 0.5, offset_y: null }, A4, 'en-US');
    expect(p).toMatchObject({ w: 40, h: 30, margin: 0, dx: 0.5, dy: 0, lang: 'en' });
    expect(planCss(p)).toBe('@page { size: 40mm 30mm; margin: 0mm; }');
  });
  it('إزاحة غلط أو بره ±10 = صفر', () => {
    for (const v of ['abc', 11, -10.5, Infinity]) expect(pagePlan('flow', {}, { width_mm: 80, height_mm: null, margin_mm: 3, offset_x: v }, A4, 'ar').dx).toBe(0);
  });
  it('الخلفية: ورق فاضي بتتطبع، والورق المطبوع جاهز للشاشة بس', () => {
    const paper = { kind: '40x30' as const };
    expect(pagePlan('free', { paper, bg: { ...bg, stock: 'blank' } }, null, A4, 'ar').bg).toEqual({ file: bg.file, print: true });
    expect(pagePlan('free', { paper, bg: { ...bg, stock: 'preprinted' } }, null, A4, 'ar').bg).toEqual({ file: bg.file, print: false });
  });
  it('لغة القالب تكسب لغة البرنامج', () => {
    expect(pagePlan('flow', { lang: 'en' }, null, A4, 'ar').lang).toBe('en');
    expect(pagePlan('flow', { lang: 'app' }, null, A4, 'en').lang).toBe('en');
  });
  it('خط وحجم الخانة لو اتحددوا', () => {
    expect(blockStyle({ font: 'mono', pt: 14 })).toEqual({ fontFamily: 'var(--font-mono)', fontSize: '14pt' });
  });
  it('الحقل الحر بمكانه بالمللي', () => {
    expect(freeStyle({ key: 'customer', x: 2.5, y: 4, w: 30, h: 5, font: 'sans', pt: 9, align: 'center', bold: true })).toMatchObject({
      position: 'absolute', left: '2.5mm', top: '4mm', width: '30mm', height: '5mm', fontSize: '9pt', fontWeight: 700, textAlign: 'center',
    });
  });
  it('المسطرة كل 5 مللي لحد آخر الورقة', () => {
    expect(rulerTicks(22)).toEqual([{ at: 0, long: true }, { at: 5, long: false }, { at: 10, long: true }, { at: 15, long: false }, { at: 20, long: true }]);
  });
});
