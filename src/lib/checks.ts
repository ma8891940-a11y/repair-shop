import BRAND_ALIASES from '../data/brandAliases.json';
/** بنود الفحص السريع (الأسماء في الترجمة: checks.items.*) */
export const CHECK_ITEMS = ['wifi', 'bluetooth', 'front_camera', 'rear_camera', 'fingerprint', 'speaker', 'mic', 'charging', 'screen_touch', 'network'] as const;
export type CheckItem = (typeof CHECK_ITEMS)[number];
export type CheckValue = 'ok' | 'fail' | 'na';
/** النتيجة لكل بند (البنود الجاهزة أو اللي كتبها صاحب المحل) */
export type CheckItems = Partial<Record<CheckItem | (string & {}), CheckValue>>;

export interface CheckDiff {
  item: CheckItem;
  intake: CheckValue | undefined;
  delivery: CheckValue | undefined;
  /** كان شغال وقت الاستلام وبقى عطلان وقت التسليم: ده اللي بيحمي المحل في الخلاف */
  regressed: boolean;
  fixed: boolean;
}

export function compareChecks(intake: CheckItems | null | undefined, delivery: CheckItems | null | undefined, keys: readonly string[] = CHECK_ITEMS): CheckDiff[] {
  return (keys as CheckItem[]).map((item) => {
    const a = intake?.[item];
    const b = delivery?.[item];
    return { item, intake: a, delivery: b, regressed: a === 'ok' && b === 'fail', fixed: a === 'fail' && b === 'ok' };
  });
}

export function checkSummary(items: CheckItems | null | undefined): { ok: number; fail: number; na: number; total: number } {
  const v = Object.values(items ?? {});
  return { ok: v.filter((x) => x === 'ok').length, fail: v.filter((x) => x === 'fail').length, na: v.filter((x) => x === 'na').length, total: CHECK_ITEMS.length };
}

// ---------- C2: قوالب الفحص لكل ماركة ----------
/** بنود جاهزة إضافية (الأسماء في الترجمة: checks.items.*) */
export const EXTRA_ITEMS = ['face_id', 'true_tone', 'icloud', 'battery_health', 's_pen', 'nfc', 'ir_blaster', 'earpiece', 'proximity', 'vibration', 'buttons', 'sim_tray', 'flash', 'water'] as const;
export const BRANDS = ['general', 'apple', 'samsung', 'xiaomi', 'oppo', 'realme'] as const;
export type BrandKey = (typeof BRANDS)[number];

/** بند في القالب: بند جاهز (اسمه من الترجمة) أو بند كتبه صاحب المحل (label) */
export interface TemplateItem {
  key: string;
  label?: string;
}

const BASE: TemplateItem[] = CHECK_ITEMS.map((key) => ({ key }));
const plus = (...keys: string[]): TemplateItem[] => [...BASE, ...keys.map((key) => ({ key }))];
/** القوالب الجاهزة: العام = الفحص القديم بالظبط (10 بنود)، وكل ماركة زيه + بنود خاصة بيها */
export const BUILTIN_TEMPLATES: Record<BrandKey, TemplateItem[]> = {
  general: BASE,
  apple: plus('face_id', 'true_tone', 'icloud', 'battery_health', 'earpiece', 'proximity', 'buttons', 'sim_tray'),
  samsung: plus('s_pen', 'nfc', 'earpiece', 'vibration', 'buttons', 'sim_tray'),
  xiaomi: plus('ir_blaster', 'nfc', 'earpiece', 'vibration', 'buttons', 'sim_tray'),
  oppo: plus('earpiece', 'proximity', 'vibration', 'buttons', 'sim_tray', 'flash'),
  realme: plus('earpiece', 'proximity', 'vibration', 'buttons', 'sim_tray', 'flash'),
};

/** الماركة من اسم الجهاز ("iPhone 13" = apple، "Redmi Note" = xiaomi...). أي حاجة تانية = general */
export function brandKey(brand: string | null | undefined): BrandKey {
  const b = (brand ?? '').trim().toLowerCase();
  for (const [k, names] of Object.entries(BRAND_ALIASES)) if (names.some((n) => b.includes(n))) return k as BrandKey;
  return 'general';
}

/** قالب الجهاز: قالب صاحب المحل للماركة لو موجود، وإلا الجاهز */
export function templateFor(brand: string | null | undefined, custom: Partial<Record<string, TemplateItem[]>> = {}): TemplateItem[] {
  const k = brandKey(brand);
  return normalizeTemplate(custom[k] ?? BUILTIN_TEMPLATES[k]);
}

/** تنضيف قالب متخزّن: مفاتيح سليمة، من غير تكرار، والاسم لحد 60 حرف، ولحد 40 بند */
export function normalizeTemplate(raw: unknown): TemplateItem[] {
  const out: TemplateItem[] = [];
  const seen = new Set<string>();
  for (const x of Array.isArray(raw) ? raw : []) {
    if (!x || typeof x !== 'object') continue;
    const o = x as Record<string, unknown>;
    const key = typeof o.key === 'string' ? o.key.trim() : '';
    if (!/^[a-z0-9_]{1,40}$/.test(key) || seen.has(key)) continue;
    const label = typeof o.label === 'string' ? o.label.trim().slice(0, 60) : '';
    // بند جديد من صاحب المحل لازم يكون له اسم
    if (!label && !(CHECK_ITEMS as readonly string[]).includes(key) && !(EXTRA_ITEMS as readonly string[]).includes(key)) continue;
    seen.add(key);
    out.push(label ? { key, label } : { key });
    if (out.length >= 40) break;
  }
  return out;
}

/** مفتاح لبند جديد بيكتبه صاحب المحل */
export const customKey = () => `c_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;

/** أسماء البنود اللي كتبها صاحب المحل (بتتحفظ مع الفحص، عشان الورقة المطبوعة تفضل زي ما هي لو القالب اتغير بعدين) */
export function labelsOf(items: TemplateItem[]): Record<string, string> {
  return Object.fromEntries(items.filter((i) => i.label).map((i) => [i.key, i.label!]));
}

/** ترتيب البنود في المقارنة والطباعة: بنود القالب، وبعدها أي بند متسجل في الفحص ومش في القالب */
export function checkKeys(template: TemplateItem[], ...stages: (CheckItems | null | undefined)[]): string[] {
  const keys = template.map((i) => i.key);
  for (const st of stages) for (const k of Object.keys(st ?? {})) if (!keys.includes(k)) keys.push(k);
  return keys;
}
