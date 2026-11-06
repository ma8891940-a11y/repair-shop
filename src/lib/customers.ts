export type CustomerCategory = 'new' | 'regular' | 'vip' | 'late';

/**
 * اقتراح تصنيف العميل من تاريخه (صاحب المحل يقدر يغيّره بإيده):
 * - عليه فلوس متأخرة أكتر من 14 يوم = متأخر في الدفع (المرحلة 3 بتوفر الرقم)
 * - 6 أجهزة أو أكتر، أو صرف 5000 جنيه أو أكتر = VIP
 * - جهازين أو أكتر = دائم
 * - غير كده = جديد
 */
export function suggestCategory(o: { devices: number; spentMinor: number; overdueDays?: number }): CustomerCategory {
  if ((o.overdueDays ?? 0) > 14) return 'late';
  if (o.devices >= 6 || o.spentMinor >= 500_000) return 'vip';
  if (o.devices >= 2) return 'regular';
  return 'new';
}

/** لسه في الضمان؟ */
export function inWarranty(warrantyUntil: string | null | undefined, now: Date): boolean {
  return !!warrantyUntil && new Date(warrantyUntil).getTime() >= now.getTime();
}
