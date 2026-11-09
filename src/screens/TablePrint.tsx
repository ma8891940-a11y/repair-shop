import { useTranslation } from 'react-i18next';
import { getPendingTable } from '../app/exporting';
import { PrintFrame, PrintHeader } from './finance/FinancePrint';
import { useFormat } from '../i18n/format';
import type { Cell, ColType } from '../lib/xlsx';
import { EmptyState } from '../ui/Feedback';

/** PDF من أي شاشة: نفس جدول التصدير على A4 بلوجو المحل والعنوان والفترة وتاريخ الطباعة. "حفظ كـ PDF" من نافذة الطباعة */
export function TablePrint() {
  const { t } = useTranslation();
  const f = useFormat();
  const tb = getPendingTable();
  if (!tb) return <EmptyState title={t('export.nothing')} />;
  const fmt = (v: Cell, type: ColType = 'text') => {
    if (v == null || v === '') return '';
    if (type === 'money' && typeof v === 'number') return f.money(v);
    if (type === 'int' && typeof v === 'number') return f.number(v);
    if (type === 'date' && typeof v === 'string') return f.date(v);
    if (type === 'datetime' && typeof v === 'string') return f.dateTime(v);
    return String(v);
  };
  const [shopName, ...meta] = tb.meta ?? [];
  void shopName; // اسم المحل في الترويسة نفسها
  const totals = tb.columns.map((c, i) => (c.total ? tb.rows.reduce((s, r) => s + (typeof r[i] === 'number' ? (r[i] as number) : 0), 0) : null));
  const num = (c: { type?: ColType }) => c.type === 'money' || c.type === 'int';
  return (
    <PrintFrame ready>
      <PrintHeader title={tb.title} sub={meta.join(' · ')} />
      <table className="w-full border-collapse" data-testid="table-print">
        <thead>
          <tr className="[&_th]:border-b [&_th]:border-black [&_th]:px-1 [&_th]:py-1 [&_th]:text-start">
            {tb.columns.map((c) => (
              <th key={c.header}>{c.header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {tb.rows.map((r, ri) => (
            <tr key={ri} className="[&_td]:border-b [&_td]:border-neutral-200 [&_td]:px-1 [&_td]:py-0.5 break-inside-avoid">
              {tb.columns.map((c, i) => (
                <td key={i} className={num(c) ? 'font-mono' : undefined} dir={num(c) ? 'ltr' : undefined} style={num(c) ? { textAlign: 'end' } : undefined}>
                  {fmt(r[i], c.type)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
        {totals.some((x) => x != null) && (
          <tfoot>
            <tr className="font-bold [&_td]:border-t-2 [&_td]:border-black [&_td]:px-1 [&_td]:py-1" data-testid="table-print-total">
              {tb.columns.map((c, i) => (
                <td key={i} className={num(c) ? 'font-mono' : undefined} dir={num(c) ? 'ltr' : undefined} style={num(c) ? { textAlign: 'end' } : undefined}>
                  {i === 0 && totals[0] == null ? tb.totalLabel : totals[i] != null ? fmt(totals[i], c.type) : ''}
                </td>
              ))}
            </tr>
          </tfoot>
        )}
      </table>
      {tb.rows.length === 0 && <p className="mt-4 text-center text-neutral-600">{t('export.empty')}</p>}
      <p className="mt-3 text-[10px] text-neutral-600">{t('export.rows', { n: tb.rows.length })}</p>
    </PrintFrame>
  );
}
