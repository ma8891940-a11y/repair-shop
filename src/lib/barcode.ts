// باركود EAN-13 للأصناف (من غير أي مكتبة): رقم داخلي بيبدأ بـ 2 (للاستخدام جوه المحل بس، ومش متسجل لأي منتج عالمي)

/** رقم التحقق لأول 12 رقم */
export function ean13Check(d12: string): number {
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(d12[i]) * (i % 2 ? 3 : 1);
  return (10 - (sum % 10)) % 10;
}

export function isEan13(code: string): boolean {
  return /^\d{13}$/.test(code) && ean13Check(code.slice(0, 12)) === Number(code[12]);
}

/** باركود داخلي جديد: 2 + 11 رقم عشوائي + رقم التحقق */
export function newInternalEan13(rand: () => number = Math.random): string {
  let d = '2';
  for (let i = 0; i < 11; i++) d += String(Math.floor(rand() * 10));
  return d + String(ean13Check(d));
}

const L = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
const G = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
const R = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
const PARITY = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];

/** الخطوط (1 = أسود) لباركود EAN-13 كامل: 95 وحدة */
export function ean13Bits(code: string): string {
  if (!isEan13(code)) throw new Error('E_BAD_BARCODE');
  const first = Number(code[0]);
  let out = '101';
  for (let i = 1; i <= 6; i++) out += (PARITY[first][i - 1] === 'L' ? L : G)[Number(code[i])];
  out += '01010';
  for (let i = 7; i <= 12; i++) out += R[Number(code[i])];
  return out + '101';
}
