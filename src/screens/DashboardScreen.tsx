import { Link, useNavigate } from 'react-router';
import { motion } from 'motion/react';
import { AlarmClock, ArrowLeft, CheckCheck, Inbox, PackagePlus, Wrench, type LucideIcon } from 'lucide-react';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { PageHeader } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { computeDashboard, isLate } from '../lib/dashboard';
import { daysSince, SHOP_TZ } from '../lib/dates';
import { formatPounds } from '../lib/money';
import { STATUSES, STATUS_LABELS, type DeviceStatus } from '../lib/status';
import type { DeviceListRow } from '../lib/types';
import { Button } from '../ui/Button';
import { Panel, PanelHeader } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { AnimatedNumber } from '../ui/AnimatedNumber';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

const todayFmt = new Intl.DateTimeFormat('ar-EG-u-nu-latn', { timeZone: SHOP_TZ, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

type Row = Pick<DeviceListRow, 'id' | 'order_no' | 'brand' | 'model' | 'status' | 'received_at' | 'delivered_at' | 'final_cost' | 'customer_name'>;

export function DashboardScreen() {
  const { profile } = useMe();
  const navigate = useNavigate();
  const owner = profile.role === 'owner';
  const front = profile.role !== 'technician';

  const { data, error, loading, reload } = useLoad(
    async () => {
      const since = new Date(Date.now() - 2 * 86_400_000).toISOString();
      const rows = must(
        await supabase
          .from('devices_list')
          .select('id, order_no, brand, model, status, received_at, delivered_at, final_cost, customer_name')
          .is('deleted_at', null)
          .or(`status.neq.delivered,delivered_at.gte."${since}"`)
          .order('received_at', { ascending: true })
          .limit(5000),
      ) as Row[];
      return rows;
    },
    [],
    { pollMs: 60_000 },
  );

  const now = new Date();
  const stats = data ? computeDashboard(data, now) : null;
  const active = (data ?? []).filter((d) => d.status !== 'delivered');
  const late = active.filter((d) => isLate(d, now)).slice(0, 6);
  const ready = active.filter((d) => d.status === 'ready').slice(0, 6);
  const dist = STATUSES.filter((s) => s !== 'delivered').map((s) => ({ s, n: active.filter((d) => d.status === s).length }));

  return (
    <div>
      <PageHeader
        title="لوحة التحكم"
        sub={todayFmt.format(now)}
        actions={
          front && (
            <Button variant="primary" icon={<PackagePlus className="size-4" />} shortcut="F2" tip="استلام جهاز جديد" onClick={() => navigate('/intake')}>
              استلام جهاز
            </Button>
          )
        }
      />

      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : (
        <>
          <div className={cn('grid gap-3', owner ? 'grid-cols-2 lg:grid-cols-5' : 'grid-cols-2 lg:grid-cols-4')}>
            <Readout i={0} label="أجهزة اليوم" icon={Inbox} value={stats?.today} to="/devices?filter=today" loading={loading} caption="اتسلّمت النهارده" />
            <Readout i={1} label="تحت الصيانة" icon={Wrench} value={stats?.underRepair} to="/devices?filter=under_repair" loading={loading} caption="جوه المحل دلوقتي" />
            <Readout i={2} label="جاهزة للاستلام" icon={CheckCheck} value={stats?.ready} to="/devices?status=ready" loading={loading} tone="ok" caption="مستنية العميل" />
            <Readout
              i={3}
              label="متأخرة"
              icon={AlarmClock}
              value={stats?.late}
              to="/devices?filter=late"
              loading={loading}
              tone={stats && stats.late > 0 ? 'danger' : undefined}
              caption="أكتر من 7 أيام"
            />
            {owner && (
              <Readout
                i={4}
                label="إيراد اليوم"
                value={stats?.revenueToday}
                loading={loading}
                money
                tone="accent"
                caption="التكلفة النهائية للأجهزة المسلّمة"
                className="col-span-2 lg:col-span-1"
              />
            )}
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1.25fr)_minmax(0,1fr)]">
            <Panel>
              <PanelHeader index="01" title="توزيع الأجهزة في المحل" actions={<span className="text-xs text-fg-3"><span className="num">{active.length}</span> جهاز</span>} />
              <div className="p-4">
                {loading ? (
                  <Skeleton className="h-3 w-full" />
                ) : active.length === 0 ? (
                  <EmptyState title="المحل فاضي" icon={<Inbox className="size-5" />}>
                    مفيش أجهزة جوه المحل دلوقتي.
                  </EmptyState>
                ) : (
                  <>
                    <div className="flex h-3 w-full gap-[2px] overflow-hidden rounded-full bg-sunken" role="img" aria-label="توزيع الحالات">
                      {dist
                        .filter((x) => x.n > 0)
                        .map((x, i) => (
                          <motion.div
                            key={x.s}
                            initial={{ scaleX: 0 }}
                            animate={{ scaleX: 1 }}
                            transition={{ duration: 0.4, delay: 0.05 * i, ease: [0.2, 0.8, 0.2, 1] }}
                            style={{ flexGrow: x.n, backgroundColor: `var(--st-${x.s})`, transformOrigin: 'right' }}
                            className="h-full first:rounded-s-full last:rounded-e-full"
                            title={`${STATUS_LABELS[x.s]}: ${x.n}`}
                          />
                        ))}
                    </div>
                    <ul className="mt-4 grid grid-cols-2 gap-x-6 gap-y-1.5 sm:grid-cols-3">
                      {dist.map((x) => (
                        <li key={x.s}>
                          <Link to={`/devices?status=${x.s}`} className="flex items-center gap-2 rounded-sm py-0.5 text-sm text-fg-2 hover:text-fg">
                            <span className="size-2 shrink-0 rounded-full" style={{ backgroundColor: `var(--st-${x.s})` }} aria-hidden />
                            <span className="flex-1 truncate">{STATUS_LABELS[x.s]}</span>
                            <span className={cn('num text-sm', x.n ? 'text-fg' : 'text-fg-3')}>{x.n}</span>
                          </Link>
                        </li>
                      ))}
                    </ul>
                  </>
                )}
              </div>
            </Panel>

            <DeviceMiniList
              index="02"
              title="متأخرة — الأقدم الأول"
              rows={late}
              loading={loading}
              showCustomer={front}
              empty="مفيش أجهزة متأخرة. كله ماشي في وقته."
              danger
              moreTo="/devices?filter=late"
            />
          </div>

          <div className="mt-4">
            <DeviceMiniList
              index="03"
              title="جاهزة ومستنية العميل"
              rows={ready}
              loading={loading}
              showCustomer={front}
              empty="مفيش أجهزة جاهزة دلوقتي."
              moreTo="/devices?status=ready"
            />
          </div>
        </>
      )}
    </div>
  );
}

