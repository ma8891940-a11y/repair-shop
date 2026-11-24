import { Link, useNavigate, useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useState } from 'react';
import { ArrowLeft, MessageCircle } from 'lucide-react';
import { WhatsAppDialog, type MessageTarget } from '../../app/messaging';
import { supabase } from '../../lib/supabase';
import { balanceKinds, type BalKind } from '../../lib/ledger';
import { daysSince } from '../../lib/dates';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad, must } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { useBranch } from '../../app/branch';
import { rpc, useAccountName } from '../../app/ledgerApi';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import { ExportMenu } from '../../app/exporting';
import { useSensitiveNames } from '../../app/assist';

interface Row {
  party_type: 'customer' | 'supplier' | 'employee';
  party_id: string;
  name: string | null;
  account: string;
  balance: number;
  oldest: string | null;
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
  const { shop, profile } = useMe();
  const accName = useAccountName();
  const kinds = balanceKinds(profile.role === 'owner');
  const kind = (kinds.includes(k as BalKind) ? k : 'customers') as BalKind;
  const br = useBranch();
  const { data, error, loading, reload } = useLoad(async () => {
    const rows = await rpc<Row[]>('party_balances', { p_kind: kind });
    const ids = rows.filter((r) => r.party_type === 'customer').map((r) => r.party_id);
    const phones = ids.length ? must(await supabase.from('customers').select('id, phone').in('id', ids)) as { id: string; phone: string }[] : [];
    return { rows, phones: new Map(phones.map((p) => [p.id, p.phone])) };
  }, [kind, br.working?.id]);
  const [wa, setWa] = useState<MessageTarget | null>(null);
  useLiveRefresh(reload);
  const rows = (data?.rows ?? []).map((r) => ({ ...r, balance: Number(r.balance) }));
  useSensitiveNames(rows.filter((r) => r.party_type === 'customer').map((r) => r.name));
  const total = rows.reduce((a, r) => a + r.balance, 0);
  return (
    <div className="max-w-4xl">
      <Back />
      <PageHeader
        title={t(`fin.balances.${kind}`)}
        sub={t(`fin.balancesSub.${kind}`)}
        actions={
          <ExportMenu
            testid="balances-export"
            disabled={!data}
            table={() => ({
              title: t(`fin.balances.${kind}`),
              columns: [
                { header: t('customers.cols.name') },
                ...(kind === 'customers' ? [{ header: t('customers.cols.phone') }] : []),
                ...(kind === 'employees' ? [{ header: t('export.cols.account') }] : []),
                { header: t('export.cols.oldest'), type: 'date' as const },
                { header: t('fin.cols.amount'), type: 'money' as const, total: true },
              ],
              rows: rows.map((r) => [r.name, ...(kind === 'customers' ? [data?.phones.get(r.party_id) ?? ''] : []), ...(kind === 'employees' ? [accName({ code: r.account, name: null })] : []), r.balance > 0 ? r.oldest : null, r.balance]),
            })}
          />
        }
      />
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
              <li key={`${r.party_id}-${r.account}`} className="flex items-center">
                <Link to={`/finance/${r.party_type}/${r.party_id}`} className="flex min-w-0 flex-1 items-center gap-3 px-4 py-2.5 text-sm hover:bg-raised/50" data-testid="balance-row">
                  <span className="min-w-0 flex-1 truncate text-fg">
                    <bdi>{r.name}</bdi>
                  </span>
                  {kind === 'employees' && <span className="text-2xs text-fg-3">{accName({ code: r.account, name: null })}</span>}
                  {r.oldest && r.balance > 0 && (
                    <span className="hidden text-2xs text-fg-3 sm:inline" title={f.date(r.oldest)}>
                      {t('fin.oldest', { d: f.days(daysSince(r.oldest, new Date())) })}
                    </span>
                  )}
                  <span className={cn('num w-24 text-end', r.balance < 0 ? 'text-warn' : 'text-fg')}>{f.money(r.balance)}</span>
                </Link>
                {kind === 'customers' && r.balance > 0 && data?.phones.get(r.party_id) && (
                  <button
                    type="button"
                    className="me-3 rounded-sm p-1.5 text-fg-3 hover:bg-raised hover:text-ok"
                    aria-label={`${t('wa.keys.debt')} ${r.name ?? ''}`}
                    onClick={() => setWa({ deviceId: null, customerId: r.party_id, customerName: r.name ?? '', phone: data.phones.get(r.party_id)!, orderNo: '', device: '', status: 'delivered', token: null, cost: null, balance: r.balance })}
                  >
                    <MessageCircle className="size-4" aria-hidden />
                  </button>
                )}
              </li>
            ))}
          </ul>
        </Panel>
      )}
      <WhatsAppDialog open={!!wa} onOpenChange={(v) => !v && setWa(null)} target={wa} initial="debt" />
    </div>
  );
}

