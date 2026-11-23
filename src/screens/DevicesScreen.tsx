import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { PackagePlus, Search, X } from 'lucide-react';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
import { BranchTag } from '../app/BranchSwitcher';
import { StaleNote } from '../ui/StaleNote';
import { useLoad, must } from '../app/useLoad';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { buildSearchFilter } from '../lib/search';
import { STATUSES, UNDER_REPAIR, isStatus, type DeviceStatus } from '../lib/status';
import { isLate } from '../lib/dashboard';
import { cairoDay, daysSince } from '../lib/dates';
import type { DeviceListRow } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';
import { Panel } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Kbd } from '../ui/Kbd';
import { cn } from '../ui/cn';
import { ExportMenu } from '../app/exporting';
import type { ExportTable } from '../lib/xlsx';

const FILTERS = ['today', 'under_repair', 'late'] as const;

export function DevicesScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile } = useMe();
  const front = (profile.role === 'owner' || profile.role === 'reception');
  const navigate = useNavigate();
  const location = useLocation();
  const [params, setParams] = useSearchParams();
  const status = params.get('status') ?? '';
  const filter = params.get('filter') ?? '';
  const [q, setQ] = useState(params.get('q') ?? '');
  const [debounced, setDebounced] = useState(q);
  const [active, setActive] = useState(0);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const tm = setTimeout(() => setDebounced(q), 220);
    return () => clearTimeout(tm);
  }, [q]);

  const { data, error, loading, reload, stale } = useLoad(async () => {
    let query = supabase.from('devices_list').select('*').is('deleted_at', null).order('received_at', { ascending: false }).limit(500);
    const cols = front ? ['order_no', 'imei', 'customer_name', 'customer_phone', 'model', 'brand'] : ['order_no', 'imei', 'model', 'brand'];
    const sf = buildSearchFilter(debounced, cols);
    if (sf) query = query.or(sf);
    return must(await query) as DeviceListRow[];
  }, [debounced, front], { cacheKey: debounced ? undefined : `devices:${profile.id}` });
  useLiveRefresh(reload);

  const now = new Date();
  const br = useBranch();
  // B: الفرع المختار (والجهاز اللي في الطريق له)
  const all = useMemo(() => (data ?? []).filter((d) => !br.filter || d.branch_id === br.filter || d.transfer_to === br.filter), [data, br.filter]);
  const counts = useMemo(() => {
    const c: Record<string, number> = { all: all.length };
    for (const s of STATUSES) c[s] = 0;
    for (const d of all) c[d.status]++;
    return c;
  }, [all]);
  const rows = all.filter((d) => {
    if (isStatus(status) && d.status !== status) return false;
    if (filter === 'today' && cairoDay(d.received_at) !== cairoDay(now)) return false;
    if (filter === 'under_repair' && !UNDER_REPAIR.includes(d.status)) return false;
    if (filter === 'late' && !isLate(d, now)) return false;
    return true;
  });

  useEffect(() => setActive(0), [status, filter, debounced]);

  const setParam = (key: string, value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
  };
  const open = (id: string) => navigate(`/devices/${id}`, { state: { bg: location } });

  const onKey = (e: React.KeyboardEvent) => {
    if (!rows.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => Math.min(rows.length - 1, a + 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => Math.max(0, a - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      open(rows[active].id);
    }
  };

  const hasFilters = Boolean(status || filter || debounced);

  // التصدير: نفس الصفوف اللي ظاهرة (بالبحث والفلتر والترتيب)، ونفس الأعمدة. الفني من غير بيانات العميل
  const exportTable = (): ExportTable => ({
    title: t('devices.title'),
    meta: [
      isStatus(status) ? t('export.filter', { v: t(`status.${status}`) }) : '',
      filter ? t('export.filter', { v: t(`devices.filters.${filter}`) }) : '',
      debounced ? t('export.search', { v: debounced }) : '',
    ].filter(Boolean),
    columns: [
      { header: t('devices.cols.order') },
      ...(front ? [{ header: t('devices.cols.customer') }, { header: t('customers.cols.phone') }] : []),
      { header: t('devices.cols.device') },
      { header: t('devices.cols.imei') },
      { header: t('devices.cols.status') },
      { header: t('devices.cols.received'), type: 'datetime' as const },
      { header: t('devices.cols.age'), type: 'int' as const },
    ],
    rows: rows.map((d) => [d.order_no, ...(front ? [d.customer_name, d.customer_phone] : []), `${d.brand} ${d.model}`, d.imei, t(`status.${d.status}`), d.received_at, daysSince(d.received_at, now)]),
  });

  return (
    <div onKeyDown={onKey}>
      <PageHeader
        title={t('devices.title')}
        sub={t('devices.sub')}
        actions={
          <>
            <ExportMenu table={exportTable} testid="devices-export" disabled={!data} />
            {front && (
              <Button variant="primary" icon={<PackagePlus className="size-4" />} shortcut="Alt+2" tip={t('dashboard.newDeviceTip')} onClick={() => navigate('/intake')}>
                {t('dashboard.newDevice')}
              </Button>
            )}
          </>
        }
      />
      <StaleNote at={stale} />

      <Panel className="mb-3 p-3">
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative min-w-[220px] flex-1">
            <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
            <input
              ref={searchRef}
              autoFocus
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={front ? t('devices.search') : t('devices.searchTech')}
              aria-label={t('nav.search')}
              className="h-9 w-full rounded-md border border-line bg-sunken/60 pe-3 ps-9 text-sm text-fg placeholder:text-fg-3 focus:border-accent focus:shadow-[0_0_0_3px_var(--accent-soft)] focus:outline-none"
            />
          </div>
          {FILTERS.map((k) => (
            <button
              key={k}
              type="button"
              aria-pressed={filter === k}
              onClick={() => setParam('filter', filter === k ? '' : k)}
              className={cn(
                'h-8 rounded-full border px-3 text-xs font-medium transition-colors',
                filter === k ? 'border-[rgb(var(--accent-rgb)/0.5)] bg-accent-soft text-accent' : 'border-line text-fg-2 hover:border-line-strong hover:text-fg',
              )}
            >
              {t(`devices.filters.${k}`)}
            </button>
          ))}
          {hasFilters && (
            <Button
              variant="ghost"
              size="sm"
              icon={<X className="size-3.5" />}
              onClick={() => {
                setQ('');
                setParams(new URLSearchParams(), { replace: true });
              }}
            >
              {t('devices.clear')}
            </Button>
          )}
        </div>
        <div className="-mx-1 mt-2.5 flex gap-1 overflow-x-auto px-1 pb-0.5" role="tablist" aria-label={t('devices.cols.status')}>
          {(['', ...STATUSES] as const).map((s) => {
            const on = status === s;
            const n = s ? counts[s] : counts.all;
            return (
              <button
                key={s || 'all'}
                type="button"
                role="tab"
                aria-selected={on}
                onClick={() => setParam('status', s)}
                className={cn('relative flex h-7 shrink-0 items-center gap-1.5 rounded-sm px-2.5 text-xs transition-colors', on ? 'text-fg' : 'text-fg-3 hover:text-fg')}
              >
                {on && <motion.span layoutId="status-tab" className="absolute inset-0 rounded-sm border border-glass-border-strong bg-raised" transition={{ duration: 0.18 }} />}
                {s && <span className="relative size-1.5 rounded-full" style={{ backgroundColor: `var(--st-${s})` }} aria-hidden />}
                <span className="relative">{s ? t(`status.${s}`) : t('devices.all')}</span>
                <span className="num relative text-2xs text-fg-3">{f.number(n ?? 0)}</span>
              </button>
            );
          })}
        </div>
      </Panel>

      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading ? (
        <Panel className="flex flex-col gap-2 p-3">
          {[0, 1, 2, 3, 4, 5].map((k) => (
            <Skeleton key={k} className="h-11 w-full rounded-md" />
          ))}
        </Panel>
      ) : rows.length === 0 ? (
        <Panel>
          {all.length === 0 && !debounced ? (
            <EmptyState
              line="phone"
              title={t('devices.emptyShop')}
              action={
                front && (
                  <Button variant="primary" size="sm" onClick={() => navigate('/intake')}>
                    {t('dashboard.newDevice')}
                  </Button>
                )
              }
            >
              {t('devices.emptyShopText')}
            </EmptyState>
          ) : (
            <EmptyState line="scan" title={t('devices.empty')}>
              {t('devices.emptyText')}
            </EmptyState>
          )}
        </Panel>
      ) : (
        <>
          <div className="mb-2 flex items-center justify-between px-1 text-xs text-fg-3">
            <span>{t('devices.count', { n: f.number(rows.length) })}</span>
            <span className="hidden items-center gap-1 md:flex">
              <Kbd>↑</Kbd>
              <Kbd>↓</Kbd>
              <Kbd>Enter</Kbd>
            </span>
          </div>
          {/* كمبيوتر: جدول مضغوط */}
          <Panel className="hidden overflow-hidden md:block">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-glass-border text-start text-xs text-fg-3">
                  <th className="px-4 py-2.5 text-start font-medium">{t('devices.cols.order')}</th>
                  {front && <th className="px-3 py-2.5 text-start font-medium">{t('devices.cols.customer')}</th>}
                  <th className="px-3 py-2.5 text-start font-medium">{t('devices.cols.device')}</th>
                  <th className="px-3 py-2.5 text-start font-medium">{t('devices.cols.imei')}</th>
                  <th className="px-3 py-2.5 text-start font-medium">{t('devices.cols.status')}</th>
                  <th className="px-3 py-2.5 text-start font-medium">{t('devices.cols.received')}</th>
                  <th className="px-4 py-2.5 text-end font-medium">{t('devices.cols.age')}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((d, i) => {
                  const late = isLate(d, now);
                  return (
                    <tr
                      key={d.id}
                      onClick={() => open(d.id)}
                      onMouseEnter={() => setActive(i)}
                      aria-selected={active === i}
                      className={cn('cursor-pointer border-b border-glass-border transition-colors last:border-0', active === i ? 'bg-accent-soft' : 'hover:bg-raised/50')}
                    >
                      <td className="relative px-4 py-2.5">
                        {late && <span className="absolute inset-y-1.5 start-0 w-[3px] rounded-full bg-danger" aria-hidden />}
                        <Link to={`/devices/${d.id}`} state={{ bg: location }} className="num text-fg" dir="ltr" onClick={(e) => e.stopPropagation()}>
                          {d.order_no}
                        </Link>
                        <DeviceBranchNote d={d} />
                      </td>
                      {front && (
                        <td className="px-3 py-2.5">
                          <bdi className="text-fg">{d.customer_name}</bdi>
                          <div className="num text-2xs text-fg-3" dir="ltr">
                            {d.customer_phone}
                          </div>
                        </td>
                      )}
                      <td className="px-3 py-2.5 text-fg">
                        {d.brand} {d.model}
                      </td>
                      <td className="num px-3 py-2.5 text-xs text-fg-2" dir="ltr">
                        {d.imei ?? ''}
                      </td>
                      <td className="px-3 py-2.5">
                        <StatusBadge status={d.status as DeviceStatus} size="sm" />
                      </td>
                      <td className="px-3 py-2.5 text-xs text-fg-2">{f.date(d.received_at)}</td>
                      <td className={cn('px-4 py-2.5 text-end text-xs', late ? 'font-medium text-danger' : 'text-fg-3')}>{f.days(daysSince(d.received_at, now))}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </Panel>
          {/* موبايل: كروت */}
          <ul className="flex flex-col gap-2 md:hidden">
            {rows.map((d) => (
              <li key={d.id}>
                <Link to={`/devices/${d.id}`} state={{ bg: location }} className="glass lift block rounded-lg p-3">
                  <div className="flex items-center justify-between gap-2">
                    <span className="num text-sm text-fg" dir="ltr">
                      {d.order_no}
                    </span>
                    <StatusBadge status={d.status as DeviceStatus} size="sm" />
                  </div>
                  <DeviceBranchNote d={d} />
                  <div className="mt-1.5 break-words text-sm text-fg">
                    {d.brand} {d.model}
                    {front && d.customer_name && (
                      <span className="text-fg-3">
                        {' · '}
                        <bdi>{d.customer_name}</bdi>
                      </span>
                    )}
                  </div>
                  <div className={cn('mt-1 text-xs', isLate(d, now) ? 'text-danger' : 'text-fg-3')}>{f.days(daysSince(d.received_at, now))}</div>
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}

/** B: فرع الجهاز (لما العرض "كل الفروع")، و"في الطريق لـ ..." */
function DeviceBranchNote({ d }: { d: { branch_id?: string; transfer_to?: string | null } }) {
  const { t } = useTranslation();
  const br = useBranch();
  if (!br.multi) return null;
  return (
    <div className="mt-0.5 flex flex-wrap gap-1">
      {br.view === 'all' && <BranchTag id={d.branch_id} />}
      {d.transfer_to && (
        <span className="rounded-sm border border-[color-mix(in_srgb,var(--warn)_40%,transparent)] px-1.5 py-px text-2xs text-warn" data-testid="device-in-transit">
          {t('branch.inTransit', { name: br.name(d.transfer_to) })}
        </span>
      )}
    </div>
  );
}
