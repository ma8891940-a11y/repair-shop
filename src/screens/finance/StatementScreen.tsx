import { useMemo, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { PlansPanel } from '../../app/finance/PlansPanel';
import { useCanCorrect } from '../../app/correct';
import { entrySection } from '../../lib/entrySection';
import { ArrowLeft, ArrowDownUp, HandCoins, Lock, Pencil, Printer, Search, Undo2, Users, Wallet } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useBranch } from '../../app/branch';
import { useLoad, must } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { rpc, useAccountName, type Move, type Statement, type StatementKind } from '../../app/ledgerApi';
import { OpDialog, type Op, type OpFixed } from '../../app/finance/OpDialog';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { CloseDrawerDialog } from '../../app/finance/CloseDrawerDialog';
import { ReverseDialog } from '../../app/finance/ReverseDialog';
import { EditEntryDialog } from '../../app/finance/EditEntryDialog';
import { loadLink, NettingDialog, PartyLinkBar, type LinkInfo } from '../../app/finance/PartyLink';
import { EDITABLE_SOURCES } from '../../lib/ledger';
import { WhatsAppButton, WhatsAppDialog, type MessageTarget } from '../../app/messaging';
import { supabase } from '../../lib/supabase';
import { matchMove, plainPounds, toCsv } from '../../lib/ledger';
import { ExportMenu } from '../../app/exporting';
import type { ExportTable } from '../../lib/xlsx';
import { useFormat } from '../../i18n/format';
import { Panel } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

const KINDS: StatementKind[] = ['cashbox', 'customer', 'supplier', 'employee', 'partner', 'linked'];
type Dir = 'all' | 'in' | 'out';

interface Head {
  link?: LinkInfo | null;
  title: string;
  sub?: string;
  phone?: string;
  balance: number;
  fixed: OpFixed;
}

