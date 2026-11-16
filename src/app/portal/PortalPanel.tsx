import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Copy, Store } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { appBase } from '../../lib/publicUrl';
import { waLink } from '../../lib/messages';
import { useMe } from '../auth';
import { useBranch } from '../branch';
import { useLoad } from '../useLoad';
import { rpc } from '../ledgerApi';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Input, Select } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

export function portalUrl(base: string, token: string): string {
  return `${base.replace(/#.*$/, '').replace(/\/$/, '')}/#/w/${token}`;
}
interface Order {
  id: string;
  created_at: string;
  status: 'new' | 'seen' | 'done' | 'cancelled';
  note: string | null;
  lines: { item: string; name: string; qty: number }[];
}

/** C8: بوابة عميل الجملة في ملف العميل: فتح وقفل الرابط، وإرساله على واتساب، والطلبيات اللي بعتها وحالتها */
export function PortalPanel({ customerId, phone }: { customerId: string; phone: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const { shop, profile } = useMe();
  const br = useBranch();
  // صاحب المحل في محل فروع: البوابة لفرع معيّن (كشف حساب الفرع وطلبياته) أو لكل الفروع. الموظف: فرعه بس (من القاعدة)
  const [branch, setBranch] = useState<string>(br.filter ?? '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const { data, reload } = useLoad(async () => {
    const [c, o] = await Promise.all([
      supabase.from('customers').select('portal_token, portal_branch').eq('id', customerId).maybeSingle(),
      supabase.from('wholesale_orders').select('id, created_at, status, note, lines').eq('customer_id', customerId).is('deleted_at', null).order('created_at', { ascending: false }).limit(20),
    ]);
    const row = c.data as { portal_token: string | null; portal_branch: string | null } | null;
    return { token: row?.portal_token ?? null, branch: row?.portal_branch ?? null, orders: (o.data ?? []) as Order[] };
  }, [customerId]);
  const url = data?.token ? portalUrl(appBase(shop.extras, window.location.href), data.token) : null;
  async function toggle(on: boolean) {
    setErr(null);
    setBusy(true);
    try {
      await rpc('set_portal', { p_customer: customerId, p_on: on, p_branch: branch || null });
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function setStatus(o: Order, status: Order['status']) {
    const { error } = await supabase.from('wholesale_orders').update({ status }).eq('id', o.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    reload();
  }
  const wa = url ? waLink(phone, t('portal.waText', { shop: shop.name, link: url })) : null;
  return (
    <Panel className="mb-4" data-testid="portal-panel">
      <PanelHeader title={t('portal.title')} actions={data && data.orders.some((o) => o.status === 'new') && <span className="rounded-sm bg-accent-soft px-1.5 py-0.5 text-2xs text-accent">{t('portal.newOrders', { n: data.orders.filter((o) => o.status === 'new').length })}</span>} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('portal.hint')}</p>
        {!data ? (
          <Skeleton className="h-16 w-full" />
        ) : url ? (
          <div className="flex flex-wrap items-center gap-2">
            {br.multi && <span className="w-full text-xs text-fg-2" data-testid="portal-branch">{data.branch ? br.name(data.branch) : t('portal.allBranches')}</span>}
            <Input readOnly value={url} dir="ltr" className="min-w-0 flex-1 text-xs" aria-label={t('portal.link')} data-testid="portal-link" />
            <Button size="sm" onClick={() => void navigator.clipboard?.writeText(url).then(() => toast({ tone: 'ok', title: t('catalog.copied') }))} icon={<Copy className="size-3.5" />}>
              {t('catalog.copy')}
            </Button>
            {wa && (
              <a href={wa} target="_blank" rel="noopener noreferrer" className="inline-flex h-8 items-center rounded-md border border-line px-3 text-xs text-fg-2 hover:text-fg">
                {t('portal.sendWa')}
              </a>
            )}
            <Button size="sm" variant="ghost" loading={busy} onClick={() => void toggle(false)} data-testid="portal-off">
              {t('portal.off')}
            </Button>
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            {br.multi && profile.role === 'owner' && (
              <Select value={branch} onChange={(e) => setBranch(e.target.value)} className="h-9 w-auto text-sm" aria-label={t('portal.branch')} data-testid="portal-branch-pick">
                <option value="">{t('portal.allBranches')}</option>
                {br.all.map((x) => (
                  <option key={x.id} value={x.id}>
                    {x.name}
                  </option>
                ))}
              </Select>
            )}
            <Button variant="secondary" loading={busy} onClick={() => void toggle(true)} icon={<Store className="size-4" />} data-testid="portal-on">
              {t('portal.on')}
            </Button>
          </div>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
        {data && data.orders.length > 0 && (
          <ul className="divide-y divide-line rounded-md border border-line" data-testid="portal-orders">
            {data.orders.map((o) => (
              <li key={o.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm" data-testid="portal-order">
                <span className="text-2xs text-fg-3">{f.dateTime(o.created_at)}</span>
                <span className="min-w-0 flex-1 text-fg">
                  {o.lines.map((l) => `${l.name} × ${l.qty}`).join(t('common.sep'))}
                  {o.note && <span className="block text-2xs text-fg-3">{o.note}</span>}
                </span>
                <Select value={o.status} onChange={(e) => void setStatus(o, e.target.value as Order['status'])} className="h-7 text-xs" aria-label={t('portal.status')}>
                  {(['new', 'seen', 'done', 'cancelled'] as const).map((s) => (
                    <option key={s} value={s}>
                      {t(`portal.s.${s}`)}
                    </option>
                  ))}
                </Select>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Panel>
  );
}
