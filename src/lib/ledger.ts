import { assertPiasters, type Piasters } from './money';
import { cairoDay, cairoDayEnd, cairoDayStart } from './dates';

/** أنواع مصادر القيود (لازم تطابق journal_entries.source_type) */
export const SOURCE_TYPES = ['payment', 'delivery', 'purchase', 'supplier_payment', 'part_use', 'sale', 'expense', 'salary', 'salary_payment', 'advance', 'advance_settle', 'capital', 'drawing', 'transfer', 'drawer_close', 'reversal'] as const;
export type SourceType = (typeof SOURCE_TYPES)[number];

export type PeriodKind = 'today' | 'week' | 'month' | 'custom';
export interface Period {
  kind: PeriodKind;
  /** YYYY-MM-DD بتوقيت القاهرة (للمخصص) */
  from?: string;
  to?: string;
}

function addDays(day: string, n: number): string {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** الفترة كلحظتين [from, to) بتوقيت القاهرة، والأيام اللي فيها */
export function periodRange(p: Period, now: Date): { from: Date; to: Date; days: string[] } {
  const today = cairoDay(now);
  let a = today;
  let b = today;
  if (p.kind === 'week') a = addDays(today, -6);
  else if (p.kind === 'month') a = `${today.slice(0, 8)}01`;
  else if (p.kind === 'custom') {
    a = p.from || today;
    b = p.to || a;
    if (b < a) [a, b] = [b, a];
  }
  const days: string[] = [];
  for (let d = a; d <= b && days.length < 400; d = addDays(d, 1)) days.push(d);
  return { from: cairoDayStart(a), to: cairoDayEnd(b), days };
}

/** بيملا الأيام الفاضية بصفر عشان الرسم اليومي يبقى متصل */
export function fillDaily<T extends { day: string }>(days: string[], rows: T[], empty: (day: string) => T): T[] {
  const m = new Map(rows.map((r) => [r.day.slice(0, 10), r]));
  return days.map((d) => m.get(d) ?? empty(d));
}

/**
 * حاسبة التسعير: تكلفة القطع + المصنعية + نسبة ربح على القطع، والسعر بيتقرّب لفوق لأقرب "خطوة" (مثلًا 5 جنيه).
 * كله أعداد صحيحة بالقروش. النسبة عدد صحيح (15 = 15%).
 */
export function suggestPrice(o: { parts: Piasters; labor: Piasters; marginPct: number; step?: Piasters }): { price: Piasters; profit: Piasters; markup: Piasters } {
  for (const v of [o.parts, o.labor]) {
    assertPiasters(v);
    if (v < 0) throw new Error('NEGATIVE_AMOUNT');
  }
  if (!Number.isInteger(o.marginPct) || o.marginPct < 0 || o.marginPct > 1000) throw new Error('BAD_MARGIN');
  const step = o.step ?? 500;
  // تقريب لفوق من غير كسور: ceil(parts * pct / 100)
  const markup = Math.floor((o.parts * o.marginPct + 99) / 100);
  const raw = o.parts + o.labor + markup;
  const price = step > 0 ? Math.ceil(raw / step) * step : raw;
  assertPiasters(price);
  return { price, profit: price - o.parts, markup };
}

/** ملف CSV يفتح في Excel بالعربي (BOM + فاصل سطور ويندوز) */
export function toCsv(rows: (string | number | null | undefined)[][]): string {
  const esc = (v: string | number | null | undefined) => {
    const s = v == null ? '' : String(v);
    // حماية من الصيغ في Excel (=, +, -, @ في أول الخلية)، إلا لو رقم سالب عادي
    const safe = /^[=+@\t\r]/.test(s) || (/^-/.test(s) && !/^-\d+(\.\d+)?$/.test(s.replace(/,/g, ''))) ? `'${s}` : s;
    return /[",\n\r]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
  };
  return '﻿' + rows.map((r) => r.map(esc).join(',')).join('\r\n');
}

/** نص المبلغ للملفات: بالجنيه بنقطة عشرية ومن غير فواصل (عشان Excel يقراه رقم) */
export function plainPounds(minor: Piasters): string {
  assertPiasters(minor);
  const neg = minor < 0;
  const abs = Math.abs(minor);
  const s = `${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
  return neg ? `-${s}` : s;
}

/** فلترة حركات كشف الحساب بالبحث (البيان، رقم الطلب، الموظف، رقم القيد) */
export function matchMove(m: { memo?: string | null; order_no?: string | null; by?: string | null; entry_no?: number | string }, q: string, label: string): boolean {
  const s = q.trim().toLowerCase();
  if (!s) return true;
  return [m.memo, m.order_no, m.by, String(m.entry_no ?? ''), label].some((x) => (x ?? '').toLowerCase().includes(s));
}
