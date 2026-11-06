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

export const FOLLOW_UP_DAYS = 10;

/**
 * الأجهزة الجاهزة اللي العميل ما جاش ياخدها من FOLLOW_UP_DAYS يوم أو أكتر.
 * "جاهز من" = آخر مرة الجهاز دخل حالة ready (لو رجع للصيانة وجهز تاني، العدّ بيبدأ من جديد).
 * النتيجة مترتبة من الأقدم.
 */
export function overdueReady<T extends { id: string; status: string }>(
  devices: T[],
  events: { device_id: string; new_status: string; created_at: string }[],
  now: Date,
  days = FOLLOW_UP_DAYS,
): (T & { readySince: string; days: number })[] {
  const last = new Map<string, string>();
  for (const e of events) {
    if (e.new_status !== 'ready') continue;
    const prev = last.get(e.device_id);
    if (!prev || new Date(e.created_at) > new Date(prev)) last.set(e.device_id, e.created_at);
  }
  const out: (T & { readySince: string; days: number })[] = [];
  for (const d of devices) {
    if (d.status !== 'ready') continue;
    const since = last.get(d.id);
    if (!since) continue;
    const n = Math.floor((now.getTime() - new Date(since).getTime()) / 86_400_000);
    if (n >= days) out.push({ ...d, readySince: since, days: n });
  }
  return out.sort((a, b) => b.days - a.days);
}
