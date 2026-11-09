// جرد المحل أول مرة: التقدم في الخطوات، واللصق من Excel في الجدول، وفحص السطور قبل الحفظ
import { parseCsv } from './csv';
import { toLatinDigits } from './digits';
import { parsePounds } from './money';

export const OPENING_STEPS = ['stock', 'cash', 'customers', 'suppliers'] as const;
export type OpeningStep = (typeof OPENING_STEPS)[number];

export interface OpeningProgress {
  steps: Record<OpeningStep, boolean>;
  count: number;
  total: number;
  done: boolean;
}

/** التقدم محفوظ في shops.extras: opening_steps (الخطوات اللي اتحفظت أو اتخطت) وopening_done */
export function openingProgress(extras: unknown): OpeningProgress {
  const o = extras && typeof extras === 'object' ? (extras as Record<string, unknown>) : {};
  const st = o.opening_steps && typeof o.opening_steps === 'object' ? (o.opening_steps as Record<string, unknown>) : {};
  const steps = Object.fromEntries(OPENING_STEPS.map((k) => [k, st[k] === true])) as Record<OpeningStep, boolean>;
  const count = OPENING_STEPS.filter((k) => steps[k]).length;
  return { steps, count, total: OPENING_STEPS.length, done: o.opening_done === true };
}

/**
 * لصق من Excel: النص اللي اتنسخ (أعمدة بـ Tab وسطور) بيتحط في الجدول ابتداءً من الخانة اللي عليها التركيز،
 * وبيزوّد سطور لو محتاج. الأعمدة الزيادة عن الجدول بتتجاهل.
 */
export function pasteIntoGrid<T extends object>(rows: T[], row: number, col: number, text: string, cols: (keyof T)[], blank: () => T): T[] {
  const grid = parseCsv(text.includes('\t') ? text : text.replace(/,/g, '\t'));
  const out = rows.map((r) => ({ ...r }));
  grid.forEach((cells, i) => {
    const ri = row + i;
    while (out.length <= ri) out.push(blank());
    cells.forEach((v, j) => {
      const c = cols[col + j];
      if (c !== undefined) (out[ri] as unknown as Record<string, string>)[c as string] = v;
    });
  });
  return out;
}

export interface StockRowIn {
  name: string;
  kind: string;
  qty: string;
  cost: string;
  price: string;
}
export interface StockLineOk {
  index: number;
  name: string;
  kind: 'part' | 'accessory';
  qty: number;
  unitCost: number;
  salePrice: number | null;
}
/** سطور الجدول: الفاضي بيتجاهل، والغلط بيرجع برقمه والعمود. التكلفة بالقروش أعداد صحيحة */
export function checkStockRows(rows: StockRowIn[]): { lines: StockLineOk[]; errors: { index: number; col: keyof StockRowIn }[] } {
  const lines: StockLineOk[] = [];
  const errors: { index: number; col: keyof StockRowIn }[] = [];
  rows.forEach((r, index) => {
    if (!r.name.trim() && !r.qty.trim() && !r.cost.trim() && !r.price.trim()) return;
    if (!r.name.trim()) return errors.push({ index, col: 'name' });
    const qty = Number(toLatinDigits(r.qty.trim()));
    if (!Number.isInteger(qty) || qty <= 0 || qty > 100000) return errors.push({ index, col: 'qty' });
    const unitCost = parsePounds(r.cost);
    if (unitCost == null) return errors.push({ index, col: 'cost' });
    const salePrice = r.price.trim() ? parsePounds(r.price) : null;
    if (r.price.trim() && salePrice == null) return errors.push({ index, col: 'price' });
    lines.push({ index, name: r.name.trim(), kind: r.kind === 'accessory' ? 'accessory' : 'part', qty, unitCost, salePrice });
  });
  return { lines, errors };
}
