import { useTranslation } from 'react-i18next';
import { durationParts } from '../../lib/tech';

/** أسماء التخصصات والمسارات: الأساسية مترجمة من الكود، والمضافة بالاسم اللي اتكتب */
export function useSpecName() {
  const { t } = useTranslation();
  return (s: { code: string | null; name: string | null } | null | undefined) => (!s ? '' : s.name || t(`tech.spec.${s.code}`, { defaultValue: s.code ?? '' }));
}
export function useRouteName() {
  const { t } = useTranslation();
  return (r: { code: string | null; name: string | null } | null | undefined) => (!r ? '' : r.name || t(`tech.routes.${r.code}`, { defaultValue: r.code ?? '' }));
}
export function useDuration() {
  const { t } = useTranslation();
  return (minutes: number | null | undefined) => {
    if (!minutes) return '';
    const p = durationParts(minutes);
    return t(`tech.dur.${p.unit}`, { count: p.value, n: p.value });
  };
}
