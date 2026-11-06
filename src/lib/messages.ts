import { normalizeEgyptPhone, toInternational } from './phone';

export const TEMPLATE_KEYS = ['received', 'status', 'approval', 'ready', 'reminder', 'delivered'] as const;
export type TemplateKey = (typeof TEMPLATE_KEYS)[number];
export const PLACEHOLDERS = ['name', 'order', 'device', 'status', 'cost', 'link', 'shop', 'tech', 'days', 'warranty'] as const;
export type Vars = Partial<Record<(typeof PLACEHOLDERS)[number], string>>;

/** بيملا القالب: {name} و{order}... وأي متغير مش موجود بيتشال من غير ما يسيب أقواس */
export function fillTemplate(body: string, vars: Vars): string {
  return body
    .replace(/\{(\w+)\}/g, (_, k: string) => (k in vars ? (vars[k as keyof Vars] ?? '') : ''))
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
}

/** رابط واتساب جاهز (wa.me) برقم العميل بالصيغة الدولية والرسالة */
export function waLink(phone: string, text: string): string | null {
  if (!normalizeEgyptPhone(phone)) return null;
  return `https://wa.me/${toInternational(phone)}?text=${encodeURIComponent(text)}`;
}

/** رابط التتبع اللي بيتحط في الرسايل والـ QR */
export function trackingUrl(base: string, token: string): string {
  return `${base.replace(/#.*$/, '').replace(/\/$/, '')}/#/t/${token}`;
}
