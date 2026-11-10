import { useLayoutEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeftRight } from 'lucide-react';
import { useBranch } from '../branch';
import { opId, rpc } from '../ledgerApi';
import { useLoad } from '../useLoad';
import { useFormat } from '../../i18n/format';
import { errorMessage } from '../../lib/errors';
import { toLatinDigits } from '../../lib/digits';
import { Button } from '../../ui/Button';
import { Field, Input, Select } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/**
 * B: مخزون الصنف في كل فرع، وتحويل كمية بين الفروع (صاحب المحل).
 * بتخرج من فرع بمتوسط تكلفته وتدخل التاني بنفس القيمة، فحساب المخزون ما بيتغيرش.
 */
export function BranchStock({ item, onDone }: { item: { id: string; name: string }; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const br = useBranch();
  const toast = useToast();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [qty, setQty] = useState('1');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [id, setId] = useState(opId);
  const st = useLoad(async () => (await rpc<{ branch_id: string; qty: number; value: number }[]>('item_branch_stock', { p_item: item.id })).map((r) => ({ ...r, qty: Number(r.qty), value: Number(r.value) })), [item.id]);
  useLayoutEffect(() => {
    const withStock = (st.data ?? []).find((r) => r.qty > 0)?.branch_id ?? br.all[0]?.id ?? '';
    setFrom(withStock);
    setTo(br.all.find((b) => b.id !== withStock)?.id ?? '');
    setQty('1');
    setErr(null);
    setId(opId());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [item.id, st.data]);
  if (!br.multi) return null;
  const avail = st.data?.find((r) => r.branch_id === from)?.qty ?? 0;
  async function go() {
    setErr(null);
    const n = Number(toLatinDigits(qty.trim()));
    if (!Number.isInteger(n) || n <= 0) return setErr(t('fin.errAmount'));
    if (n > avail) return setErr(t('errors.db.E_STOCK'));
    setBusy(true);
    try {
      await rpc('transfer_stock', { p_id: id, p_item: item.id, p_qty: n, p_from: from, p_to: to });
      toast({ tone: 'ok', title: t('branch.transferred', { qty: f.number(n), item: item.name, to: br.name(to) }) });
      setId(opId());
      st.reload();
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="flex flex-col gap-2 rounded-md border border-glass-border p-3" data-testid="branch-stock">
      <div className="text-sm font-medium text-fg">{t('branch.stock')}</div>
      <ul className="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
        {br.all.map((b) => {
          const r = st.data?.find((x) => x.branch_id === b.id);
          return (
            <li key={b.id} className="rounded-sm bg-sunken/50 px-2 py-1.5 text-xs" data-testid="branch-stock-row" data-branch={b.name}>
              <div className="truncate text-fg-3">{b.name}</div>
              <div className="num text-sm text-fg">{f.number(r?.qty ?? 0)}</div>
            </li>
          );
        })}
      </ul>
      <p className="text-2xs text-fg-3">{t('branch.transferHint')}</p>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-[1fr_1fr_6rem_auto] sm:items-end">
        <Field label={t('branch.from')}>
          <Select value={from} onChange={(e) => setFrom(e.target.value)} data-testid="transfer-from">
            {br.all.map((b) => (
              <option key={b.id} value={b.id}>
                {b.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t('branch.to')}>
          <Select value={to} onChange={(e) => setTo(e.target.value)} data-testid="transfer-to">
            {br.all
              .filter((b) => b.id !== from)
              .map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
          </Select>
        </Field>
        <Field label={t('branch.qty')} hint={t('branch.available', { n: f.number(avail) })}>
          <Input value={qty} onChange={(e) => setQty(e.target.value)} inputMode="numeric" mono data-testid="transfer-qty" />
        </Field>
        <Button variant="outline" icon={<ArrowLeftRight className="size-4" />} loading={busy} needsNet disabled={!from || !to || from === to} onClick={() => void go()} data-testid="transfer-go">
          {t('branch.transfer')}
        </Button>
      </div>
      {err && <Alert tone="danger">{err}</Alert>}
    </section>
  );
}
