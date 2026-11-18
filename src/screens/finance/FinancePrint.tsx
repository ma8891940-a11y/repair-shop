import { useEffect, type ReactNode } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
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
import { useBranch } from '../../app/branch';
import { defaultBlocks, normalizeBlocks, type Block, type BlockKey, type Size } from '../../lib/printTemplate';
import { cn } from '../../ui/cn';
import { VOUCHER_SOURCES } from '../../lib/ledger';

export function PrintFrame({ ready, children }: { ready: boolean; children: React.ReactNode }) {
  useBackground('off');
  const { t } = useTranslation();
  const navigate = useNavigate();
  // U5: معاينة مصمم الطباعة (جوه إطار): من غير نافذة طباعة ومن غير الشريط
  const [params] = useSearchParams();
  const preview = params.get('preview') === '1';
  const embed = params.get('embed') === '1';
  useEffect(() => {
    if (!ready || preview) return;
    const tm = setTimeout(() => window.print(), 350);
    return () => clearTimeout(tm);
  }, [ready, preview]);
  return (
    <div className="min-h-dvh bg-white text-black">
      <style>{'@page { size: A4; margin: 12mm; }'}</style>
      <div className={`flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-neutral-50 px-4 py-3 print:hidden${embed ? ' hidden' : ''}`}>
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

export function PrintHeader({ title, sub }: { title: string; sub: string }) {
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
  const br = useBranch();
  const [params] = useSearchParams();
  const preview = params.get('preview') === '1';
  const previewV = params.get('v');
  const { data } = useLoad(async () => {
    const st = await rpc<Statement>('statement', { p_kind: kind, p_id: id, p_from: range.from.toISOString(), p_to: range.to.toISOString() });
    let name = '';
    if (kind === 'linked') {
      const li = await loadLink('link', id);
      name = li ? `${li.customer} ⇄ ${li.supplier}` : '';
    } else {
      const table = kind === 'cashbox' ? 'accounts' : kind === 'customer' ? 'customers' : kind === 'supplier' ? 'suppliers' : kind === 'partner' ? 'partners' : 'profiles';
      const row = must(await supabase.from(table).select('*').eq('id', id).maybeSingle()) as Record<string, string | null> | null;
      name = kind === 'cashbox' ? accName(row as { code: string | null; name: string | null }) : (row?.name ?? row?.full_name ?? '');
    }
    // U5: قالب "كشف الحساب" الافتراضي (قالب الفرع الشغال يكسب قالب المحل)، أو مسودة المصمم في المعاينة
    const { data: ts } = await supabase.from('print_templates').select('branch_id, blocks').eq('doc', 'statement').eq('is_default', true).is('deleted_at', null);
    const list = (ts ?? []) as { branch_id: string | null; blocks: unknown }[];
    const pick = list.find((x) => x.branch_id && x.branch_id === br.working?.id) ?? list.find((x) => !x.branch_id);
    let draft: unknown = null;
    if (preview) {
      try {
        draft = JSON.parse(sessionStorage.getItem('tpl-preview:statement') ?? 'null');
      } catch {
        draft = null;
      }
    }
    const tpl = draft ? normalizeBlocks('statement', draft) : pick ? normalizeBlocks('statement', pick.blocks) : null;
    return { st, name, tpl };
  }, [kind, id, range.from.getTime(), range.to.getTime(), br.working?.id, preview, previewV]);
  const last = data?.st.moves.at(-1);
  const blocks = data ? (data.tpl ?? defaultBlocks('statement')) : [];
  // نفس مقاسات الكشف من غير قالب: العادي 12 والكبير 14 (الرصيد الختامي)
  const fs: Record<Size, string> = { sm: 'text-[11px]', md: 'text-[12px]', lg: 'text-[14px]' };
  const cls = (x: Block) => cn(fs[x.size], x.bold && 'font-bold', x.align === 'center' ? 'text-center' : x.align === 'end' ? 'text-end' : 'text-start');
  const shown = (k: BlockKey) => blocks.some((x) => x.key === k && x.show);
  const period = `${f.date(range.from)} - ${f.date(new Date(range.to.getTime() - 1))}`;
  const title = `${t('fin.statement')} · ${t(`fin.kinds.${kind as StatementKind}`)}`;
  // الرصيد الافتتاحي والحركات والختامي جدول واحد (زي الكشف من غير قالب)، في مكان أول واحد فيهم
  const TABLE: BlockKey[] = ['opening', 'moves', 'closing'];
  const tableAt = blocks.findIndex((x) => TABLE.includes(x.key) && x.show);
  const table = (rows: Block[]) => (
    <table key="table" className="w-full border-collapse">
      {rows.some((x) => x.key === 'moves') && (
        <thead>
          <tr className="[&_th]:border-b [&_th]:border-black [&_th]:px-1 [&_th]:py-1 [&_th]:text-start">
            <th>{t('fin.cols.time')}</th>
            <th>{t('fin.cols.desc')}</th>
            <th>{t('fin.cols.source')}</th>
            <th className="!text-end">{t('fin.cols.amount')}</th>
            <th className="!text-end">{t('fin.cols.balance')}</th>
          </tr>
        </thead>
      )}
      <tbody className="[&_td]:border-b [&_td]:border-dotted [&_td]:border-neutral-400 [&_td]:px-1 [&_td]:py-1">
        {rows.map((x) =>
          x.key === 'opening' ? (
            <tr key="opening" className={cls(x)} data-block="opening">
              <td colSpan={4} className={x.bold ? 'font-bold' : 'font-semibold'}>
                {t('fin.opening')}
              </td>
              <td className="text-end font-mono" dir="ltr" data-testid="statement-opening">
                {f.money(data!.st.opening)}
              </td>
            </tr>
          ) : x.key === 'moves' ? (
            data!.st.moves.map((m) => (
              <tr key={`${m.entry_id}-${m.account}`} className={cn(fs[x.size], x.bold && 'font-bold', m.reversed && 'text-neutral-500 line-through')} data-testid="statement-moves">
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
            ))
          ) : (
            <tr key="closing" className={cls(x)} data-block="closing">
              <td colSpan={4} className="!border-t-2 !border-solid !border-black">
                {t('fin.closingBalance')}
              </td>
              <td className="!border-t-2 !border-solid !border-black text-end font-mono" dir="ltr" data-testid="statement-closing">
                {f.money(last ? last.balance : data!.st.opening)}
              </td>
            </tr>
          ),
        )}
      </tbody>
    </table>
  );
  const render = (x: Block, i: number): ReactNode => {
    if (!x.show) return null;
    if (TABLE.includes(x.key)) return i === tableAt ? table(blocks.filter((b) => TABLE.includes(b.key) && b.show)) : null;
    switch (x.key) {
      case 'header':
        // اسم المحل ولوجوه، والعنوان والاسم والفترة جوه الرأس زي الكشف من غير قالب (كل واحد بيتخفي لوحده)
        return (
          <PrintHeader
            key="header"
            title={shown('title') ? title : ''}
            sub={[shown('party') ? data!.name : '', shown('period') ? period : ''].filter(Boolean).join(' · ')}
          />
        );
      case 'title':
        return shown('header') ? null : (
          <div key="title" className={cn('mb-1', cls(x))} data-block="title">
            {title}
          </div>
        );
      case 'party':
        return shown('header') ? (
          <span key="party" className="hidden" data-testid="statement-party">
            {data!.name}
          </span>
        ) : (
          <div key="party" className={cls(x)} data-block="party" data-testid="statement-party">
            <bdi>{data!.name}</bdi>
          </div>
        );
      case 'period':
        return shown('header') ? null : (
          <div key="period" className={cn('mb-2', cls(x))} data-block="period">
            {period}
          </div>
        );
      case 'signature':
        return (
          <div key="signature" className={cn('mt-6', cls(x))} data-block="signature">
            {t('print.sign')}: ..............................
          </div>
        );
      case 'thanks':
        return (
          <div key="thanks" className={cn('mt-2 text-neutral-600', cls(x))} data-block="thanks">
            {t('print.thanks')}
          </div>
        );
      case 'text':
        return x.text ? (
          <p key={`text-${i}`} className={cn('mt-2 whitespace-pre-wrap', cls(x))} data-block="text">
            {x.text}
          </p>
        ) : null;
      default:
        return null;
    }
  };
  return (
    // نستنى الفروع كمان، عشان الطباعة ما تبدأش بقالب المحل قبل ما قالب الفرع يوصل
    <PrintFrame ready={!!data && br.ready}>
      {data && <div data-testid="print-statement">{blocks.map(render)}</div>}
    </PrintFrame>
  );
}

/**
 * U5: سند قبض أو صرف لقيد واحد (A4) بقالب من مصمم الطباعة.
 * المبلغ = حركة الخزنة في القيد نفسه (من غير أي حساب جديد)، والطرف التاني من سطور القيد.
 */
export function VoucherPrint() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  const br = useBranch();
  const [params] = useSearchParams();
  const preview = params.get('preview') === '1';
  const previewV = params.get('v');
  const { data, error } = useLoad(async () => {
    const e = must(await supabase.from('journal_entries').select('id, entry_no, occurred_at, source_type, memo, branch_id').eq('id', id).maybeSingle()) as
      | { id: string; entry_no: number; occurred_at: string; source_type: string; memo: string | null; branch_id: string | null }
      | null;
    if (!e || !VOUCHER_SOURCES.includes(e.source_type)) throw new Error('E_NOT_FOUND');
    const lines = (must(await supabase.from('journal_lines').select('account_id, party_type, party_id, debit, credit').eq('entry_id', id)) ?? []) as {
      account_id: string;
      party_type: string | null;
      party_id: string | null;
      debit: number;
      credit: number;
    }[];
    const accs = (must(await supabase.from('accounts').select('id, code, name, kind').in('id', [...new Set(lines.map((l) => l.account_id))])) ?? []) as {
      id: string;
      code: string | null;
      name: string | null;
      kind: string;
    }[];
    const cashIds = new Set(accs.filter((a) => a.kind === 'cash').map((a) => a.id));
    const cashLine = lines.find((l) => cashIds.has(l.account_id));
    if (!cashLine) throw new Error('E_NOT_FOUND');
    const receipt = Number(cashLine.debit) > 0;
    const amount = receipt ? Number(cashLine.debit) : Number(cashLine.credit);
    // الطرف التاني: عميل أو مورد أو موظف، أو بند المصروف
    const pl = lines.find((l) => l.party_type && l.party_id);
    let party = '';
    if (pl) {
      const table = pl.party_type === 'customer' ? 'customers' : pl.party_type === 'supplier' ? 'suppliers' : 'profiles';
      const row = (await supabase.from(table).select('*').eq('id', pl.party_id as string).maybeSingle()).data as Record<string, string | null> | null;
      party = row?.name ?? row?.full_name ?? '';
    } else {
      const other = lines.find((l) => !cashIds.has(l.account_id));
      const a = accs.find((x) => x.id === other?.account_id);
      party = a ? accName(a) : '';
    }
    const cash = accs.find((a) => a.id === cashLine.account_id)!;
    const pay = e.source_type === 'payment' ? ((await supabase.from('payments').select('method').eq('entry_id', id).maybeSingle()).data as { method: string } | null) : null;
    const { data: ts } = await supabase.from('print_templates').select('branch_id, blocks').eq('doc', 'voucher').eq('is_default', true).is('deleted_at', null);
    const list = (ts ?? []) as { branch_id: string | null; blocks: unknown }[];
    const pick = list.find((x) => x.branch_id && x.branch_id === (e.branch_id ?? br.working?.id)) ?? list.find((x) => !x.branch_id);
    let draft: unknown = null;
    if (preview) {
      try {
        draft = JSON.parse(sessionStorage.getItem('tpl-preview:voucher') ?? 'null');
      } catch {
        draft = null;
      }
    }
    const tpl = draft ? normalizeBlocks('voucher', draft) : pick ? normalizeBlocks('voucher', pick.blocks) : null;
    return { e, receipt, amount, party, cashbox: accName(cash), method: pay?.method ?? null, tpl };
  }, [id, preview, previewV, br.working?.id]);
  const blocks = data ? (data.tpl ?? defaultBlocks('voucher')) : [];
  const fs: Record<Size, string> = { sm: 'text-[12px]', md: 'text-[14px]', lg: 'text-[20px]' };
  const cls = (x: Block) => cn(fs[x.size], x.bold && 'font-bold', x.align === 'center' ? 'text-center' : x.align === 'end' ? 'text-end' : 'text-start');
  const title = data ? t(data.receipt ? 'voucher.receipt' : 'voucher.payment') : '';
  const row = (x: Block, label: ReactNode, value: ReactNode, testid?: string, mono = false) => (
    <div key={x.key} className={cn('flex gap-2 border-b border-dotted border-neutral-400 px-1 py-1.5', fs[x.size], x.bold && 'font-bold', x.align === 'center' && 'justify-center', x.align === 'end' && 'justify-end')} data-block={x.key}>
      <span className="w-[30%] shrink-0 font-semibold">{label}</span>
      <span className={cn('min-w-0', mono && 'font-mono')} dir={mono ? 'ltr' : undefined} data-testid={testid}>
        {value}
      </span>
    </div>
  );
  const render = (x: Block, i: number): ReactNode => {
    if (!x.show || !data) return null;
    switch (x.key) {
      case 'header':
        return <PrintHeader key="header" title={blocks.some((b) => b.key === 'title' && b.show) ? title : ''} sub={blocks.some((b) => b.key === 'entryNo' && b.show) ? `#${data.e.entry_no}` : ''} />;
      case 'title':
        return blocks.some((b) => b.key === 'header' && b.show) ? null : (
          <div key="title" className={cn('mb-2', cls(x))} data-block="title">
            {title}
          </div>
        );
      case 'entryNo':
        return blocks.some((b) => b.key === 'header' && b.show) ? null : row(x, t('voucher.no'), `#${data.e.entry_no}`, undefined, true);
      case 'date':
        return row(x, t('print.date'), f.dateTime(data.e.occurred_at));
      case 'party':
        return data.party ? row(x, t(data.receipt ? 'voucher.from' : 'voucher.to'), <bdi>{data.party}</bdi>, 'voucher-party') : null;
      case 'amount':
        return row(x, t('voucher.amount'), `${f.money(data.amount)} ${f.currency()}`, 'voucher-amount', true);
      case 'method':
        return data.method ? row(x, t('voucher.method'), t(`payments.${data.method}`, { defaultValue: data.method })) : null;
      case 'cashbox':
        return row(x, t('voucher.cashbox'), data.cashbox, 'voucher-cashbox');
      case 'memo':
        return row(x, t('voucher.memo'), `${t(`fin.src.${data.e.source_type}`)}${data.e.memo ? ` - ${data.e.memo}` : ''}`);
      case 'sign':
        return (
          <div key="sign" className={cn('mt-8 grid grid-cols-2 gap-6', cls(x))} data-block="sign">
            <div>{t('voucher.signReceiver')}: ..............................</div>
            <div>{t('voucher.signCashier')}: ..............................</div>
          </div>
        );
      case 'thanks':
        return (
          <div key="thanks" className={cn('mt-3 text-neutral-600', cls(x))} data-block="thanks">
            {t('print.thanks')}
          </div>
        );
      case 'text':
        return x.text ? (
          <p key={`text-${i}`} className={cn('mt-2 whitespace-pre-wrap', cls(x))} data-block="text">
            {x.text}
          </p>
        ) : null;
      default:
        return null;
    }
  };
  if (error) return <p className="p-6 text-sm text-red-700">{error}</p>;
  return (
    <PrintFrame ready={!!data && br.ready}>
      {data && (
        <div data-testid="print-voucher" data-kind={data.receipt ? 'receipt' : 'payment'}>
          {blocks.map(render)}
        </div>
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
          <PrintHeader title={t('fin.dayReport')} sub={f.dateLong(cairoDayStart(day))} />
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
