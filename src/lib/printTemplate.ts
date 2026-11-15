/**
 * U5: قوالب الطباعة. القالب = خانات مرتبة (تظهر أو لأ، وحجم الخط، والمحاذاة، والعريض، ونص حر).
 * القالب بيتحكم في الشكل بس: الأرقام والبيانات دايمًا من البرنامج.
 */
export type TemplateDoc = 'receipt' | 'receipt-a4' | 'invoice';
export type BlockKey =
  | 'header' | 'title' | 'orderNo' | 'date' | 'customer' | 'phone' | 'device' | 'imei' | 'issue'
  | 'accessories' | 'condition' | 'estimate' | 'parts' | 'total' | 'paid' | 'remaining' | 'warranty'
  | 'terms' | 'signature' | 'qr' | 'sign' | 'thanks' | 'text';
export type Size = 'sm' | 'md' | 'lg';
export type Align = 'start' | 'center' | 'end';
export interface Block {
  key: BlockKey;
  show: boolean;
  size: Size;
  align: Align;
  bold: boolean;
  /** نص حر (للخانة "text" بس) */
  text?: string;
}

const RECEIPT: BlockKey[] = ['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'accessories', 'condition', 'estimate', 'terms', 'signature', 'qr', 'sign', 'thanks'];
const INVOICE: BlockKey[] = ['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'parts', 'total', 'paid', 'remaining', 'warranty', 'sign', 'thanks'];
/** الخانات المتاحة لكل نوع ورقة (بالترتيب الافتراضي)، و"نص حر" ممكن يتضاف في أي مكان */
export const DOC_BLOCKS: Record<TemplateDoc, BlockKey[]> = { receipt: RECEIPT, 'receipt-a4': RECEIPT, invoice: INVOICE };

const BIG: BlockKey[] = ['orderNo', 'total'];
export function defaultBlocks(doc: TemplateDoc): Block[] {
  return DOC_BLOCKS[doc].map((key) => ({
    key,
    show: true,
    size: BIG.includes(key) ? 'lg' : 'md',
    align: doc === 'receipt' && ['header', 'title', 'orderNo', 'qr', 'thanks'].includes(key) ? 'center' : 'start',
    bold: BIG.includes(key) || key === 'title',
  }));
}

/** القالب المتخزّن بيتنضّف: الخانات المجهولة بتتشال، والناقصة بتتضاف في الآخر مخفية، والقيم الغلط بترجع للافتراضي */
export function normalizeBlocks(doc: TemplateDoc, raw: unknown): Block[] {
  const allowed = new Set<BlockKey>([...DOC_BLOCKS[doc], 'text']);
  const def = new Map(defaultBlocks(doc).map((b) => [b.key, b]));
  const out: Block[] = [];
  const seen = new Set<BlockKey>();
  for (const x of Array.isArray(raw) ? raw : []) {
    if (!x || typeof x !== 'object') continue;
    const o = x as Record<string, unknown>;
    const key = o.key as BlockKey;
    if (!allowed.has(key) || (key !== 'text' && seen.has(key))) continue;
    seen.add(key);
    const d = def.get(key) ?? { key, show: true, size: 'md' as Size, align: 'start' as Align, bold: false };
    out.push({
      key,
      show: typeof o.show === 'boolean' ? o.show : d.show,
      size: o.size === 'sm' || o.size === 'md' || o.size === 'lg' ? o.size : d.size,
      align: o.align === 'start' || o.align === 'center' || o.align === 'end' ? o.align : d.align,
      bold: typeof o.bold === 'boolean' ? o.bold : d.bold,
      ...(key === 'text' ? { text: typeof o.text === 'string' ? o.text.slice(0, 300) : '' } : {}),
    });
  }
  for (const k of DOC_BLOCKS[doc]) if (!seen.has(k)) out.push({ ...def.get(k)!, show: false });
  return out;
}

export const move = <T,>(list: T[], from: number, to: number): T[] => {
  if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length) return list;
  const next = [...list];
  const [x] = next.splice(from, 1);
  next.splice(to, 0, x);
  return next;
};

// ---------- الطابعات ----------
export type PrinterKind = 'thermal58' | 'thermal80' | 'label' | 'a4' | 'a5' | 'dot';
export interface PrinterPreset {
  model: string;
  kind: PrinterKind;
  width_mm: number;
  height_mm: number | null;
  margin_mm: number;
}
/** قوالب جاهزة لأشهر الموديلات في السوق المصري (المقاس المطبوع الفعلي والهوامش المناسبة) */
export const PRINTER_PRESETS: PrinterPreset[] = [
  { model: 'Xprinter XP-58', kind: 'thermal58', width_mm: 48, height_mm: null, margin_mm: 2 },
  { model: 'Xprinter XP-80 / XP-N160', kind: 'thermal80', width_mm: 72, height_mm: null, margin_mm: 3 },
  { model: 'Rongta RP80', kind: 'thermal80', width_mm: 72, height_mm: null, margin_mm: 3 },
  { model: 'Epson TM-T20', kind: 'thermal80', width_mm: 72, height_mm: null, margin_mm: 3 },
  { model: 'Xprinter XP-365B', kind: 'label', width_mm: 40, height_mm: 30, margin_mm: 0 },
  { model: 'Rongta RP410', kind: 'label', width_mm: 50, height_mm: 30, margin_mm: 0 },
  { model: 'HP LaserJet (A4)', kind: 'a4', width_mm: 210, height_mm: 297, margin_mm: 12 },
  { model: 'Canon LBP (A4)', kind: 'a4', width_mm: 210, height_mm: 297, margin_mm: 12 },
  { model: 'Canon / HP (A5)', kind: 'a5', width_mm: 148, height_mm: 210, margin_mm: 10 },
  { model: 'Epson LX-310', kind: 'dot', width_mm: 210, height_mm: 140, margin_mm: 8 },
];

/** مقاس الصفحة في @page من ملف الطابعة */
export function pageCss(p: { width_mm: number; height_mm: number | null; margin_mm: number }): string {
  return `@page { size: ${p.width_mm}mm ${p.height_mm ? `${p.height_mm}mm` : 'auto'}; margin: ${p.margin_mm}mm; }`;
}
