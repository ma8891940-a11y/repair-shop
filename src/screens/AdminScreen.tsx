import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Search } from 'lucide-react';
import { PageHeader } from '../app/AppShell';
import { useLoad } from '../app/useLoad';
import { rpc } from '../app/ledgerApi';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Input, Select } from '../ui/Field';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

interface ShopRow {
  id: string;
  name: string;
  created_at: string;
  plan: string;
  suspended: boolean;
  staff: number;
  devices: number;
  devices_month: number;
  last_activity: string | null;
  total: number;
}
const PAGE = 50;
interface ReportRow {
  post_id: string;
  body: string;
  author: string;
  shop: string;
  reports: number;
  hidden: boolean;
}

/** لوحة المشرف (صاحب المنصة بس): المحلات واستخدامها من غير أي بيانات عملاء، والخطط، والإيقاف، ومراجعة المجتمع */
export function AdminScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  // المحلات على صفحات (50 في المرة) وبحث بالاسم
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [pages, setPages] = useState(1);
  useEffect(() => {
    const tm = setTimeout(() => {
      setSearch(query.trim());
      setPages(1);
    }, 300);
    return () => clearTimeout(tm);
  }, [query]);
  const { data, error, loading, reload } = useLoad(async () => {
    const [shops, reports, plans] = await Promise.all([
      rpc<ShopRow[]>('admin_shops', { p_search: search || null, p_limit: PAGE * pages, p_offset: 0 }),
      rpc<ReportRow[]>('admin_reports'),
      supabase.from('plans').select('code').is('deleted_at', null).order('sort'),
    ]);
    return { shops, reports, plans: (plans.data ?? []).map((p) => p.code as string), total: shops[0]?.total ?? 0 };
  }, [search, pages]);
  async function run(fn: () => Promise<unknown>) {
    try {
      await fn();
      toast({ tone: 'ok', title: t('settings.saved') });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  if (error) return <ErrorState message={error} onRetry={reload} />;
  if (!data) return <Skeleton className="h-64 w-full" />;
  return (
    <div className="max-w-6xl">
      <PageHeader title={t('admin.title')} sub={t('admin.sub')} />
      <Panel className="mb-4 overflow-x-auto">
        <PanelHeader
          title={t('admin.shops', { n: data.total })}
          actions={
            <div className="relative w-56">
              <Search className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
              <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('admin.search')} aria-label={t('admin.search')} className="h-8 ps-8" />
            </div>
          }
        />
        <table className="w-full min-w-[760px] text-sm">
          <thead className="text-2xs text-fg-3">
            <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
              <th>{t('admin.shop')}</th>
              <th>{t('admin.plan')}</th>
              <th>{t('admin.staff')}</th>
              <th>{t('admin.devices')}</th>
              <th>{t('admin.month')}</th>
              <th>{t('admin.last')}</th>
              <th />
            </tr>
          </thead>
          <tbody className="divide-y divide-glass-border">
            {data.shops.map((s) => (
              <tr key={s.id} className={cn('[&_td]:px-3 [&_td]:py-2', s.suspended && 'text-fg-3')} data-testid="admin-shop">
                <td className="text-fg">
                  {s.name}
                  <div className="text-2xs text-fg-3">{f.date(s.created_at)}</div>
                </td>
                <td>
                  <Select aria-label={`${t('admin.plan')} ${s.name}`} value={s.plan} onChange={(e) => void run(() => rpc('admin_set_plan', { p_shop: s.id, p_plan: e.target.value }))} className="h-8 w-28">
                    {data.plans.map((p) => (
                      <option key={p} value={p}>
                        {t(`admin.plans.${p}`, { defaultValue: p })}
                      </option>
                    ))}
                  </Select>
                </td>
                <td className="num">{f.number(s.staff)}</td>
                <td className="num">{f.number(s.devices)}</td>
                <td className="num">{f.number(s.devices_month)}</td>
                <td className="text-xs text-fg-3">{s.last_activity ? f.dateTime(s.last_activity) : t('common.none')}</td>
                <td>
                  <Button size="sm" variant={s.suspended ? 'secondary' : 'ghost'} onClick={() => void run(() => rpc('admin_suspend', { p_shop: s.id, p_suspend: !s.suspended }))}>
                    {s.suspended ? t('admin.unsuspend') : t('admin.suspend')}
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {data.shops.length === 0 && <EmptyState line="scan" title={t('admin.noShops')} />}
        {data.shops.length < data.total && (
          <div className="flex items-center justify-center gap-3 border-t border-glass-border p-3 text-sm text-fg-3">
            <span>{t('admin.showing', { n: data.shops.length, total: data.total })}</span>
            <Button size="sm" loading={loading} onClick={() => setPages((n) => n + 1)}>
              {t('admin.more')}
            </Button>
          </div>
        )}
      </Panel>
      <Panel>
        <PanelHeader title={t('admin.reports')} />
        {data.reports.length === 0 ? (
          <EmptyState line="shield" title={t('admin.noReports')} />
        ) : (
          <ul className="divide-y divide-glass-border">
            {data.reports.map((r) => (
              <li key={r.post_id} className="flex flex-wrap items-start gap-3 px-4 py-3 text-sm">
                <div className="min-w-0 flex-1">
                  <p className="text-fg">{r.body}</p>
                  <div className="text-2xs text-fg-3">
                    {r.author} · {r.shop} · {t('admin.reportCount', { n: r.reports })}
                  </div>
                </div>
                <Button size="sm" variant={r.hidden ? 'secondary' : 'danger'} onClick={() => void run(() => rpc('admin_moderate', { p_post: r.post_id, p_hide: !r.hidden }))}>
                  {r.hidden ? t('admin.show') : t('admin.hide')}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </div>
  );
}
