// البحث عن الصنف بالكتابة: جزء من الكلمة، وبالعربي أو الإنجليزي، في الاسم والنوع والماركة والموديل والجودة واللون والباركود.
// "شاشه 13 برو" بتجيب "شاشة iPhone 13 Pro".
import { toLatinDigits } from './digits';
import itemLists from '../data/itemLists.json';

/** توحيد الحروف: الهمزات والتاء المربوطة والياء والتشكيل، وكله حروف صغيرة */
export function normalize(s: string): string {
  return toLatinDigits(s)
    .toLowerCase()
    .replace(/[\u064B-\u0652\u0670\u0640]/g, '') // التشكيل والتطويل
    .replace(/[\u0623\u0625\u0622\u0671]/g, '\u0627')
    .replace(/\u0629/g, '\u0647')
    .replace(/\u0649/g, '\u064A')
    .replace(/\u0624/g, '\u0648')
    .replace(/\u0626/g, '\u064A')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

// كلمات شائعة بالعربي ← نفس الكلمة بالإنجليزي (والعكس)
const PAIRS: [string, string][] = itemLists.search_pairs as [string, string][];
const TO: Map<string, string[]> = (() => {
  const m = new Map<string, string[]>();
  for (const [a, b] of PAIRS) {
    const x = normalize(a);
    const y = normalize(b);
    m.set(x, [...(m.get(x) ?? []), y]);
    m.set(y, [...(m.get(y) ?? []), x]);
  }
  return m;
})();

/** كل الصيغ لكلمة (نفسها + المرادف بالعربي أو الإنجليزي) */
function variants(word: string): string[] {
  return [word, ...(TO.get(word) ?? [])];
}

export interface SearchableItem {
  name: string;
  item_type?: string | null;
  brand?: string | null;
  model?: string | null;
  quality?: string | null;
  color?: string | null;
  category?: string | null;
  sku?: string | null;
  barcode?: string | null;
}

export function haystack(i: SearchableItem): string {
  return normalize([i.name, i.item_type, i.brand, i.model, i.quality, i.color, i.category, i.sku, i.barcode].filter(Boolean).join(' '));
}

/** كل كلمة اتكتبت (أو مرادفها) لازم تكون موجودة في الصنف، ولو جزء من كلمة */
export function matches(i: SearchableItem, query: string): boolean {
  const q = normalize(query);
  if (!q) return true;
  const h = haystack(i);
  return q.split(' ').every((w) => variants(w).some((v) => h.includes(v)));
}

/** ترتيب: الباركود بالظبط الأول، وبعدين اللي الاسم بيبدأ بالكلام، وبعدين الباقي */
export function searchItems<T extends SearchableItem>(items: T[], query: string, limit = 30): T[] {
  const q = normalize(query);
  if (!q) return items.slice(0, limit);
  const code = toLatinDigits(query.trim());
  const exact = items.filter((i) => (i.barcode && i.barcode === code) || (i.sku && i.sku === code));
  const rest = items.filter((i) => !exact.includes(i) && matches(i, query));
  rest.sort((a, b) => Number(normalize(b.name).startsWith(q)) - Number(normalize(a.name).startsWith(q)));
  return [...exact, ...rest].slice(0, limit);
}

/** صنف بالباركود أو الكود بالظبط (قارئ الباركود بيكتب الرقم ويدوس Enter) */
export function byCode<T extends SearchableItem>(items: T[], code: string): T | undefined {
  const c = toLatinDigits(code.trim());
  if (!c) return undefined;
  return items.find((i) => i.barcode === c || i.sku === c);
}

/** الاسم من الخانات: "شاشة iPhone 13 Pro - OLED - أسود" (الماركة بتظهر بس لو مفيش موديل) */
export function composeItemName(p: { item_type?: string; brand?: string; model?: string; quality?: string; color?: string }): string {
  const t = (v?: string) => (v ?? '').trim();
  const head = [t(p.item_type), t(p.model) || t(p.brand)].filter(Boolean).join(' ');
  return [head, t(p.quality), t(p.color)].filter(Boolean).join(' - ');
}
