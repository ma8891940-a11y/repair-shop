import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowDownRight, ArrowUpRight, Target, ThumbsDown, ThumbsUp } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { rpc } from '../app/ledgerApi';
import { useLoad } from '../app/useLoad';
import { useBranch } from '../app/branch';
import { useMe } from '../app/auth';
import { PeriodFilter, usePeriod } from '../app/finance/PeriodFilter';
import { ExportMenu } from '../app/exporting';
import { previousRange } from '../lib/financeSummary';
import { change, derive, insights, rank, toNum, total, type Insight, type Kpi } from '../lib/analytics';
import { parsePounds } from '../lib/money';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Input } from '../ui/Field';
import { ErrorState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';
import type { ExportTable } from '../lib/xlsx';
import { RepairInsights } from '../app/analytics/RepairInsights';

type Metric = 'revenue' | 'profit' | 'margin' | 'avgInvoice' | 'avgRepair' | 'returnRate' | 'expenseRatio' | 'turnover' | 'staleShare' | 'devices_in';
const METRICS: Metric[] = ['revenue', 'profit', 'margin', 'devices_in', 'avgInvoice', 'avgRepair', 'returnRate', 'expenseRatio', 'turnover', 'staleShare'];
// الأقل أحسن في دول (السهم الأخضر لما ينزلوا)
const LOWER_BETTER: Metric[] = ['avgRepair', 'returnRate', 'expenseRatio', 'staleShare'];

/**
 * U3: الأداء والتحليلات (صاحب المحل، أو اللي اتفتحله "التقارير"):
 * مؤشرات لكل فرع وللمجموع، ومقارنة بالأعمدة، وترتيب، والتغيّر عن الفترة اللي فاتت،
 * ونقاط القوة والضعف مكتوبة من الأرقام، والتوصيات، والأهداف الشهرية. كل حاجة بفلتر الفترة وبتتصدّر.
 */
export function AnalyticsScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const br = useBranch();
  const { profile } = useMe();
  const owner = profile.role === 'owner';
  const { period, range, set } = usePeriod();
  const [metric, setMetric] = useState<Metric>('revenue');
  const { data, error, reload } = useLoad(async () => {
    const prev = previousRange(period, new Date());
    const [cur, pv, stale] = await Promise.all([
      rpc<Record<string, unknown>[]>('branch_kpis', { p_from: range.from.toISOString(), p_to: range.to.toISOString() }),
      rpc<Record<string, unknown>[]>('branch_kpis', { p_from: prev.from.toISOString(), p_to: prev.to.toISOString() }),
      rpc<{ branch_id: string; item_id: string; name: string; qty: number; value: number; last_out: string | null }[]>('stale_items', { p_days: 60 }),
    ]);
    const c = cur.map(toNum);
    const p = pv.map(toNum);
    return { rows: c.map(derive), prev: new Map(p.map((x) => [x.branch_id, derive(x)])), all: total(c), allPrev: total(p), stale };
  }, [range.from.getTime(), range.to.getTime()]);
  useLiveRefresh(reload);
  const rows = useMemo(() => (data ? rank(data.rows) : []), [data]);
  const top = rows[0]?.branch_id;
  const fmt = (m: Metric, k: Kpi): string => {
    const v = k[m as keyof Kpi] as number | null;
    if (v == null) return t('common.none');
    if (m === 'revenue' || m === 'profit' || m === 'avgInvoice') return f.money(v);
    if (m === 'avgRepair') return t('analytics.hours', { n: f.number(Math.round(v / 60)) });
    if (m === 'turnover') return f.number(v / 100);
    if (m === 'devices_in') return f.number(v);
    return `${f.number(Math.round(v / 100))}%`;
  };
  const say = (i: Insight) => {
    const p = { ...i.params } as Record<string, string | number>;
    if (typeof p.amount === 'number') p.amount = f.money(p.amount);
    return t(`analytics.insights.${i.key}`, p);
  };
  const table = (): ExportTable | null | undefined =>
    data && {
      title: t('analytics.title'),
      meta: [t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) })],
      columns: [{ header: t('analytics.branch') }, ...METRICS.map((m) => ({ header: t(`analytics.m.${m}`) }))],
      rows: [...rows, data.all].map((k) => [k.branch_id === 'all' ? t('analytics.total') : br.name(k.branch_id), ...METRICS.map((m) => fmt(m, k))]),
    };
  const max = Math.max(1, ...rows.map((k) => Math.abs(Number(k[metric as keyof Kpi] ?? 0))));
  return (
    <div className="max-w-6xl" data-testid="analytics">
      <PageHeader title={t('analytics.title')} sub={t('analytics.sub')} actions={<ExportMenu table={table} testid="analytics-export" disabled={!data} />} />
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <PeriodFilter value={period} onChange={set} />
      </div>
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : !data ? (
        <Skeleton className="h-72" />
      ) : (
        <>
          {/* المجموع */}
          <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
            {(['revenue', 'profit', 'margin', 'avgInvoice', 'devices_in'] as const).map((m) => {
              const c = m === 'margin' ? null : change(Number(data.all[m] ?? 0), Number(data.allPrev[m] ?? 0));
              return (
                <Panel key={m} className="p-3" data-testid={`an-total-${m}`}>
                  <div className="readout-label">{t(`analytics.m.${m}`)}</div>
                  <div className="num mt-1 text-lg font-semibold text-fg">{fmt(m, data.all)}</div>
                  {c != null && <Delta v={c} better={!LOWER_BETTER.includes(m)} />}
                </Panel>
              );
            })}
          </div>

          {/* مقارنة الفروع */}
          {rows.length > 1 && (
            <Panel className="mt-4">
              <PanelHeader
                title={t('analytics.compare')}
                actions={
                  <select value={metric} onChange={(e) => setMetric(e.target.value as Metric)} aria-label={t('analytics.metric')} className="h-8 rounded-md border border-line bg-sunken/60 px-2 text-xs text-fg" data-testid="an-metric">
                    {METRICS.map((m) => (
                      <option key={m} value={m}>
                        {t(`analytics.m.${m}`)}
                      </option>
                    ))}
                  </select>
                }
              />
              <ul className="flex flex-col gap-2 p-3" data-testid="an-bars">
                {rows.map((k, i) => {
                  const v = Number(k[metric as keyof Kpi] ?? 0);
                  return (
                    <li key={k.branch_id} className="grid grid-cols-[24px_minmax(80px,160px)_1fr_auto] items-center gap-2 text-sm">
                      <span className="num text-center text-2xs text-fg-3">{f.number(i + 1)}</span>
                      <span className="truncate text-fg">
                        <bdi>{br.name(k.branch_id)}</bdi>
                      </span>
                      <span className="h-3 overflow-hidden rounded-full bg-sunken" aria-hidden>
                        <span className={cn('block h-full rounded-full', v < 0 ? 'bg-danger' : 'bg-accent')} style={{ width: `${Math.round((Math.abs(v) * 100) / max)}%` }} />
                      </span>
                      <span className="num text-end text-xs text-fg-2">{fmt(metric, k)}</span>
                    </li>
                  );
                })}
              </ul>
            </Panel>
          )}

          {/* كل فرع: المؤشرات، والقوة والضعف، والهدف */}
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {rows.map((k) => {
              const prev = data.prev.get(k.branch_id) ?? null;
              const list = insights(k, data.all, prev, { top: rows.length > 1 && k.branch_id === top });
              return (
                <Panel key={k.branch_id} className="p-3" data-testid="an-branch">
                  <div className="mb-2 flex items-center gap-2">
                    <span className="font-medium text-fg">
                      <bdi>{br.name(k.branch_id)}</bdi>
                    </span>
                    {rows.length > 1 && <span className="text-2xs text-fg-3">{t('analytics.rankN', { n: f.number(rows.indexOf(k) + 1), of: f.number(rows.length) })}</span>}
                  </div>
                  <dl className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs sm:grid-cols-3">
                    {METRICS.map((m) => {
                      const c = prev && m !== 'margin' && !LOWER_BETTER.includes(m) ? change(Number(k[m as keyof Kpi] ?? 0), Number(prev[m as keyof Kpi] ?? 0)) : null;
                      return (
                        <div key={m} className="flex flex-col" data-testid={`an-${m}`}>
                          <dt className="text-fg-3">{t(`analytics.m.${m}`)}</dt>
                          <dd className="num text-fg">
                            {fmt(m, k)} {c != null && <Delta v={c} better small />}
                          </dd>
                        </div>
                      );
                    })}
                  </dl>
                  <Goal k={k} owner={owner} month={range.from} onSaved={reload} />
                  {list.length > 0 && (
                    <ul className="mt-2 flex flex-col gap-1 text-xs" data-testid="an-insights">
                      {list.map((i) => (
                        <li key={i.key} className={cn('flex items-start gap-1.5', i.kind === 'strength' ? 'text-ok' : 'text-warn')} data-kind={i.kind}>
                          {i.kind === 'strength' ? <ThumbsUp className="mt-0.5 size-3.5 shrink-0" aria-hidden /> : <ThumbsDown className="mt-0.5 size-3.5 shrink-0" aria-hidden />}
                          <span>{say(i)}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                </Panel>
              );
            })}
          </div>

          {/* التوصيات */}
          <Panel className="mt-4">
            <PanelHeader title={t('analytics.recos')} />
            <ul className="flex flex-col divide-y divide-glass-border text-sm" data-testid="an-recos">
              {data.stale.slice(0, 8).map((s) => (
                <li key={`${s.branch_id}:${s.item_id}`} className="flex items-center gap-2 px-3 py-1.5">
                  <Link to="/inventory" className="min-w-0 flex-1 truncate hover:text-accent">
                    {t('analytics.staleReco', { name: s.name, days: f.number(s.last_out ? Math.floor((Date.now() - new Date(s.last_out).getTime()) / 86400_000) : 60) })}
                  </Link>
                  {br.multi && <span className="text-2xs text-fg-3">{br.name(s.branch_id)}</span>}
                  <span className="num text-xs text-fg-2">{f.money(Number(s.value))}</span>
                </li>
              ))}
              {data.all.receivables_60 > 0 && (
                <li className="px-3 py-1.5">
                  <Link to="/finance/balances/customers" className="hover:text-accent">
                    {t('analytics.debtReco', { amount: f.money(data.all.receivables_60) })}
                  </Link>
                </li>
              )}
              {!data.stale.length && data.all.receivables_60 <= 0 && <li className="px-3 py-2 text-xs text-fg-3">{t('analytics.noRecos')}</li>}
            </ul>
          </Panel>
          {/* C6: تحليلات الصيانة والمخزون */}
          <RepairInsights from={range.from} to={range.to} branch={br.filter} owner={owner} />
          <p className="mt-2 text-xs text-fg-3">{t('analytics.hint')}</p>
        </>
      )}
    </div>
  );
}

function Delta({ v, better, small }: { v: number; better: boolean; small?: boolean }) {
  const up = v >= 0;
  const good = up === better;
  const I = up ? ArrowUpRight : ArrowDownRight;
  return (
    <span className={cn('num inline-flex items-center gap-0.5', small ? 'text-2xs' : 'text-xs', good ? 'text-ok' : 'text-danger')}>
      <I className="size-3" aria-hidden />
      {Math.abs(Math.round(v / 100))}%
    </span>
  );
}

/** الهدف الشهري للفرع (الإيرادات) والتقدم. صاحب المحل بيحدده */
function Goal({ k, owner, month, onSaved }: { k: Kpi; owner: boolean; month: Date; onSaved: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [edit, setEdit] = useState(false);
  const [val, setVal] = useState('');
  const goal = k.goal_revenue;
  const pct = goal ? Math.min(100, Math.round((k.revenue * 100) / goal)) : 0;
  async function save() {
    const v = val.trim() ? parsePounds(val) : 0;
    if (v == null) return;
    try {
      await rpc('save_goal', { p_branch: k.branch_id, p_month: month.toISOString().slice(0, 10), p_metric: 'revenue', p_target: v });
      setEdit(false);
      onSaved();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  if (!goal && !owner) return null;
  return (
    <div className="mt-2 text-xs" data-testid="an-goal">
      {goal ? (
        <>
          <div className="flex items-center gap-1.5 text-fg-2">
            <Target className="size-3.5" aria-hidden /> {t('analytics.goal', { v: f.money(goal), pct: f.number(pct) })}
          </div>
          <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-sunken" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} aria-label={t('analytics.goalProgress')}>
            <div className={cn('h-full rounded-full', pct >= 100 ? 'bg-ok' : 'bg-accent')} style={{ width: `${pct}%` }} />
          </div>
        </>
      ) : null}
      {owner &&
        (edit ? (
          <div className="mt-1 flex items-center gap-1.5">
            <Input mono inputMode="decimal" value={val} onChange={(e) => setVal(e.target.value)} className="h-7 w-28" aria-label={t('analytics.goalSet')} data-testid="an-goal-input" />
            <Button size="sm" variant="primary" onClick={() => void save()} data-testid="an-goal-save">
              {t('common.save')}
            </Button>
          </div>
        ) : (
          <button type="button" onClick={() => { setVal(goal ? String(goal / 100) : ''); setEdit(true); }} className="mt-1 text-accent hover:underline" data-testid="an-goal-edit">
            {goal ? t('analytics.goalChange') : t('analytics.goalSet')}
          </button>
        ))}
    </div>
  );
}
