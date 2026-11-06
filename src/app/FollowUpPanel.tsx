import { useMemo, useState } from 'react';
import { Link, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { overdueReady } from '../lib/customers';
import type { DeviceStatus } from '../lib/status';
import { useFormat } from '../i18n/format';
import { useLoad, must } from './useLoad';
import { useLiveRefresh } from './AppShell';
import { WhatsAppDialog, type MessageTarget } from './messaging';
import { Panel, PanelHeader } from '../ui/Panel';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Button } from '../ui/Button';

interface Row {
  id: string;
  order_no: string;
  brand: string;
  model: string;
  status: DeviceStatus;
  customer_id: string;
  customer_name: string | null;
  customer_phone: string | null;
  final_cost: number | null;
}

/** متابعة: أجهزة جاهزة من 10 أيام أو أكتر ولسه ما اتسلمتش، مع زرار تذكير على واتساب */
export function FollowUpPanel() {
  const { t } = useTranslation();
  const f = useFormat();
  const location = useLocation();
  const [target, setTarget] = useState<MessageTarget | null>(null);
  const { data, error, loading, reload } = useLoad(async () => {
    const rows = must(await supabase.from('devices_list').select('id, order_no, brand, model, status, customer_id, customer_name, customer_phone, final_cost').eq('status', 'ready').is('deleted_at', null).limit(1000)) as Row[];
    if (!rows.length) return { rows, events: [], tokens: new Map<string, string>() };
    const ids = rows.map((r) => r.id);
    const [ev, tk] = await Promise.all([
      supabase.from('status_log').select('device_id, new_status, created_at').in('device_id', ids).eq('new_status', 'ready'),
      supabase.from('devices').select('id, tracking_token').in('id', ids),
    ]);
    const tokens = new Map((must(tk) as { id: string; tracking_token: string }[]).map((x) => [x.id, x.tracking_token]));
    return { rows, events: must(ev) as { device_id: string; new_status: string; created_at: string }[], tokens };
  }, []);
  useLiveRefresh(reload);
  const list = useMemo(() => (data ? overdueReady(data.rows, data.events, new Date()) : []), [data]);

  return (
    <Panel className="flex min-w-0 flex-col">
      <PanelHeader index="04" title={t('follow.title')} />
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading ? (
        <div className="flex flex-col gap-2 p-3">
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
        </div>
      ) : list.length === 0 ? (
        <EmptyState line="phone" title={t('follow.empty')} />
      ) : (
        <ul className="divide-y divide-glass-border" data-testid="follow-list">
          {list.map((d) => (
            <li key={d.id} className="flex items-center gap-3 px-4 py-2.5 text-sm">
              <Link to={`/devices/${d.id}`} state={{ bg: location }} className="num w-[86px] shrink-0 text-fg hover:text-accent" dir="ltr">
                {d.order_no}
              </Link>
              <div className="min-w-0 flex-1">
                <div className="truncate text-fg">
                  {d.brand} {d.model}
                </div>
                <div className="truncate text-2xs text-fg-3">{d.customer_name && <bdi>{d.customer_name}</bdi>}</div>
              </div>
              <span className="num shrink-0 text-xs text-warn">{f.days(d.days)}</span>
              <Button
                size="sm"
                variant="secondary"
                disabled={!d.customer_phone}
                onClick={() =>
                  setTarget({
                    deviceId: d.id,
                    customerId: d.customer_id,
                    customerName: d.customer_name ?? '',
                    phone: d.customer_phone ?? '',
                    orderNo: d.order_no,
                    device: `${d.brand} ${d.model}`,
                    status: d.status,
                    token: data!.tokens.get(d.id) ?? '',
                    cost: d.final_cost,
                    readySince: d.readySince,
                  })
                }
              >
                {t('follow.remind')}
              </Button>
            </li>
          ))}
        </ul>
      )}
      <WhatsAppDialog open={!!target} onOpenChange={(v) => !v && setTarget(null)} target={target} initial="reminder" />
    </Panel>
  );
}
