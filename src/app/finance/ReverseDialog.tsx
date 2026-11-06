import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { rpc, type Move } from '../ledgerApi';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Textarea } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/** تصحيح غلط: قيد عكسي مربوط بالأصلي (القيد نفسه ما بيتعدلش ولا بيتحذف). السبب إجباري وبيتسجل في السجل */
export function ReverseDialog({ move, onOpenChange, onDone }: { move: Move | null; onOpenChange: (v: boolean) => void; onDone?: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setReason('');
    setErr(null);
  }, [move]);
  async function submit() {
    if (!move) return;
    if (!reason.trim()) return setErr(t('fin.errReason'));
    setBusy(true);
    try {
      await rpc('reverse_entry', { p_entry: move.entry_id, p_reason: reason.trim() });
      toast({ tone: 'ok', title: t('fin.reversed') });
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
      open={!!move}
      onOpenChange={onOpenChange}
      title={t('fin.reverse')}
      description={move ? `#${move.entry_no} · ${t(`fin.src.${move.source_type}`)} · ${f.money(move.amount)}` : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="danger" loading={busy} onClick={() => void submit()}>
            {t('fin.reverseNow')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <p className="text-sm text-fg-2">{t('fin.reverseHint')}</p>
        <Field label={t('fin.reason')} required>
          <Textarea autoFocus rows={2} maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
