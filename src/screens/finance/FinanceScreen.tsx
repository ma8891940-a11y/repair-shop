import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ArrowDownUp, Banknote, Boxes, CheckCircle2, HandCoins, Landmark, PiggyBank, Printer, Receipt, Scale, TrendingUp, Users, Wallet, type LucideIcon } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { rpc, sortCashboxes, useAccountName, type Position } from '../../app/ledgerApi';
import { OpDialog, type Op } from '../../app/finance/OpDialog';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { fillDaily } from '../../lib/ledger';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { CountUp, Sparkline } from '../../ui/viz';
import { DailyChart } from '../../ui/DailyChart';
import { Alert, EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { Button } from '../../ui/Button';
import { IntegrityAlert } from '../../app/IntegrityAlert';
import { cn } from '../../ui/cn';

const QUICK_OPS: { op: Op; icon: LucideIcon }[] = [
  { op: 'expense', icon: Receipt },
  { op: 'transfer', icon: ArrowDownUp },
  { op: 'salary', icon: Users },
  { op: 'salary_payment', icon: HandCoins },
  { op: 'advance', icon: Wallet },
  { op: 'capital', icon: PiggyBank },
  { op: 'drawing', icon: Banknote },
];

/** الوضع المالي (صاحب المحل بس): كل رقم بيتحسب من القيود وبيتفتح لتفاصيله */
export function FinanceScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const accName = useAccountName();
  const { period, range, set, query } = usePeriod();
  const [op, setOp] = useState<Op | null>(null);
  const cur = f.currency(shop.currency);

  const { data, error, loading, reload } = useLoad(async () => {
    const args = { p_from: range.from.toISOString(), p_to: range.to.toISOString() };
    const [p, daily] = await Promise.all([rpc<Position>('financial_position', args), rpc<{ cashbox: string; day: string; net: number }[]>('cashbox_daily', args)]);
    return { p, daily };
  }, [range.from.getTime(), range.to.getTime()]);
  useLiveRefresh(reload);

  const p = data?.p;
  const days = useMemo(() => (p ? fillDaily(range.days, p.daily, (day) => ({ day, revenue: 0, expenses: 0, profit: 0 })) : []), [p, range.days]);
  // رصيد كل خزنة في آخر كل يوم من الفترة (للـ sparkline): من الرصيد الحالي ورجوعًا
  const spark = useMemo(() => {
    const m = new Map<string, number[]>();
    if (!data) return m;
    for (const cb of data.p.cashboxes) {
      const net = new Map(data.daily.filter((x) => x.cashbox === cb.id).map((x) => [x.day.slice(0, 10), Number(x.net)]));
      const total = [...net.values()].reduce((a, b) => a + b, 0);
      let bal = cb.balance - total;
      m.set(cb.id, range.days.map((d) => (bal += net.get(d) ?? 0)));
    }
    return m;
  }, [data, range.days]);

  const money = (n: number) => f.money(n);
  const kpis: { key: string; value?: number; icon: LucideIcon; to: string; tone?: 'ok' | 'danger' }[] = [
    { key: 'cash', value: p?.cash, icon: Wallet, to: '#cashboxes' },
    { key: 'receivables', value: p?.receivables, icon: HandCoins, to: '/finance/balances/customers' },
    { key: 'payables', value: p?.payables, icon: Landmark, to: '/finance/balances/suppliers' },
    { key: 'inventory', value: p?.inventory, icon: Boxes, to: '/inventory' },
    { key: 'profit', value: p?.profit, icon: TrendingUp, to: `/finance/pl${query}`, tone: p && p.profit < 0 ? 'danger' : 'ok' },
    { key: 'net_worth', value: p?.net_worth, icon: Scale, to: '#equation' },
  ];

  return (
    <div>
      <PageHeader
        title={t('fin.title')}
        sub={t('fin.sub')}
        actions={
          <Link to={`/print/day/${range.days.at(-1)}`} className="inline-flex h-9 items-center gap-2 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg">
            <Printer className="size-4" aria-hidden /> {t('fin.dayReport')}
          </Link>
        }
      />
      <div className="mb-4">
        <PeriodFilter value={period} onChange={set} />
      </div>

      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : (
        <>
          {p && !p.balanced && (
            <Alert tone="danger" className="mb-4" title={t('fin.unbalancedTitle')}>
              <span data-testid="ledger-unbalanced">{t('fin.unbalancedText', { n: p.unbalanced_entries, d: f.money(p.debits), c: f.money(p.credits) })}</span>
            </Alert>
          )}
          <IntegrityAlert className="mb-4" />
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-6">
            {kpis.map((k, i) => (
              <motion.div key={k.key} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.22, delay: i * 0.04 }}>
                <Link
                  to={k.to}
                  onClick={(e) => {
                    if (k.to.startsWith('#')) {
                      e.preventDefault();
                      document.getElementById(k.to.slice(1))?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    }
                  }}
                  className="glass lift group block h-full rounded-lg p-4 focus-visible:outline-none"
                  data-testid={`kpi-${k.key}`}
                >
                  <div className="flex items-center justify-between">
                    <span className="readout-label">{t(`fin.kpi.${k.key}`)}</span>
                    <k.icon className={cn('size-4', k.tone === 'danger' ? 'text-danger' : k.tone === 'ok' ? 'text-ok' : 'text-fg-3')} aria-hidden />
                  </div>
                  <div className={cn('num mt-2 truncate text-xl font-semibold', k.tone === 'danger' ? 'text-danger' : 'text-fg')}>
                    {loading || k.value == null ? <Skeleton className="h-7 w-24" /> : <CountUp value={k.value} format={money} />}
                  </div>
                  <div className="mt-1 text-2xs text-fg-3">
                    {cur} · {t(`fin.kpiCap.${k.key}`)}
                  </div>
                </Link>
              </motion.div>
            ))}
          </div>

          {/* المعادلة */}
          <Panel id="equation" className="mt-4 scroll-mt-20 p-4">
            {loading || !p ? (
              <Skeleton className="h-16 w-full" />
            ) : (
              <>
                <div className="flex flex-wrap items-center gap-3" aria-label={t('fin.equation')}>
                  <EqTerm label={t('fin.eq.assets')} value={f.money(p.equation.assets)} />
                  <span className="text-lg text-fg-3">=</span>
                  <EqTerm label={t('fin.eq.liabilities')} value={f.money(p.equation.liabilities)} />
                  <span className="text-lg text-fg-3">+</span>
                  <EqTerm label={t('fin.eq.equity')} value={f.money(p.equation.equity)} />
                  <span className="text-lg text-fg-3">+</span>
                  <EqTerm label={t('fin.eq.earnings')} value={f.money(p.equation.earnings)} />
                  <div className="ms-auto">
                    {p.balanced ? (
                      <span className="inline-flex items-center gap-1.5 rounded-full border border-[color-mix(in_srgb,var(--ok)_45%,transparent)] px-3 py-1 text-sm font-medium text-ok" data-testid="ledger-balanced">
                        <CheckCircle2 className="size-4" aria-hidden /> {t('fin.balanced')}
                      </span>
                    ) : null}
                  </div>
                </div>
                {!p.balanced && <p className="mt-2 text-sm font-medium text-danger">{t('fin.unbalancedTitle')}</p>}
              </>
            )}
          </Panel>

          {/* حقوق الملكية: رأس مال صاحب المحل والشركاء والأرباح المحتجزة والسحوبات. دي مش ديون على المحل */}
          {p?.equity_parts && <EquityPanel p={p} money={money} cur={cur} />}

          {/* عمليات سريعة */}
          <div className="mt-4 flex flex-wrap gap-2">
            {QUICK_OPS.map(({ op: o, icon: I }) => (
              <Button key={o} size="sm" icon={<I className="size-4" />} onClick={() => setOp(o)}>
                {t(`fin.ops.${o}`)}
              </Button>
            ))}
          </div>

          {/* الخزن */}
          <section id="cashboxes" className="mt-4 scroll-mt-20">
            <h2 className="mb-2 text-sm font-semibold text-fg-2">{t('fin.cashboxes')}</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
              {loading || !p
                ? [0, 1, 2].map((k) => <Skeleton key={k} className="h-24 w-full" />)
                : sortCashboxes(p.cashboxes).map((cb) => (
                    <Link key={cb.id} to={`/finance/cashbox/${cb.id}${query}`} className="glass lift block rounded-lg p-3" data-testid="cashbox-card">
                      <div className="flex items-center justify-between gap-2">
                        <span className="truncate text-sm font-medium text-fg">{accName(cb)}</span>
                        <span className="text-2xs text-fg-3">{t(`payments.${cb.method}`, { defaultValue: cb.method })}</span>
                      </div>
                      <div className={cn('num mt-1 text-lg font-semibold', cb.balance < 0 ? 'text-danger' : 'text-fg')}>
                        <CountUp value={cb.balance} format={money} /> <span className="font-sans text-2xs font-normal text-fg-3">{cur}</span>
                      </div>
                      <Sparkline data={spark.get(cb.id) ?? []} height={28} className="mt-1" />
                    </Link>
                  ))}
            </div>
          </section>

          <div className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
            <Panel className="min-w-0">
              <PanelHeader title={t('fin.dailyChart')} />
              <div className="p-4">{loading || !p ? <Skeleton className="h-48 w-full" /> : <DailyChart data={days} />}</div>
            </Panel>
            <div className="flex min-w-0 flex-col gap-4">
              <TopList title={t('fin.topCustomers')} rows={p?.top_customers} loading={loading} kind="customer" empty={t('fin.noDebtors')} more="/finance/balances/customers" />
              <TopList title={t('fin.topSuppliers')} rows={p?.top_suppliers} loading={loading} kind="supplier" empty={t('fin.noCreditors')} more="/finance/balances/suppliers" />
            </div>
          </div>
        </>
      )}
      {op && <OpDialog op={op} open={!!op} onOpenChange={(v) => !v && setOp(null)} onDone={reload} />}
    </div>
  );
}