/** صافي الربح: الإيرادات والمصروفات لكل بند في الفترة */
type PlRow = { account_id: string; code: string | null; name: string | null; type: 'revenue' | 'expense'; amount: number };
/** قسم الإيرادات أو المصروفات. برّه الشاشة عشان قايمة التصدير ما تتقفلش مع التحديث المباشر (المكوّن كان بيتبني من جديد كل مرة) */
function PlBlock({ title, items, tone, testid, periodLine }: { title: string; items: PlRow[]; tone: string; testid: string; periodLine: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  const sum = (x: PlRow[]) => x.reduce((a, r) => a + r.amount, 0);
  return (
    <Panel className="overflow-hidden">
      <PanelHeader
        title={title}
        actions={
          <span className="flex items-center gap-2">
            <ExportMenu testid={testid} table={() => ({ title, meta: [periodLine], columns: [{ header: t('export.cols.item') }, { header: t('fin.cols.amount'), type: 'money', total: true }], rows: items.map((r) => [accName(r), r.amount]) })} />
            <span className={cn('num text-md', tone)}>{f.money(sum(items))}</span>
          </span>
        }
      />
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
}

export function ProfitScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const accName = useAccountName();
  const br = useBranch();
  const { period, range, set } = usePeriod();
  const { data, error, loading, reload } = useLoad(
    () => rpc<{ account_id: string; code: string | null; name: string | null; type: 'revenue' | 'expense'; amount: number }[]>('pl_breakdown', { p_from: range.from.toISOString(), p_to: range.to.toISOString(), p_branch: br.filter }),
    [range.from.getTime(), range.to.getTime(), br.filter],
  );
  useLiveRefresh(reload);
  const rows = (data ?? []).map((r) => ({ ...r, amount: Number(r.amount) }));
  const rev = rows.filter((r) => r.type === 'revenue');
  const exp = rows.filter((r) => r.type === 'expense');
  const sum = (x: typeof rows) => x.reduce((a, r) => a + r.amount, 0);
  const cur = f.currency(shop.currency);
  const periodLine = t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) });
  return (
    <div className="max-w-4xl">
      <Back />
      <PageHeader
        title={t('fin.kpi.profit')}
        sub={t('fin.plSub')}
        actions={
          <ExportMenu
            testid="pl-export"
            disabled={!data}
            table={() => ({
              title: t('fin.kpi.profit'),
              meta: [periodLine, `${t('fin.kpi.profit')}: ${f.money(sum(rev) - sum(exp))} ${cur}`],
              columns: [{ header: t('export.cols.kind') }, { header: t('export.cols.item') }, { header: t('fin.cols.amount'), type: 'money' }],
              rows: [...rev.map((r) => [t('fin.revenue'), accName(r), r.amount]), ...exp.map((r) => [t('fin.expenses'), accName(r), r.amount])],
            })}
          />
        }
      />
      <div className="mb-3">
        <PeriodFilter value={period} onChange={set} />
      </div>
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading ? (
        <Skeleton className="h-40 w-full" />
      ) : (
        <div className="flex flex-col gap-4">
          <PlBlock periodLine={periodLine} title={t('fin.revenue')} items={rev} tone="text-ok" testid="pl-export-revenue" />
          <PlBlock periodLine={periodLine} title={t('fin.expenses')} items={exp} tone="text-danger" testid="pl-export-expenses" />
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
