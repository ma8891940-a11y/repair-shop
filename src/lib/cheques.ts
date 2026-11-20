// R7: الشيكات: قرب ميعاد الاستحقاق (بيوم القاهرة)، للتنبيه في القايمة
import { cairoDay } from './dates';

export type ChequeStatus = 'pending' | 'cleared' | 'bounced';
export type ChequeUrgency = 'overdue' | 'soon' | 'later' | 'done';

/** الأيام بين يومين (YYYY-MM-DD) من غير ساعات ولا توقيت صيفي */
function dayDiff(a: string, b: string): number {
  const [ya, ma, da] = a.split('-').map(Number);
  const [yb, mb, db] = b.split('-').map(Number);
  return Math.round((Date.UTC(ya, ma - 1, da) - Date.UTC(yb, mb - 1, db)) / 86_400_000);
}

/** فات ميعاده، أو فاضل 3 أيام أو أقل، أو لسه بدري. الشيك اللي اتصرف أو اترفض خلص */
export function chequeUrgency(status: ChequeStatus, due: string, now: Date, soonDays = 3): ChequeUrgency {
  if (status !== 'pending') return 'done';
  const left = dayDiff(due.slice(0, 10), cairoDay(now));
  if (left < 0) return 'overdue';
  return left <= soonDays ? 'soon' : 'later';
}