/** كشف حساب: خزنة أو عميل أو مورد أو موظف. كل الحركات بالترتيب والرصيد بعد كل حركة */
export function StatementScreen() {
  const { kind: k = '', id = '' } = useParams();
  const kind = (KINDS.includes(k as StatementKind) ? k : 'cashbox') as StatementKind;
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, profile } = useMe();
  const accName = useAccountName();
  const navigate = useNavigate();
  const location = useLocation();
  const { period, range, set, query } = usePeriod();
  const [q, setQ] = useState('');
  const [dir, setDir] = useState<Dir>('all');
  const [op, setOp] = useState<Op | null>(null);
  const [closing, setClosing] = useState(false);
  const canCorrect = useCanCorrect();
  const [reverse, setReverse] = useState<Move | null>(null);
  const [edit, setEdit] = useState<Move | null>(null);
  const [netting, setNetting] = useState<LinkInfo | null>(null);
  const [wa, setWa] = useState(false);
  const cur = f.currency(shop.currency);

  const br = useBranch();
  const { data, error, loading, reload } = useLoad(async () => {
    const st = await rpc<Statement>('statement', { p_kind: kind, p_id: id, p_from: range.from.toISOString(), p_to: range.to.toISOString() });
    const all = await rpc<Statement>('statement', { p_kind: kind, p_id: id, p_from: range.from.toISOString(), p_to: new Date(Date.now() + 86_400_000).toISOString() });
    const balance = all.moves.length ? all.moves[all.moves.length - 1].balance : all.opening;
    let head: Head;
    if (kind === 'cashbox') {
      const a = must(await supabase.from('accounts').select('id, code, name, method').eq('id', id).maybeSingle()) as { id: string; code: string | null; name: string | null; method: string } | null;
      head = { title: accName(a), sub: a ? t(`payments.${a.method}`, { defaultValue: a.method }) : '', balance, fixed: { cashbox: id } };
    } else if (kind === 'customer') {
      const c = must(await supabase.from('customers').select('id, name, phone').eq('id', id).maybeSingle()) as { id: string; name: string; phone: string } | null;
      head = { title: c?.name ?? '', phone: c?.phone, balance, fixed: c ? { customer: { id: c.id, name: c.name } } : {} };
    } else if (kind === 'supplier') {
      const s = must(await supabase.from('suppliers').select('id, name, phone').eq('id', id).maybeSingle()) as { id: string; name: string; phone: string | null } | null;
      head = { title: s?.name ?? '', phone: s?.phone ?? undefined, balance, fixed: s ? { supplier: { id: s.id, name: s.name } } : {} };
    } else if (kind === 'linked') {
      const li = await loadLink('link', id);
      head = { title: li ? `${li.customer} ⇄ ${li.supplier}` : '', sub: t('link.netSub'), balance, fixed: {}, link: li };
    } else if (kind === 'partner') {
      const p = must(await supabase.from('partners').select('id, name, phone, share_bp').eq('id', id).maybeSingle()) as { id: string; name: string; phone: string | null; share_bp: number } | null;
      head = { title: p?.name ?? '', sub: p ? t('partners.shareOf', { p: f.percentBp(p.share_bp) }) : '', phone: p?.phone ?? undefined, balance, fixed: {} };
    } else {
      const p = must(await supabase.from('profiles').select('id, full_name, role').eq('id', id).maybeSingle()) as { id: string; full_name: string; role: string } | null;
      head = { title: p?.full_name ?? '', sub: p ? t(`roles.${p.role}`) : '', balance, fixed: p ? { employee: { id: p.id, name: p.full_name } } : {} };
    }
    return { st, head };
  }, [kind, id, range.from.getTime(), range.to.getTime(), br.working?.id]);
  useLiveRefresh(reload);

  const label = (m: Move) => (m.source_type === 'reversal' ? t('fin.src.reversal') : t(`fin.src.${m.source_type}`));
  const moves = useMemo(
    () => (data?.st.moves ?? []).filter((m) => (dir === 'all' || (dir === 'in' ? m.amount > 0 : m.amount < 0)) && matchMove(m, q, label(m))),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [data, dir, q, t],
  );
  const totals = useMemo(() => {
    let inn = 0;
    let out = 0;
    for (const m of data?.st.moves ?? []) {
      if (m.amount > 0) inn += m.amount;
      else out -= m.amount;
    }
    return { inn, out };
  }, [data]);

  function exportCsv() {
    if (!data) return;
    const rows: (string | number | null)[][] = [
      [data.head.title, `${f.dateNum(range.days[0], { plain: true })} → ${f.dateNum(range.days.at(-1)!, { plain: true })}`],
      [t('fin.opening'), plainPounds(data.st.opening)],
      [t('fin.cols.no'), t('fin.cols.time'), t('fin.cols.desc'), t('fin.cols.source'), t('fin.cols.by'), t('fin.cols.amount'), t('fin.cols.balance')],
      ...moves.map((m) => [m.entry_no, f.dateTime(m.at, { plain: true }), [label(m), m.memo].filter(Boolean).join(' - '), m.order_no ?? '', m.by ?? '', plainPounds(m.amount), plainPounds(m.balance)]),
    ];
    const blob = new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `${kind}-${range.days[0]}-${range.days.at(-1)}.csv`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  // Excel وPDF: نفس الحركات الظاهرة (بالفترة والبحث والاتجاه)، والرصيد الافتتاحي فوق
  const statementTable = (): ExportTable | null | undefined =>
    data && {
      title: `${t('fin.statement')} - ${data.head.title}`,
      meta: [
        t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) }),
        `${t('fin.opening')}: ${plainPounds(data.st.opening)}`,
        q.trim() ? t('export.search', { v: q.trim() }) : '',
        dir !== 'all' ? t('export.filter', { v: t(`fin.dir.${dir}`) }) : '',
      ].filter(Boolean),
      columns: [
        { header: t('fin.cols.no'), type: 'int' },
        { header: t('fin.cols.time'), type: 'datetime' },
        { header: t('fin.cols.desc') },
        { header: t('fin.cols.source') },
        { header: t('fin.cols.by') },
        { header: t('fin.cols.amount'), type: 'money', total: true },
        { header: t('fin.cols.balance'), type: 'money' },
      ],
      rows: moves.map((m) => [Number(m.entry_no), m.at, [label(m), m.memo].filter(Boolean).join(' - '), m.order_no, m.by, m.amount, m.balance]),
    };

  const actions: { op: Op; icon: typeof Wallet }[] =
    kind === 'cashbox'
      ? [{ op: 'transfer', icon: ArrowDownUp }]
      : kind === 'customer'
        ? [{ op: 'payment', icon: HandCoins }]
        : kind === 'supplier'
          ? [{ op: 'supplier_payment', icon: HandCoins }]
          : kind === 'partner' || kind === 'linked' || profile.role !== 'owner'
            ? []
            : [
              { op: 'salary', icon: Users },
              { op: 'salary_payment', icon: HandCoins },
              { op: 'advance', icon: Wallet },
              { op: 'advance_settle', icon: Undo2 },
            ];

  const h = data?.head;
  const waTarget: MessageTarget | null =
    kind === 'customer' && h?.phone && h.fixed.customer
      ? { deviceId: null, customerId: h.fixed.customer.id, customerName: h.title, phone: h.phone, orderNo: '', device: '', status: 'delivered', token: null, cost: null, balance: h.balance }
      : null;

  return (
    <div className="max-w-6xl">
      <button type="button" onClick={() => navigate(`/finance${query}`)} className="mb-3 inline-flex items-center gap-1.5 text-sm text-fg-3 hover:text-fg">
        <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden /> {t('fin.title')}
      </button>
      <PageHeader
        title={h ? <bdi>{h.title || t('device.notFound')}</bdi> : <Skeleton className="h-7 w-48" />}
        sub={h ? `${t(`fin.kinds.${kind}`)}${h.sub ? ` · ${h.sub}` : ''}` : undefined}
        actions={
          h && (
            <div className="text-end">
              <div className="readout-label">{t(`fin.balanceOf.${kind}`)}</div>
              <div className={cn('num text-xl font-semibold', h.balance < 0 ? 'text-danger' : 'text-fg')} data-testid="statement-balance">
                {f.money(h.balance)} <span className="font-sans text-xs font-normal text-fg-3">{cur}</span>
              </div>
            </div>
          )
        }
      />

      <div className="mb-3 flex flex-wrap items-center gap-2">
        {actions.map(({ op: o, icon: I }) => (
          <Button key={o} size="sm" variant={o === actions[0]?.op ? 'primary' : 'secondary'} icon={<I className="size-4" />} onClick={() => setOp(o)}>
            {t(`fin.ops.${o}`)}
          </Button>
        ))}
        {kind === 'cashbox' && (
          <Button size="sm" icon={<Lock className="size-4" />} onClick={() => setClosing(true)}>
            {t('fin.closeDrawer')}
          </Button>
        )}
        {waTarget && h && h.balance > 0 && <WhatsAppButton onClick={() => setWa(true)} />}
        <div className="ms-auto flex flex-wrap gap-2">
          <ExportMenu table={statementTable} csv={exportCsv} testid="statement-export" disabled={!data} />
          <Link to={`/print/statement/${kind}/${id}${query}`} className="inline-flex h-8 items-center gap-1.5 rounded-md px-3 text-sm text-fg-2 hover:bg-raised hover:text-fg">
            <Printer className="size-4" aria-hidden /> {t('fin.pdf')}
          </Link>
        </div>
      </div>

      {(kind === 'customer' || kind === 'supplier') && h && <PartyLinkBar kind={kind} id={id} name={h.title} onChanged={reload} />}
      {/* N: مواعيد التحصيل والأقساط */}
      {(kind === 'customer' || kind === 'supplier') && h && <PlansPanel key={`${kind}:${id}:${h.balance}`} partyType={kind} partyId={id} balance={h.balance} />}
      {kind === 'linked' && h?.link && (
        <div className="mb-3 flex flex-wrap items-center gap-2 text-sm" data-testid="linked-summary">
          <span className="text-fg-2">{t('link.owesUs', { name: h.link.customer })}</span>
          <span className="num text-fg" dir="ltr">
            {f.money(h.link.receivable)}
          </span>
          <span className="text-fg-3">·</span>
          <span className="text-fg-2">{t('link.weOwe', { name: h.link.supplier })}</span>
          <span className="num text-fg" dir="ltr">
            {f.money(h.link.payable)}
          </span>
          <Button size="sm" className="ms-auto" onClick={() => setNetting(h.link ?? null)} disabled={h.link.max_netting <= 0} data-testid="linked-netting">
            {t('link.netting')}
          </Button>
        </div>
      )}
      <NettingDialog info={netting} onOpenChange={(v) => !v && setNetting(null)} onDone={reload} />
      <Panel className="mb-3 flex flex-wrap items-center gap-3 p-3">
        <PeriodFilter value={period} onChange={set} />
        <div className="relative min-w-[180px] flex-1">
          <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('fin.search')} aria-label={t('fin.search')} className="h-8 w-full rounded-md border border-line bg-sunken/60 pe-3 ps-9 text-sm text-fg placeholder:text-fg-3 focus:border-accent focus:outline-none" />
        </div>
        <div className="inline-flex rounded-md border border-glass-border p-0.5" role="radiogroup" aria-label={t('fin.direction')}>
          {(['all', 'in', 'out'] as Dir[]).map((d) => (
            <button key={d} type="button" role="radio" aria-checked={dir === d} onClick={() => setDir(d)} className={cn('h-7 rounded-sm px-2.5 text-xs', dir === d ? 'bg-raised text-fg' : 'text-fg-3')}>
              {t(`fin.dir.${d}`)}
            </button>
          ))}
        </div>
      </Panel>

      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading || !data ? (
        <Panel className="flex flex-col gap-2 p-3">
          {[0, 1, 2, 3].map((x) => (
            <Skeleton key={x} className="h-9 w-full" />
          ))}
        </Panel>
      ) : (
        <Panel className="overflow-hidden">
          <div className="grid grid-cols-3 gap-px border-b border-glass-border bg-glass-border text-sm">
            <Sum label={t('fin.opening')} value={f.money(data.st.opening)} />
            <Sum label={t(`fin.in.${kind}`)} value={f.money(totals.inn)} tone="ok" />
            <Sum label={t(`fin.out.${kind}`)} value={f.money(totals.out)} tone="danger" />
          </div>
          {moves.length === 0 ? (
            <EmptyState line="receipt" title={t('fin.noMoves')} />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-sm">
                <thead className="text-start text-2xs text-fg-3">
                  <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                    <th>{t('fin.cols.time')}</th>
                    <th>{t('fin.cols.desc')}</th>
                    <th>{t('fin.cols.source')}</th>
                    <th>{t('fin.cols.by')}</th>
                    <th className="!text-end">{t('fin.cols.amount')}</th>
                    <th className="!text-end">{t('fin.cols.balance')}</th>
                    <th>
                      <span className="sr-only">{t('fin.reverse')}</span>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-glass-border">
                  {moves.map((m) => (
                    <tr key={`${m.entry_id}-${m.account}`} className={cn('[&_td]:px-3 [&_td]:py-2', m.reversed && 'text-fg-3 line-through decoration-fg-3/40')} data-testid="move-row">
                      <td className="num whitespace-nowrap text-xs text-fg-3">
                        {f.dateTime(m.at)}
                        <div className="text-2xs" dir="ltr">
                          #{m.entry_no}
                        </div>
                      </td>
                      <td className="max-w-[260px]">
                        <div className="text-fg">
                          {m.source_type === 'private' ? (
                            label(m)
                          ) : (
                            <Link to={`/finance/entry/${m.entry_id}`} className="hover:text-accent hover:underline">
                              {label(m)}
                            </Link>
                          )}
                          {m.reversed && (
                            <span className="ms-2 inline-block rounded-full border border-line px-1.5 text-2xs text-fg-3 no-underline" data-testid="move-cancelled">
                              {t('fin.cancelledTag')}
                            </span>
                          )}
                        </div>
                        {m.memo && <div className="truncate text-2xs text-fg-3">{m.memo}</div>}
                      </td>
                      <td>
                        {m.device_id ? (
                          <Link to={`/devices/${m.device_id}`} state={{ bg: location }} className="num text-accent hover:underline" dir="ltr">
                            {m.order_no}
                          </Link>
                        ) : (
                          <span className="text-fg-3">{t('common.none')}</span>
                        )}
                      </td>
                      <td className="text-fg-2">{m.by ?? (m.source_type === 'private' ? '' : t('fin.system'))}</td>
                      <td className={cn('num whitespace-nowrap text-end', m.amount > 0 ? 'text-ok' : 'text-danger')} dir="ltr">
                        {m.amount > 0 ? '+' : ''}
                        {f.money(m.amount)}
                      </td>
                      <td className="num whitespace-nowrap text-end text-fg" dir="ltr">
                        {f.money(m.balance)}
                      </td>
                      <td className="text-end">
                        {!m.reversed && canCorrect(entrySection(m.source_type)) && EDITABLE_SOURCES.includes(m.source_type) && (
                          <button type="button" onClick={() => setEdit(m)} className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-accent" aria-label={t('edit.edit')} title={t('edit.edit')} data-testid="move-edit">
                            <Pencil className="size-3.5" aria-hidden />
                          </button>
                        )}
                        {!m.reversed && m.source_type !== 'private' && canCorrect(entrySection(m.source_type)) && m.source_type !== 'reversal' && m.source_type !== 'cost_adjust' && (
                          <button type="button" onClick={() => setReverse(m)} className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-danger" aria-label={t('fin.reverse')} title={t('fin.reverse')}>
                            <Undo2 className="size-3.5" aria-hidden />
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>
      )}
      {op && h && <OpDialog op={op} open={!!op} onOpenChange={(v) => !v && setOp(null)} fixed={h.fixed} onDone={reload} />}
      {kind === 'cashbox' && <CloseDrawerDialog open={closing} onOpenChange={setClosing} cashboxId={id} name={h?.title ?? ''} onDone={reload} />}
      <ReverseDialog move={reverse} onOpenChange={(v) => !v && setReverse(null)} onDone={reload} />
      <EditEntryDialog entry={edit} onOpenChange={(v) => !v && setEdit(null)} onDone={reload} />
      <WhatsAppDialog open={wa} onOpenChange={setWa} target={waTarget} initial="debt" />
    </div>
  );
}

function Sum({ label, value, tone }: { label: string; value: string; tone?: 'ok' | 'danger' }) {
  return (
    <div className="bg-surface/60 px-4 py-2.5">
      <div className="readout-label">{label}</div>
      <div className={cn('num text-md', tone === 'ok' ? 'text-ok' : tone === 'danger' ? 'text-danger' : 'text-fg')}>{value}</div>
    </div>
  );
}
