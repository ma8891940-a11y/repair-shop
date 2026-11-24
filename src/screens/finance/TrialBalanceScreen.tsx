import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { ArrowLeft, CheckCircle2, AlertTriangle } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { rpc, useAccountName } from '../../app/ledgerApi';
import { useLoad } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { usePerms } from '../../app/perms';
import { useBranch } from '../../app/branch';
import { ExportMenu } from '../../app/exporting';
import { useFormat } from '../../i18n/format';
import { Panel } from '../../ui/Panel';
import { ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';
import type { ExportTable } from '../../lib/xlsx';

interface TbRow {
  account_id: string | null;
  code: string | null;
  name: string | null;
  type: string;
  kind: string;
  debit: number;
  credit: number;
  balance: number;
}

/**
 * U2: ميزان المراجعة لكل فرع لوحده أو للمحل كله (من مبدّل الفروع فوق).
 * كل فرع بيقفل متوازن لوحده: تحويلات الفلوس والبضاعة بين الفروع بتبان "مستحق من فرع / مستحق لفرع"،
 * وفي الموحّد بتلغي بعض. القيود نفسها ما بتتغيرش.
 */
export function TrialBalanceScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const br = useBranch();
  const accName = useAccountName();
  const priv = usePerms().grant('private_finance');
  const owner = useMe().profile.role === 'owner';
  const { data, error, reload } = useLoad(async () => {
    const [rows, dues] = await Promise.all([
      rpc<TbRow[]>('trial_balance', { p_branch: br.filter }),
      br.filter ? rpc<{ branch_id: string; other_id: string; amount: number }[]>('inter_branch_dues') : Promise.resolve([]),
    ]);
    return {
      rows: rows.map((r) => ({ ...r, debit: Number(r.debit), credit: Number(r.credit), balance: Number(r.balance) })),
      dues: dues.filter((d) => d.branch_id === br.filter).map((d) => ({ ...d, amount: Number(d.amount) })),
    };
  }, [br.filter]);
  useLiveRefresh(reload);
  const label = (r: TbRow) => (r.kind === 'inter_branch' ? t('tb.interBranch') : accName({ code: r.code, name: r.name }));
  const tot = (data?.rows ?? []).reduce((a, r) => ({ dr: a.dr + (r.balance > 0 ? r.balance : 0), cr: a.cr + (r.balance < 0 ? -r.balance : 0) }), { dr: 0, cr: 0 });
  const balanced = !!data && tot.dr === tot.cr;
  // الموظف: حسابات مخفية، فالميزان ممكن ما يقفلش عنده
  const full = priv && (owner || balanced);
  const note = priv ? t('fin.partnersNote') : t('fin.privateNote');
  const scope = br.filter ? br.name(br.filter) : t('tb.allBranches');
  const table = (): ExportTable | null | undefined =>
    data && {
      title: `${t('tb.title')} - ${scope}`,
      meta: full ? [] : [note],
      columns: [{ header: t('tb.account') }, { header: t('tb.debit'), type: 'money', total: full }, { header: t('tb.credit'), type: 'money', total: full }],
      rows: data.rows.map((r) => [label(r), r.balance > 0 ? r.balance : 0, r.balance < 0 ? -r.balance : 0]),
    };
  return (
    <div className="max-w-4xl" data-testid="trial-balance">
      <Link to="/finance" className="mb-3 inline-flex items-center gap-1.5 text-sm text-fg-3 hover:text-fg">
        <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden /> {t('fin.title')}
      </Link>
      <PageHeader title={t('tb.title')} sub={scope} actions={<ExportMenu table={table} testid="tb-export" disabled={!data} />} />
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : !data ? (
        <Skeleton className="h-64" />
      ) : (
        <>
          {!full ? (
            <p className="mb-3 text-xs text-fg-3" data-testid="private-note">{note}</p>
          ) : (
          <div className={cn('mb-3 flex items-center gap-2 text-sm', balanced ? 'text-ok' : 'text-danger')} data-testid={balanced ? 'tb-balanced' : 'tb-unbalanced'}>
            {balanced ? <CheckCircle2 className="size-4" aria-hidden /> : <AlertTriangle className="size-4" aria-hidden />}
            {balanced ? t('tb.balanced') : t('tb.unbalanced')}
          </div>
          )}
          <Panel className="overflow-x-auto">
            <table className="w-full min-w-[480px] text-sm">
              <thead className="text-2xs text-fg-3">
                <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                  <th>{t('tb.account')}</th>
                  <th className="!text-end">{t('tb.debit')}</th>
                  <th className="!text-end">{t('tb.credit')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-glass-border">
                {data.rows.map((r) => (
                  <tr key={r.account_id ?? 'inter'} className={cn('[&_td]:px-3 [&_td]:py-1.5', r.kind === 'inter_branch' && 'bg-accent-soft/30')} data-testid="tb-row" data-kind={r.kind}>
                    <td className="text-fg">
                      {r.account_id ? (
                        <Link to={`/finance/cashbox/${r.account_id}`} className={cn(r.kind === 'cash' ? 'hover:text-accent' : 'pointer-events-none')}>
                          {label(r)}
                        </Link>
                      ) : (
                        label(r)
                      )}
                    </td>
                    <td className="num text-end text-fg">{r.balance > 0 ? f.money(r.balance) : ''}</td>
                    <td className="num text-end text-fg">{r.balance < 0 ? f.money(-r.balance) : ''}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot hidden={!full} className="border-t border-glass-border-strong font-semibold">
                <tr className="[&_td]:px-3 [&_td]:py-2">
                  <td>{t('fin.total')}</td>
                  <td className="num text-end" data-testid="tb-dr">{f.money(tot.dr)}</td>
                  <td className="num text-end" data-testid="tb-cr">{f.money(tot.cr)}</td>
                </tr>
              </tfoot>
            </table>
          </Panel>
          {data.dues.length > 0 && (
            <Panel className="mt-3 p-3 text-sm" data-testid="tb-dues">
              <div className="readout-label mb-1">{t('tb.duesTitle')}</div>
              <ul className="flex flex-col gap-1">
                {data.dues.map((d) => (
                  <li key={d.other_id} className="flex items-center gap-2">
                    <span className="flex-1 text-fg-2">{d.amount > 0 ? t('tb.dueFrom', { b: br.name(d.other_id) }) : t('tb.dueTo', { b: br.name(d.other_id) })}</span>
                    <span className="num text-fg">{f.money(Math.abs(d.amount))}</span>
                  </li>
                ))}
              </ul>
            </Panel>
          )}
          <p className="mt-2 text-xs text-fg-3">{t('tb.hint')}</p>
        </>
      )}
    </div>
  );
}
