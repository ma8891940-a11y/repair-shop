import { describe, expect, it } from 'vitest';
import { DOC_BLOCKS, defaultBlocks, move, normalizeBlocks, pageCss, PRINTER_PRESETS } from './printTemplate';

describe('قوالب الطباعة', () => {
  it('الافتراضي فيه كل خانات نوع الورقة بالترتيب، ورقم الطلب والإجمالي كبار', () => {
    const r = defaultBlocks('receipt');
    expect(r.map((b) => b.key)).toEqual(DOC_BLOCKS.receipt);
    expect(r.every((b) => b.show)).toBe(true);
    expect(r.find((b) => b.key === 'orderNo')).toMatchObject({ size: 'lg', bold: true, align: 'center' });
    expect(defaultBlocks('invoice').find((b) => b.key === 'total')).toMatchObject({ size: 'lg', bold: true });
  });
  it('القالب المتخزّن بيتنضّف: المجهول بيتشال، والمتكرر مرة واحدة، والناقص بيتضاف مخفي، والقيم الغلط للافتراضي', () => {
    const n = normalizeBlocks('invoice', [
      { key: 'total', show: true, size: 'huge', align: 'center', bold: false },
      { key: 'hack', show: true },
      { key: 'total', show: false },
      { key: 'text', text: 'شكرًا لزيارتك'.padEnd(400, '.') },
      { key: 'text', text: 'تاني' },
    ]);
    expect(n[0]).toEqual({ key: 'total', show: true, size: 'lg', align: 'center', bold: false });
    expect(n.filter((b) => b.key === 'total')).toHaveLength(1);
    expect(n.filter((b) => b.key === 'text')).toHaveLength(2);
    expect(n[1].text).toHaveLength(300);
    expect(n.some((b) => (b.key as string) === 'hack')).toBe(false);
    // كل خانات الفاتورة موجودة، واللي ما كانتش في المتخزّن مخفية
    expect(new Set(n.map((b) => b.key))).toEqual(new Set([...DOC_BLOCKS.invoice, 'text']));
    expect(n.find((b) => b.key === 'paid')?.show).toBe(false);
    expect(normalizeBlocks('receipt', 'garbage').map((b) => b.key)).toEqual(DOC_BLOCKS.receipt);
  });
  it('الترتيب بالسحب، ومقاس الصفحة من ملف الطابعة', () => {
    expect(move(['a', 'b', 'c'], 0, 2)).toEqual(['b', 'c', 'a']);
    expect(move(['a', 'b'], 0, 5)).toEqual(['a', 'b']);
    expect(pageCss({ width_mm: 72, height_mm: null, margin_mm: 3 })).toBe('@page { size: 72mm auto; margin: 3mm; }');
    expect(PRINTER_PRESETS.some((p) => p.kind === 'dot')).toBe(true);
    expect(PRINTER_PRESETS.every((p) => p.width_mm > 0)).toBe(true);
  });
});
