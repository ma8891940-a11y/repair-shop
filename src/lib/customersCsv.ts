// R3: استيراد العملاء من ملف CSV (Excel بيحفظه بـ "CSV UTF-8")
import { parseCsv } from './csv';
import { normalizeEgyptPhone } from './phone';
import ar from '../i18n/ar.json';
import en from '../i18n/en.json';

export interface CustomerImportRow {
  /** رقم السطر في الملف (من 1، والعناوين سطر 1) */
  line: number;
  name: string;
  phone: string;
  area: string | null;
}
export type CustomerImportReason = 'name' | 'phone' | 'dupFile' | 'exists';
export interface CustomerImportResult {
  rows: CustomerImportRow[];
  errors: {
    line: number;
    reason: CustomerImportReason;
    name: string;
    phone: string;
  }[];
  /** مفيش عمود اسم أو موبايل في أول سطر */
  missingHeaders: ('name' | 'phone')[];
}

type Field = 'name' | 'phone' | 'area';
type Dict = typeof ar;
// العناوين المقبولة: عناوين ملف التصدير نفسه (فالملف اللي بيطلع من البرنامج بيرجع يدخله)، وأسماء تانية شائعة من ملفات الترجمة
const fromLang = (d: Dict): [string, Field][] => [
  [d.customers.cols.name, 'name'],
  [d.customers.cols.phone, 'phone'],
  [d.customers.cols.area, 'area'],
  ...d.custImport.aliases.name.split('|').map((x) => [x, 'name'] as [string, Field]),
  ...d.custImport.aliases.phone.split('|').map((x) => [x, 'phone'] as [string, Field]),
  ...d.custImport.aliases.area.split('|').map((x) => [x, 'area'] as [string, Field]),
];
const key = (s: string) => s.trim().toLowerCase().replace(/\s+/g, ' ');
const HEAD: Record<string, Field> = Object.fromEntries([...fromLang(ar), ...fromLang(en as Dict)].map(([k, v]) => [key(k), v]));

/** أول عمود بالاسم ده (لو العنوان مكرر بناخد الأول) */
function columns(header: string[]): Partial<Record<Field, number>> {
  const out: Partial<Record<Field, number>> = {};
  header.forEach((h, i) => {
    const f = HEAD[key(h)];
    if (f && out[f] == null) out[f] = i;
  });
  return out;
}

/**
 * بيقرا العملاء من الملف: أول سطر عناوين (عربي أو إنجليزي). الموبايل بيتوحّد بنفس قواعد البرنامج (أرقام عربي، +20، مسافات).
 * existingPhones: أرقام عملاء المحل الموجودين (موحّدة)، اللي فيها بيتخطى. المكرر في الملف نفسه أول مرة بس بيدخل.
 */
export function parseCustomersCsv(text: string, existingPhones: ReadonlySet<string> = new Set()): CustomerImportResult {
  const all = parseCsv(text);
  const out: CustomerImportResult = {
    rows: [],
    errors: [],
    missingHeaders: [],
  };
  if (!all.length) return out;
  // ملف التصدير من البرنامج فيه العنوان واسم المحل والتاريخ فوق العناوين: بندوّر على سطر العناوين في أول 10 سطور
  const found = all.slice(0, 10).findIndex((r) => {
    const c = columns(r);
    return c.name != null && c.phone != null;
  });
  const h = Math.max(found, 0);
  const cols = columns(all[h]);
  if (cols.name == null) out.missingHeaders.push('name');
  if (cols.phone == null) out.missingHeaders.push('phone');
  if (out.missingHeaders.length) return out;
  const seen = new Set<string>();
  all.slice(h + 1).forEach((r, k) => {
    const line = h + k + 2;
    const get = (f: Field) => (cols[f] == null ? '' : (r[cols[f]!] ?? '').trim());
    const name = get('name').replace(/\s+/g, ' ');
    const rawPhone = get('phone');
    if (!name || name.length > 120) return out.errors.push({ line, reason: 'name', name, phone: rawPhone });
    const phone = normalizeEgyptPhone(rawPhone);
    if (!phone) return out.errors.push({ line, reason: 'phone', name, phone: rawPhone });
    if (existingPhones.has(phone)) return out.errors.push({ line, reason: 'exists', name, phone });
    if (seen.has(phone)) return out.errors.push({ line, reason: 'dupFile', name, phone });
    seen.add(phone);
    out.rows.push({
      line,
      name,
      phone,
      area: get('area').slice(0, 120) || null,
    });
  });
  return out;
}

/** بيقسم القايمة لدفعات (للحفظ 100 في المرة) */
export function chunks<T>(list: readonly T[], size: number): T[][] {
  if (size < 1) throw new Error('E_BAD_INPUT');
  const out: T[][] = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}
