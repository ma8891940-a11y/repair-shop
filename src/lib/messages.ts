import { normalizeEgyptPhone, toInternational } from './phone';

export const TEMPLATE_KEYS = ['received', 'status', 'approval', 'ready', 'reminder', 'delivered', 'debt', 'marketing'] as const;
export type TemplateKey = (typeof TEMPLATE_KEYS)[number];
export const PLACEHOLDERS = ['name', 'order', 'device', 'status', 'cost', 'link', 'shop', 'tech', 'days', 'warranty', 'balance', 'eta'] as const;
export type Vars = Partial<Record<(typeof PLACEHOLDERS)[number], string>>;

/** بيملا القالب: {name} و{order}... وأي متغير مش موجود بيتشال من غير ما يسيب أقواس */
export function fillTemplate(body: string, vars: Vars): string {
  const filled = body
    .replace(/\{(\w+)\}/g, (_, k: string) => (k in vars ? (vars[k as keyof Vars] ?? '') : ''))
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
  return vars.link ? linkOnOwnLine(filled, vars.link) : filled;
}

/** البند 12: رابط التتبع في سطر لوحده (عشان واتساب يعرفه رابط ويتداس صح، وما يلزقش في كلمة) */
export function linkOnOwnLine(text: string, link: string): string {
  if (!link || !text.includes(link)) return text;
  return text
    .split(link)
    .map((part, i, a) => (i === 0 ? part.replace(/\s+$/, '') : i === a.length - 1 ? part.replace(/^\s+/, '') : part.trim()))
    .join(`\n${link}\n`)
    .replace(/\n{3,}/g, '\n\n')
    .replace(/^\n+|\n+$/g, '')
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
