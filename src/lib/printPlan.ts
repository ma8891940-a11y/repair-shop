// الطباعة: الإعدادات (الإعدادات ← الطباعة)، ومقاس الاستيكر، واللي بيتعمل تلقائي بعد الاستلام
import type { FreeField, PrintLayout } from './printLayout';
export type PrintDoc = 'sticker' | 'receipt' | 'receipt-a4' | 'invoice' | 'label';
/** أزرار "طباعة وإرسال" في الاستلام وصفحة الجهاز */
export const ACTIONS = ['thermal', 'paper', 'sticker', 'qr', 'whatsapp'] as const;
export type PrintAction = (typeof ACTIONS)[number];
export const ACTION_DOC: Record<Exclude<PrintAction, 'whatsapp'>, PrintDoc> = { thermal: 'receipt', paper: 'receipt-a4', sticker: 'sticker', qr: 'label' };

/** المقاسات الجاهزة للاستيكر (عرض × ارتفاع بالمليمتر) */
export const STICKER_PRESETS: [number, number][] = [
  [30, 20],
  [38, 25],
  [40, 30],
  [50, 25],
  [50, 30],
  [58, 40],
  [60, 40],
];

export interface StickerSettings {
  /** بالمليمتر */
  w: number;
  h: number;
  /** إطار حوالين الاستيكر */
  frame: boolean;
  /** إزاحة بالمليمتر (لو الطباعة طالعة مزحزحة) */
  dx: number;
  dy: number;
  /** عدد النسخ */
  copies: number;
}

export interface PrintSettings {
  /** التسليم: فاتورة ورقية A4 (بيظهر زرار "فاتورة التسليم" بعد التسليم) */
  deliveryPaper: boolean;
  /** اللي بيتعمل لوحده بعد الاستلام */
  auto: Record<PrintAction, boolean>;
  sticker: StickerSettings;
}

export const DEFAULT_STICKER: StickerSettings = { w: 40, h: 30, frame: false, dx: 0, dy: 0, copies: 1 };
export const DEFAULT_PRINT: PrintSettings = {
  deliveryPaper: true,
  auto: { thermal: false, paper: false, sticker: false, qr: false, whatsapp: false },
  sticker: DEFAULT_STICKER,
};

const num = (v: unknown, min: number, max: number, d: number) => (typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, Math.round(v * 10) / 10)) : d);

export function readSticker(v: unknown): StickerSettings {
  const s = v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  return {
    w: num(s.w, 15, 120, DEFAULT_STICKER.w),
    h: num(s.h, 10, 120, DEFAULT_STICKER.h),
    frame: typeof s.frame === 'boolean' ? s.frame : DEFAULT_STICKER.frame,
    dx: num(s.dx, -10, 10, 0),
    dy: num(s.dy, -10, 10, 0),
    copies: Math.round(num(s.copies, 1, 20, 1)),
  };
}

export function readPrint(extras: unknown): PrintSettings {
  const ex = extras && typeof extras === 'object' ? (extras as Record<string, unknown>) : {};
  const p = ex.print && typeof ex.print === 'object' ? (ex.print as Record<string, unknown>) : {};
  const a = p.auto && typeof p.auto === 'object' ? (p.auto as Record<string, unknown>) : null;
  // الإعدادات القديمة (قبل "طباعة وإرسال"): "اطبع تلقائي" كان بيطبع اللي متعلّم في الاستلام
  const legacyOn = typeof p.autoAfterIntake === 'boolean' ? p.autoAfterIntake : ex.auto_print === true;
  const legacy = (k: string, d: boolean) => legacyOn && (typeof p[k] === 'boolean' ? (p[k] as boolean) : d);
  const auto = Object.fromEntries(
    ACTIONS.map((k) => [
      k,
      a ? a[k] === true : k === 'sticker' ? legacy('intakeSticker', true) : k === 'paper' ? legacy('intakePaper', true) : k === 'thermal' ? legacy('intakeThermal', false) : false,
    ]),
  ) as Record<PrintAction, boolean>;
  return {
    deliveryPaper: typeof p.deliveryPaper === 'boolean' ? p.deliveryPaper : true,
    auto,
    sticker: readSticker(p.sticker),
  };
}

/** مقاس الصفحة (@page) لكل مستند */
export function pageSize(doc: PrintDoc, st: StickerSettings): string {
  if (doc === 'sticker') return `${st.w}mm ${st.h}mm`;
  if (doc === 'label') return '50mm 30mm';
  if (doc === 'receipt') return '80mm auto';
  return 'A4';
}

/** الباقي = التكلفة − المقدم (بالقروش، أعداد صحيحة، ومش أقل من صفر) */
export function remaining(cost: number | null, paid: number): number | null {
  if (cost == null) return null;
  return Math.max(cost - paid, 0);
}

