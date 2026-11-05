import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { assertPiasters } from '../lib/money';
import { SHOP_TZ } from '../lib/dates';
import type { Lang } from './index';

/** صيغة الأرقام والتواريخ حسب اللغة. العربي بأرقام لاتيني (المعتاد في المحلات في مصر) */
export function localeTag(lang: Lang): string {
  return lang === 'ar' ? 'ar-EG-u-nu-latn' : 'en-GB';
}

/** المبلغ بالقروش => نص بالعملة. من غير أي حساب عشري: القسمة بتتعمل كأعداد صحيحة */
export function formatMinor(minor: number, lang: Lang): string {
  assertPiasters(minor);
  const neg = minor < 0;
  const abs = Math.abs(minor);
  const major = Math.floor(abs / 100);
  const rest = abs % 100;
  const majorStr = new Intl.NumberFormat(localeTag(lang), { useGrouping: true, maximumFractionDigits: 0 }).format(major);
  const dec = lang === 'ar' ? '.' : '.';
  const body = rest === 0 ? majorStr : `${majorStr}${dec}${String(rest).padStart(2, '0')}`;
  return neg ? `-${body}` : body;
}

export function useFormat() {
  const { t, i18n } = useTranslation();
  const lang = (i18n.language === 'en' ? 'en' : 'ar') as Lang;
  return useMemo(() => {
    const tag = localeTag(lang);
    const date = new Intl.DateTimeFormat(tag, { timeZone: SHOP_TZ, day: 'numeric', month: 'short', year: 'numeric' });
    const dateLong = new Intl.DateTimeFormat(tag, { timeZone: SHOP_TZ, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
    const dateTime = new Intl.DateTimeFormat(tag, { timeZone: SHOP_TZ, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    const num = new Intl.NumberFormat(tag);
    return {
      lang,
      tag,
      number: (n: number) => num.format(n),
      money: (minor: number) => formatMinor(minor, lang),
      /** رمز العملة حسب اللغة: ج.م / EGP */
      currency: (code = 'EGP') => t(`currency.${code}`, { defaultValue: code }),
      date: (d: Date | string) => date.format(new Date(d)),
      dateLong: (d: Date | string) => dateLong.format(new Date(d)),
      dateTime: (d: Date | string) => dateTime.format(new Date(d)),
      days: (n: number) => t('units.days', { count: n, n: num.format(n) }),
    };
  }, [lang, t]);
}
