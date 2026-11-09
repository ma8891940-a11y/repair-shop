// الشركاء: النسبة بتتخزن عدد صحيح بالـ 0.01% (60% = 6000)، من غير كسور
import { parsePounds } from './money';

/** "60" أو "33.5" أو "٣٣٫٥" ← 6000 أو 3350. نفس قراءة المبالغ (منزلتين عشريتين بالظبط) */
export function parsePercent(input: string): number | null {
  const v = parsePounds(input.replace(/[%\u066A]/g, ''));
  return v == null || v > 10000 ? null : v;
}

/** نصيب كل شريك من ربح (أو خسارة) بالقروش: نفس قسمة قاعدة البيانات (أعداد صحيحة، والكسر بيتشال ناحية الصفر) */
export function shareOf(profit: number, bp: number): number {
  return Math.trunc((profit * bp) / 10000) || 0;
}

/** الباقي للمحل بعد نسب الشركاء */
export function remainingBp(shares: number[]): number {
  return 10000 - shares.reduce((a, b) => a + b, 0);
}
