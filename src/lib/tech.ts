/** المدة بالدقايق => أنسب وحدة للعرض (دقيقة / ساعة / يوم)، بأعداد صحيحة */
export type DurationUnit = 'minute' | 'hour' | 'day';
export function durationParts(minutes: number): { value: number; unit: DurationUnit } {
  if (!Number.isFinite(minutes) || minutes <= 0) return { value: 0, unit: 'minute' };
  const m = Math.round(minutes);
  if (m < 60) return { value: m, unit: 'minute' };
  if (m < 24 * 60) return { value: Math.round(m / 60), unit: 'hour' };
  return { value: Math.round(m / (24 * 60)), unit: 'day' };
}
export function toMinutes(value: number, unit: DurationUnit): number | null {
  if (!Number.isFinite(value) || value <= 0) return null;
  const m = Math.round(value * (unit === 'day' ? 1440 : unit === 'hour' ? 60 : 1));
  return m >= 1 && m <= 100000 ? m : null;
}

export const PRIORITIES = ['urgent', 'normal', 'warranty'] as const;
export type Priority = (typeof PRIORITIES)[number];
/** نفس ترتيب قائمة الفني في قاعدة البيانات (my_queue): عاجل، ضمان، عادي، ثم الأقدم */
export function queueOrder<T extends { priority: string; received_at: string }>(rows: T[]): T[] {
  const rank = (p: string) => (p === 'urgent' ? 0 : p === 'warranty' ? 1 : 2);
  return [...rows].sort((a, b) => rank(a.priority) - rank(b.priority) || a.received_at.localeCompare(b.received_at));
}
