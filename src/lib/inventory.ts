/** طلبيات النواقص: الأصناف اللي وصلت للحد الأدنى، متجمّعة حسب المورد الأساسي، والكمية المقترحة بترجّع المخزون لضعف الحد */
export interface ShortItem {
  id: string;
  name: string;
  qty: number;
  min_qty?: number;
  supplier_id?: string | null;
  short?: boolean;
}
export interface SupplierRef {
  id: string;
  name: string;
  phone: string | null;
}
export interface ShortageOrder {
  supplierId: string;
  name: string;
  phone: string | null;
  lines: { itemId: string; name: string; qty: number }[];
}

export function suggestedOrderQty(qty: number, min: number): number {
  return Math.max(1, min * 2 - Math.max(0, qty));
}

export function shortageOrders(items: ShortItem[], suppliers: SupplierRef[]): ShortageOrder[] {
  const byId = new Map(suppliers.map((s) => [s.id, s]));
  const out = new Map<string, ShortageOrder>();
  for (const i of items) {
    if (!i.short || !i.supplier_id) continue;
    const s = byId.get(i.supplier_id);
    if (!s) continue;
    const o = out.get(s.id) ?? { supplierId: s.id, name: s.name, phone: s.phone, lines: [] };
    o.lines.push({ itemId: i.id, name: i.name, qty: suggestedOrderQty(i.qty, i.min_qty ?? 0) });
    out.set(s.id, o);
  }
  return [...out.values()];
}
