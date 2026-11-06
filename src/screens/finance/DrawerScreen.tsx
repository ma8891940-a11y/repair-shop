import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Lock } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad, must } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { rpc, useAccountName } from '../../app/ledgerApi';
import { CloseDrawerDialog } from '../../app/finance/CloseDrawerDialog';
import { supabase } from '../../lib/supabase';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

interface Drawer {
  id: string;
  code: string | null;
  name: string | null;
  method: string;
  expected: number;
}

/**
 * الدرج: الخزن اللي الموظف مسؤول عنها، وتقفيلها.
 * الاستقبال بتعدّ من غير ما تشوف المتوقع (عدّ أعمى)، وصاحب المحل بيشوف الكل.
 */
export function DrawerScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const owner = profile.role === 'owner';
  const accName = useAccountName();
  const [closing, setClosing] = useState<Drawer | null>(null);
  const { data, error, loading, reload } = useLoad(async () => {
    const drawers = await rpc<Drawer[]>('my_drawers');
    const closings = must(await supabase.from('drawer_closings').select('id, cashbox_id, expected, counted, diff, created_at').order('created_at', { ascending: false }).limit(20)) as { id: string; cashbox_id: string; expected: number; counted: number; diff: number; created_at: string }[];
    return { drawers, closings };
  }, []);
  useLiveRefresh(reload);
  const cur = f.currency(shop.currency);
  const nameOf = (id: string) => accName(data?.drawers.find((d) => d.id === id) ?? null);
  return (
    <div className="max-w-4xl">
      <PageHeader title={t('drawer.title')} sub={owner ? t('drawer.subOwner') : t('drawer.sub')} />
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading || !data ? (
        <Skeleton className="h-32 w-full" />
      ) : data.drawers.length === 0 ? (
        <Panel>
          <EmptyState line="wallet" title={t('drawer.none')}>
            {t('drawer.noneText')}
          </EmptyState>
        </Panel>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {data.drawers.map((d) => (
            <Panel key={d.id} className="flex items-center gap-3 p-4" data-testid="drawer-card">
              <div className="min-w-0 flex-1">
                <div className="truncate font-medium text-fg">{accName(d)}</div>
                <div className="text-2xs text-fg-3">{t(`payments.${d.method}`, { defaultValue: d.method })}</div>
                {owner && (
                  <div className="num mt-1 text-md text-fg">
                    {f.money(Number(d.expected))} <span className="font-sans text-2xs text-fg-3">{cur}</span>
                  </div>
                )}
              </div>
              <Button size="sm" variant="primary" icon={<Lock className="size-4" />} onClick={() => setClosing(d)}>
                {t('fin.closeDrawer')}
              </Button>
            </Panel>
          ))}
        </div>
      )}
      {data && data.closings.length > 0 && (
        <Panel className="mt-4">
          <PanelHeader title={t('drawer.history')} />
          <ul className="divide-y divide-glass-border text-sm">
            {data.closings.map((c) => (
              <li key={c.id} className="grid grid-cols-[minmax(0,1fr)_auto_auto] items-center gap-3 px-4 py-2">
                <span className="min-w-0 truncate text-fg">
                  {nameOf(c.cashbox_id)} <span className="text-2xs text-fg-3">· {f.dateTime(c.created_at)}</span>
                </span>
                <span className="num text-fg-2">{f.money(Number(c.counted))}</span>
                <span className={cn('num w-24 text-end', Number(c.diff) < 0 ? 'text-danger' : Number(c.diff) > 0 ? 'text-warn' : 'text-ok')}>{f.money(Number(c.diff))}</span>
              </li>
            ))}
          </ul>
        </Panel>
      )}
      <CloseDrawerDialog open={!!closing} onOpenChange={(v) => !v && setClosing(null)} cashboxId={closing?.id ?? ''} name={accName(closing)} onDone={reload} />
    </div>
  );
}
