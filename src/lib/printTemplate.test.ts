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

describe('U5: قالب كشف الحساب', () => {
  it('الافتراضي بالترتيب، والتوقيع والشكر مخفيين، والرصيد الختامي كبير وعريض', () => {
    const b = defaultBlocks('statement');
    expect(b.map((x) => x.key)).toEqual(['header', 'title', 'party', 'period', 'opening', 'moves', 'closing', 'signature', 'thanks']);
    expect(b.filter((x) => !x.show).map((x) => x.key)).toEqual(['signature', 'thanks']);
    expect(b.find((x) => x.key === 'closing')).toMatchObject({ size: 'lg', bold: true });
  });
  it('التنضيف: خانة من نوع تاني بتتشال، والناقصة بتتضاف مخفية، و"نص حر" مسموح', () => {
    const b = normalizeBlocks('statement', [
      { key: 'imei', show: true },
      { key: 'closing', show: true, size: 'sm' },
      { key: 'text', show: true, text: 'شكرًا' },
    ]);
    expect(b.map((x) => x.key)).not.toContain('imei');
    expect(b[0]).toMatchObject({ key: 'closing', size: 'sm' });
    expect(b[1]).toMatchObject({ key: 'text', text: 'شكرًا' });
    expect(b.filter((x) => x.key !== 'closing' && x.key !== 'text').every((x) => !x.show)).toBe(true);
    expect(b).toHaveLength(2 + 8);
  });
  it('الأنواع القديمة زي ما هي (الإيصال والفاتورة من غير خانات كشف الحساب)', () => {
    for (const d of ['receipt', 'receipt-a4', 'invoice'] as const) {
      const keys = defaultBlocks(d).map((x) => x.key);
      for (const k of ['party', 'period', 'opening', 'moves', 'closing']) expect(keys).not.toContain(k);
      expect(defaultBlocks(d).every((x) => x.show)).toBe(true);
    }
  });
});

describe('U5: قالب السند', () => {
  it('الافتراضي بالترتيب، والمبلغ كبير وعريض، والشكر مخفي', () => {
    const b = defaultBlocks('voucher');
    expect(b.map((x) => x.key)).toEqual(['header', 'title', 'entryNo', 'date', 'party', 'amount', 'method', 'cashbox', 'memo', 'sign', 'thanks']);
    expect(b.filter((x) => !x.show).map((x) => x.key)).toEqual(['thanks']);
    expect(b.find((x) => x.key === 'amount')).toMatchObject({ size: 'lg', bold: true });
    expect(normalizeBlocks('voucher', [{ key: 'opening', show: true }]).map((x) => x.key)).not.toContain('opening');
  });
});

describe('6ب: قالب فاتورة البيع', () => {
  it('الافتراضي بالترتيب وكله ظاهر، وجدول الأصناف خانة واحدة، والإجمالي كبير', () => {
    const b = defaultBlocks('sale');
    expect(b.map((x) => x.key)).toEqual(['header', 'title', 'entryNo', 'date', 'customer', 'phone', 'lines', 'total', 'paid', 'remaining', 'memo', 'sign', 'thanks']);
    expect(b.every((x) => x.show)).toBe(true);
    expect(b.find((x) => x.key === 'total')).toMatchObject({ size: 'lg', bold: true });
    expect(normalizeBlocks('sale', [{ key: 'qr', show: true }]).map((x) => x.key)).not.toContain('qr');
  });
});

describe('6ج: قالب ملصق الباركود', () => {
  it('الافتراضي = الملصق القديم: اسم المحل صغير وعريض، والسعر كبير وعريض، وكله في النص', () => {
    const b = defaultBlocks('barcode');
    expect(b.map((x) => [x.key, x.size, x.bold, x.align])).toEqual([
      ['header', 'sm', true, 'center'],
      ['itemName', 'md', false, 'center'],
      ['code', 'md', false, 'center'],
      ['price', 'lg', true, 'center'],
    ]);
    expect(b.every((x) => x.show)).toBe(true);
    // التنضيف بيرجّع الناقص بنفس افتراضي الملصق (مش الافتراضي العام)
    const n = normalizeBlocks('barcode', [{ key: 'price', show: false }]);
    expect(n[0]).toMatchObject({ key: 'price', show: false, size: 'lg', bold: true, align: 'center' });
    expect(n.find((x) => x.key === 'header')).toMatchObject({ show: false, size: 'sm', bold: true });
  });
});
