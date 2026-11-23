import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { loadCashboxes, opId, rpc, useAccountName } from '../../app/ledgerApi';
import { useLoad } from '../../app/useLoad';
import { useFormat } from '../../i18n/format';
import { toLatinDigits } from '../../lib/digits';
import { errorMessage } from '../../lib/errors';
import { Button } from '../../ui/Button';
import { Checkbox } from '../../ui/Checkbox';
import { cn } from '../../ui/cn';
import { Dialog } from '../../ui/Dialog';
import { Alert } from '../../ui/Feedback';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { useToast } from '../../ui/Toast';
import { ReasonChips } from './InventoryOps';

interface ReturnLine {
  id: string;
  name: string;
  qty: number;
  price: number;
  returned: number;
  service: boolean;
}
interface SaleForReturn {
  entry_no: number;
  at: string;
  branch_id: string;
  cancelled: boolean;
  credit: boolean;
  lines: ReturnLine[];
}

/** مرتجع بسطر من فاتورة بيع: المبلغ والضريبة والتكلفة بيتحسبوا في قاعدة البيانات من البيع نفسه (sale_line_return) */
export function SaleReturnDialog({ modes, onOpenChange, onDone }: { modes: ReactNode; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const [no, setNo] = useState('');
  const [sale, setSale] = useState<SaleForReturn | null>(null);
  const [line, setLine] = useState('');
  const [qty, setQty] = useState('1');
  const [way, setWay] = useState('');
  const [restock, setRestock] = useState(true);
  const [reason, setReason] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [id, setId] = useState(opId);
  const cbs = useLoad(loadCashboxes, []);
  const boxes = (cbs.data ?? []).filter((c) => !sale || c.branch_id === sale.branch_id);
  const cashbox = way || (boxes[0]?.id ?? '');
  const l = sale?.lines.find((x) => x.id === line);
  const n = Number(toLatinDigits(qty.trim()));
  const okQty = !!l && Number.isInteger(n) && n > 0 && n <= l.qty - l.returned;

  async function load() {
    setErr(null);
    setSale(null);
    setLine('');
    const v = toLatinDigits(no.trim()).replace(/^#/, '');
    if (!/^[0-9]{1,15}$/.test(v)) return setErr(t('invop.ret.errNo'));
    setBusy(true);
    try {
      const s = (await rpc('sale_for_return', { p_no: Number(v) })) as SaleForReturn;
      if (s.cancelled) return setErr(t('invop.ret.cancelled'));
      if (!s.lines.length) return setErr(t('invop.ret.legacy'));
      setSale(s);
      setWay('');
      setId(opId());
      const open = s.lines.filter((x) => x.returned < x.qty);
      if (open.length === 1) setLine(open[0].id);
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function submit() {
    setErr(null);
    if (!sale || !l) return setErr(t('invop.ret.pickLine'));
    if (!okQty) return setErr(t('errors.db.E_RETURN_QTY'));
    if (!reason.trim()) return setErr(t('fin.errReason'));
    setBusy(true);
    try {
      await rpc('sale_line_return', { p_id: id, p_line: l.id, p_qty: n, p_cashbox: sale.credit || cashbox === 'account' ? null : cashbox, p_restock: restock, p_reason: reason.trim() });
      toast({ tone: 'ok', title: t('invop.done.sale_return') });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open
      onOpenChange={onOpenChange}
      title={t('invop.title.sale_return')}
      description={t('invop.hint.sale_return')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} disabled={!sale} onClick={() => void submit()} data-testid="invop-submit">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {modes}
        <form
          className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            void load();
          }}
        >
          <Field label={t('invop.ret.invNo')} required>
            <Input mono dir="ltr" inputMode="numeric" value={no} onChange={(e) => setNo(e.target.value)} data-testid="ret-no" />
          </Field>
          <Button type="submit" needsNet loading={busy && !sale} data-testid="ret-load">
            {t('invop.ret.load')}
          </Button>
        </form>
        {sale && (
          <>
            <div className="flex flex-col gap-1.5" role="radiogroup" aria-label={t('invop.ret.pickLine')}>
              {sale.lines.map((x) => (
                <button
                  key={x.id}
                  type="button"
                  role="radio"
                  aria-checked={line === x.id}
                  disabled={x.returned >= x.qty}
                  onClick={() => {
                    setLine(x.id);
                    setQty('1');
                    setId(opId());
                  }}
                  data-testid="ret-line"
                  className={cn('flex items-center justify-between gap-2 rounded-md border px-3 py-2 text-start text-sm disabled:opacity-50', line === x.id ? 'border-accent bg-raised text-fg' : 'border-glass-border text-fg-2')}
                >
                  <bdi className="min-w-0 break-words">{x.name}</bdi>
                  <span className="shrink-0 text-xs text-fg-3">
                    {t('invop.ret.left', { n: f.number(x.qty - x.returned), q: f.number(x.qty) })} · <span className="num">{f.money(x.price)}</span>
                  </span>
                </button>
              ))}
            </div>
            {l && (
              <div className="grid grid-cols-2 gap-2">
                <Field label={t('inv.cols.qty')} required>
                  <Input mono inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="ret-qty" />
                </Field>
                <div className="flex flex-col gap-1 text-sm">
                  <span className="text-fg-3">{t('invop.ret.total')}</span>
                  <span className="num text-fg" data-testid="ret-total">
                    {okQty ? f.money(n * l.price) : '-'}
                  </span>
                </div>
              </div>
            )}
            {sale.credit ? (
              <p className="text-xs text-fg-3">{t('invop.ret.credit')}</p>
            ) : (
              <Field label={t('fin.cashbox')}>
                <Select value={cashbox} onChange={(e) => setWay(e.target.value)}>
                  {boxes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {accName(c)}
                    </option>
                  ))}
                  <option value="account">{t('invop.ret.account')}</option>
                </Select>
              </Field>
            )}
            {l && !l.service && <Checkbox checked={restock} onChange={setRestock} label={t('invop.restock')} />}
            <ReasonChips list="return_reasons" value={reason} onPick={setReason} />
            <Field label={t('fin.reason')} required>
              <Textarea rows={2} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} />
            </Field>
          </>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
