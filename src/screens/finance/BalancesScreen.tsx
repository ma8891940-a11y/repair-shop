import { Link, useNavigate, useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { rpc, useAccountName } from '../../app/ledgerApi';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

type BalKind = 'customers' | 'suppliers' | 'employees';
interface Row {
  party_type: 'customer' | 'supplier' | 'employee';
  party_id: string;
  name: string | null;
  account: string;
  balance: number;
}

function Back() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { query } = usePeriod();
  return (
    <button type="button" onClick={() => navigate(`/finance${query}`)} className="mb-3 inline-flex items-center gap-1.5 text-sm text-fg-3 hover:text-fg">
      <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden /> {t('fin.title')}
    </button>
  );
}

/** "ليّا عند الناس" و"عليّا للناس": كل الأرصدة، وكل واحد بيفتح كشف حسابه */
export function BalancesScreen() {
  const { kind: k = 'customers' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const accName = useAccountName();
  const kinds: BalKind[] = ['customers', 'suppliers', 'employees'];
  const kind = (kinds.includes(k as BalKind) ? k : 'customers') as BalKind;
  const { data, error, loading, reload } = useLoad(() => rpc<Row[]>('party_balances', { p_kind: kind }), [kind]);
  useLiveRefresh(reload);
  const rows = (data ?? []).map((r) => ({ ...r, balance: Number(r.balance) }));
  const total = rows.reduce((a, r) => a + r.balance, 0);
  return (
    <div className="max-w-4xl">
      <Back />
      <PageHeader title={t(`fin.balances.${kind}`)} sub={t(`fin.balancesSub.${kind}`)} />
      <div className="glass mb-3 inline-flex rounded-md p-1">
        {kinds.map((x) => (
          <Link key={x} to={`/finance/balances/${x}`} className={cn('h-7 rounded-sm px-3 text-sm leading-7', x === kind ? 'bg-accent-soft text-fg' : 'text-fg-3 hover:text-fg')} aria-current={x === kind ? 'page' : undefined}>
            {t(`fin.balances.${x}`)}
          </Link>
        ))}
      </div>
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading ? (
        <Skeleton className="h-40 w-full" />
      ) : rows.length === 0 ? (
        <Panel>
          <EmptyState line="wallet" title={t('fin.noBalances')} />
        </Panel>
      ) : (
        <Panel className="overflow-hidden">
          <PanelHeader
            title={t('fin.total')}
            actions={
              <span className="num text-md text-fg">
                {f.money(total)} <span className="font-sans text-2xs text-fg-3">{f.currency(shop.currency)}</span>
              </span>
            }
          />
          <ul className="divide-y divide-glass-border">
            {rows.map((r) => (
              <li key={`${r.party_id}-${r.account}`}>
                <Link to={`/finance/${r.party_type}/${r.party_id}`} className="flex items-center gap-3 px-4 py-2.5 text-sm hover:bg-raised/50">
                  <span className="min-w-0 flex-1 truncate text-fg">
                    <bdi>{r.name}</bdi>
                  </span>
                  {kind === 'employees' && <span className="text-2xs text-fg-3">{accName({ code: r.account, name: null })}</span>}
                  <span className={cn('num', r.balance < 0 ? 'text-warn' : 'text-fg')}>{f.money(r.balance)}</span>
                </Link>
              </li>
            ))}
          </ul>
        </Panel>
      )}
    </div>
  );
}

/** صافي الربح: الإيرادات والمصروفات لكل بند في الفترة */
export function ProfitScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const accName = useAccountName();
  const { period, range, set } = usePeriod();
  const { data, error, loading, reload } = useLoad(
    () => rpc<{ account_id: string; code: string | null; name: string | null; type: 'revenue' | 'expense'; amount: number }[]>('pl_breakdown', { p_from: range.from.toISOString(), p_to: range.to.toISOString() }),
    [range.from.getTime(), range.to.getTime()],
  );
  useLiveRefresh(reload);
  const rows = (data ?? []).map((r) => ({ ...r, amount: Number(r.amount) }));
  const rev = rows.filter((r) => r.type === 'revenue');
  const exp = rows.filter((r) => r.type === 'expense');
  const sum = (x: typeof rows) => x.reduce((a, r) => a + r.amount, 0);
  const cur = f.currency(shop.currency);
  const Block = ({ title, items, tone }: { title: string; items: typeof rows; tone: string }) => (
    <Panel className="overflow-hidden">
      <PanelHeader title={title} actions={<span className={cn('num text-md', tone)}>{f.money(sum(items))}</span>} />
      {items.length === 0 ? (
        <p className="p-4 text-sm text-fg-3">{t('fin.noMoves')}</p>
      ) : (
        <ul className="divide-y divide-glass-border">
          {items.map((r) => (
            <li key={r.account_id} className="flex justify-between px-4 py-2 text-sm">
              <span className="text-fg">{accName(r)}</span>
              <span className="num text-fg-2">{f.money(r.amount)}</span>
            </li>
          ))}
        </ul>
      )}
    </Panel>
  );
  return (
    <div className="max-w-4xl">
      <Back />
      <PageHeader title={t('fin.kpi.profit')} sub={t('fin.plSub')} />
      <div className="mb-3">
        <PeriodFilter value={period} onChange={set} />
      </div>
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading ? (
        <Skeleton className="h-40 w-full" />
      ) : (
        <div className="flex flex-col gap-4">
          <Block title={t('fin.revenue')} items={rev} tone="text-ok" />
          <Block title={t('fin.expenses')} items={exp} tone="text-danger" />
          <Panel className="flex items-center justify-between p-4">
            <span className="font-semibold text-fg">{t('fin.kpi.profit')}</span>
            <span className={cn('num text-xl font-semibold', sum(rev) - sum(exp) < 0 ? 'text-danger' : 'text-ok')} data-testid="pl-profit">
              {f.money(sum(rev) - sum(exp))} <span className="font-sans text-xs font-normal text-fg-3">{cur}</span>
            </span>
          </Panel>
        </div>
      )}
    </div>
  );
}
