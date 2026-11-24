/** القيد بتاع أنهي قسم: نفس entry_section في قاعدة البيانات (0075) */
export function entrySection(source: string): string {
  if (['sale', 'sale_return'].includes(source)) return 'sales';
  if (['payment', 'transfer', 'drawer_close'].includes(source)) return 'cashbox';
  if (source === 'expense') return 'expenses';
  if (['purchase', 'supplier_payment', 'supplier_return'].includes(source)) return 'purchases';
  if (['write_off', 'stock_transfer'].includes(source)) return 'inventory';
  if (['part_use', 'delivery'].includes(source)) return 'devices';
  return 'finance';
}
