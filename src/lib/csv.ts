// قراءة ملف CSV (Excel بيحفظه بـ "CSV UTF-8"): فواصل , أو ; أو Tab، وعلامات تنصيص، وسطور جديدة جوه الخلية
import { toLatinDigits } from './digits';
import { parsePounds } from './money';
import ar from '../i18n/ar.json';
import en from '../i18n/en.json';

export function parseCsv(text: string): string[][] {
  const s = text.replace(/^\uFEFF/, '');
  const firstLine = s.split(/\r?\n/, 1)[0] ?? '';
  const sep = [',', ';', '\t'].map((c) => [c, firstLine.split(c).length] as const).sort((a, b) => b[1] - a[1])[0][0];
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let q = false;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (q) {
      if (ch === '"' && s[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (ch === '"') q = false;
      else cell += ch;
    } else if (ch === '"') q = true;
    else if (ch === sep) {
      row.push(cell);
      cell = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && s[i + 1] === '\n') i++;
      row.push(cell);
      if (row.some((c) => c.trim() !== '')) rows.push(row);
      row = [];
      cell = '';
    } else cell += ch;
  }
  row.push(cell);
  if (row.some((c) => c.trim() !== '')) rows.push(row);
  // علامة ' اللي بنحطها قدام الخلايا الخطرة في التصدير بتتشال
  return rows.map((r) => r.map((c) => c.trim().replace(/^'(?=[\s\u200b-\u200f\u202a-\u202e\u2066-\u2069]*[=+\-@＝＋－＠])/, '')));
}

export interface ItemImportRow {
  name: string;
  kind: 'part' | 'accessory';
  category: string | null;
  barcode: string | null;
  sale_price: number | null;
  min_qty: number;
}
export interface ImportResult {
  rows: ItemImportRow[];
  /** رقم السطر في الملف (من 1) والسبب */
  errors: { line: number; reason: 'name' | 'kind' | 'price' | 'min' | 'barcode' | 'dup' }[];
}

// عناوين الأعمدة المقبولة: نفس عناوين ملف التصدير بالعربي والإنجليزي (من ملفات الترجمة)، فالملف اللي بيطلع من البرنامج بيرجع يدخله زي ما هو
type Dict = typeof ar;
const fromLang = (d: Dict): [string, keyof ItemImportRow][] => [
  [d.inv.cols.name, 'name'],
  [d.inv.cols.kind, 'kind'],
  [d.inv.category, 'category'],
  [d.barcode.code, 'barcode'],
  [d.inv.cols.price, 'sale_price'],
  [d.inv.minQty, 'min_qty'],
];
const HEAD: Record<string, keyof ItemImportRow> = Object.fromEntries(
  [...fromLang(ar), ...fromLang(en as Dict), ['name', 'name'], ['item', 'name'], ['kind', 'kind'], ['type', 'kind'], ['category', 'category'], ['barcode', 'barcode'], ['price', 'sale_price'], ['min', 'min_qty']].map(([k, v]) => [k.trim().toLowerCase(), v as keyof ItemImportRow]),
);
const KIND: Record<string, 'part' | 'accessory'> = Object.fromEntries(
  [ar, en as Dict].flatMap((d) => [[d.inv.kinds.part, 'part'], [d.inv.kinds.accessory, 'accessory']]).concat([['part', 'part'], ['accessory', 'accessory']]).map(([k, v]) => [k.trim().toLowerCase(), v as 'part' | 'accessory']),
);

/** أصناف من جدول Excel: أول سطر عناوين (عربي أو إنجليزي). السطور الغلط بترجع بالسبب، والباقي بيتستورد */
export function parseItemsCsv(text: string, existingBarcodes: Set<string> = new Set()): ImportResult {
  const all = parseCsv(text);
  const out: ImportResult = { rows: [], errors: [] };
  if (!all.length) return out;
  const cols = all[0].map((h) => HEAD[h.trim().toLowerCase()]);
  const seen = new Set(existingBarcodes);
  all.slice(1).forEach((r, k) => {
    const line = k + 2;
    const get = (f: keyof ItemImportRow) => {
      const i = cols.indexOf(f);
      return i < 0 ? '' : (r[i] ?? '').trim();
    };
    const name = get('name');
    if (!name || name.length > 120) return out.errors.push({ line, reason: 'name' });
    const kindRaw = get('kind').toLowerCase();
    const kind = kindRaw ? KIND[kindRaw] : 'part';
    if (!kind) return out.errors.push({ line, reason: 'kind' });
    const priceRaw = get('sale_price');
    const sale_price = priceRaw ? parsePounds(priceRaw) : null;
    if (priceRaw && sale_price == null) return out.errors.push({ line, reason: 'price' });
    const minRaw = toLatinDigits(get('min_qty'));
    const min_qty = minRaw ? Number(minRaw) : 0;
    if (!Number.isInteger(min_qty) || min_qty < 0) return out.errors.push({ line, reason: 'min' });
    const barcode = toLatinDigits(get('barcode')) || null;
    if (barcode && !/^[0-9A-Za-z-]{4,32}$/.test(barcode)) return out.errors.push({ line, reason: 'barcode' });
    if (barcode && seen.has(barcode)) return out.errors.push({ line, reason: 'dup' });
    if (barcode) seen.add(barcode);
    out.rows.push({ name, kind, category: get('category') || null, barcode, sale_price, min_qty });
  });
  return out;
}
