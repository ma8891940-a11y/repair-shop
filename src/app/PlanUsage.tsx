import { useTranslation } from 'react-i18next';
import { useLoad } from './useLoad';
import { rpc } from './ledgerApi';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { ErrorState, Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

interface Usage {
  plan: string;
  max_devices_month: number | null;
  max_staff: number | null;
  ai_daily: number;
  max_videos: number | null;
  devices_month: number;
  staff: number;
  ai_today: number;
  videos: number;
}

/** الخطة والاستخدام لصاحب المحل: كل حد بيتطبق في قاعدة البيانات، والشاشة دي بتوريه بس */
export function PlanUsage() {
  const { t } = useTranslation();
  const f = useFormat();
  const { data, error, loading, reload } = useLoad(() => rpc<Usage>('plan_usage'), []);
  if (error) return <ErrorState message={error} onRetry={reload} />;
  if (loading || !data) return <Skeleton className="h-32 w-full" />;
  const rows: [string, number, number | null][] = [
    ['devices', data.devices_month, data.max_devices_month],
    ['staff', data.staff, data.max_staff],
    ['ai', data.ai_today, data.ai_daily],
    ['videos', data.videos, data.max_videos],
  ];
  return (
    <Panel data-testid="plan-usage">
      <PanelHeader title={t('plan.title')} actions={<span className="text-sm text-fg-2">{t('plan.current')}: {t(`admin.plans.${data.plan}`, { defaultValue: data.plan })}</span>} />
      <ul className="grid gap-3 p-4 sm:grid-cols-2">
        {rows.map(([k, used, max]) => {
          const pct = max ? Math.min(100, Math.round((used * 100) / max)) : 0;
          return (
            <li key={k} className="flex flex-col gap-1">
              <div className="flex justify-between text-sm">
                <span className="text-fg-2">{t(`plan.${k}`)}</span>
                <span className="num text-fg">{max == null ? `${f.number(used)} · ${t('plan.unlimited')}` : t('plan.of', { used: f.number(used), max: f.number(max) })}</span>
              </div>
              {max != null && (
                <div className="h-1.5 overflow-hidden rounded-full bg-sunken" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} aria-label={t(`plan.${k}`)}>
                  <div className={cn('h-full rounded-full', pct >= 90 ? 'bg-danger' : pct >= 75 ? 'bg-warn' : 'bg-accent')} style={{ width: `${pct}%` }} />
                </div>
              )}
              {max != null && pct >= 90 && <span className="text-2xs text-warn">{t('plan.near')}</span>}
            </li>
          );
        })}
      </ul>
    </Panel>
  );
}
