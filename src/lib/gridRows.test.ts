import { describe, expect, it } from 'vitest';
import { addRows, removeBlankRows, removeRows, rowCount, pastedRows } from './gridRows';
import { checkStockRows, isBlankStock, pasteIntoGrid, type StockRowIn } from './opening';

type R = StockRowIn & { k: string };
let n = 0;
const blank = (): R => ({ k: `k${++n}`, name: '', kind: 'part', qty: '', cost: '', price: '' });
const row = (name: string, qty = '1', cost = '10'): R => ({ ...blank(), name, qty, cost });

describe('سطور جدول الجرد', () => {
  it('"عدد السطور": بيزوّد العدد المكتوب بالظبط (1 افتراضيًا)، وبالأرقام العربي، ومش أكتر من 500', () => {
    expect(rowCount('')).toBe(1);
    expect(rowCount('3')).toBe(3);
    expect(rowCount('٧')).toBe(7);
    expect(rowCount('0')).toBe(1);
    expect(rowCount('-4')).toBe(1);
    expect(rowCount('abc')).toBe(1);
    expect(rowCount('100000')).toBe(500);
    const rows = [blank()];
    expect(addRows(rows, rowCount('3'), blank)).toHaveLength(4);
    expect(addRows(rows, rowCount(''), blank)).toHaveLength(2);
  });

  it('حذف سطر أو كذا سطر بالمفتاح، والباقي ما بيتلخبطش', () => {
    const rows = [row('أ'), row('ب'), row('ج'), row('د')];
    const out = removeRows(rows, new Set([rows[1].k, rows[3].k]), blank);
    expect(out.map((r) => r.name)).toEqual(['أ', 'ج']);
    expect(out[1].k).toBe(rows[2].k);
    // حذف الكل: بيفضل سطر واحد فاضي
    expect(removeRows(rows, new Set(rows.map((r) => r.k)), blank)).toHaveLength(1);
  });

  it('"حذف السطور الفاضية"، والسطر الفاضي ما بيتحسبش ولا بيطلّع خطأ (حتى لو النوع اتغير)', () => {
    const rows = [row('شاشة'), blank(), { ...blank(), kind: 'accessory' }, row('بطارية', '2', '50'), blank()];
    expect(removeBlankRows(rows, isBlankStock, blank).map((r) => r.name)).toEqual(['شاشة', 'بطارية']);
    expect(removeBlankRows([blank(), blank()], isBlankStock, blank)).toHaveLength(1);
    const c = checkStockRows(rows);
    expect(c.errors).toEqual([]);
    expect(c.lines.map((l) => l.name)).toEqual(['شاشة', 'بطارية']);
  });

  it('اللصق من Excel بيزوّد بعدد السطور الملصوقة بس (من غير السطر الفاضي اللي Excel بيحطه في الآخر)', () => {
    expect(pastedRows('a\t1\nb\t2\n')).toEqual(['a\t1', 'b\t2']);
    expect(pastedRows('a\t1\r\nb\t2\r\n\r\n')).toEqual(['a\t1', 'b\t2']);
    const cols: (keyof R)[] = ['name', 'kind', 'qty', 'cost', 'price'];
    // جدول فيه سطر واحد فاضي، لصق 3 سطور ← 3 سطور بالظبط
    const out = pasteIntoGrid([blank()], 0, 0, 'شاشة\tpart\t2\t100\t\nبطارية\tpart\t1\t50\t\nجراب\taccessory\t5\t10\t\n', cols, blank);
    expect(out).toHaveLength(3);
    // لصق سطرين من السطر التاني في جدول 3 سطور ← 3 (مش 4)
    expect(pasteIntoGrid([blank(), blank(), blank()], 1, 0, 'a\tpart\t1\t1\t\nb\tpart\t1\t1\t\n', cols, blank)).toHaveLength(3);
  });
});
