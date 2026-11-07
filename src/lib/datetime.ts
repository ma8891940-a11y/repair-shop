/**
 * دالة واحدة لتنسيق التاريخ والوقت في البرنامج كله (الشاشات والطباعة وصفحة التتبع والرسايل والتصدير).
 *
 * - بتوقيت القاهرة دايمًا.
 * - العربي: يوم/شهر/سنة زي المعتاد في مصر (07/11/2026)، أو بأسماء الشهور (7 نوفمبر 2026). بأرقام لاتيني.
 * - الإنجليزي: 7 Nov 2026.
 * - التاريخ بالأرقام والوقت بيتحطوا جوه "عزل" اتجاه (LRI…PDI، زي <bdi dir="ltr">)، فما بيتقلبوش جوه كلام عربي
 *   في أي مكان: الشاشة والطباعة وواتساب. (صيغة المتصفح العربي فيها علامات RLM بتقلب 07/11/2026 لـ 2026/11/07.)
 * - plain: من غير علامات العزل (للتصدير CSV وأسماء الملفات).
 */
import { SHOP_TZ } from './dates';

export type DateLang = 'ar' | 'en';
export type DateStyle = 'date' | 'dateLong' | 'numeric' | 'dateTime' | 'time';

const LRI = '\u2066';
const RLI = '\u2067';
const PDI = '\u2069';

const partsFmt = new Intl.DateTimeFormat('en-GB', { timeZone: SHOP_TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', weekday: 'long' });
const monthAr = new Intl.DateTimeFormat('ar-EG-u-nu-latn', { timeZone: SHOP_TZ, month: 'long' });
const longAr = new Intl.DateTimeFormat('ar-EG-u-nu-latn', { timeZone: SHOP_TZ, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
// ص/م من صيغة العربي نفسها (من غير ما نكتبهم في الكود)
const periodAr = new Intl.DateTimeFormat('ar-EG-u-nu-latn', { timeZone: SHOP_TZ, hour: 'numeric', hour12: true });
const dayPeriod = (d: Date) => strip(periodAr.formatToParts(d).find((x) => x.type === 'dayPeriod')?.value ?? '');
const monthEnShort = new Intl.DateTimeFormat('en-GB', { timeZone: SHOP_TZ, month: 'short' });
const monthEnLong = new Intl.DateTimeFormat('en-GB', { timeZone: SHOP_TZ, month: 'long' });

function parts(d: Date) {
  const p: Record<string, string> = {};
  for (const x of partsFmt.formatToParts(d)) p[x.type] = x.value;
  return { day: p.day, month: p.month, year: p.year, hour: Number(p.hour), minute: p.minute, weekday: p.weekday };
}
const strip = (s: string) => s.replace(/[\u200e\u200f\u061c\u2066-\u2069]/g, "");

/** "2026-11-07" (يوم من غير وقت) بيتفهم يوم القاهرة ده بالظبط، مش نص الليل UTC */
function toDate(d: Date | string | number): Date {
  if (typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d)) return new Date(`${d}T12:00:00Z`);
  return d instanceof Date ? d : new Date(d);
}

export function formatDate(input: Date | string | number, lang: DateLang, style: DateStyle = 'date', opts: { plain?: boolean } = {}): string {
  const d = toDate(input);
  if (Number.isNaN(d.getTime())) return '';
  const ltr = (s: string) => (opts.plain ? s : `${LRI}${s}${PDI}`);
  const rtl = (s: string) => (opts.plain ? s : `${RLI}${s}${PDI}`);
  const p = parts(d);
  const dayNum = String(Number(p.day));
  const numeric = `${p.day}/${p.month}/${p.year}`;
  const time = () => {
    if (lang === 'en') return `${String(p.hour).padStart(2, '0')}:${p.minute}`;
    const h12 = p.hour % 12 === 0 ? 12 : p.hour % 12;
    return `${ltr(`${String(h12).padStart(2, '0')}:${p.minute}`)} ${dayPeriod(d)}`;
  };
  if (lang === 'en') {
    switch (style) {
      case 'numeric':
        return ltr(numeric);
      case 'dateLong':
        return ltr(`${p.weekday}, ${dayNum} ${monthEnLong.format(d)} ${p.year}`);
      case 'dateTime':
        return ltr(`${dayNum} ${monthEnShort.format(d)} ${p.year}, ${time()}`);
      case 'time':
        return ltr(time());
      default:
        return ltr(`${dayNum} ${monthEnShort.format(d)} ${p.year}`);
    }
  }
  const month = strip(monthAr.format(d));
  switch (style) {
    case 'numeric':
      return ltr(numeric);
    case 'dateLong':
      return rtl(strip(longAr.format(d)));
    case 'dateTime':
      return rtl(`${ltr(numeric)} ${time()}`);
    case 'time':
      return rtl(time());
    default:
      return rtl(`${dayNum} ${month} ${p.year}`);
  }
}

/** نفس النص من غير علامات العزل (للمقارنة والاختبار) */
export const plainText = strip;
