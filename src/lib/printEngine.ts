/**
 * 50.6: محرّك الطباعة: من القالب (flow أو free) وملف الطابعة لمقاس الصفحة، والإزاحة، والخلفية، وأماكن الحقول بالمللي.
 * حساب بس (من غير React): الشاشات بتاخد النتيجة وترسمها. القوالب القديمة (من غير خط ولا حجم ولا ورقة) بتطلع زي ما هي.
 */
import { paperSize, type FreeField, type PrintLayout } from './printLayout';
import type { Block } from './printTemplate';

export const FONT_CSS = { sans: 'var(--font-sans)', mono: 'var(--font-mono)', system: 'system-ui, sans-serif' } as const;

export interface PrinterRow {
  width_mm: number;
  height_mm: number | null;
  margin_mm: number;
  offset_x?: number | string | null;
  offset_y?: number | string | null;
}
export interface PagePlan {
  /** مقاس الورقة بالمللي (null = طول مفتوح زي الحراري) */
  w: number;
  h: number | null;
  margin: number;
  /** إزاحة الطابعة بالمللي (موجب = يمين / تحت) */
  dx: number;
  dy: number;
  /** print = بتتطبع (ورق فاضي)، وإلا للشاشة بس (الورق مطبوع جاهز) */
  bg: { file: string; print: boolean } | null;
  lang: 'ar' | 'en';
}

/** مقاس كل مستند من غير قالب ولا طابعة (نفس اللي الشاشات بتطبعه دلوقتي) */
export const DOC_PAGE: Record<string, { w: number; h: number | null; margin: number }> = {
  receipt: { w: 80, h: null, margin: 3 },
  'receipt-a4': { w: 210, h: 297, margin: 14 },
  invoice: { w: 210, h: 297, margin: 14 },
  statement: { w: 210, h: 297, margin: 12 },
  voucher: { w: 210, h: 297, margin: 12 },
  sale: { w: 210, h: 297, margin: 12 },
  barcode: { w: 50, h: 30, margin: 1 },
  sticker: { w: 40, h: 30, margin: 0 },
  label: { w: 50, h: 30, margin: 1 },
};

/** خط وحجم الخانة بس لو القالب حددهم (من غيرهم: شكل الخانة القديم بالظبط) */
export function blockStyle(b: Pick<Block, 'font' | 'pt'>): { fontFamily?: string; fontSize?: string } {
  return { ...(b.font ? { fontFamily: FONT_CSS[b.font] } : {}), ...(b.pt ? { fontSize: `${b.pt}pt` } : {}) };
}

// numeric من PostgREST ممكن يرجع نص، وأي حاجة غلط أو بره ±10 = صفر
const off = (v: unknown) => {
  const n = Number(v ?? 0);
  return Number.isFinite(n) && Math.abs(n) <= 10 ? Math.round(n * 10) / 10 : 0;
};

/**
 * مقاس الصفحة: ورقة القالب، وإلا ملف الطابعة، وإلا مقاس المستند الافتراضي.
 * القالب الحر هامشه صفر (الأماكن من حافة الورقة)، والإزاحة دايمًا من الطابعة.
 */
export function pagePlan(
  mode: 'flow' | 'free',
  layout: PrintLayout | null | undefined,
  printer: PrinterRow | null | undefined,
  fallback: { w: number; h: number | null; margin: number },
  appLang: string,
): PagePlan {
  const paper = layout?.paper ? paperSize(layout.paper) : null;
  const w = paper?.w ?? printer?.width_mm ?? fallback.w;
  const h = paper ? paper.h : printer ? printer.height_mm : fallback.h;
  const margin = mode === 'free' ? 0 : (printer?.margin_mm ?? fallback.margin);
  const bg = layout?.bg ? { file: layout.bg.file, print: layout.bg.stock === 'blank' } : null;
  const lang = layout?.lang === 'ar' || layout?.lang === 'en' ? layout.lang : appLang.startsWith('en') ? 'en' : 'ar';
  return { w, h, margin, dx: off(printer?.offset_x), dy: off(printer?.offset_y), bg, lang };
}

export function planCss(p: PagePlan): string {
  return `@page { size: ${p.w}mm ${p.h ? `${p.h}mm` : 'auto'}; margin: ${p.margin}mm; }`;
}

/** مكان الحقل الحر بالمللي من شمال الورقة وفوقها (ثابت في العربي والإنجليزي، زي الورق نفسه) */
export function freeStyle(f: FreeField) {
  return {
    position: 'absolute' as const,
    left: `${f.x}mm`,
    top: `${f.y}mm`,
    width: `${f.w}mm`,
    height: `${f.h}mm`,
    fontFamily: FONT_CSS[f.font],
    fontSize: `${f.pt}pt`,
    fontWeight: f.bold ? 700 : 400,
    textAlign: f.align,
    lineHeight: 1.15,
    overflow: 'hidden' as const,
  };
}

/** علامات المسطرة كل 5 مللي (الطويلة كل 10) لخطوط الإرشاد في الطباعة التجريبية */
export function rulerTicks(len: number): { at: number; long: boolean }[] {
  return Array.from({ length: Math.floor(len / 5) + 1 }, (_, i) => ({ at: i * 5, long: i % 2 === 0 }));
}
