import { toLatinDigits } from './digits';

/**
 * يوحّد رقم الموبايل المصري لصيغة 01XXXXXXXXX (11 رقم).
 * يقبل: أرقام عربية، مسافات وشرط، +20 أو 0020 أو 20 في الأول.
 * يرجع null لو الرقم مش موبايل مصري صالح.
 */
export function normalizeEgyptPhone(input: string): string | null {
  let d = toLatinDigits(input).replace(/[^\d+]/g, '');
  if (d.startsWith('+')) d = d.slice(1);
  if (d.startsWith('0020')) d = d.slice(4);
  else if (d.startsWith('20') && d.length === 12) d = d.slice(2);
  if (d.length === 10 && d.startsWith('1')) d = '0' + d;
  if (!/^01[0125]\d{8}$/.test(d)) return null;
  return d;
}

/** يحوّل 01012345678 => 201012345678 (الصيغة اللي wa.me محتاجها) */
export function toInternational(phone: string): string {
  const n = normalizeEgyptPhone(phone);
  if (!n) throw new Error('INVALID_PHONE');
  return '20' + n.slice(1);
}

/** للبحث: يرجّع الأرقام بس (ويحوّل العربي لإنجليزي) */
export function phoneSearchDigits(input: string): string {
  return toLatinDigits(input).replace(/\D/g, '');
}
