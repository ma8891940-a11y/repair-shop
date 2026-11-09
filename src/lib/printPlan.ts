// الطباعة: يطبع إيه في كل خطوة (الإعدادات ← الطباعة)، وترتيب الطباعة ورا بعض
export type StickerSize = '80' | '50x30' | '58x40';
export type PrintDoc = 'sticker' | 'receipt' | 'receipt-a4' | 'invoice';

export interface PrintSettings {
  /** الاستلام: استيكر حراري يتلزق على الجهاز */
  intakeSticker: boolean;
  /** الاستلام: إيصال ورقي A4 بلوجو المحل */
  intakePaper: boolean;
  /** الاستلام: إيصال حراري 80مم (الإيصال القديم) */
  intakeThermal: boolean;
  /** التسليم: فاتورة ورقية A4 */
  deliveryPaper: boolean;
  stickerSize: StickerSize;
  /** اطبع تلقائي بعد الاستلام (نفس مفتاح الإضافات القديم auto_print) */
  autoAfterIntake: boolean;
}

/** الافتراضي: الاستيكر الحراري في الاستلام بس، والورقي في الاستلام والتسليم */
export const DEFAULT_PRINT: PrintSettings = { intakeSticker: true, intakePaper: true, intakeThermal: false, deliveryPaper: true, stickerSize: '80', autoAfterIntake: false };

export function readPrint(extras: unknown): PrintSettings {
  const ex = extras && typeof extras === 'object' ? (extras as Record<string, unknown>) : {};
  const p = ex.print && typeof ex.print === 'object' ? (ex.print as Record<string, unknown>) : {};
  const b = (k: keyof PrintSettings) => (typeof p[k] === 'boolean' ? (p[k] as boolean) : (DEFAULT_PRINT[k] as boolean));
  const size = p.stickerSize === '50x30' || p.stickerSize === '58x40' || p.stickerSize === '80' ? p.stickerSize : DEFAULT_PRINT.stickerSize;
  return {
    intakeSticker: b('intakeSticker'),
    intakePaper: b('intakePaper'),
    intakeThermal: b('intakeThermal'),
    deliveryPaper: b('deliveryPaper'),
    stickerSize: size,
    autoAfterIntake: typeof p.autoAfterIntake === 'boolean' ? p.autoAfterIntake : ex.auto_print === true,
  };
}

/** المستندات اللي بتتطبع في الاستلام بالترتيب: الاستيكر الأول (بيتلزق على الجهاز)، وبعدين الإيصال */
export function intakeDocs(s: PrintSettings): PrintDoc[] {
  return [s.intakeSticker && 'sticker', s.intakeThermal && 'receipt', s.intakePaper && 'receipt-a4'].filter(Boolean) as PrintDoc[];
}

/** رابط أول مستند، والباقي ورا بعض (?next=) */
export function printChain(deviceId: string, docs: PrintDoc[]): string | null {
  if (!docs.length) return null;
  const [first, ...rest] = docs;
  return `/print/${first}/${deviceId}${rest.length ? `?next=${rest.join(',')}` : ''}`;
}

/** مقاس الصفحة (@page) لكل مستند */
export function pageSize(doc: PrintDoc | 'label', size: StickerSize): string {
  if (doc === 'sticker') return size === '50x30' ? '50mm 30mm' : size === '58x40' ? '58mm 40mm' : '80mm auto';
  if (doc === 'label') return '80mm 40mm';
  if (doc === 'receipt') return '80mm auto';
  return 'A4';
}
