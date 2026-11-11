import { useTranslation } from 'react-i18next';
import { Printer } from 'lucide-react';
import { Link } from 'react-router';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { useLoad } from '../app/useLoad';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
import { rpc, type StockRow } from '../app/ledgerApi';
import { PeriodFilter, usePeriod } from '../app/finance/PeriodFilter';
import { useDuration, useRouteName } from '../app/tech/names';
import { plainPounds, toCsv } from '../lib/ledger';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { ErrorState, Skeleton } from '../ui/Feedback';
import { ExportMenu } from '../app/exporting';
import type { ExportTable } from '../lib/xlsx';
import { AssistBox } from '../app/assist';
import { anonymizeRows } from '../lib/assistPayloads';

interface TechRow {
  tech_id: string;
  name: string;
  devices: number;
  steps: number;
  avg_minutes: number | null;
  returns: number;
  return_rate: number;
  revenue: number;
}
interface IssueRow {
  route_id: string | null;
  code: string | null;
  name: string | null;
  devices: number;
  revenue: number;
  parts: number;
  profit: number;
}

function download(name: string, rows: (string | number | null)[][]) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8' }));
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/** التقارير (صاحب المحل): أداء الفنيين، وربحية كل نوع عطل، والأعطال والموديلات، والمخزون والنواقص. كل تقرير بيتصدّر Excel أو PDF */
export function ReportsScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, profile } = useMe();
  const br = useBranch();
  const routeName = useRouteName();
  const dur = useDuration();
  const { period, range, set } = usePeriod();
  const args = { p_from: range.from.toISOString(), p_to: range.to.toISOString() };
  // B: فلتر الفرع (null = كل الفروع)
  const bargs = { ...args, p_branch: br.filter };
  const { data, error, loading, reload } = useLoad(async () => {
    const [tech, issue, models, items] = await Promise.all([
      // الموظف اللي مش معاه كل الفروع: تقرير الفنيين على مستوى المحل كله مش ليه (الباقي بفرعه)
      rpc<TechRow[]>('tech_report', args).catch((e) => {
        if (profile.role === 'owner') throw e;
        return [] as TechRow[];
      }),
      rpc<IssueRow[]>('issue_report', bargs),
      rpc<{ kind: 'model' | 'route'; label: string; devices: number }[]>('models_report', bargs),
      rpc<StockRow[]>('items_stock', br.multi && br.view === 'all' ? { p_all: true } : {}),
    ]);
    return { tech, issue: issue.map((r) => ({ ...r, revenue: Number(r.revenue), parts: Number(r.parts), profit: Number(r.profit) })), models, short: items.filter((i) => i.short) };
     
  }, [range.from.getTime(), range.to.getTime(), br.filter]);
  useLiveRefresh(reload);
  const span = `${range.days[0]}_${range.days.at(-1)}`;
  const cur = f.currency(shop.currency);
  const label = (r: { code: string | null; name: string | null }) => (r.code || r.name ? routeName(r) : t('reports.noRoute'));

  const periodLine = t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) });
  // كل تقرير: Excel وPDF بنفس الصفوف اللي ظاهرة، وCSV زي ما كان
  const Section = ({ title, onCsv, table, children, testid }: { title: string; onCsv: () => void; table: () => Omit<ExportTable, 'title'>; children: React.ReactNode; testid: string }) => (
    <Panel className="break-inside-avoid overflow-hidden" data-testid={testid}>
      <PanelHeader
        title={title}
        actions={
          <span className="print:hidden">
            <ExportMenu testid={`${testid}-export`} csv={onCsv} table={() => ({ title, ...table(), meta: [periodLine] })} />
          </span>
        }
      />
      <div className="overflow-x-auto">{children}</div>
    </Panel>
  );
  const th = '[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium';
  const td = '[&_td]:px-3 [&_td]:py-2';

  return (
    <div className="max-w-6xl">
      <PageHeader
        title={t('reports.title')}
        sub={t('reports.sub')}
        actions={
          <Button size="sm" icon={<Printer className="size-4" />} onClick={() => window.print()} className="print:hidden">
            {t('fin.pdf')}
          </Button>
        }
      />
      <div className="mb-4 print:hidden">
        <PeriodFilter value={period} onChange={set} />
      </div>
      {error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : loading || !data ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <div className="flex flex-col gap-4">
          {(() => {
            // ملخص مكتوب: أسماء الفنيين بتتشفّر (فني 1، فني 2) وبترجع في الرد، والأرقام بس
            const tech = anonymizeRows(
              data.tech.map((r) => ({ label: r.name, values: [{ k: 'devices', n: r.devices }, { k: 'steps', n: r.steps }, { k: 'returns', n: r.returns }, { k: 'revenue', n: Number(r.revenue), money: true }] })),
              data.tech.map((r) => r.name),
              t('assist.report.techCode'),
            );
            const issues = data.issue.map((r) => ({ label: label(r), values: [{ k: 'devices', n: r.devices }, { k: 'revenue', n: r.revenue, money: true }, { k: 'parts', n: r.parts, money: true }, { k: 'profit', n: r.profit, money: true }] }));
            return (
              <AssistBox
                area="reports"
                kind="report"
                className="print:hidden"
                title={t('assist.report.title')}
                askLabel={t('assist.report.ask')}
                testid="assist-report"
                privacy={t('assist.privacyReport')}
                build={() => {
                  const models = data.models.map((m) => ({ label: `${t(`reports.top.${m.kind}`)}: ${m.kind === 'route' ? label({ code: m.label === '-' ? null : m.label, name: null }) : m.label}`, values: [{ k: 'devices', n: Number(m.devices) }] }));
                  const rows = [...tech.rows, ...issues, ...models];
                  return rows.length ? { title: t('reports.title'), period: periodLine, rows } : null;
                }}
                render={(answer) => <p className="whitespace-pre-wrap">{tech.restore(answer)}</p>}
              />
            );
          })()}
          <Section
            testid="report-tech"
            title={t('reports.tech')}
            table={() => ({
              columns: [
                { header: t('roles.technician') },
                { header: t('reports.devices'), type: 'int', total: true },
                { header: t('reports.steps'), type: 'int', total: true },
                { header: t('reports.avgTime') },
                { header: t('reports.returns'), type: 'int', total: true },
                { header: t('reports.returnRate') },
                { header: t('reports.revenue'), type: 'money', total: true },
              ],
              rows: data.tech.map((r) => [r.name, r.devices, r.steps, r.avg_minutes ? dur(r.avg_minutes) : '', r.returns, `${r.return_rate}%`, Number(r.revenue)]),
            })}
            onCsv={() =>
              download(`technicians_${span}.csv`, [
                [t('roles.technician'), t('reports.devices'), t('reports.steps'), t('reports.avgTime'), t('reports.returns'), t('reports.returnRate'), t('reports.revenue')],
                ...data.tech.map((r) => [r.name, r.devices, r.steps, r.avg_minutes ?? '', r.returns, `${r.return_rate}%`, plainPounds(Number(r.revenue))]),
              ])
            }
          >
            <table className="w-full min-w-[640px] text-sm">
              <thead className={`text-2xs text-fg-3 ${th}`}>
                <tr>
                  <th>{t('roles.technician')}</th>
                  <th>{t('reports.devices')}</th>
                  <th>{t('reports.steps')}</th>
                  <th>{t('reports.avgTime')}</th>
                  <th>{t('reports.returns')}</th>
                  <th>{t('reports.revenue')}</th>
                </tr>
              </thead>
              <tbody className={`divide-y divide-glass-border ${td}`}>
                {data.tech.map((r) => (
                  <tr key={r.tech_id}>
                    <td className="text-fg">{r.name}</td>
                    <td className="num">{f.number(r.devices)}</td>
                    <td className="num">{f.number(r.steps)}</td>
                    <td>{r.avg_minutes ? dur(r.avg_minutes) : t('common.none')}</td>
                    <td className="num">
                      {f.number(r.returns)} <span className="text-2xs text-fg-3">({r.return_rate}%)</span>
                    </td>
                    <td className="num">
                      {f.money(Number(r.revenue))} <span className="font-sans text-2xs text-fg-3">{cur}</span>
                    </td>
                  </tr>
                ))}
                {data.tech.length === 0 && (
                  <tr>
                    <td colSpan={6} className="text-fg-3">
                      {t('techSettings.noTechs')}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </Section>

          <Section
            testid="report-issue"
            title={t('reports.issue')}
            table={() => ({
              columns: [
                { header: t('tech.route') },
                { header: t('reports.devices'), type: 'int', total: true },
                { header: t('reports.revenue'), type: 'money', total: true },
                { header: t('reports.parts'), type: 'money', total: true },
                { header: t('reports.profit'), type: 'money', total: true },
              ],
              rows: data.issue.map((r) => [label(r), r.devices, r.revenue, r.parts, r.profit]),
            })}
            onCsv={() =>
              download(`issues_${span}.csv`, [
                [t('tech.route'), t('reports.devices'), t('reports.revenue'), t('reports.parts'), t('reports.profit')],
                ...data.issue.map((r) => [label(r), r.devices, plainPounds(r.revenue), plainPounds(r.parts), plainPounds(r.profit)]),
              ])
            }
          >
            <table className="w-full min-w-[560px] text-sm">
              <thead className={`text-2xs text-fg-3 ${th}`}>
                <tr>
                  <th>{t('tech.route')}</th>
                  <th>{t('reports.devices')}</th>
                  <th>{t('reports.revenue')}</th>
                  <th>{t('reports.parts')}</th>
                  <th>{t('reports.profit')}</th>
                </tr>
              </thead>
              <tbody className={`divide-y divide-glass-border ${td}`}>
                {data.issue.map((r) => (
                  <tr key={r.route_id ?? 'none'}>
                    <td className="text-fg">{label(r)}</td>
                    <td className="num">{f.number(r.devices)}</td>
                    <td className="num">{f.money(r.revenue)}</td>
                    <td className="num text-fg-2">{f.money(r.parts)}</td>
                    <td className={r.profit < 0 ? 'num text-danger' : 'num text-ok'}>{f.money(r.profit)}</td>
                  </tr>
                ))}
                {data.issue.length === 0 && (
                  <tr>
                    <td colSpan={5} className="text-fg-3">
                      {t('fin.noMoves')}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </Section>

          <div className="grid gap-4 md:grid-cols-2">
            {(['model', 'route'] as const).map((k) => (
              <Section
                key={k}
                testid={`report-${k}`}
                title={t(`reports.top.${k}`)}
                table={() => ({
                  columns: [{ header: t(`reports.top.${k}`) }, { header: t('reports.devices'), type: 'int', total: true }],
                  rows: data.models.filter((m) => m.kind === k).map((m) => [k === 'route' ? label({ code: m.label === '-' ? null : m.label, name: null }) : m.label, m.devices]),
                })}
                onCsv={() => download(`top_${k}_${span}.csv`, [[t(`reports.top.${k}`), t('reports.devices')], ...data.models.filter((m) => m.kind === k).map((m) => [k === 'route' ? label({ code: m.label, name: null }) : m.label, m.devices])])}
              >
                <ul className="divide-y divide-glass-border text-sm">
                  {data.models
                    .filter((m) => m.kind === k)
                    .map((m) => (
                      <li key={m.label} className="flex justify-between px-4 py-2">
                        <span className="text-fg">{k === 'route' ? label({ code: m.label === '-' ? null : m.label, name: null }) : m.label}</span>
                        <span className="num text-fg-2">{f.number(m.devices)}</span>
                      </li>
                    ))}
                </ul>
              </Section>
            ))}
          </div>

          <Section
            testid="report-short"
            title={t('reports.short')}
            table={() => ({
              columns: [{ header: t('inv.cols.name') }, { header: t('inv.cols.qty'), type: 'int' }, { header: t('inv.minQty'), type: 'int' }],
              rows: data.short.map((i) => [i.name, Number(i.qty), i.min_qty ?? 0]),
            })}
            onCsv={() => download(`shortages.csv`, [[t('inv.cols.name'), t('inv.cols.qty'), t('inv.minQty')], ...data.short.map((i) => [i.name, Number(i.qty), i.min_qty ?? 0])])}
          >
            <ul className="divide-y divide-glass-border text-sm">
              {data.short.map((i) => (
                <li key={i.id} className="flex justify-between px-4 py-2">
                  <span className="text-fg">{i.name}</span>
                  <span className="num text-warn">
                    {f.number(Number(i.qty))} / {f.number(i.min_qty ?? 0)}
                  </span>
                </li>
              ))}
              {data.short.length === 0 && <li className="px-4 py-2 text-fg-3">{t('reports.noShort')}</li>}
            </ul>
          </Section>
          <p className="text-xs text-fg-3 print:hidden">
            {t('reports.debtsHint')}{' '}
            <Link to="/finance/balances/customers" className="text-accent hover:underline">
              {t('fin.balances.customers')}
            </Link>
          </p>
        </div>
      )}
    </div>
  );
}
