/**
 * الميزات الإضافية: مفاتيح التشغيل، ونص ملخص اليوم على واتساب.
 * كل حاجة هنا من غير أي بيانات عملاء.
 */
import { formatPounds, type Piasters } from './money';

export interface Extras {
  /** أعطال جاهزة في الاستلام */
  quick_issues: boolean;
  /** ملخص اليوم على واتساب لصاحب المحل */
  day_summary: boolean;
  /** طباعة الإيصال تلقائيًا بعد حفظ الاستلام */
  auto_print: boolean;
  /** ربط المخزون بالصيانة: القطع بتتصرف من المخزون. لو مقفول، القطعة بتتكتب على الجهاز يدوي بتكلفتها */
  link_inventory: boolean;
}
export const DEFAULT_EXTRAS: Extras = { quick_issues: true, day_summary: true, auto_print: false, link_inventory: true };

/** بيقرا المفاتيح من المحل، وأي قيمة ناقصة أو غلط بترجع للافتراضي */
export function readExtras(v: unknown): Extras {
  const o = v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  const pick = (k: keyof Extras) => (typeof o[k] === 'boolean' ? (o[k] as boolean) : DEFAULT_EXTRAS[k]);
  return { quick_issues: pick('quick_issues'), day_summary: pick('day_summary'), auto_print: pick('auto_print'), link_inventory: pick('link_inventory') };
}

/** S6: "السماح بالبيع بدون رصيد" (مقفول افتراضيًا). نفس القيمة اللي السيرفر بيقراها في allow_negative_stock() */
export function readAllowNegative(v: unknown): boolean {
  const o = v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  return o.allow_negative_stock === true;
}

export interface DayNumbers {
  received: number;
  delivered: number;
  ready: number;
  revenue: Piasters;
  expenses: Piasters;
  /** المقبوض بكل طريقة دفع (بالقروش) */
  byMethod: Record<string, Piasters>;
}

/**
 * نص ملخص اليوم. labels بتيجي من الترجمة عشان النص يطلع بلغة البرنامج.
 * المبالغ بالقروش كأعداد صحيحة، والتحويل لجنيه هنا في العرض بس.
 */
export function daySummaryText(shop: string, date: string, n: DayNumbers, labels: Record<'title' | 'received' | 'delivered' | 'ready' | 'revenue' | 'expenses' | 'profit' | 'collected' | 'currency', string>, methodName: (m: string) => string): string {
  const money = (v: Piasters) => `${formatPounds(v)} ${labels.currency}`;
  const lines = [
    `${labels.title}: ${shop}`,
    date,
    '',
    `${labels.received}: ${n.received}`,
    `${labels.delivered}: ${n.delivered}`,
    `${labels.ready}: ${n.ready}`,
    '',
    `${labels.revenue}: ${money(n.revenue)}`,
    `${labels.expenses}: ${money(n.expenses)}`,
    `${labels.profit}: ${money(n.revenue - n.expenses)}`,
  ];
  const methods = Object.entries(n.byMethod).filter(([, v]) => v > 0);
  if (methods.length) {
    lines.push('', `${labels.collected}:`);
    for (const [m, v] of methods) lines.push(`- ${methodName(m)}: ${money(v)}`);
  }
  return lines.join('\n');
}

/** رابط واتساب من غير رقم: صاحب المحل بيختار يبعته لنفسه أو لشريكه */
export function waShareUrl(text: string): string {
  return `https://wa.me/?text=${encodeURIComponent(text)}`;
}
