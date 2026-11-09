import { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useBackground } from '../../app/stage';
import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { useLoad, must } from '../../app/useLoad';
import { loadLink } from '../../app/finance/PartyLink';
import { rpc, useAccountName, type Position, type Statement, type StatementKind } from '../../app/ledgerApi';
import { usePeriod } from '../../app/finance/PeriodFilter';
import { supabase } from '../../lib/supabase';
import { cairoDayEnd, cairoDayStart } from '../../lib/dates';
import { useFormat } from '../../i18n/format';
import { Skeleton } from '../../ui/Feedback';
import { ColorHeader, useBranding } from '../../app/brand/branding';

function PrintFrame({ ready, children }: { ready: boolean; children: React.ReactNode }) {
  useBackground('off');
  const { t } = useTranslation();
  const navigate = useNavigate();
  useEffect(() => {
    if (!ready) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ready]);
  return (
    <div className="min-h-dvh bg-white text-black">
      <style>{'@page { size: A4; margin: 12mm; }'}</style>
      <div className="flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden">
        <button type="button" onClick={() => window.print()} className="h-9 rounded-md bg-accent px-4 text-sm font-semibold text-on-accent">
          {t('print.print')}
        </button>
        <button type="button" onClick={() => navigate(-1)} className="h-9 rounded-md border border-neutral-300 px-4 text-sm">
          {t('print.back')}
        </button>
        <span className="text-xs text-neutral-600">{t('fin.pdfHint')}</span>
      </div>
      <article className="mx-auto max-w-[190mm] p-[8mm] text-[12px] print:max-w-none print:p-0">{ready ? children : <Skeleton className="h-40 w-full" />}</article>
    </div>
  );
}

function Header({ title, sub }: { title: string; sub: string }) {
  const { shop } = useMe();
  const branding = useBranding();
  return (
    <div className="mb-4">
      <ColorHeader shop={shop} b={branding.data ?? null} title={title} sub={sub} />
    </div>
  );
}

