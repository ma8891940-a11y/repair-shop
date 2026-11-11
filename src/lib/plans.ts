/**
 * N: تقسيم مبلغ على أقساط بالقروش (أعداد صحيحة بس). الكسر بيروح على آخر قسط عشان المجموع يطلع بالظبط.
 * والمواعيد: كل شهر (نفس اليوم، ولو الشهر أقصر آخر يوم فيه) أو كل أسبوع.
 */
export type Every = 'month' | 'week';

export function splitEven(total: number, count: number): number[] {
  if (!Number.isInteger(total) || total <= 0 || !Number.isInteger(count) || count < 1) return [];
  const base = Math.floor(total / count);
  if (base <= 0) return [total];
  const out = Array.from({ length: count }, () => base);
  out[count - 1] += total - base * count;
  return out;
}

/** 'YYYY-MM-DD' + n شهور/أسابيع (بالتاريخ بس، من غير ساعات عشان فرق التوقيت ما يلخبطش اليوم) */
export function addPeriod(iso: string, n: number, every: Every): string {
  const [y, m, d] = iso.split('-').map(Number);
  if (every === 'week') {
    const t = new Date(Date.UTC(y, m - 1, d + 7 * n));
    return t.toISOString().slice(0, 10);
  }
  const target = new Date(Date.UTC(y, m - 1 + n, 1));
  const last = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  target.setUTCDate(Math.min(d, last));
  return target.toISOString().slice(0, 10);
}

export function buildSchedule(total: number, count: number, first: string, every: Every): { due: string; amount: number }[] {
  return splitEven(total, count).map((amount, i) => ({ due: addPeriod(first, i, every), amount }));
}
