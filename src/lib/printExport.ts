/** 50.5: تصدير القالب لملف JSON واستيراده. من غير أي ids، والاستيراد بنفس فحص الحفظ، والصورة بنفس فحص 50.3 */
import { BG_MAX_BYTES, sniffImage, type BgType } from './printBackground';
import { templateError, type PrintDoc, type PrintLayout, type PrintMode } from './printLayout';
import type { Block } from './printTemplate';

export const EXPORT_FORMAT = 'gawalak-print-template';
/** صورة 2 ميجا base64 + القالب */
export const EXPORT_MAX_CHARS = 3_000_000;
/** اسم وهمي للفحص بس: الملف الحقيقي بياخد اسم جديد وقت الرفع */
const DUMMY = (t: BgType) => `00000000-0000-4000-8000-000000000000.${t}`;

export interface TemplateContent {
  doc: PrintDoc;
  mode: PrintMode;
  blocks: Block[];
  layout: PrintLayout;
}
export interface TemplateImage {
  type: BgType;
  bytes: Uint8Array;
}
export interface ImportedTemplate {
  /** layout.bg بيبقى null: الشاشة بترفع image الأول (prepareBackground) وتحط اسمها الجديد مع bg */
  template: TemplateContent;
  image: TemplateImage | null;
  /** طريقة الورق من هنا، والمقاس من prepareBackground بعد ما الصورة تترسم (مش من الملف) */
  bg: { stock: 'preprinted' | 'blank'; w: number; h: number } | null;
}

function toBase64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** من غير image: الخلفية ما بتدخلش الملف (اسمها بتاع المحل ده بس) */
export function exportTemplate(t: TemplateContent, image: TemplateImage | null): string {
  const { bg, ...layout } = t.layout;
  const out = JSON.stringify({
    format: EXPORT_FORMAT, version: 1, doc: t.doc, mode: t.mode, blocks: t.blocks, layout,
    ...(bg && image ? { background: { stock: bg.stock, w: bg.w, h: bg.h, type: image.type, data: toBase64(image.bytes) } } : {}),
  });
  // ما يتصدّرش ملف مش هيتستورد
  parseTemplate(out);
  return out;
}

const isObj = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const onlyKeys = (o: object, keys: string[]) => Object.keys(o).every((k) => keys.includes(k));
const bad = (): never => {
  throw new Error('E_TEMPLATE_FILE');
};

/** بترمي E_TEMPLATE_FILE لأي ملف مش سليم بالظبط */
export function parseTemplate(text: string): ImportedTemplate {
  if (text.length > EXPORT_MAX_CHARS) bad();
  let j: unknown;
  try {
    j = JSON.parse(text);
  } catch {
    return bad();
  }
  if (!isObj(j) || !onlyKeys(j, ['format', 'version', 'doc', 'mode', 'blocks', 'layout', 'background']) || j.format !== EXPORT_FORMAT || j.version !== 1) return bad();
  if (!isObj(j.layout) || 'bg' in j.layout || typeof j.doc !== 'string' || typeof j.mode !== 'string') return bad();
  let image: TemplateImage | null = null;
  let bg: ImportedTemplate['bg'] = null;
  const b = j.background;
  if (b !== undefined) {
    if (!isObj(b) || !onlyKeys(b, ['stock', 'w', 'h', 'type', 'data']) || typeof b.data !== 'string' || (b.type !== 'png' && b.type !== 'jpg')) return bad();
    let raw = '';
    try {
      raw = atob(b.data);
    } catch {
      bad();
    }
    const bytes = Uint8Array.from(raw, (c) => c.charCodeAt(0));
    if (bytes.length > BG_MAX_BYTES || sniffImage(bytes) !== b.type) return bad();
    image = { type: b.type, bytes };
    bg = { stock: b.stock as 'blank', w: b.w as number, h: b.h as number };
  }
  const layout = bg && image ? { ...j.layout, bg: { file: DUMMY(image.type), ...bg } } : j.layout;
  if (templateError(j.doc, j.mode, j.blocks, layout)) return bad();
  const fields = [...(j.blocks as { text?: string }[]), ...((j.layout as PrintLayout).fields ?? [])];
  // النص الحر بيتطبع كنص، بس ملف جاي من بره فيه وسوم بيترفض خالص
  if (fields.some((f) => f.text && /<\s*[a-z!/?]/i.test(f.text))) return bad();
  return { template: { doc: j.doc as PrintDoc, mode: j.mode as PrintMode, blocks: j.blocks as Block[], layout: { ...(j.layout as PrintLayout), bg: null } }, image, bg };
}
