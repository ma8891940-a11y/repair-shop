// جداول الإدخال (الجرد): السطور بتتزوّد بالعدد المكتوب بالظبط، والحذف لسطر أو أكتر أو للسطور الفاضية.
// كل سطر ليه مفتاح ثابت (k)، فحذف سطر ما بيلخبطش اللي بعده.

export const MAX_ADD = 500;

/** عدد السطور المكتوب: من 1 لـ 500 (الفاضي أو الغلط = 1) */
export function rowCount(v: string): number {
  const n = Math.trunc(Number(String(v).replace(/[٠-٩]/g, (d) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).trim()));
  if (!Number.isFinite(n) || n < 1) return 1;
  return Math.min(n, MAX_ADD);
}

export const newKey = () => (typeof crypto !== 'undefined' && 'randomUUID' in crypto ? crypto.randomUUID() : Math.random().toString(36).slice(2));

export function addRows<T>(rows: T[], n: number, blank: () => T): T[] {
  return [...rows, ...Array.from({ length: Math.max(1, Math.min(MAX_ADD, Math.trunc(n))) }, blank)];
}

/** حذف سطور بالمفتاح. لو الجدول فضي خالص بيفضل فيه سطر واحد فاضي */
export function removeRows<T extends { k: string }>(rows: T[], keys: Set<string>, blank: () => T): T[] {
  const out = rows.filter((r) => !keys.has(r.k));
  return out.length ? out : [blank()];
}

/** حذف السطور الفاضية (ويفضل سطر واحد فاضي لو الجدول فضي) */
export function removeBlankRows<T extends { k: string }>(rows: T[], isBlank: (r: T) => boolean, blank: () => T): T[] {
  const out = rows.filter((r) => !isBlank(r));
  return out.length ? out : [blank()];
}

/** سطور النص الملصوق من Excel (من غير السطور الفاضية اللي في الآخر، زي اللي Excel بيزوّدها) */
export function pastedRows(text: string): string[] {
  const lines = text.replace(/\r\n?/g, '\n').split('\n');
  while (lines.length && lines[lines.length - 1].replace(/\t/g, '').trim() === '') lines.pop();
  return lines;
}
