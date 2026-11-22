import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Receipt } from 'lucide-react';
import { useMe } from '../auth';
import { useLoad } from '../useLoad';
import { loadCashboxes, opId, rpc, useAccountName } from '../ledgerApi';
import { parsePounds } from '../../lib/money';
import { plainPounds } from '../../lib/ledger';
import { errorMessage } from '../../lib/errors';
import { readVat } from '../../lib/vat';
import { useFormat } from '../../i18n/format';
import { Panel } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/** R5: الضريبة المستحقة في الوضع المالي (من ضمن "عليّا")، وسدادها للمصلحة (صاحب المحل) */
export function VatDuePanel({ due, onPaid }: { due: number; onPaid: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const [open, setOpen] = useState(false);
  if (!readVat(shop.extras).enabled && due === 0) return null;
  return (
    <Panel className="mb-4 flex flex-wrap items-center gap-3 px-4 py-3" data-testid="vat-due">
      <Receipt className="size-4 text-fg-3" aria-hidden />
      <span className="text-sm text-fg-2">{t('vat.due')}</span>
      <span className="num text-md font-semibold text-fg" data-testid="vat-due-amount">
        {f.money(due)} {f.currency()}
      </span>
      <span className="ms-auto flex flex-wrap gap-2">
        {profile.role === 'owner' && due > 0 && (
          <Button size="sm" onClick={() => setOpen(true)} data-testid="vat-pay">
            {t('vat.pay')}
          </Button>
        )}
      </span>
      {open && (
        <PayVatDialog
          due={due}
          onClose={() => setOpen(false)}
          onDone={() => {
            setOpen(false);
            onPaid();
          }}
        />
      )}
    </Panel>
  );
}

function PayVatDialog({ due, onClose, onDone }: { due: number; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const boxes = useLoad(loadCashboxes, []);
  const [cb, setCb] = useState('');
  const [amount, setAmount] = useState(plainPounds(due));
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [id] = useState(opId);
  const box = cb || boxes.data?.[0]?.id || '';
  async function save() {
    setErr(null);
    const a = parsePounds(amount);
    if (a == null || a <= 0) return setErr(t('vat.errAmount'));
    if (!box) return setErr(t('vat.errBox'));
    setBusy(true);
    try {
      await rpc('pay_vat', { p_id: id, p_cashbox: box, p_amount: a, p_note: note.trim() || null });
      toast({ tone: 'ok', title: t('vat.paid') });
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
      onOpenChange={(v) => !v && onClose()}
      title={t('vat.pay')}
      description={t('vat.payHint')}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="vat-pay-save">
            {t('vat.pay')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('vat.amount')} required>
          <Input mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency()} data-testid="vat-pay-amount" />
        </Field>
        <Field label={t('vat.from')} required>
          <Select value={box} onChange={(e) => setCb(e.target.value)} data-testid="vat-pay-box">
            {(boxes.data ?? []).map((b) => (
              <option key={b.id} value={b.id}>
                {accName(b)}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t('vat.note')}>
          <Textarea rows={2} maxLength={200} value={note} onChange={(e) => setNote(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
