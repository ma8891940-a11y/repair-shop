import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { errorMessage } from '../../lib/errors';
import { formatPounds, parsePounds } from '../../lib/money';
import { supabase } from '../../lib/supabase';
import { useFormat } from '../../i18n/format';
import { loadCashboxes, opId, rpc, useAccountName, type Cashbox } from '../ledgerApi';
import { useLoad } from '../useLoad';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/** بيانات العملية زي ما قاعدة البيانات رجعتها (entry_args) */
export interface EntryArgs {
  source_type: string;
  entry_no: number;
  note: string | null;
  editable: boolean;
  reversed: boolean;
  amount?: number;
  cashbox?: string | null;
  from?: string;
  to?: string;
  lines?: { item: string; qty: number; unit_cost?: number; price?: number }[];
  [k: string]: unknown;
}
type Line = { item: string; qty: string; money: string };

/**
 * تعديل عملية فلوس أو مخزون: الأصل ما بيتلمسش. قاعدة البيانات بتعمل قيد عكسي ليه + نفس العملية بالأرقام الجديدة،
 * في نفس اللحظة (لو أي حاجة غلط، ولا حاجة بتتسجل). السبب إجباري وبيتسجل في سجل النشاط.
 */
export function EditEntryDialog({ entry, onOpenChange, onDone }: { entry: { entry_id: string; entry_no: number } | null; onOpenChange: (v: boolean) => void; onDone?: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const [amount, setAmount] = useState('');
  const [cashbox, setCashbox] = useState('');
  const [to, setTo] = useState('');
  const [lines, setLines] = useState<Line[]>([]);
  const [note, setNote] = useState('');
  const [reason, setReason] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // رقم ثابت للتعديل ده: لو اتبعت مرتين (النت قطع ورجع)، ما يتسجلش مرتين
  const newId = useMemo(() => (entry ? opId() : ''), [entry]);

  const { data, error } = useLoad(async () => {
    if (!entry) return null;
    const args = await rpc<EntryArgs>('entry_args', { p_entry: entry.entry_id });
    const cbs: Cashbox[] = args.cashbox !== undefined || args.from ? await loadCashboxes() : [];
    const ids = (args.lines ?? []).map((l) => l.item);
    const names = new Map<string, string>();
    if (ids.length) {
      const r = await supabase.from('items').select('id, name').in('id', ids);
      for (const x of (r.data ?? []) as { id: string; name: string }[]) names.set(x.id, x.name);
    }
    return { args, cbs, names };
  }, [entry?.entry_id]);

  useEffect(() => {
    const a = data?.args;
    setErr(null);
    setReason('');
    if (!a) return;
    setAmount(a.amount != null ? formatPounds(a.amount) : '');
    setCashbox((a.cashbox as string | null) ?? a.from ?? '');
    setTo(a.to ?? '');
    setNote(a.note ?? '');
    setLines((a.lines ?? []).map((l) => ({ item: l.item, qty: String(l.qty), money: formatPounds((a.source_type === 'sale' ? l.price : l.unit_cost) ?? 0) })));
  }, [data]);

  const a = data?.args;
  const isLines = a?.source_type === 'purchase' || a?.source_type === 'sale';
  // الشراء والبيع بالآجل (من غير خزنة) بيفضلوا آجل
  const showCashbox = !!a && !isLines ? a.cashbox !== undefined || !!a.from : !!a?.cashbox;

  async function submit() {
    if (!entry || !a) return;
    setErr(null);
    if (!reason.trim()) return setErr(t('fin.errReason'));
    const next: Record<string, unknown> = { ...a, id: newId, note: note.trim() || null };
    if (isLines) {
      const ls = [];
      for (const l of lines) {
        const q = Number(l.qty);
        const m = parsePounds(l.money);
        if (!Number.isInteger(q) || q <= 0 || m == null) return setErr(t('fin.errAmount'));
        ls.push(a.source_type === 'sale' ? { item: l.item, qty: q, price: m } : { item: l.item, qty: q, unit_cost: m });
      }
      next.lines = ls;
      if (a.cashbox) next.cashbox = cashbox;
    } else {
      const m = parsePounds(amount);
      if (!m || m <= 0) return setErr(t('fin.errAmount'));
      next.amount = m;
      if (a.source_type === 'transfer') {
        if (!to || to === cashbox) return setErr(t('fin.errTo'));
        next.from = cashbox;
        next.to = to;
      } else if (a.cashbox !== undefined) next.cashbox = cashbox;
    }
    setBusy(true);
    try {
      await rpc('edit_entry', { p_entry: entry.entry_id, p_reason: reason.trim(), p_new: next });
      toast({ tone: 'ok', title: t('edit.saved', { no: a.entry_no }) });
      onOpenChange(false);
      onDone?.();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={!!entry}
      onOpenChange={onOpenChange}
      title={t('edit.title')}
      description={a ? `#${a.entry_no} · ${t(`fin.src.${a.source_type}`)}` : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} disabled={!a?.editable || a.reversed} onClick={() => void submit()}>
            {t('edit.save')}
          </Button>
        </>
      }
    >
      {error ? (
        <Alert tone="danger">{error}</Alert>
      ) : !a ? (
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-full" />
          <Skeleton className="h-9 w-full" />
        </div>
      ) : !a.editable || a.reversed ? (
        <Alert tone="warn">{a.reversed ? t('edit.alreadyReversed') : t('errors.db.E_NOT_EDITABLE')}</Alert>
      ) : (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-fg-2">{t('edit.hint')}</p>
          {isLines ? (
            <div className="flex flex-col gap-2" data-testid="edit-lines">
              {lines.map((l, i) => (
                <div key={l.item} className="grid grid-cols-[minmax(0,1fr)_5rem_7rem] items-end gap-2">
                  <div className="truncate pb-2 text-sm text-fg">{data?.names.get(l.item) ?? ''}</div>
                  <Field label={t('edit.qty')}>
                    <Input mono inputMode="numeric" value={l.qty} onChange={(e) => setLines((cur) => cur.map((x, k) => (k === i ? { ...x, qty: e.target.value } : x)))} />
                  </Field>
                  <Field label={a.source_type === 'sale' ? t('edit.price') : t('edit.unitCost')}>
                    <Input mono inputMode="decimal" value={l.money} onChange={(e) => setLines((cur) => cur.map((x, k) => (k === i ? { ...x, money: e.target.value } : x)))} suffix={f.currency()} />
                  </Field>
                </div>
              ))}
            </div>
          ) : (
            <Field label={t('fin.amount')} required>
              <Input mono inputMode="decimal" autoFocus value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency()} />
            </Field>
          )}
          {showCashbox && (
            <Field label={a.source_type === 'transfer' ? t('edit.from') : t('fin.cashbox')}>
              <Select value={cashbox} onChange={(e) => setCashbox(e.target.value)}>
                {data?.cbs.map((c) => (
                  <option key={c.id} value={c.id}>
                    {accName(c)}
                  </option>
                ))}
              </Select>
            </Field>
          )}
          {a.source_type === 'transfer' && (
            <Field label={t('edit.to')}>
              <Select value={to} onChange={(e) => setTo(e.target.value)}>
                {data?.cbs.map((c) => (
                  <option key={c.id} value={c.id}>
                    {accName(c)}
                  </option>
                ))}
              </Select>
            </Field>
          )}
          <Field label={t('edit.note')}>
            <Input value={note} onChange={(e) => setNote(e.target.value)} maxLength={300} />
          </Field>
          <Field label={t('fin.reason')} required>
            <Textarea rows={2} maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          </Field>
          {err && <Alert tone="danger">{err}</Alert>}
        </div>
      )}
    </Dialog>
  );
}
