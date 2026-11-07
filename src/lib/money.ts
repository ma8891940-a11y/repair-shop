// كل المبالغ في البرنامج بالقروش كأعداد صحيحة (100 قرش = 1 جنيه).
// ممنوع أي عدد عشري في الحسابات. التحويل لجنيه بيحصل في العرض بس.
import { toLatinDigits } from './digits';

export type Piasters = number;

export const MAX_PIASTERS = 2_000_000_000; // حد أمان (20 مليون جنيه) أقل من حد integer في PostgreSQL

/**
 * يحوّل نص مكتوب بالجنيه (مثل "150" أو "150.5" أو "١٥٠٫٥٠") لقروش.
 * التحويل بيتعمل على النص نفسه، من غير أي عملية عشرية.
 * يرجع null لو النص مش رقم صحيح.
 */
export function parsePounds(input: string): Piasters | null {
  const s = toLatinDigits(input.trim())
    .replace(/[\u066B\u066C,\u060C]/g, (ch) => (ch === '\u066B' ? '.' : '')) // ٫ فاصلة عشرية عربية، والفواصل الألفية (٬ و, و،) تتشال
    .replace(/\s+/g, '');
  if (s === '') return null;
  const m = /^(\d+)(?:\.(\d{1,2}))?$/.exec(s);
  if (!m) return null;
  const pounds = m[1].replace(/^0+(?=\d)/, '');
  const frac = (m[2] ?? '').padEnd(2, '0');
  if (pounds.length > 8) return null;
  const value = Number(pounds) * 100 + Number(frac);
  if (!Number.isSafeInteger(value) || value > MAX_PIASTERS) return null;
  return value;
}

/** يعرض القروش بالجنيه: 15050 => "150.50" و 15000 => "150" */
export function formatPounds(piasters: Piasters): string {
  assertPiasters(piasters);
  const negative = piasters < 0;
  const abs = Math.abs(piasters);
  const pounds = Math.floor(abs / 100);
  const rest = abs % 100;
  const poundsStr = String(pounds).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const text = rest === 0 ? poundsStr : `${poundsStr}.${String(rest).padStart(2, '0')}`;
  return negative ? `-${text}` : text;
}

/** يجمع مبالغ بالقروش ويتأكد إنها كلها أعداد صحيحة */
export function sumPiasters(values: Array<Piasters | null | undefined>): Piasters {
  let total = 0;
  for (const v of values) {
    if (v == null) continue;
    assertPiasters(v);
    total += v;
  }
  assertPiasters(total);
  return total;
}

export function assertPiasters(v: number): void {
  if (!Number.isSafeInteger(v)) {
    throw new Error(`AMOUNT_NOT_INTEGER_MINOR_UNITS: ${v}`);
  }
}
