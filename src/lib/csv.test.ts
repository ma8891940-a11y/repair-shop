import { describe, expect, it } from 'vitest';
import { parseCsv, parseItemsCsv } from './csv';
import { toCsv } from './ledger';

describe('قراءة CSV من Excel', () => {
  it('تنصيص وفواصل وسطور جوه الخلية، وفاصلة منقوطة', () => {
    expect(parseCsv('﻿a,b\r\n"x, y","q""z"\n')).toEqual([['a', 'b'], ['x, y', 'q"z']]);
    expect(parseCsv('a;b\n1;2')).toEqual([['a', 'b'], ['1', '2']]);
    expect(parseCsv('a,b\n"سطر\nتاني",2')).toEqual([['a', 'b'], ['سطر\nتاني', '2']]);
  });
  it('اللي بنصدّره بنعرف نقراه تاني زي ما هو', () => {
    const rows = [['الصنف', 'السعر'], ['=خطر', '-5'], ['جراب, أسود', '12.50']];
    expect(parseCsv(toCsv(rows))).toEqual(rows);
  });
  it('استيراد أصناف: عناوين عربي، وأرقام عربي، والسطور الغلط بسببها', () => {
    const csv = ['الصنف,النوع,التصنيف,الباركود,سعر البيع,الحد الأدنى', 'شاشة A10,قطعة غيار,شاشات,2000000000017,٤٥٠,٢', 'جراب,إكسسوار,,,50.5,', ',قطعة,,,,', 'بطارية,حاجة,,,,', 'سلك,إكسسوار,,,abc,', 'شاحن,إكسسوار,,2000000000017,,'].join('\n');
    const r = parseItemsCsv(csv);
    expect(r.rows).toEqual([
      { name: 'شاشة A10', kind: 'part', category: 'شاشات', barcode: '2000000000017', sale_price: 45000, min_qty: 2 },
      { name: 'جراب', kind: 'accessory', category: null, barcode: null, sale_price: 5050, min_qty: 0 },
    ]);
    expect(r.errors).toEqual([
      { line: 4, reason: 'name' },
      { line: 5, reason: 'kind' },
      { line: 6, reason: 'price' },
      { line: 7, reason: 'dup' },
    ]);
  });
  it('عناوين إنجليزي، والباركود الموجود في المحل بيترفض', () => {
    const r = parseItemsCsv('name,kind,barcode,price\nCable,accessory,123456,10', new Set(['123456']));
    expect(r.errors).toEqual([{ line: 2, reason: 'dup' }]);
  });
});
