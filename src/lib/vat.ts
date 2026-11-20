// R5: ضريبة القيمة المضافة الاختيارية. الحساب الفعلي في قاعدة البيانات (vat_of)، وده نفس المعادلة للعرض بس.
import { toLatinDigits } from './digits';

export interface VatSettings {
  enabled: boolean;
  /** النسبة بالـ basis points: 1400 = 14% */
  rate_bp: number;
  reg_no: string;
}
export const DEFAULT_VAT_BP = 1400;
export const MAX_VAT_BP = 3000;

/** من shops.extras.vat: نفس قواعد vat_bp في قاعدة البيانات (قيمة مش سليمة = 14%، وأقصى حاجة 30%) */
export function readVat(extras: unknown): VatSettings {
  const ex = extras && typeof extras === 'object' ? (extras as Record<string, unknown>) : {};
  const v = ex.vat && typeof ex.vat === 'object' ? (ex.vat as Record<string, unknown>) : {};
  const raw = String(v.rate_bp ?? '');
  const bp = /^[0-9]{1,5}$/.test(raw) ? Math.min(Number(raw), MAX_VAT_BP) : DEFAULT_VAT_BP;
  return { enabled: v.enabled === true, rate_bp: bp, reg_no: typeof v.reg_no === 'string' ? v.reg_no : '' };
}

/** الضريبة جوه مبلغ شامل (بالقروش): round(g × bp ÷ (10000 + bp))، تقريب نص لفوق. أعداد صحيحة بس */
export function vatOf(gross: number, bp: number): number {
  if (!Number.isSafeInteger(gross) || !Number.isSafeInteger(bp)) throw new Error('E_BAD_AMOUNT');
  if (bp <= 0 || gross <= 0) return 0;
  return Math.floor((gross * bp * 2 + (10000 + bp)) / (2 * (10000 + bp)));
}

/** "14" أو "14.5" أو "١٤" ← basis points (1400، 1450). من غير كسور عشرية في الحساب. null لو مش سليم أو أكتر من 30% */
export function parsePercentBp(input: string): number | null {
  const s = toLatinDigits(input.trim()).replace(',', '.').replace(/%$/, '');
  const m = /^(\d{1,2})(?:\.(\d{1,2}))?$/.exec(s);
  if (!m) return null;
  const bp = Number(m[1]) * 100 + Number((m[2] ?? '').padEnd(2, '0'));
  return bp > MAX_VAT_BP ? null : bp;
}

/** 1400 ← "14"، و1450 ← "14.5" (للعرض في الخانة) */
export function bpToPercent(bp: number): string {
  const i = Math.floor(bp / 100);
  const f = bp % 100;
  return f === 0 ? String(i) : `${i}.${String(f).padStart(2, '0').replace(/0$/, '')}`;
}
