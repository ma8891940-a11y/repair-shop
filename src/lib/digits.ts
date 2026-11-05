// تحويل الأرقام العربية (٠١٢) والفارسية (۰۱۲) لأرقام إنجليزية (012)
// لأن لوحة المفاتيح العربية بتكتب أرقام هندية.
export function toLatinDigits(input: string): string {
  return input.replace(/[٠-٩۰-۹]/g, (ch) => {
    const code = ch.charCodeAt(0);
    const base = code >= 0x06f0 ? 0x06f0 : 0x0660;
    return String(code - base);
  });
}