/**
 * مقاس الخط في الاستيكر عشان كل السطور تدخل في الارتفاع: رقم الصيانة أكبر سطر.
 * بيرجع مقاس كل سطر بالمليمتر. العرض بيتحكم فيه بالـ "..." للكلام الطويل.
 */
export const STICKER_LINES = [
  { key: 'order', weight: 1.7 },
  { key: 'name', weight: 1 },
  { key: 'phone', weight: 1 },
  { key: 'issue', weight: 1 },
  { key: 'money', weight: 0.95 },
  { key: 'date', weight: 0.85 },
] as const;
export const STICKER_PAD_MM = 1.2;
export const LINE_HEIGHT = 1.12;

export function stickerFont(st: Pick<StickerSettings, 'w' | 'h'>): Record<(typeof STICKER_LINES)[number]['key'], number> {
  // 4% احتياطي عشان تقريب البكسلات في الطباعة والمعاينة
  const inner = (st.h - STICKER_PAD_MM * 2) * 0.96;
  const total = STICKER_LINES.reduce((a, l) => a + l.weight, 0) * LINE_HEIGHT;
  // ومش أكبر من اللي العرض يستحمله (رقم الطلب 9 حروف تقريبًا)
  const byWidth = (st.w - STICKER_PAD_MM * 2) / (9 * 0.62 * 1.7);
  const unit = Math.min(inner / total, byWidth);
  return Object.fromEntries(STICKER_LINES.map((l) => [l.key, Math.round(unit * l.weight * 100) / 100])) as Record<(typeof STICKER_LINES)[number]['key'], number>;
}

/** رابط صفحة الطباعة لمستند (embed = جوه إطار مخفي من غير ما تسيب الشاشة) */
export function printUrl(doc: PrintDoc, deviceId: string, o: { embed?: boolean; no?: string } = {}): string {
  const q = new URLSearchParams();
  if (o.embed) q.set('embed', '1');
  if (o.no) q.set('no', o.no);
  const qs = q.toString();
  return `/print/${doc}/${deviceId}${qs ? `?${qs}` : ''}`;
}

const r1 = (n: number) => Math.round(n * 10) / 10;
const clampInt = (n: number, min: number, max: number) => Math.min(max, Math.max(min, Math.round(n)));
/**
 * 50.8: نقطة البداية لقالب الستيكر في المصمم: نفس سطور الاستيكر الحالي بمقاسه وخطوطه (أقرب pt صحيح).
 * من غير قالب محفوظ، الاستيكر بيتطبع بـ StickerLabel زي ما هو بالظبط.
 */
export function stickerLayout(st: Pick<StickerSettings, 'w' | 'h'>): PrintLayout {
  const w = clampInt(st.w, 20, 120);
  const h = clampInt(st.h, 10, 120);
  const fs = stickerFont({ w, h });
  const inner = r1(w - STICKER_PAD_MM * 2);
  const pt = (mm: number) => clampInt((mm * 72) / 25.4, 5, 72);
  let y = STICKER_PAD_MM;
  const fields: FreeField[] = [];
  const line = (size: number, parts: { key: string; x: number; w: number; font?: FreeField['font']; bold?: boolean; cap?: boolean }[]) => {
    const lh = Math.max(1, Math.floor(size * LINE_HEIGHT * 10) / 10);
    for (const p of parts)
      fields.push({ key: p.key, x: r1(STICKER_PAD_MM + p.x), y: r1(y), w: r1(p.w), h: lh, font: p.font ?? 'sans', pt: pt(size), align: 'start', bold: !!p.bold, ...(p.cap ? { cap: true } : {}) });
    y += lh;
  };
  const full = (key: string, o: { font?: FreeField['font']; bold?: boolean } = {}) => [{ key, x: 0, w: inner, ...o }];
  // من اليمين (عربي): الجهاز ثم العطل، والتكلفة ثم المقدم ثم الباقي
  const dev = r1(inner * 0.45);
  const third = r1(inner / 3);
  line(fs.order, full('orderNo', { font: 'mono', bold: true }));
  line(fs.name, full('customer', { bold: true }));
  line(fs.phone, full('phone', { font: 'mono', bold: true }));
  line(fs.issue, [{ key: 'device', x: r1(inner - dev), w: dev }, { key: 'issue', x: 0, w: r1(inner - dev) }]);
  line(fs.money, [
    { key: 'price', x: r1(inner - third), w: third, bold: true, cap: true },
    { key: 'paid', x: third, w: r1(inner - 2 * third), bold: true, cap: true },
    { key: 'remaining', x: 0, w: third, bold: true, cap: true },
  ]);
  line(fs.date, full('date'));
  return { paper: { kind: 'custom', w, h }, fields };
}
