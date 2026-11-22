import { useTranslation } from 'react-i18next';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useMe } from '../../app/auth';
import { useBranch } from '../../app/branch';
import { useLoad } from '../../app/useLoad';
import { rpc } from '../../app/ledgerApi';
import { ExportMenu } from '../../app/exporting';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { bpToPercent, readVat } from '../../lib/vat';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Alert, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

interface VatReport {
  rate_bp: number;
  sales_vat: number;
  repair_vat: number;
  reversed_vat: number;
  paid: number;
  sales_net: number;
  repair_net: number;
  due: number;
}

/**
 * R6: تقرير ضريبة القيمة المضافة للفترة (من الدفتر بس، vat_report): ضريبة المبيعات والصيانة، والمرتجع بالإلغاء،
 * والصافي قبل الضريبة، والمدفوع للمصلحة، والمستحق لحد آخر الفترة. المبالغ بالقروش، والعرض بالجنيه.
 */
export function VatReportScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const br = useBranch();
  const { period, range, set } = usePeriod();
  const { data, error, reload } = useLoad(
    async () => {
      const r = await rpc<VatReport>('vat_report', { p_from: range.from.toISOString(), p_to: range.to.toISOString(), p_branch: br.filter });
      // الأرقام من jsonb ممكن توصل نصوص: كلها أعداد صحيحة بالقروش
      return Object.fromEntries(Object.entries(r).map(([k, v]) => [k, typeof v === 'string' && /^-?\d+$/.test(v) ? Number(v) : v])) as unknown as VatReport;
    },
    [range.from.getTime(), range.to.getTime(), br.filter],
  );
  useLiveRefresh(reload);
  const vat = readVat(shop.extras);
  const cur = f.currency(shop.currency);
  const periodLine = t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) });
  const collected = data ? data.sales_vat + data.repair_vat - data.reversed_vat : 0;
  const rows: { key: string; v: number; strong?: boolean; tone?: string }[] = data
    ? [
        { key: 'salesNet', v: data.sales_net },
        { key: 'salesVat', v: data.sales_vat },
        { key: 'repairNet', v: data.repair_net },
        { key: 'repairVat', v: data.repair_vat },
        { key: 'reversed', v: -data.reversed_vat },
        { key: 'collected', v: collected, strong: true },
        { key: 'paid', v: -data.paid },
        { key: 'due', v: data.due, strong: true, tone: data.due > 0 ? 'text-warn' : 'text-ok' },
      ]
    : [];

  return (
    <div data-testid="vat-report">
      <PageHeader
        title={t('vatReport.title')}
        sub={t('vatReport.sub')}
        actions={
          <ExportMenu
            testid="vat-report-export"
            disabled={!data}
            table={() =>
              data && {
                title: t('vatReport.title'),
                meta: [shop.name, periodLine, ...(vat.reg_no ? [`${t('vat.reg')}: ${vat.reg_no}`] : [])],
                columns: [{ header: t('export.cols.item') }, { header: t('fin.cols.amount'), type: 'money' }],
                rows: rows.map((r) => [t(`vatReport.rows.${r.key}`), r.v]),
              }
            }
          />
        }
      />
      <div className="mb-4">
        <PeriodFilter value={period} onChange={set} />
      </div>
      {!vat.enabled && (
        <Alert tone="info" className="mb-4">
          {t('vatReport.off')}
        </Alert>
      )}
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : !data ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <Panel className="overflow-hidden">
          <PanelHeader title={t('vatReport.summary')} actions={<span className="num text-sm text-fg-3">{t('vatReport.rate', { r: bpToPercent(data.rate_bp) })}</span>} />
          <ul className="divide-y divide-glass-border">
            {rows.map((r) => (
              <li key={r.key} className={cn('flex justify-between gap-3 px-4 py-2 text-sm', r.strong && 'bg-raised/40 font-semibold')} data-testid={`vat-row-${r.key}`}>
                <span className={r.strong ? 'text-fg' : 'text-fg-2'}>{t(`vatReport.rows.${r.key}`)}</span>
                <span className={cn('num', r.tone ?? (r.strong ? 'text-fg' : 'text-fg-2'))} dir="ltr" data-testid={`vat-val-${r.key}`}>
                  {f.money(r.v)} {cur}
                </span>
              </li>
            ))}
          </ul>
          <p className="border-t border-line px-4 py-2 text-xs text-fg-3">{t('vatReport.note')}</p>
        </Panel>
      )}
    </div>
  );
}
