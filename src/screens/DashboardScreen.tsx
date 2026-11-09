import { Link, useLocation, useNavigate } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { AlarmClock, ArrowRight, CheckCheck, Inbox, PackagePlus, TrendingUp, Wallet, Wrench, type LucideIcon } from 'lucide-react';
import { useMe } from '../app/auth';
import { StaleNote } from '../ui/StaleNote';
import { useLoad, must } from '../app/useLoad';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { DaySummaryButton } from '../app/DaySummaryButton';
import { supabase } from '../lib/supabase';
import { rpc, type Position } from '../app/ledgerApi';
import { cairoDay, cairoDayEnd, cairoDayStart } from '../lib/dates';
import { computeDashboard, computeSeries, isLate, type StatusEvent } from '../lib/dashboard';
import { daysSince } from '../lib/dates';
import { STATUSES, type DeviceStatus } from '../lib/status';
import type { DeviceListRow } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';
import { Panel, PanelHeader } from '../ui/Panel';
import { FollowUpPanel } from '../app/FollowUpPanel';
import { MarketingPanel } from '../app/MarketingPanel';
import { OwnerAlerts } from '../app/OwnerAlerts';
import { IntegrityAlert } from '../app/IntegrityAlert';
import { OpeningCard } from '../app/OpeningCard';
import { StatusBadge } from '../ui/StatusBadge';
import { CountUp, Ring, Sparkline } from '../ui/viz';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

type Row = Pick<DeviceListRow, 'id' | 'order_no' | 'brand' | 'model' | 'status' | 'received_at' | 'delivered_at' | 'final_cost' | 'customer_name'>;

