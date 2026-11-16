/**
 * C6: توقع نفاد المخزون من معدل الصرف (بيع + قطع اتركبت) في آخر 30 يوم. أعداد صحيحة بس.
 * - مفيش صرف: مش هيخلص (null).
 * - الرصيد صفر أو أقل: خلص (0).
 * - غير كده: عدد الأيام = floor(الرصيد × 30 ÷ صرف الـ 30 يوم).
 */
export function daysLeft(qty: number, used30: number): number | null {
  if (!Number.isFinite(qty) || !Number.isFinite(used30)) return null;
  if (qty <= 0) return 0;
  if (used30 <= 0) return null;
  return Math.floor((qty * 30) / used30);
}

export type Urgency = 'out' | 'soon' | 'month' | 'ok';
/** خلص، أو أقل من أسبوع، أو أقل من شهر، أو كويس */
export function urgency(days: number | null): Urgency {
  if (days === null) return 'ok';
  if (days <= 0) return 'out';
  if (days < 7) return 'soon';
  if (days < 30) return 'month';
  return 'ok';
}

/** الكمية المقترح تشتريها عشان تكفي `cover` يوم (بالتقريب لفوق) */
export function reorderQty(qty: number, used30: number, cover = 30): number {
  if (used30 <= 0) return 0;
  const need = Math.ceil((used30 * cover) / 30) - Math.max(qty, 0);
  return Math.max(need, 0);
}

/** نسبة تكلفة القطع من الإيراد بـ basis points (10000 = 100%)، أعداد صحيحة */
export function shareBp(cost: number, revenue: number): number | null {
  if (revenue <= 0) return null;
  return Math.round((cost * 10000) / revenue);
}
