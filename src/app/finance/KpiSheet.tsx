import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowUpRight, Search } from 'lucide-react';
import { useMe } from '../auth';
import { useLoad } from '../useLoad';
import { rpc, sortCashboxes, useAccountName, type Position, type StockRow } from '../ledgerApi';
import { ExportMenu } from '../exporting';
import { useFormat } from '../../i18n/format';
import { toLatinDigits } from '../../lib/digits';
import { Sheet } from '../../ui/Sheet';
import { Select } from '../../ui/Field';
import { Checkbox } from '../../ui/Checkbox';
import { EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

export type KpiKey = 'cash' | 'receivables' | 'payables' | 'inventory' | 'profit' | 'net_worth';
interface Row {
  id: string;
  label: string;
  /** نوع السطر (للفلتر): خزنة، عميل، مورد، موظف، إيراد، مصروف... */
  group: string;
  amount: number;
  qty?: number;
  date?: string | null;
  to?: string;
}
type Sort = 'amount_desc' | 'amount_asc' | 'name';

/**
 * البند 8: كل كارت في الوضع المالي بيفتح تفاصيله في لوح جانبي: بحث، وفلتر بالنوع، وإخفاء الأصفار،
 * وترتيب، وتصدير لنفس اللي ظاهر. و"افتح الصفحة كاملة" للصفحة اللي كانت موجودة قبل كده.
 */
export function KpiSheet({ kpi, onClose, p, range, query, page }: { kpi: KpiKey | null; onClose: () => void; p: Position | undefined; range: { from: Date; to: Date; days: string[] }; query: string; page: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const accName = useAccountName();
  const [q, setQ] = useState('');
  const [group, setGroup] = useState('');
  const [hideZero, setHideZero] = useState(true);
  const [sort, setSort] = useState<Sort>('amount_desc');

  const { data, error, loading, reload } = useLoad(async (): Promise<Row[]> => {
    if (!kpi || !p) return [];
    const args = { p_from: range.from.toISOString(), p_to: range.to.toISOString() };
    if (kpi === 'cash') return sortCashboxes(p.cashboxes).map((cb) => ({ id: cb.id, label: accName(cb), group: t(`payments.${cb.method}`, { defaultValue: cb.method }), amount: Number(cb.balance), to: `/finance/cashbox/${cb.id}${query}` }));
    if (kpi === 'receivables' || kpi === 'payables') {
      const kinds = kpi === 'receivables' ? ['customers'] : ['suppliers', 'employees'];
      const all = await Promise.all(kinds.map((k) => rpc<{ party_type: string; party_id: string; name: string | null; account: string; balance: number; oldest: string | null }[]>('party_balances', { p_kind: k })));
      return all.flat().map((r) => ({ id: `${r.party_id}-${r.account}`, label: r.name ?? '', group: t(`fin.kinds.${r.party_type}`), amount: Number(r.balance), date: r.oldest, to: `/finance/${r.party_type}/${r.party_id}` }));
    }
    if (kpi === 'inventory') {
      const items = await rpc<StockRow[]>('items_stock');
      return items.map((i) => ({ id: i.id, label: i.name, group: t(`inv.kinds.${i.kind}`), amount: Number(i.value ?? 0), qty: Number(i.qty), to: '/inventory' }));
    }
    if (kpi === 'profit') {
      const r = await rpc<{ account_id: string; code: string | null; name: string | null; type: 'revenue' | 'expense'; amount: number }[]>('pl_breakdown', args);
      // في الربح: المصروف بيتحسب بالسالب عشان المجموع يطلع صافي الربح بالظبط
      return r.map((x) => ({ id: x.account_id, label: accName(x), group: t(x.type === 'revenue' ? 'fin.revenue' : 'fin.expenses'), amount: x.type === 'revenue' ? Number(x.amount) : -Number(x.amount), to: `/finance/pl${query}` }));
    }
    // صافي قيمة المحل: الأصول ناقص الالتزامات
    const e = p.equation;
    return [
      { id: 'assets', label: t('fin.eq.assets'), group: t('fin.eq.assets'), amount: Number(e.assets) },
      { id: 'liabilities', label: t('fin.eq.liabilities'), group: t('fin.eq.liabilities'), amount: -Number(e.liabilities) },
    ];
  }, [kpi, p, range.from.getTime(), range.to.getTime()]);

  const groups = useMemo(() => [...new Set((data ?? []).map((r) => r.group))], [data]);
  const needle = toLatinDigits(q.trim()).toLowerCase();
  const rows = useMemo(() => {
    const list = (data ?? []).filter((r) => (!group || r.group === group) && (!hideZero || r.amount !== 0 || (r.qty ?? 0) !== 0) && (!needle || toLatinDigits(r.label).toLowerCase().includes(needle)));
    const cmp: Record<Sort, (a: Row, b: Row) => number> = {
      amount_desc: (a, b) => b.amount - a.amount || a.label.localeCompare(b.label),
      amount_asc: (a, b) => a.amount - b.amount || a.label.localeCompare(b.label),
      name: (a, b) => a.label.localeCompare(b.label, 'ar'),
    };
    return [...list].sort(cmp[sort]);
  }, [data, group, hideZero, needle, sort]);
  const total = rows.reduce((a, r) => a + r.amount, 0);
  const title = kpi ? t(`fin.kpi.${kpi}`) : '';
  const period = t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) });

  return (
    <Sheet
      open={!!kpi}
      onOpenChange={(v) => {
        if (!v) {
          onClose();
          setQ('');
          setGroup('');
        }
      }}
      title={title}
      description={kpi ? t(`fin.kpiCap.${kpi}`) : undefined}
      testid="kpi-sheet"
      actions={
        <ExportMenu
          testid="kpi-export"
          disabled={!data}
          table={() => ({
            title,
            file: `finance-${kpi}`,
            meta: [period, group ? t('export.filter', { v: group }) : '', q.trim() ? t('export.search', { v: q.trim() }) : ''].filter(Boolean),
            columns: [
              { header: t('export.cols.item') },
              { header: t('export.cols.kind') },
              ...(kpi === 'inventory' ? [{ header: t('inv.cols.qty'), type: 'int' as const }] : []),
              ...(kpi === 'receivables' || kpi === 'payables' ? [{ header: t('export.cols.oldest'), type: 'date' as const }] : []),
              { header: t('fin.cols.amount'), type: 'money' as const, total: true },
            ],
            rows: rows.map((r) => [r.label, r.group, ...(kpi === 'inventory' ? [r.qty ?? 0] : []), ...(kpi === 'receivables' || kpi === 'payables' ? [r.amount > 0 ? (r.date ?? null) : null] : []), r.amount]),
          })}
        />
      }
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative min-w-[180px] flex-1">
            <Search className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={t('kpi.search')}
              aria-label={t('kpi.search')}
              className="h-8 w-full rounded-md border border-line bg-sunken/60 pe-2 ps-8 text-sm text-fg placeholder:text-fg-3 focus:border-accent focus:outline-none"
              data-testid="kpi-search"
            />
          </div>
          <Select value={sort} onChange={(e) => setSort(e.target.value as Sort)} aria-label={t('kpi.sort')} className="h-8 w-auto text-sm" data-testid="kpi-sort">
            <option value="amount_desc">{t('kpi.sorts.amount_desc')}</option>
            <option value="amount_asc">{t('kpi.sorts.amount_asc')}</option>
            <option value="name">{t('kpi.sorts.name')}</option>
          </Select>
        </div>
        {groups.length > 1 && (
          <div className="flex flex-wrap gap-1" role="group" aria-label={t('kpi.filter')}>
            {['', ...groups].map((g) => (
              <button key={g || 'all'} type="button" aria-pressed={group === g} onClick={() => setGroup(g)} className={cn('h-7 rounded-full border px-3 text-xs', group === g ? 'border-[rgb(var(--accent-rgb)/0.5)] bg-accent-soft text-accent' : 'border-line text-fg-2 hover:text-fg')}>
                {g || t('devices.all')}
              </button>
            ))}
          </div>
        )}
        <Checkbox checked={hideZero} onChange={setHideZero} label={t('kpi.hideZero')} />
        {error ? (
          <ErrorState message={error} onRetry={reload} />
        ) : loading || !data ? (
          <Skeleton className="h-40 w-full" />
        ) : rows.length === 0 ? (
          <EmptyState line="wallet" title={t('kpi.empty')} />
        ) : (
          <ul className="divide-y divide-glass-border text-sm" data-testid="kpi-rows">
            {rows.map((r) => {
              const inner = (
                <>
                  <span className="min-w-0 flex-1">
                    <bdi className="block truncate text-fg">{r.label}</bdi>
                    <span className="text-2xs text-fg-3">
                      {r.group}
                      {r.qty != null && ` · ${t('inv.cols.qty')} ${f.number(r.qty)}`}
                      {r.date && r.amount > 0 && ` · ${t('export.cols.oldest')} ${f.date(r.date)}`}
                    </span>
                  </span>
                  <span className={cn('num shrink-0', r.amount < 0 ? 'text-danger' : 'text-fg')}>{f.money(r.amount)}</span>
                </>
              );
              return (
                <li key={r.id} data-testid="kpi-row">
                  {r.to ? (
                    <Link to={r.to} onClick={onClose} className="flex items-center gap-3 py-2 hover:bg-raised/40">
                      {inner}
                    </Link>
                  ) : (
                    <div className="flex items-center gap-3 py-2">{inner}</div>
                  )}
                </li>
              );
            })}
          </ul>
        )}
        <div className="flex items-center justify-between border-t border-glass-border pt-2 text-sm font-semibold">
          <span className="text-fg-2">{t('export.total')}</span>
          <span className="num text-fg" data-testid="kpi-total">
            {f.money(total)} <span className="font-sans text-2xs font-normal text-fg-3">{f.currency(shop.currency)}</span>
          </span>
        </div>
        <Link to={page} onClick={onClose} className="inline-flex items-center gap-1 self-start text-sm text-accent hover:underline" data-testid="kpi-open-page">
          {t('kpi.openPage')} <ArrowUpRight className="size-3.5 rtl:-scale-x-100" aria-hidden />
        </Link>
      </div>
    </Sheet>
  );
}