export function DashboardScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const navigate = useNavigate();
  const owner = profile.role === 'owner';
  const front = (profile.role === 'owner' || profile.role === 'reception');

  // ربح اليوم (صاحب المحل بس): من الدفتر نفسه = إيرادات اليوم − مصروفاته (ومنها تكلفة القطع)
  const profit = useLoad(async () => {
    if (profile.role !== 'owner') return null;
    const day = cairoDay(new Date());
    return rpc<Position>('financial_position', { p_from: cairoDayStart(day).toISOString(), p_to: cairoDayEnd(day).toISOString() });
  }, [profile.role]);
  const { data, error, loading, reload, stale } = useLoad(
    async () => {
      const since = new Date(Date.now() - 14 * 86_400_000).toISOString();
      const [rows, events] = await Promise.all([
        supabase
          .from('devices_list')
          .select('id, order_no, brand, model, status, received_at, delivered_at, final_cost, customer_name')
          .is('deleted_at', null)
          .or(`status.neq.delivered,delivered_at.gte."${since}"`)
          .order('received_at', { ascending: true })
          .limit(5000),
        supabase.from('status_log').select('new_status, created_at').eq('new_status', 'ready').gte('created_at', since).limit(5000),
      ]);
      return { rows: must(rows) as Row[], events: must(events) as StatusEvent[] };
    },
    [],
    { pollMs: 120_000, cacheKey: `dashboard:${profile.id}` },
  );

  // تحديث لحظي: أي تغيير في الأجهزة أو الأسعار أو الحالات بيحدّث اللوحة
  useLiveRefresh(reload);
  useLiveRefresh(profit.reload);

  const now = new Date();
  const rows = data?.rows ?? [];
  const stats = data ? computeDashboard(rows, now) : null;
  const series = data ? computeSeries(rows, data.events, now) : null;
  const active = rows.filter((d) => d.status !== 'delivered');
  const late = active.filter((d) => isLate(d, now)).slice(0, 6);
  const ready = active.filter((d) => d.status === 'ready').slice(0, 6);
  const segments = STATUSES.filter((s) => s !== 'delivered').map((s) => ({ key: s, value: active.filter((d) => d.status === s).length, color: `var(--st-${s})`, label: t(`status.${s}`) }));

  return (
    <div>
      <PageHeader
        title={t('dashboard.title')}
        sub={f.dateLong(now)}
        actions={
          front && (
            <div className="flex flex-wrap gap-2">
              <DaySummaryButton />
              <Button variant="primary" icon={<PackagePlus className="size-4" />} shortcut="F2" tip={t('dashboard.newDeviceTip')} onClick={() => navigate('/intake')}>
                {t('dashboard.newDevice')}
              </Button>
            </div>
          )
        }
      />
      <StaleNote at={stale} />

      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : (
        <>
          {owner && <IntegrityAlert className="mb-4" />}
          {owner && <OpeningCard />}
          {owner && <OwnerAlerts />}
          <div className={cn('grid gap-3', owner ? 'grid-cols-2 lg:grid-cols-6' : 'grid-cols-2 lg:grid-cols-4')}>
            <Kpi i={0} label={t('dashboard.today')} caption={t('dashboard.todayCap')} icon={Inbox} value={stats?.today} series={series?.today} to="/devices?filter=today" loading={loading} />
            <Kpi i={1} label={t('dashboard.under')} caption={t('dashboard.underCap')} icon={Wrench} value={stats?.underRepair} series={series?.underRepair} to="/devices?filter=under_repair" loading={loading} />
            <Kpi i={2} label={t('dashboard.ready')} caption={t('dashboard.readyCap')} icon={CheckCheck} value={stats?.ready} series={series?.ready} to="/devices?status=ready" loading={loading} tone="ok" />
            <Kpi i={3} label={t('dashboard.late')} caption={t('dashboard.lateCap')} icon={AlarmClock} value={stats?.late} series={series?.late} to="/devices?filter=late" loading={loading} tone={stats && stats.late > 0 ? 'danger' : undefined} />
            {owner && (
              <Kpi
                i={4}
                label={t('dashboard.revenue')}
                caption={t('dashboard.revenueCap')}
                icon={Wallet}
                value={stats?.revenueToday}
                series={series?.revenue}
                loading={loading}
                tone="accent"
                format={(n) => f.money(n)}
                unit={f.currency(shop.currency)}
              />
            )}
            {owner && (
              <Kpi
                i={5}
                label={t('dashboard.profit')}
                caption={t('dashboard.profitCap')}
                icon={TrendingUp}
                value={profit.data?.profit}
                loading={profit.loading}
                tone={profit.data && profit.data.profit < 0 ? 'danger' : 'ok'}
                format={(n) => f.money(n)}
                unit={f.currency(shop.currency)}
                to="/finance"
              />
            )}
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
            <Panel className="min-w-0">
              <PanelHeader index="01" title={t('dashboard.dist')} actions={<span className="text-xs text-fg-3">{t('units.devices', { n: f.number(active.length) })}</span>} />
              <div className="p-5">
                {loading ? (
                  <div className="flex items-center gap-6">
                    <Skeleton className="size-[180px] rounded-full" />
                    <div className="flex flex-1 flex-col gap-2">
                      {[0, 1, 2, 3].map((k) => (
                        <Skeleton key={k} className="h-4 w-full" />
                      ))}
                    </div>
                  </div>
                ) : active.length === 0 ? (
                  <EmptyState line="phone" title={t('dashboard.emptyShop')}>
                    {t('dashboard.emptyShopText')}
                  </EmptyState>
                ) : (
                  <div className="flex flex-col items-center gap-6 sm:flex-row sm:items-center">
                    <Ring
                      segments={segments}
                      label={segments.map((x) => `${x.label}: ${f.number(x.value)}`).join(t('common.sep'))}
                      center={(a) => (
                        <div>
                          <div className="num text-3xl font-medium text-fg">{f.number(a ? a.value : active.length)}</div>
                          <div className="mt-0.5 max-w-[110px] text-2xs text-fg-3">{a ? a.label : t('dashboard.inShop')}</div>
                        </div>
                      )}
                    />
                    <ul className="grid w-full flex-1 grid-cols-1 gap-x-5 gap-y-1 sm:grid-cols-1 xl:grid-cols-2">
                      {segments.map((x) => (
                        <li key={x.key}>
                          <Link to={`/devices?status=${x.key}`} className="flex items-center gap-2 rounded-sm px-1 py-1 text-sm text-fg-2 transition-colors hover:bg-raised/60 hover:text-fg">
                            <span className="size-2 shrink-0 rounded-full" style={{ backgroundColor: x.color, boxShadow: x.value ? `0 0 6px ${x.color}` : undefined }} aria-hidden />
                            <span className="flex-1 truncate">{x.label}</span>
                            <span className={cn('num text-sm', x.value ? 'text-fg' : 'text-fg-3')}>{f.number(x.value)}</span>
                          </Link>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            </Panel>

            <DeviceList index="02" title={t('dashboard.lateList')} rows={late} loading={loading} showCustomer={front} empty={t('dashboard.lateEmpty')} danger moreTo="/devices?filter=late" />
          </div>

          <div className={front ? 'mt-4 grid gap-4 lg:grid-cols-2' : 'mt-4'}>
            <DeviceList index="03" title={t('dashboard.readyList')} rows={ready} loading={loading} showCustomer={front} empty={t('dashboard.readyEmpty')} moreTo="/devices?status=ready" />
            {front && <FollowUpPanel />}
            {front && <MarketingPanel />}
          </div>
        </>
      )}
    </div>
  );
}

function Kpi({
  label,
  caption,
  value,
  series,
  icon: Icon,
  to,
  tone,
  loading,
  i,
  format,
  unit,
  className,
}: {
  label: string;
  caption: string;
  value: number | undefined;
  series?: number[];
  icon: LucideIcon;
  to?: string;
  tone?: 'ok' | 'danger' | 'accent';
  loading: boolean;
  i: number;
  format?: (n: number) => string;
  unit?: string;
  className?: string;
}) {
  const f = useFormat();
  const toneText = tone === 'danger' ? 'text-danger' : tone === 'ok' ? 'text-ok' : tone === 'accent' ? 'text-accent' : 'text-fg';
  const line = tone === 'danger' ? 'var(--danger)' : tone === 'ok' ? 'var(--ok)' : 'var(--accent)';
  const body = (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.26, delay: i * 0.05, ease: [0.2, 0.8, 0.2, 1] }}
      className={cn('glass lift group relative h-full overflow-hidden rounded-lg p-4', tone === 'danger' && 'border-[color-mix(in_srgb,var(--danger)_35%,var(--glass-border))]')}
    >
      <div className="flex items-center justify-between">
        <span className="readout-label">{label}</span>
        <span className={cn('grid size-7 place-items-center rounded-md border border-glass-border bg-sunken/50', tone ? toneText : 'text-fg-3')}>
          <Icon className="size-3.5" aria-hidden />
        </span>
      </div>
      <div className={cn('num mt-2 flex items-baseline gap-1.5 text-2xl font-medium', toneText, tone === 'accent' && 'text-glow')}>
        {loading || value === undefined ? (
          <Skeleton className="h-9 w-16" />
        ) : (
          <>
            <CountUp value={value} format={format ?? ((n) => f.number(n))} />
            {unit && <span className="font-sans text-sm text-fg-3">{unit}</span>}
          </>
        )}
      </div>
      <div className="mt-2 -mx-1">{series && !loading ? <Sparkline data={series} color={line} /> : <div className="h-8" />}</div>
      <div className="mt-1 flex items-center justify-between text-xs text-fg-3">
        <span className="truncate">{caption}</span>
        {to && <ArrowRight className="size-3.5 opacity-0 transition-opacity group-hover:opacity-100 rtl:-scale-x-100" aria-hidden />}
      </div>
    </motion.div>
  );
  return to ? (
    <Link to={to} className={cn('block rounded-lg', className)} aria-label={`${label}: ${value ?? ''}`}>
      {body}
    </Link>
  ) : (
    <div className={className}>{body}</div>
  );
}

function DeviceList({ index, title, rows, loading, showCustomer, empty, danger, moreTo }: { index: string; title: string; rows: Row[]; loading: boolean; showCustomer: boolean; empty: string; danger?: boolean; moreTo: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const location = useLocation();
  const now = new Date();
  return (
    <Panel className="flex min-w-0 flex-col">
      <PanelHeader
        index={index}
        title={title}
        actions={
          <Link to={moreTo} className="text-xs text-fg-3 hover:text-accent">
            {t('common.viewAll')}
          </Link>
        }
      />
      {loading ? (
        <div className="flex flex-col gap-2 p-3">
          {[0, 1, 2].map((k) => (
            <Skeleton key={k} className="h-12 w-full rounded-md" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <EmptyState line={danger ? 'shield' : 'receipt'} title={empty} />
      ) : (
        <ul className="flex flex-col gap-1.5 p-2.5">
          {rows.map((d, i) => (
            <motion.li key={d.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.04 * i, duration: 0.2 }}>
              <Link to={`/devices/${d.id}`} state={{ bg: location }} className="block rounded-md">
                <motion.div layoutId={`device-card-${d.id}`} className="lift flex items-center gap-3 rounded-md border border-glass-border bg-sunken/40 px-3 py-2.5" transition={{ duration: 0.28, ease: [0.2, 0.8, 0.2, 1] }}>
                  <motion.span layoutId={`device-order-${d.id}`} className="num w-[86px] shrink-0 text-sm text-fg" dir="ltr">
                    {d.order_no}
                  </motion.span>
                  <span className="min-w-0 flex-1 truncate text-sm">
                    <span className="text-fg">
                      {d.brand} {d.model}
                    </span>
                    {showCustomer && d.customer_name && (
                      <span className="text-fg-3">
                        {' · '}
                        <bdi>{d.customer_name}</bdi>
                      </span>
                    )}
                  </span>
                  <span className="hidden shrink-0 sm:block">
                    <StatusBadge status={d.status as DeviceStatus} size="sm" />
                  </span>
                  <span className={cn('w-16 shrink-0 text-end text-xs', danger ? 'text-danger' : 'text-fg-3')}>{f.days(daysSince(d.received_at, now))}</span>
                </motion.div>
              </Link>
            </motion.li>
          ))}
        </ul>
      )}
    </Panel>
  );
}
