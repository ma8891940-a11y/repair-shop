/**
 * 50.2: نموذج القالب: flow (خانات بالترتيب، زي printTemplate) وfree (حقول بأماكنها بالمللي للمقاسات الثابتة).
 * نفس الفحص على السيرفر في 0088 (print_template_error)، وفيه اختبار بيتأكد إنهم متطابقين.
 */
import { BG_MAX_PX, bgFits } from './printBackground';

export const PRINT_DOCS = ['receipt', 'receipt-a4', 'invoice', 'statement', 'voucher', 'sale', 'barcode', 'sticker', 'label'] as const;
export type PrintDoc = (typeof PRINT_DOCS)[number];
export type PrintMode = 'flow' | 'free';
export const FONTS = ['sans', 'mono', 'system'] as const;
export const LANGS = ['app', 'ar', 'en'] as const;
export const PAPERS = { '40x30': { w: 40, h: 30 }, '58': { w: 58, h: null }, '80': { w: 80, h: null }, a4: { w: 210, h: 297 } } as const;
export const PT = { min: 5, max: 72 };
export const MM = { minW: 20, maxW: 300, minH: 10, maxH: 450, minField: 1 };
export const MAX_FIELDS = 60;
export const MAX_JSON = 65536;
const ALIGNS = ['start', 'center', 'end'];
const SIZES = ['sm', 'md', 'lg'];