function Readout({
  label,
  value,
  caption,
  icon: Icon,
  to,
  tone,
  money,
  loading,
  i,
  className,
}: {
  label: string;
  value: number | undefined;
  caption?: string;
  icon?: LucideIcon;
  to?: string;
  tone?: 'ok' | 'danger' | 'accent';
  money?: boolean;
  loading: boolean;
  i: number;
  className?: string;
}) {
  const toneText = tone === 'danger' ? 'text-danger' : tone === 'ok' ? 'text-ok' : tone === 'accent' ? 'text-accent' : 'text-fg';
  const body = (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.22, delay: i * 0.04, ease: [0.2, 0.8, 0.2, 1] }}
      className={cn(
        'group relative h-full overflow-hidden rounded-lg border border-line bg-surface p-4 shadow-1 transition-[border-color,background-color] duration-150',
        to && 'hover:border-line-strong hover:bg-raised',
        tone === 'danger' && 'border-[color-mix(in_srgb,var(--danger)_35%,var(--line))]',
      )}
    >
      <div className="flex items-center justify-between">
        <span className="readout-label">{label}</span>
        {Icon && <Icon className={cn('size-4', tone ? toneText : 'text-fg-3')} aria-hidden />}
      </div>
      <div className={cn('num mt-3 flex items-baseline gap-1.5 text-2xl font-medium', toneText)}>
        {loading || value === undefined ? (
          <Skeleton className="h-9 w-16" />
        ) : money ? (
          <>
            <AnimatedNumber value={value} format={(n) => formatPounds(n)} />
            <span className="font-sans text-sm text-fg-3">ج.م</span>
          </>
        ) : (
          <AnimatedNumber value={value} />
        )}
      </div>
      <div className="mt-2 flex items-center justify-between text-xs text-fg-3">
        <span>{caption}</span>
        {to && <ArrowLeft className="size-3.5 opacity-0 transition-opacity group-hover:opacity-100" aria-hidden />}
      </div>
      <div className="ruler absolute inset-x-4 bottom-0 opacity-50" aria-hidden />
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

function DeviceMiniList({
  index,
  title,
  rows,
  loading,
  showCustomer,
  empty,
  danger,
  moreTo,
}: {
  index: string;
  title: string;
  rows: Row[];
  loading: boolean;
  showCustomer: boolean;
  empty: string;
  danger?: boolean;
  moreTo: string;
}) {
  const now = new Date();
  return (
    <Panel className="flex min-w-0 flex-col">
      <PanelHeader
        index={index}
        title={title}
        actions={
          <Link to={moreTo} className="text-xs text-fg-3 hover:text-accent">
            عرض الكل
          </Link>
        }
      />
      {loading ? (
        <div className="flex flex-col gap-2 p-4">
          {[0, 1, 2].map((k) => (
            <Skeleton key={k} className="h-8 w-full" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <EmptyState title={empty} />
      ) : (
        <ul className="divide-y divide-line">
          {rows.map((d, i) => (
            <motion.li key={d.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.03, duration: 0.18 }}>
              <Link to={`/devices/${d.id}`} className="flex items-center gap-3 px-4 py-2.5 transition-colors hover:bg-raised">
                <span className="num w-[86px] shrink-0 text-sm text-fg" dir="ltr">
                  {d.order_no}
                </span>
                <span className="min-w-0 flex-1 truncate text-sm">
                  <span className="text-fg">
                    {d.brand} {d.model}
                  </span>
                  {showCustomer && d.customer_name && <span className="text-fg-3"> · {d.customer_name}</span>}
                </span>
                <span className="hidden shrink-0 sm:block">
                  <StatusBadge status={d.status as DeviceStatus} size="sm" />
                </span>
                <span className={cn('w-14 shrink-0 text-end text-xs', danger ? 'text-danger' : 'text-fg-3')}>
                  <span className="num">{daysSince(d.received_at, now)}</span> يوم
                </span>
              </Link>
            </motion.li>
          ))}
        </ul>
      )}
    </Panel>
  );
}