function EqTerm({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-glass-border bg-sunken/40 px-3 py-1.5">
      <div className="readout-label">{label}</div>
      <div className="num text-md text-fg">{value}</div>
    </div>
  );
}

function TopList({ title, rows, loading, kind, empty, more }: { title: string; rows?: { id: string; name: string; balance: number }[]; loading: boolean; kind: 'customer' | 'supplier'; empty: string; more: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  return (
    <Panel>
      <PanelHeader
        title={title}
        actions={
          <Link to={more} className="text-2xs text-fg-3 hover:text-accent">
            {t('common.all')}
          </Link>
        }
      />
      {loading || !rows ? (
        <div className="p-3">
          <Skeleton className="h-16 w-full" />
        </div>
      ) : rows.length === 0 ? (
        <EmptyState line="wallet" title={empty} />
      ) : (
        <ul className="divide-y divide-glass-border">
          {rows.map((r) => (
            <li key={r.id}>
              <Link to={`/finance/${kind}/${r.id}`} className="flex items-center justify-between gap-3 px-4 py-2 text-sm hover:bg-raised/50">
                <span className="truncate text-fg">
                  <bdi>{r.name}</bdi>
                </span>
                <span className="num text-fg-2">{f.money(r.balance)}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Panel>
  );
}

/** قسم "حقوق الملكية": كل جزء لوحده، والإجمالي، والمعادلة: الأصول = الالتزامات + حقوق الملكية */
function EquityPanel({ p, money, cur }: { p: Position; money: (n: number) => string; cur: string }) {
  const { t } = useTranslation();
  const e = p.equity_parts!;
  const partners = e.partners.map((x) => ({ ...x, capital: Number(x.capital), current: Number(x.current) }));
  const total = Number(e.owner_capital) - Number(e.drawings) + Number(e.retained) + partners.reduce((a, x) => a + x.capital + x.current, 0);
  const rows: { k: string; label: string; v: number; sub?: string; testid: string }[] = [
    { k: 'owner', label: t('equity.owner'), v: Number(e.owner_capital), testid: 'equity-owner' },
    ...partners.map((x) => ({ k: `p-${x.id}`, label: t('equity.partnerCapital', { name: x.name }), v: x.capital, testid: 'equity-partner' })),
    { k: 'retained', label: t('equity.retained'), v: Number(e.retained), sub: t('equity.retainedSub'), testid: 'equity-retained' },
    // جاري الشركاء كله (عشان السطور تجمع الإجمالي بالظبط): أرباح اتوزعت ولسه ما اتسحبتش (أو خسارة اتوزعت)
    { k: 'due', label: t('equity.partnersDue'), v: partners.reduce((a, x) => a + x.current, 0), sub: t('equity.partnersDueSub'), testid: 'equity-partners-due' },
    { k: 'drawings', label: t('equity.drawings'), v: -Number(e.drawings), testid: 'equity-drawings' },
  ].filter((r) => r.k === 'owner' || r.k === 'retained' || r.v !== 0 || r.k.startsWith('p-'));
  const assets = Number(p.equation.assets);
  const liab = Number(p.equation.liabilities);
  return (
    <Panel className="mt-4 p-4" data-testid="equity-panel">
      <h2 className="mb-1 text-sm font-semibold text-fg">{t('equity.title')}</h2>
      <p className="mb-3 text-xs text-fg-3">{t('equity.sub')}</p>
      <table className="w-full max-w-xl text-sm">
        <tbody className="divide-y divide-glass-border">
          {rows.map((r) => (
            <tr key={r.k} className="[&_td]:py-1.5" data-testid={r.testid}>
              <td>
                <div className="text-fg">{r.label}</div>
                {r.sub && <div className="text-2xs text-fg-3">{r.sub}</div>}
              </td>
              <td className={cn('num text-end', r.v < 0 ? 'text-danger' : 'text-fg')} dir="ltr">
                {money(r.v)}
              </td>
            </tr>
          ))}
          <tr className="font-semibold [&_td]:py-2">
            <td className="text-fg">{t('equity.total')}</td>
            <td className="num text-end text-accent" dir="ltr" data-testid="equity-total">
              {money(total)} <span className="font-sans text-2xs font-normal text-fg-3">{cur}</span>
            </td>
          </tr>
        </tbody>
      </table>
      <p className={cn('mt-3 text-xs', assets === liab + total ? 'text-ok' : 'text-danger')} data-testid="equity-equation">
        {t('equity.equation', { a: money(assets), l: money(liab), e: money(total) })}
      </p>
    </Panel>
  );
}
