import { useState } from 'react';
import { Link, useLocation, useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { CheckCircle2, AlertTriangle, Pencil, Printer, Undo2 } from 'lucide-react';
import { Button } from '../../ui/Button';
import { ReverseDialog } from '../../app/finance/ReverseDialog';
import { EditEntryDialog } from '../../app/finance/EditEntryDialog';
import { EDITABLE_SOURCES, VOUCHER_SOURCES, type SourceType } from '../../lib/ledger';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad, must } from '../../app/useLoad';
import { useAccountName } from '../../app/ledgerApi';
import { supabase } from '../../lib/supabase';
import { useFormat } from '../../i18n/format';
import { Panel } from '../../ui/Panel';
import { ErrorState, Skeleton, EmptyState } from '../../ui/Feedback';
import { cn } from '../../ui/cn';

interface EntryRow {
  id: string;
  entry_no: number;
  occurred_at: string;
  source_type: string;
  device_id: string | null;
  memo: string | null;
  reverses_id: string | null;
  created_by: string | null;
}
interface LineRow {
  id: string;
  account_id: string;
  party_type: string | null;
  party_id: string | null;
  debit: number;
  credit: number;
}

/** تفاصيل قيد واحد (صاحب المحل): كل سطر مدين ودائن، والطرف، والقيد العكسي لو موجود. ده المكان اللي تنبيه السلامة بيفتحه */
export function EntryScreen() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  const location = useLocation();
  const [mode, setMode] = useState<'edit' | 'cancel' | null>(null);

  const { data, error, loading, reload } = useLoad(async () => {
    const e = must(await supabase.from('journal_entries').select('id, entry_no, occurred_at, source_type, device_id, memo, reverses_id, created_by').eq('id', id).maybeSingle()) as EntryRow | null;
    if (!e) return null;
    const lines = (must(await supabase.from('journal_lines').select('id, account_id, party_type, party_id, debit, credit').eq('entry_id', id).order('debit', { ascending: false })) ?? []) as LineRow[];
    const accIds = [...new Set(lines.map((l) => l.account_id))];
    const accs = accIds.length ? ((must(await supabase.from('accounts').select('id, code, name').in('id', accIds)) ?? []) as { id: string; code: string | null; name: string | null }[]) : [];
    const ids = (type: string) => [...new Set(lines.filter((l) => l.party_type === type && l.party_id).map((l) => l.party_id as string))];
    const [cs, ss, ps, rev, dev] = await Promise.all([
      ids('customer').length ? supabase.from('customers').select('id, name').in('id', ids('customer')) : null,
      ids('supplier').length ? supabase.from('suppliers').select('id, name').in('id', ids('supplier')) : null,
      [...ids('employee'), e.created_by ?? ''].filter(Boolean).length ? supabase.from('profiles').select('id, full_name').in('id', [...ids('employee'), e.created_by ?? ''].filter(Boolean)) : null,
      supabase.from('journal_entries').select('id, entry_no').eq('reverses_id', id).maybeSingle(),
      e.device_id ? supabase.from('devices').select('id, order_no').eq('id', e.device_id).maybeSingle() : null,
    ]);
    const names = new Map<string, string>();
    for (const r of (cs?.data ?? []) as { id: string; name: string }[]) names.set(r.id, r.name);
    for (const r of (ss?.data ?? []) as { id: string; name: string }[]) names.set(r.id, r.name);
    for (const r of (ps?.data ?? []) as { id: string; full_name: string }[]) names.set(r.id, r.full_name);
    const orig = e.reverses_id ? ((await supabase.from('journal_entries').select('id, entry_no').eq('id', e.reverses_id).maybeSingle()).data as { id: string; entry_no: number } | null) : null;
    return {
      e,
      lines,
      acc: new Map(accs.map((a) => [a.id, a])),
      names,
      reversedBy: rev.data as { id: string; entry_no: number } | null,
      orig,
      order: (dev?.data as { order_no: string } | null)?.order_no ?? null,
    };
  }, [id]);
  useLiveRefresh(reload);

  const debit = data?.lines.reduce((a, l) => a + Number(l.debit), 0) ?? 0;
  const credit = data?.lines.reduce((a, l) => a + Number(l.credit), 0) ?? 0;
  const balanced = debit === credit && (data?.lines.length ?? 0) >= 2;
  const partyPath = (l: LineRow) => (l.party_type && l.party_id ? `/finance/${l.party_type}/${l.party_id}` : null);

  return (
    <div>
      <PageHeader
        title={data ? t('entry.title', { no: data.e.entry_no }) : t('entry.titleBare')}
        sub={data ? `${t(`fin.src.${data.e.source_type}`, { defaultValue: t('entry.other') })} · ${f.dateTime(data.e.occurred_at)}` : undefined}
        actions={
          data && !data.reversedBy && !['reversal', 'cost_adjust'].includes(data.e.source_type) ? (
            <div className="flex gap-2">
              {/* U5: سند قبض أو صرف للقيد ده */}
              {VOUCHER_SOURCES.includes(data.e.source_type) && (
                <Link to={`/print/voucher/${data.e.id}`} className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg" data-testid="entry-voucher">
                  <Printer className="size-4" aria-hidden /> {t('voucher.print')}
                </Link>
              )}
              {EDITABLE_SOURCES.includes(data.e.source_type as SourceType) && (
                <Button size="sm" icon={<Pencil className="size-4" />} onClick={() => setMode('edit')} data-testid="entry-edit">
                  {t('edit.edit')}
                </Button>
              )}
              <Button size="sm" variant="danger" icon={<Undo2 className="size-4" />} onClick={() => setMode('cancel')} data-testid="entry-cancel">
                {t('edit.cancel')}
              </Button>
            </div>
          ) : undefined
        }
      />
      <EditEntryDialog entry={mode === 'edit' && data ? { entry_id: data.e.id, entry_no: data.e.entry_no } : null} onOpenChange={(v) => !v && setMode(null)} onDone={reload} />
      <ReverseDialog
        move={mode === 'cancel' && data ? { entry_id: data.e.id, entry_no: data.e.entry_no, source_type: data.e.source_type as SourceType, amount: data.lines.reduce((a, l) => a + Number(l.debit), 0) } : null}
        onOpenChange={(v) => !v && setMode(null)}
        onDone={reload}
      />
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading ? (
        <Panel className="flex flex-col gap-2 p-3">
          {[0, 1, 2].map((x) => (
            <Skeleton key={x} className="h-9 w-full" />
          ))}
        </Panel>
      ) : !data ? (
        <Panel>
          <EmptyState line="receipt" title={t('entry.notFound')} />
        </Panel>
      ) : (
        <>
          <Panel className="mb-3 grid gap-3 p-4 text-sm sm:grid-cols-2 lg:grid-cols-4">
            <Info label={t('entry.memo')}>{data.e.memo || t('common.none')}</Info>
            <Info label={t('fin.cols.by')}>{(data.e.created_by && data.names.get(data.e.created_by)) || t('fin.system')}</Info>
            <Info label={t('fin.cols.source')}>
              {data.e.device_id && data.order ? (
                <Link to={`/devices/${data.e.device_id}`} state={{ bg: location }} className="num text-accent hover:underline" dir="ltr">
                  {data.order}
                </Link>
              ) : (
                t('common.none')
              )}
            </Info>
            <Info label={t('entry.state')}>
              {data.reversedBy ? (
                <Link to={`/finance/entry/${data.reversedBy.id}`} className="text-warn hover:underline" data-testid="entry-reversed">
                  {t('entry.reversedBy', { no: data.reversedBy.entry_no })}
                </Link>
              ) : data.orig ? (
                <Link to={`/finance/entry/${data.orig.id}`} className="text-accent hover:underline">
                  {t('entry.reverses', { no: data.orig.entry_no })}
                </Link>
              ) : (
                t('entry.active')
              )}
            </Info>
          </Panel>

          <Panel className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] text-sm" data-testid="entry-lines">
                <thead className="text-2xs text-fg-3">
                  <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                    <th>{t('entry.account')}</th>
                    <th>{t('entry.party')}</th>
                    <th className="!text-end">{t('entry.debit')}</th>
                    <th className="!text-end">{t('entry.credit')}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-glass-border">
                  {data.lines.map((l) => {
                    const p = partyPath(l);
                    return (
                      <tr key={l.id} className="[&_td]:px-3 [&_td]:py-2">
                        <td className="text-fg">{accName(data.acc.get(l.account_id))}</td>
                        <td className="text-fg-2">
                          {p ? (
                            <Link to={p} className="hover:text-accent hover:underline">
                              {data.names.get(l.party_id as string) ?? t('common.none')}
                            </Link>
                          ) : (
                            t('common.none')
                          )}
                        </td>
                        <td className="num text-end text-fg" dir="ltr">
                          {Number(l.debit) ? f.money(Number(l.debit)) : ''}
                        </td>
                        <td className="num text-end text-fg" dir="ltr">
                          {Number(l.credit) ? f.money(Number(l.credit)) : ''}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                <tfoot className="border-t border-glass-border font-semibold">
                  <tr className="[&_td]:px-3 [&_td]:py-2">
                    <td colSpan={2}>
                      <span className={cn('inline-flex items-center gap-1.5', balanced ? 'text-ok' : 'text-danger')} data-testid="entry-balance">
                        {balanced ? <CheckCircle2 className="size-4" aria-hidden /> : <AlertTriangle className="size-4" aria-hidden />}
                        {balanced ? t('entry.balanced') : t('entry.unbalanced', { amount: f.money(Math.abs(debit - credit)) })}
                      </span>
                    </td>
                    <td className="num text-end" dir="ltr">
                      {f.money(debit)}
                    </td>
                    <td className="num text-end" dir="ltr">
                      {f.money(credit)}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </Panel>
        </>
      )}
    </div>
  );
}

function Info({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="readout-label">{label}</div>
      <div className="mt-1 text-fg">{children}</div>
    </div>
  );
}
