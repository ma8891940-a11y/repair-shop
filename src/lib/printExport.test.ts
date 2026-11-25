import { describe, expect, it } from 'vitest';
import { exportTemplate, EXPORT_MAX_CHARS, parseTemplate, type TemplateContent } from './printExport';
import { BG_MAX_BYTES } from './printBackground';
import { defaultBlocks } from './printTemplate';

const FILE = '0f8fad5b-d9cb-469f-a165-70867728950e.png';
const bytes = (n = 20) => {
  const b = new Uint8Array(n).fill(7);
  b.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  return b;
};
const flow: TemplateContent = { doc: 'sale', mode: 'flow', blocks: defaultBlocks('sale'), layout: { lang: 'ar' } };
const free: TemplateContent = {
  doc: 'sticker', mode: 'free', blocks: [],
  layout: {
    paper: { kind: '40x30' },
    bg: { file: FILE, stock: 'preprinted', w: 400, h: 300 },
    fields: [{ key: 'text', x: 1, y: 1.5, w: 30, h: 5, font: 'sans', pt: 10, align: 'start', bold: true, text: 'ضمان 5 < 10 أيام' }],
  },
};
const image = { type: 'png' as const, bytes: bytes() };
const raw = (t = free, img: typeof image | null = image) => JSON.parse(exportTemplate(t, img)) as Record<string, Record<string, unknown>>;
const rejects = (v: unknown) => expect(() => parseTemplate(typeof v === 'string' ? v : JSON.stringify(v))).toThrow('E_TEMPLATE_FILE');

describe('تصدير واستيراد القالب (50.5)', () => {
  it('بيروح ويرجع زي ما هو', () => {
    expect(parseTemplate(exportTemplate(flow, null))).toEqual({ template: { ...flow, layout: { lang: 'ar', bg: null } }, image: null, bg: null });
    const r = parseTemplate(exportTemplate(free, image));
    expect(r).toEqual({ template: { ...free, layout: { ...free.layout, bg: null } }, image, bg: { stock: 'preprinted', w: 400, h: 300 } });
  });
  it('من غير أي ids من المحل، ومن غير الصورة لو مش متصدّرة', () => {
    expect(exportTemplate(free, image)).not.toContain(FILE);
    expect(raw(free, null)).not.toHaveProperty('background');
    expect(parseTemplate(exportTemplate(free, null)).bg).toBeNull();
  });
  it('صورة كبيرة على الحد بتروح وترجع، وفوقه مرفوضة', () => {
    expect(parseTemplate(exportTemplate(free, { type: 'png', bytes: bytes(BG_MAX_BYTES) })).image!.bytes.length).toBe(BG_MAX_BYTES);
    expect(() => exportTemplate(free, { type: 'png', bytes: bytes(BG_MAX_BYTES + 1) })).toThrow('E_TEMPLATE_FILE');
  });
  it('ملف مش JSON أو ضخم أو صيغة تانية', () => {
    for (const v of ['', '<html>', 'null', '[]', '5', ' '.repeat(EXPORT_MAX_CHARS + 1)]) rejects(v);
    rejects({ ...raw(), format: 'x' });
    rejects({ ...raw(), version: 2 });
    rejects({ ...raw(), shop_id: 'x' });
  });
  it('متلاعب فيه: نفس فحص الحفظ', () => {
    rejects({ ...raw(), doc: 'receipt' });
    rejects({ ...raw(), mode: 'html' });
    rejects({ ...raw(), layout: { ...raw().layout, html: 'x' } });
    rejects({ ...raw(), layout: { ...raw().layout, bg: { file: FILE, stock: 'blank', w: 400, h: 300 } } });
    rejects({ ...raw(), layout: { ...raw().layout, fields: [{ ...(raw().layout.fields as object[])[0], x: 39 }] } });
    rejects({ ...raw(flow, null), blocks: [{ key: 'script' }] });
  });
  it('الصورة: HTML وSVG، ونوع مش مطابق، وبايظة، ونسبة أو طريقة ورق غلط', () => {
    const b = raw().background;
    const withBg = (o: object) => ({ ...raw(), background: { ...b, ...o } });
    for (const s of ['<svg onload="x">', '<html><script>']) rejects(withBg({ data: btoa(s) }));
    rejects(withBg({ type: 'jpg' }));
    rejects(withBg({ type: 'svg' }));
    rejects(withBg({ data: '***' }));
    rejects(withBg({ data: '' }));
    rejects(withBg({ h: 400 }));
    rejects(withBg({ stock: 'x' }));
    rejects(withBg({ url: 'x' }));
  });
  it('نص فيه وسوم HTML مرفوض', () => {
    for (const s of ['<b>x</b>', '< script>', '</p>', '<!--x', '<?xml', '<SVG'])
      rejects({ ...raw(), layout: { ...raw().layout, fields: [{ ...(raw().layout.fields as object[])[0], text: s }] } });
    expect(() => exportTemplate({ ...flow, blocks: [{ key: 'text', show: true, size: 'md', align: 'start', bold: false, text: '<img src=x>' }] }, null)).toThrow('E_TEMPLATE_FILE');
  });
});
