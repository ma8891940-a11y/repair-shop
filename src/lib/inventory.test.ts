import { describe, expect, it } from 'vitest';
import { shortageOrders, suggestedOrderQty } from './inventory';

describe('طلبيات النواقص', () => {
  it('الكمية المقترحة بترجّع المخزون لضعف الحد الأدنى (وأقل حاجة 1)', () => {
    expect(suggestedOrderQty(2, 5)).toBe(8);
    expect(suggestedOrderQty(0, 3)).toBe(6);
    expect(suggestedOrderQty(-2, 3)).toBe(6);
    expect(suggestedOrderQty(10, 3)).toBe(1);
  });
  it('بتتجمع حسب المورد، والأصناف من غير مورد أو مش ناقصة بتتشال', () => {
    const sup = [
      { id: 's1', name: 'أ', phone: '01011111111' },
      { id: 's2', name: 'ب', phone: null },
    ];
    const r = shortageOrders(
      [
        { id: 'i1', name: 'شاشة', qty: 1, min_qty: 2, supplier_id: 's1', short: true },
        { id: 'i2', name: 'بطارية', qty: 0, min_qty: 1, supplier_id: 's1', short: true },
        { id: 'i3', name: 'جراب', qty: 0, min_qty: 5, supplier_id: 's2', short: true },
        { id: 'i4', name: 'كابل', qty: 9, min_qty: 2, supplier_id: 's1', short: false },
        { id: 'i5', name: 'سماعة', qty: 0, min_qty: 2, supplier_id: null, short: true },
        { id: 'i6', name: 'شاحن', qty: 0, min_qty: 2, supplier_id: 'gone', short: true },
      ],
      sup,
    );
    expect(r).toEqual([
      { supplierId: 's1', name: 'أ', phone: '01011111111', lines: [{ itemId: 'i1', name: 'شاشة', qty: 3 }, { itemId: 'i2', name: 'بطارية', qty: 2 }] },
      { supplierId: 's2', name: 'ب', phone: null, lines: [{ itemId: 'i3', name: 'جراب', qty: 10 }] },
    ]);
    expect(shortageOrders([], sup)).toEqual([]);
  });
});
