import { useState } from 'react';
import { Link, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { rpc } from './ledgerApi';
import { useLoad } from './useLoad';
import { WhatsAppDialog, type MessageTarget } from './messaging';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Button } from '../ui/Button';

interface Due {
  device_id: string;
  order_no: string;
  brand: string;
  model: string;
  issue: string;
  delivered_at: string;
  customer_id: string;
  customer_name: string;
  phone: string;
  tracking_token: string;
}

/**
 * تذكيرات تسويقية بموافقة العميل (من المواصفات): "غيّرت البطارية من 6 شهور".
 * بيظهر بس العملاء اللي وافقوا (من ملف العميل)، وآخر صيانة ليهم من 6 شهور أو أكتر، وما اتبعتلهمش تذكير من وقتها.
 * الرسالة من قالب "تذكير تسويقي" اللي صاحب المحل بيعدّله، وبتتبعت برابط واتساب جاهز.
 */
export function MarketingPanel() {
  const { t } = useTranslation();
  const f = useFormat();
  const location = useLocation();
  const [target, setTarget] = useState<MessageTarget | null>(null);
  const { data, error, loading, reload } = useLoad(() => rpc<Due[]>('marketing_due', { p_days: 180 }), []);
  return (
    <Panel className="flex min-w-0 flex-col" data-testid="marketing-due">
      <PanelHeader index="05" title={t('marketingDue.title')} />
      <p className="px-4 pt-2 text-2xs text-fg-3">{t('marketingDue.sub')}</p>
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading ? (
        <div className="flex flex-col gap-2 p-3">
          <Skeleton className="h-10 w-full" />
        </div>
      ) : !data?.length ? (
        <EmptyState line="phone" title={t('marketingDue.empty')} />
      ) : (
        <ul className="divide-y divide-glass-border">
          {data.map((d) => (
            <li key={d.device_id} className="flex items-center gap-3 px-4 py-2.5 text-sm">
              <Link to={`/customers/${d.customer_id}`} state={{ bg: location }} className="min-w-0 flex-1">
                <div className="truncate text-fg hover:text-accent">
                  <bdi>{d.customer_name}</bdi>
                </div>
                <div className="truncate text-2xs text-fg-3">
                  {d.brand} {d.model} · {f.date(d.delivered_at)}
                </div>
              </Link>
              <Button
                size="sm"
                variant="secondary"
                onClick={() =>
                  setTarget({
                    deviceId: d.device_id,
                    customerId: d.customer_id,
                    customerName: d.customer_name,
                    phone: d.phone,
                    orderNo: d.order_no,
                    device: `${d.brand} ${d.model}`,
                    status: 'delivered',
                    token: d.tracking_token,
                    cost: null,
                  })
                }
              >
                {t('marketingDue.send')}
              </Button>
            </li>
          ))}
        </ul>
      )}
      <WhatsAppDialog
        open={!!target}
        onOpenChange={(v) => {
          if (!v) {
            setTarget(null);
            reload();
          }
        }}
        target={target}
        initial="marketing"
      />
    </Panel>
  );
}
