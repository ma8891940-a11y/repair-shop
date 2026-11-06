import { useTranslation } from 'react-i18next';
import { CloudOff } from 'lucide-react';
import { useFormat } from '../i18n/format';

/** ملاحظة صغيرة لما البيانات المعروضة جاية من النسخة المحفوظة على الجهاز (بدون نت) */
export function StaleNote({ at }: { at: number | null }) {
  const { t } = useTranslation();
  const f = useFormat();
  if (!at) return null;
  return (
    <p className="mb-3 inline-flex items-center gap-1.5 rounded-md border border-[color-mix(in_srgb,var(--warn)_40%,transparent)] px-2.5 py-1 text-xs text-warn" data-testid="stale" role="status">
      <CloudOff className="size-3.5" aria-hidden /> {t('sync.cached', { t: f.dateTime(new Date(at)) })}
    </p>
  );
}
