import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { useLoad } from '../useLoad';
import { rpc, type StockRow } from '../ledgerApi';
import { useRouteName, useDuration } from '../tech/names';
import { useFormat } from '../../i18n/format';
import { daysLeft, reorderQty, shareBp, urgency } from '../../lib/forecast';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Alert, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

interface Fault {
  brand: string;
  model: string;
  route_code: string | null;
  route_name: string | null;
  issue: string | null;
  devices: number;
  returns: number;
}
interface Part {
  item_id: string;
  name: string;
  uses: number;
  devices: number;
  cost: number;
  revenue: number;
}
interface Tech {
  tech_id: string;
  name: string;
  devices: number;
  avg_minutes: number | null;
  return_rate: number;
}

/**
 * C6: تحليلات الصيانة: أكتر الأعطال لكل موديل، ومتوسط وقت الإصلاح لكل فني، والقطع اللي بتاكل الربح (صاحب المحل)،
 * وتوقع نفاد المخزون من معدل الصرف. كله من البيانات، ومن غير بيانات عملاء.
 */
export function RepairInsights({ from, to, branch, owner }: { from: Date; to: Date; branch: string | null; owner: boolean }) {
  const { t } = useTranslation();
  const f = useFormat();
  const rn = useRouteName();
  const dur = useDuration();
  const args = { p_from: from.toISOString(), p_to: to.toISOString() };
  const { data, error } = useLoad(async () => {
    const [faults, techs, parts, stock, usage] = await Promise.all([
      rpc<Fault[]>('faults_by_model', { ...args, p_branch: branch }),
      rpc<Tech[]>('tech_report', args).catch(() => [] as Tech[]),
      owner ? rpc<Part[]>('parts_profit', args) : Promise.resolve([] as Part[]),
      rpc<StockRow[]>('items_stock'),
      rpc<{ item_id: string; used: number }[]>('items_usage30'),
    ]);
    const used = new Map(usage.map((u) => [u.item_id, Number(u.used)]));
    const forecast = stock
      .filter((s) => (s.kind as string) !== 'used')
      .map((s) => {
        const u = used.get(s.id) ?? 0;
        const q = Number(s.qty);
        const d = daysLeft(q, u);
        return { id: s.id, name: s.name, qty: q, used: u, days: d, level: urgency(d), buy: reorderQty(q, u) };
      })
      .filter((x) => x.used > 0 && x.level !== 'ok')
      .sort((a, b) => (a.days ?? 0) - (b.days ?? 0))
      .slice(0, 15);
    return {
      faults,
      techs: techs.filter((x) => x.devices > 0).sort((a, b) => (a.avg_minutes ?? 1e9) - (b.avg_minutes ?? 1e9)),
      parts: parts.map((p) => ({ ...p, cost: Number(p.cost), revenue: Number(p.revenue), share: shareBp(Number(p.cost), Number(p.revenue)) })).sort((a, b) => (b.share ?? 0) - (a.share ?? 0)),
      forecast,
    };
  }, [from.getTime(), to.getTime(), branch, owner]);

  if (error) return <Alert tone="danger">{error}</Alert>;
  if (!data) return <Skeleton className="mt-4 h-48 w-full" />;
  const th = 'text-2xs text-fg-3 [&_th]:px-3 [&_th]:py-1.5 [&_th]:text-start [&_th]:font-medium';
  const row = 'border-t border-glass-border [&_td]:px-3 [&_td]:py-1.5';
  const empty = <p className="px-3 py-3 text-xs text-fg-3">{t('insights.empty')}</p>;
  return (
    <div className="mt-4 grid gap-4 lg:grid-cols-2" data-testid="repair-insights">
      <Panel>
        <PanelHeader title={t('insights.faults')} />
        {data.faults.length === 0 ? (
          empty
        ) : (
          <table className="w-full text-sm" data-testid="in-faults">
            <thead className={th}>
              <tr>
                <th>{t('insights.model')}</th>
                <th>{t('insights.fault')}</th>
                <th>{t('reports.devices')}</th>
              </tr>
            </thead>
            <tbody>
              {data.faults.slice(0, 12).map((x, i) => (
                <tr key={i} className={row}>
                  <td>
                    {x.brand} {x.model}
                  </td>
                  <td className="text-fg-2">{x.route_code || x.route_name ? rn({ code: x.route_code, name: x.route_name }) : x.issue}</td>
                  <td className="num">
                    {x.devices}
                    {x.returns > 0 && <span className="ms-1 text-2xs text-warn">({t('insights.returns', { n: x.returns })})</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      <Panel>
        <PanelHeader title={t('insights.techTime')} />
        {data.techs.length === 0 ? (
          empty
        ) : (
          <table className="w-full text-sm" data-testid="in-techs">
            <thead className={th}>
              <tr>
                <th>{t('roles.technician')}</th>
                <th>{t('reports.devices')}</th>
                <th>{t('reports.avgTime')}</th>
                <th>{t('reports.returnRate')}</th>
              </tr>
            </thead>
            <tbody>
              {data.techs.map((x) => (
                <tr key={x.tech_id} className={row}>
                  <td>{x.name}</td>
                  <td className="num">{x.devices}</td>
                  <td className="num">{x.avg_minutes ? dur(x.avg_minutes) : '—'}</td>
                  <td className={cn('num', x.return_rate >= 10 && 'text-warn')}>{x.return_rate}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      {owner && (
        <Panel>
          <PanelHeader title={t('insights.parts')} />
          {data.parts.length === 0 ? (
            empty
          ) : (
            <table className="w-full text-sm" data-testid="in-parts">
              <thead className={th}>
                <tr>
                  <th>{t('insights.part')}</th>
                  <th>{t('insights.uses')}</th>
                  <th>{t('insights.cost')}</th>
                  <th>{t('insights.share')}</th>
                </tr>
              </thead>
              <tbody>
                {data.parts.slice(0, 10).map((x) => (
                  <tr key={x.item_id} className={row} data-testid="in-part">
                    <td className="max-w-[12rem] truncate">{x.name}</td>
                    <td className="num">{Number(x.uses)}</td>
                    <td className="num">{f.money(x.cost)}</td>
                    <td className={cn('num', (x.share ?? 0) >= 5000 && 'text-danger', (x.share ?? 0) >= 3000 && (x.share ?? 0) < 5000 && 'text-warn')} data-testid="in-part-share">
                      {x.share == null ? '—' : `${f.number(Math.round(x.share / 100))}%`}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p className="px-3 pb-3 text-2xs text-fg-3">{t('insights.partsHint')}</p>
        </Panel>
      )}

      <Panel>
        <PanelHeader title={t('insights.forecast')} />
        {data.forecast.length === 0 ? (
          <p className="px-3 py-3 text-xs text-fg-3">{t('insights.forecastOk')}</p>
        ) : (
          <table className="w-full text-sm" data-testid="in-forecast">
            <thead className={th}>
              <tr>
                <th>{t('insights.item')}</th>
                <th>{t('insights.qty')}</th>
                <th>{t('insights.used30')}</th>
                <th>{t('insights.daysLeft')}</th>
                <th>{t('insights.buy')}</th>
              </tr>
            </thead>
            <tbody>
              {data.forecast.map((x) => (
                <tr key={x.id} className={row} data-testid="in-forecast-row">
                  <td className="max-w-[10rem] truncate">
                    <Link to="/inventory" className="hover:text-accent">
                      {x.name}
                    </Link>
                  </td>
                  <td className="num">{x.qty}</td>
                  <td className="num">{x.used}</td>
                  <td className={cn('num', x.level === 'out' ? 'text-danger' : x.level === 'soon' ? 'text-warn' : 'text-fg-2')} data-testid="in-days">
                    {x.level === 'out' ? t('insights.out') : t('insights.days', { n: x.days ?? 0 })}
                  </td>
                  <td className="num">{x.buy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
