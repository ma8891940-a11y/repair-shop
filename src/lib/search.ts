import { toLatinDigits } from './digits';

/**
 * ينضّف كلمة البحث قبل ما تتبعت لـ Supabase.
 * الفلتر بيتكتب كنص زي "name.ilike.*x*,phone.ilike.*x*"، فأي فاصلة أو قوس
 * أو نجمة في كلام المستخدم ممكن تكسر الفلتر أو تغيّر معناه. بنشيلهم.
 */
export function sanitizeSearch(input: string): string {
  return toLatinDigits(input)
    .replace(/[,()*%\\:"'.]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 60);
}

/** يبني فلتر or لـ PostgREST على أعمدة البحث */
export function buildSearchFilter(input: string, columns: readonly string[]): string | null {
  const q = sanitizeSearch(input);
  if (!q) return null;
  return columns.map((c) => `${c}.ilike.*${q}*`).join(',');
}
