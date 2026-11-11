import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { CalendarClock } from 'lucide-react';
import { rpc } from '../ledgerApi';
import { useLoad } from '../useLoad';
import { useLiveRefresh } from '../AppShell';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { toPlan, type PlanRow } from './PlansPanel';

/** N: كارت "مستحقات قادمة" في الوضع المالي: المتأخر والقريب (ليا وعليا)، وكل سطر بيفتح كشف الطرف */
export function UpcomingDues() {
  const { t } = useTranslation();
  const f = useFormat();
  const { data, reload } = useLoad(async () => {
    const all = (await rpc<PlanRow[]>('plans_overview')).map(toPlan).filter((p) => p.status !== 'done');
    const days = await rpc<number>('reminder_days');
    return { all, days: Number(days) };
  }, []);
  useLiveRefresh(reload);
  const hot = (data?.all ?? []).filter((p) => p.status === 'overdue' || p.status === 'due_soon');
  const sum = (dir: 'customer' | 'supplier', k: 'overdue' | 'soon') =>
    hot.filter((p) => p.party_type === dir).reduce((a, p) => a + (k === 'overdue' ? p.overdue : p.status === 'due_soon' ? (p.next_amount ?? 0) : 0), 0);
  return (
    <Panel className="mt-4" data-testid="upcoming-dues">
      <PanelHeader title={t('due.title')} />
      {!data ? (
        <Skeleton className="m-3 h-14" />
      ) : !hot.length ? (
        <p className="px-4 pb-4 text-xs text-fg-3">{t('due.none')}</p>
      ) : (
        <div className="flex flex-col gap-3 p-3">
          <div className="grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
            {(['customer', 'supplier'] as const).flatMap((d) =>
              (['overdue', 'soon'] as const).map((k) => (
                <div key={`${d}-${k}`} className="rounded-md border border-glass-border px-3 py-2">
                  <div className="readout-label">
                    {t(`due.${d === 'customer' ? 'in' : 'out'}`)} · {k === 'overdue' ? t('due.overdue') : t('due.soon', { n: f.number(data.days) })}
                  </div>
                  <div className={cn('num mt-0.5 text-md', k === 'overdue' && sum(d, k) > 0 ? 'text-danger' : 'text-fg')} data-testid={`due-${d}-${k}`}>
                    {f.money(sum(d, k))}
                  </div>
                </div>
              )),
            )}
          </div>
          <ul className="divide-y divide-glass-border text-sm">
            {hot.slice(0, 8).map((p) => (
              <li key={p.plan_id}>
                <Link to={`/finance/${p.party_type}/${p.party_id}`} className="flex items-center gap-2 px-1 py-1.5 hover:text-accent" data-testid="due-row">
                  <CalendarClock className={cn('size-4 shrink-0', p.status === 'overdue' ? 'text-danger' : 'text-warn')} aria-hidden />
                  <span className="min-w-0 flex-1 truncate">
                    <bdi>{p.party_name}</bdi>
                    <span className="ms-2 text-2xs text-fg-3">{t(`due.${p.party_type === 'customer' ? 'in' : 'out'}`)}</span>
                  </span>
                  {p.next_due && <span className="num text-2xs text-fg-3">{f.dateNum(p.next_due)}</span>}
                  <span className={cn('num', p.status === 'overdue' ? 'text-danger' : 'text-fg')}>{f.money(p.overdue || (p.next_amount ?? 0))}</span>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
    </Panel>
  );
}
