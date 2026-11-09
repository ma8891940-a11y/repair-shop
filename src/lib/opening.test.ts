import { describe, expect, it } from 'vitest';
import { checkStockRows, openingProgress, pasteIntoGrid } from './opening';

const blank = () => ({ name: '', kind: 'part', qty: '', cost: '', price: '' });

describe('جرد المحل أول مرة', () => {
  it('التقدم من إعدادات المحل', () => {
    expect(openingProgress(null)).toEqual({ steps: { stock: false, cash: false, customers: false, suppliers: false }, count: 0, total: 4, done: false });
    expect(openingProgress({ opening_steps: { stock: true, cash: true, x: true }, opening_done: true })).toMatchObject({ count: 2, done: true });
  });
  it('لصق من Excel: من الخانة اللي عليها التركيز، وبيزوّد سطور، والأعمدة الزيادة بتتجاهل', () => {
    const rows = [blank()];
    const out = pasteIntoGrid(rows, 0, 0, 'شاشة\tpart\t5\t100\nشاحن\taccessory\t٣\t25.5\t40\textra', ['name', 'kind', 'qty', 'cost', 'price'], blank);
    expect(out).toEqual([
      { name: 'شاشة', kind: 'part', qty: '5', cost: '100', price: '' },
      { name: 'شاحن', kind: 'accessory', qty: '٣', cost: '25.5', price: '40' },
    ]);
    // من العمود التالت
    const out2 = pasteIntoGrid(out, 1, 2, '7\n8', ['name', 'kind', 'qty', 'cost', 'price'], blank);
    expect(out2.map((r) => r.qty)).toEqual(['5', '7', '8']);
    expect(rows[0].name).toBe(''); // الأصل ما اتغيرش
  });
  it('فحص السطور: الفاضي بيتجاهل، والغلط برقمه والعمود، والمبالغ بالقروش', () => {
    const r = checkStockRows([
      { name: 'شاشة', kind: 'part', qty: '٥', cost: '100.50', price: '' },
      blank(),
      { name: '', kind: 'part', qty: '2', cost: '1', price: '' },
      { name: 'بطارية', kind: 'part', qty: '1.5', cost: '1', price: '' },
      { name: 'كابل', kind: 'accessory', qty: '2', cost: 'x', price: '' },
      { name: 'جراب', kind: 'accessory', qty: '2', cost: '0', price: '30' },
    ]);
    expect(r.lines).toEqual([
      { index: 0, name: 'شاشة', kind: 'part', qty: 5, unitCost: 10050, salePrice: null },
      { index: 5, name: 'جراب', kind: 'accessory', qty: 2, unitCost: 0, salePrice: 3000 },
    ]);
    expect(r.errors).toEqual([
      { index: 2, col: 'name' },
      { index: 3, col: 'qty' },
      { index: 4, col: 'cost' },
    ]);
  });
});