/** طباعة كشف حساب (خزنة / عميل / مورد / موظف) للفترة. "حفظ كـ PDF" من نافذة الطباعة */
export function StatementPrint() {
  const { kind = 'cashbox', id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  const { range } = usePeriod();
  const { data } = useLoad(async () => {
    const st = await rpc<Statement>('statement', { p_kind: kind, p_id: id, p_from: range.from.toISOString(), p_to: range.to.toISOString() });
    if (kind === 'linked') {
      const li = await loadLink('link', id);
      return { st, name: li ? `${li.customer} ⇄ ${li.supplier}` : '' };
    }
    const table = kind === 'cashbox' ? 'accounts' : kind === 'customer' ? 'customers' : kind === 'supplier' ? 'suppliers' : kind === 'partner' ? 'partners' : 'profiles';
    const row = must(await supabase.from(table).select('*').eq('id', id).maybeSingle()) as Record<string, string | null> | null;
    const name = kind === 'cashbox' ? accName(row as { code: string | null; name: string | null }) : (row?.name ?? row?.full_name ?? '');
    return { st, name };
  }, [kind, id, range.from.getTime(), range.to.getTime()]);
  const last = data?.st.moves.at(-1);
  return (
    <PrintFrame ready={!!data}>
      {data && (
        <>
          <Header title={`${t('fin.statement')} · ${t(`fin.kinds.${kind as StatementKind}`)}`} sub={`${data.name} · ${f.date(range.from)} - ${f.date(new Date(range.to.getTime() - 1))}`} />
          <table className="w-full border-collapse">
            <thead>
              <tr className="[&_th]:border-b [&_th]:border-black [&_th]:px-1 [&_th]:py-1 [&_th]:text-start">
                <th>{t('fin.cols.time')}</th>
                <th>{t('fin.cols.desc')}</th>
                <th>{t('fin.cols.source')}</th>
                <th className="!text-end">{t('fin.cols.amount')}</th>
                <th className="!text-end">{t('fin.cols.balance')}</th>
              </tr>
            </thead>
            <tbody className="[&_td]:border-b [&_td]:border-dotted [&_td]:border-neutral-400 [&_td]:px-1 [&_td]:py-1">
              <tr>
                <td colSpan={4} className="font-semibold">
                  {t('fin.opening')}
                </td>
                <td className="text-end font-mono" dir="ltr">
                  {f.money(data.st.opening)}
                </td>
              </tr>
              {data.st.moves.map((m) => (
                <tr key={`${m.entry_id}-${m.account}`} className={m.reversed ? 'text-neutral-500 line-through' : ''}>
                  <td className="whitespace-nowrap font-mono">{f.dateTime(m.at)}</td>
                  <td>
                    {t(`fin.src.${m.source_type}`)}
                    {m.memo ? ` - ${m.memo}` : ''}
                  </td>
                  <td className="font-mono" dir="ltr">
                    {m.order_no ?? ''}
                  </td>
                  <td className="text-end font-mono" dir="ltr">
                    {f.money(m.amount)}
                  </td>
                  <td className="text-end font-mono" dir="ltr">
                    {f.money(m.balance)}
                  </td>
                </tr>
              ))}
              <tr className="text-[14px] font-bold">
                <td colSpan={4} className="!border-t-2 !border-solid !border-black">
                  {t('fin.closingBalance')}
                </td>
                <td className="!border-t-2 !border-solid !border-black text-end font-mono" dir="ltr">
                  {f.money(last ? last.balance : data.st.opening)}
                </td>
              </tr>
            </tbody>
          </table>
        </>
      )}
    </PrintFrame>
  );
}

/** تقرير اليوم: الإيرادات والمصروفات والربح، والدفعات بكل طريقة، والأجهزة المسلّمة، وتقفيلات الدرج */
export function DayReportPrint() {
  const { day = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  const { data } = useLoad(async () => {
    const from = cairoDayStart(day).toISOString();
    const to = cairoDayEnd(day).toISOString();
    const [p, pl] = await Promise.all([
      rpc<Position>('financial_position', { p_from: from, p_to: to }),
      rpc<{ account_id: string; code: string | null; name: string | null; type: 'revenue' | 'expense'; amount: number }[]>('pl_breakdown', { p_from: from, p_to: to }),
    ]);
    return { p, pl };
  }, [day]);
  const Line = ({ label, value, bold }: { label: string; value: string; bold?: boolean }) => (
    <tr className={bold ? 'font-bold' : ''}>
      <td className="py-0.5">{label}</td>
      <td className="py-0.5 text-end font-mono" dir="ltr">
        {value}
      </td>
    </tr>
  );
  return (
    <PrintFrame ready={!!data}>
      {data && (
        <>
          <Header title={t('fin.dayReport')} sub={f.dateLong(cairoDayStart(day))} />
          <div className="grid grid-cols-2 gap-6">
            <section>
              <h2 className="mb-1 border-b border-black font-semibold">{t('fin.revenue')}</h2>
              <table className="w-full">
                <tbody>
                  {data.pl
                    .filter((r) => r.type === 'revenue')
                    .map((r) => (
                      <Line key={r.account_id} label={accName(r)} value={f.money(Number(r.amount))} />
                    ))}
                  <Line label={t('fin.total')} value={f.money(data.p.revenue)} bold />
                </tbody>
              </table>
              <h2 className="mb-1 mt-4 border-b border-black font-semibold">{t('fin.expenses')}</h2>
              <table className="w-full">
                <tbody>
                  {data.pl
                    .filter((r) => r.type === 'expense')
                    .map((r) => (
                      <Line key={r.account_id} label={accName(r)} value={f.money(Number(r.amount))} />
                    ))}
                  <Line label={t('fin.total')} value={f.money(data.p.expenses)} bold />
                </tbody>
              </table>
              <div className="mt-3 border-t-2 border-black pt-1">
                <table className="w-full">
                  <tbody>
                    <Line label={t('fin.kpi.profit')} value={f.money(data.p.profit)} bold />
                  </tbody>
                </table>
              </div>
            </section>
            <section>
              <h2 className="mb-1 border-b border-black font-semibold">{t('fin.byMethod')}</h2>
              <table className="w-full">
                <tbody>
                  {Object.entries(data.p.by_method).map(([m, v]) => (
                    <Line key={m} label={t(`payments.${m}`, { defaultValue: m })} value={f.money(Number(v))} />
                  ))}
                  {Object.keys(data.p.by_method).length === 0 && <Line label={t('fin.noMoves')} value="" />}
                </tbody>
              </table>
              <h2 className="mb-1 mt-4 border-b border-black font-semibold">{t('fin.cashboxes')}</h2>
              <table className="w-full">
                <tbody>
                  {data.p.cashboxes.map((c) => (
                    <Line key={c.id} label={accName(c)} value={f.money(c.balance)} />
                  ))}
                </tbody>
              </table>
              <h2 className="mb-1 mt-4 border-b border-black font-semibold">{t('fin.closings')}</h2>
              <table className="w-full">
                <tbody>
                  {data.p.closings.map((c, i) => (
                    <Line key={i} label={`${c.by ?? ''} · ${f.dateTime(c.at)}`} value={`${f.money(Number(c.counted))} (${f.money(Number(c.diff))})`} />
                  ))}
                  {data.p.closings.length === 0 && <Line label={t('fin.noClosings')} value="" />}
                </tbody>
              </table>
              <p className="mt-4">
                {t('fin.deliveredCount')}: <b className="font-mono">{f.number(Number(data.p.delivered))}</b>
              </p>
            </section>
          </div>
        </>
      )}
    </PrintFrame>
  );
}
