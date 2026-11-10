import { useTranslation } from 'react-i18next';
import { useBranch } from '../branch';
import { rpc, type Position } from '../ledgerApi';
import { useLoad } from '../useLoad';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

/** B: مقارنة بين الفروع لنفس الفترة (بتظهر في "كل الفروع" بس) */
export function BranchCompare({ from, to }: { from: Date; to: Date }) {
  const { t } = useTranslation();
  const f = useFormat();
  const br = useBranch();
  const show = br.multi && br.view === 'all';
  const { data, loading } = useLoad(
    async () => (show ? Promise.all(br.all.map(async (b) => ({ b, p: await rpc<Position>('financial_position', { p_from: from.toISOString(), p_to: to.toISOString(), p_branch: b.id }) }))) : []),
    [show, from.getTime(), to.getTime(), br.all.map((b) => b.id).join()],
  );
  if (!show) return null;
  const cols = ['revenue', 'expenses', 'profit', 'cash', 'inventory'] as const;
  return (
    <Panel className="mt-4" data-testid="branch-compare">
      <PanelHeader title={t('branch.compare')} />
      <p className="px-4 pt-2 text-2xs text-fg-3">{t('branch.compareHint')}</p>
      <div className="overflow-x-auto p-2">
        {loading && !data ? (
          <Skeleton className="m-2 h-24" />
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-start text-2xs text-fg-3 [&_th]:px-2 [&_th]:py-1.5 [&_th]:font-normal">
                <th className="text-start">{t('branch.cols.branch')}</th>
                {cols.map((c) => (
                  <th key={c} className="text-end">
                    {t(`branch.cols.${c}`)}
                  </th>
                ))}
                <th className="text-end">{t('branch.cols.delivered')}</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map(({ b, p }) => (
                <tr key={b.id} className="border-t border-glass-border [&_td]:px-2 [&_td]:py-2" data-testid="branch-compare-row" data-branch={b.name}>
                  <td className="text-fg">{b.name}</td>
                  {cols.map((c) => (
                    <td key={c} className={cn('num text-end', c === 'profit' && (Number(p[c]) < 0 ? 'text-danger' : 'text-fg'))} data-col={c}>
                      {f.money(Number(p[c]))}
                    </td>
                  ))}
                  <td className="num text-end text-fg-2">{f.number(Number(p.delivered))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </Panel>
  );
}