const SHOP = ['shopName', 'logo', 'shopPhone', 'shopAddress', 'text'];
const DEVICE = [...SHOP, 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'warranty', 'terms', 'qr', 'barcode'];
/** حقول القالب الحر لكل نوع. كشف الحساب والإيصال الحراري بالترتيب بس */
export const FREE_FIELDS: Record<PrintDoc, readonly string[]> = {
  receipt: [],
  statement: [],
  sticker: DEVICE,
  label: DEVICE,
  'receipt-a4': [...DEVICE, 'price', 'paid', 'remaining'],
  invoice: [...DEVICE, 'price', 'paid', 'remaining', 'parts'],
  sale: [...SHOP, 'entryNo', 'date', 'customer', 'phone', 'lines', 'price', 'paid', 'remaining', 'terms', 'barcode'],
  voucher: [...SHOP, 'entryNo', 'date', 'party', 'amount', 'method', 'memo'],
  barcode: [...SHOP, 'itemName', 'code', 'price', 'barcode'],
};
/** خانات القالب بالترتيب (نفس DOC_BLOCKS + نص حر). الستيكر والليبل حر بس */
const RECEIPT = ['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'accessories', 'condition', 'estimate', 'terms', 'signature', 'qr', 'sign', 'thanks', 'text'];
export const FLOW_BLOCKS: Record<PrintDoc, readonly string[]> = {
  receipt: RECEIPT,
  'receipt-a4': RECEIPT,
  invoice: ['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'parts', 'total', 'paid', 'remaining', 'warranty', 'signature', 'sign', 'thanks', 'text'],
  statement: ['header', 'title', 'party', 'period', 'opening', 'moves', 'closing', 'signature', 'thanks', 'text'],
  voucher: ['header', 'title', 'entryNo', 'date', 'party', 'amount', 'method', 'cashbox', 'memo', 'sign', 'thanks', 'text'],
  sale: ['header', 'title', 'entryNo', 'date', 'customer', 'phone', 'lines', 'total', 'paid', 'remaining', 'memo', 'sign', 'thanks', 'text'],
  barcode: ['header', 'itemName', 'code', 'price', 'text'],
  sticker: [],
  label: [],
};

export interface FreeField {
  key: string;
  x: number;
  y: number;
  w: number;
  h: number;
  font: (typeof FONTS)[number];
  pt: number;
  align: 'start' | 'center' | 'end';
  bold: boolean;
  /** للحقل "text" بس */
  text?: string;
}
export interface PrintLayout {
  lang?: (typeof LANGS)[number];
  paper?: { kind: keyof typeof PAPERS } | { kind: 'custom'; w: number; h: number | null };
  /** 50.3: ملف الخلفية، وطريقة الورق، ومقاس الصورة بالبكسل */
  bg?: { file: string; stock: 'preprinted' | 'blank'; w: number; h: number } | null;
  fields?: FreeField[];
}

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => !!v && typeof v === 'object' && !Array.isArray(v);
const onlyKeys = (o: Obj, keys: string[]) => Object.keys(o).every((k) => keys.includes(k));
const isInt = (v: unknown, min: number, max: number): v is number => typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;
/** مللي بخانة عشرية واحدة بالكتير، وبيرجع أعشار المللي (عدد صحيح) */
const tenths = (v: unknown): number | null => {
  if (typeof v !== 'number' || !Number.isFinite(v)) return null;
  const n = Math.round(v * 10);
  return n / 10 === v ? n : null;
};
const textOk = (o: Obj) => (o.key === 'text' ? typeof o.text === 'string' && [...o.text].length <= 300 : !('text' in o));
const bytes = (v: unknown) => new TextEncoder().encode(JSON.stringify(v)).length;

const bgOk = (v: unknown): boolean =>
  isObj(v) && onlyKeys(v, ['file', 'stock', 'w', 'h']) && typeof v.file === 'string' && /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(png|jpg)$/.test(v.file)
  && (v.stock === 'preprinted' || v.stock === 'blank') && isInt(v.w, 1, BG_MAX_PX) && isInt(v.h, 1, BG_MAX_PX);

/** مقاس الورقة بالمللي، أو null لو الكائن غلط */
export function paperSize(paper: unknown): { w: number; h: number | null } | null {
  if (!isObj(paper)) return null;
  if (paper.kind === 'custom') {
    if (!onlyKeys(paper, ['kind', 'w', 'h']) || !isInt(paper.w, MM.minW, MM.maxW)) return null;
    if (paper.h !== null && !isInt(paper.h, MM.minH, MM.maxH)) return null;
    return { w: paper.w, h: paper.h as number | null };
  }
  if (!onlyKeys(paper, ['kind']) || typeof paper.kind !== 'string' || !Object.hasOwn(PAPERS, paper.kind)) return null;
  return PAPERS[paper.kind as keyof typeof PAPERS];
}

/** null = القالب سليم، وإلا كود الغلط (نفس أكواد print_template_error) */
export function templateError(doc: string, mode: string, blocks: unknown, layout: unknown): string | null {
  if (!(PRINT_DOCS as readonly string[]).includes(doc)) return 'doc';
  if (mode !== 'flow' && mode !== 'free') return 'mode';
  const d = doc as PrintDoc;
  if (!Array.isArray(blocks) || !isObj(layout)) return 'type';
  if (bytes(blocks) > MAX_JSON || bytes(layout) > MAX_JSON) return 'size';
  if (!onlyKeys(layout, ['lang', 'paper', 'bg', 'fields'])) return 'key';
  if ('lang' in layout && !(LANGS as readonly unknown[]).includes(layout.lang)) return 'lang';
  const bg = layout.bg as Obj | null | undefined;
  if (bg != null && !bgOk(bg)) return 'bg';
  const size = 'paper' in layout ? paperSize(layout.paper) : null;
  if ('paper' in layout && !size) return 'paper';
  if (bg != null && !(size && bgFits({ w: bg.w as number, h: bg.h as number }, size))) return 'bgsize';
  if (mode === 'flow') {
    if ('fields' in layout) return 'key';
    if (blocks.length > MAX_FIELDS) return 'count';
    const seen = new Set<unknown>();
    for (const b of blocks) {
      if (!isObj(b)) return 'type';
      if (!onlyKeys(b, ['key', 'show', 'size', 'align', 'bold', 'text', 'font', 'pt'])) return 'key';
      if (typeof b.key !== 'string' || !FLOW_BLOCKS[d].includes(b.key)) return 'field';
      if (b.key !== 'text' && seen.has(b.key)) return 'duplicate';
      seen.add(b.key);
      if (typeof b.show !== 'boolean' || typeof b.bold !== 'boolean' || !SIZES.includes(b.size as string) || !ALIGNS.includes(b.align as string)) return 'value';
      if ('font' in b && !(FONTS as readonly unknown[]).includes(b.font)) return 'font';
      if ('pt' in b && !isInt(b.pt, PT.min, PT.max)) return 'pt';
      if (!textOk(b)) return 'text';
    }
    return null;
  }
  if (!FREE_FIELDS[d].length) return 'mode';
  if (blocks.length) return 'key';
  if (!size?.h) return 'paper';
  const fields = layout.fields;
  if (!Array.isArray(fields)) return 'type';
  if (!fields.length || fields.length > MAX_FIELDS) return 'count';
  const seen = new Set<unknown>();
  for (const x of fields) {
    if (!isObj(x)) return 'type';
    if (!onlyKeys(x, ['key', 'x', 'y', 'w', 'h', 'font', 'pt', 'align', 'bold', 'text'])) return 'key';
    if (typeof x.key !== 'string' || !FREE_FIELDS[d].includes(x.key)) return 'field';
    if (x.key !== 'text' && seen.has(x.key)) return 'duplicate';
    seen.add(x.key);
    if (typeof x.bold !== 'boolean' || !ALIGNS.includes(x.align as string)) return 'value';
    if (!(FONTS as readonly unknown[]).includes(x.font)) return 'font';
    if (!isInt(x.pt, PT.min, PT.max)) return 'pt';
    const [l, t, w, h] = [tenths(x.x), tenths(x.y), tenths(x.w), tenths(x.h)];
    if (l == null || t == null || w == null || h == null) return 'number';
    if (l < 0 || t < 0 || w < MM.minField * 10 || h < MM.minField * 10 || l + w > size.w * 10 || t + h > size.h * 10) return 'bounds';
    if (!textOk(x)) return 'text';
  }
  return null;
}
