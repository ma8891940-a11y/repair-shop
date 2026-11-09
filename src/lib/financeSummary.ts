/**
 * البند 8: جملة النتيجة بالفصحى ومقارنة بالفترة اللي قبلها.
 * كل الحساب بالقروش كأعداد صحيحة. النسبة المئوية للعرض بس (عدد صحيح مقرّب).
 */
import { addDays, periodRange, type Period } from './ledger';
import { cairoDayEnd, cairoDayStart } from './dates';
import { assertPiasters } from './money';

/** الفترة اللي قبلها بنفس الطول: النهارده ← امبارح، والأسبوع ← الـ 7 أيام اللي قبله،
 *  والشهر ← نفس الأيام من الشهر اللي فات (مقارنة عادلة)، والمخصص ← نفس عدد الأيام قبله */
export function previousRange(p: Period, now: Date): { from: Date; to: Date; days: string[] } {
  const cur = periodRange(p, now);
  const first = cur.days[0];
  const n = cur.days.length;
  let a: string;
  let b: string;
  if (p.kind === 'month') {
    const [y, m] = first.split('-').map(Number);
    const py = m === 1 ? y - 1 : y;
    const pm = m === 1 ? 12 : m - 1;
    const last = new Date(Date.UTC(py, pm, 0)).getUTCDate();
    a = `${py}-${String(pm).padStart(2, '0')}-01`;
    b = `${py}-${String(pm).padStart(2, '0')}-${String(Math.min(n, last)).padStart(2, '0')}`;
  } else {
    b = addDays(first, -1);
    a = addDays(first, -n);
  }
  const days: string[] = [];
  for (let d = a; d <= b; d = addDays(d, 1)) days.push(d);
  return { from: cairoDayStart(a), to: cairoDayEnd(b), days };
}

export type Trend = 'up' | 'down' | 'same' | 'na';

/** النسبة بين فترتين (عدد صحيح، من غير كسور في الحساب). "na" لو المقارنة مالهاش معنى (الفترة اللي فاتت صفر أو إشارة مختلفة) */
export function compare(cur: number, prev: number): { trend: Trend; pct: number | null } {
  assertPiasters(cur);
  assertPiasters(prev);
  if (cur === prev) return { trend: 'same', pct: 0 };
  if (prev === 0 || Math.sign(prev) !== Math.sign(cur) || cur === 0) return { trend: cur > prev ? 'up' : 'down', pct: null };
  const diff = Math.abs(cur - prev);
  // تقريب لأقرب عدد صحيح بأعداد صحيحة بس
  const pct = Math.floor((diff * 100 + Math.floor(Math.abs(prev) / 2)) / Math.abs(prev));
  return { trend: cur > prev ? 'up' : 'down', pct };
}

export interface ResultSentence {
  /** مفتاح الجملة الأساسية: ربح / خسارة / تعادل */
  main: 'profit' | 'loss' | 'even';
  /** مفتاح المقارنة */
  cmp: 'up' | 'down' | 'same' | 'upNoPct' | 'downNoPct' | 'none';
  pct: number | null;
  profit: number;
  prevProfit: number | null;
  revenue: number;
  expenses: number;
}

export function resultSentence(cur: { profit: number; revenue: number; expenses: number }, prev: { profit: number } | null): ResultSentence {
  const profit = Number(cur.profit);
  const main = profit > 0 ? 'profit' : profit < 0 ? 'loss' : 'even';
  let cmp: ResultSentence['cmp'] = 'none';
  let pct: number | null = null;
  if (prev) {
    const c = compare(profit, Number(prev.profit));
    pct = c.pct;
    cmp = c.trend === 'same' ? 'same' : c.pct == null ? (c.trend === 'up' ? 'upNoPct' : 'downNoPct') : c.trend === 'up' ? 'up' : 'down';
  }
  return { main, cmp, pct, profit, prevProfit: prev ? Number(prev.profit) : null, revenue: Number(cur.revenue), expenses: Number(cur.expenses) };
}

