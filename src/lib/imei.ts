import { toLatinDigits } from './digits';

/** يشيل أي حاجة غير الأرقام (مسافات، شرط، /) ويحوّل الأرقام العربية */
export function normalizeImei(input: string): string {
  return toLatinDigits(input).replace(/\D/g, '');
}

/**
 * IMEI الصحيح 15 رقم وآخر رقم فيه "رقم تحقق" بخوارزمية Luhn.
 * البرنامج بينبّه بس لو الرقم شكله غلط، ومش بيمنع الحفظ
 * (ساعات الجهاز مكسور والرقم مش واضح).
 */
export function isValidImei(input: string): boolean {
  const d = normalizeImei(input);
  if (!/^\d{15}$/.test(d)) return false;
  let sum = 0;
  for (let i = 0; i < 15; i++) {
    let n = d.charCodeAt(i) - 48;
    if (i % 2 === 1) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 === 0;
}
