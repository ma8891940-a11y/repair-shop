import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useFormat } from '../../i18n/format';
import { rpc, type Move } from '../ledgerApi';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Textarea } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useUndoable } from '../correct';

/** تصحيح غلط: قيد عكسي مربوط بالأصلي (القيد نفسه ما بيتعدلش ولا بيتحذف). السبب إجباري وبيتسجل في السجل */
export function ReverseDialog({ move, onOpenChange, onDone }: { move: Pick<Move, 'entry_id' | 'entry_no' | 'source_type' | 'amount'> | null; onOpenChange: (v: boolean) => void; onDone?: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const undoable = useUndoable();
  const [reason, setReason] = useState('');
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setReason('');
    setErr(null);
  }, [move]);
  /** التأكيد: الديالوج بيتقفل، والقيد العكسي بيتسجل بعد ثواني التراجع */
  function submit() {
    if (!move) return;
    if (!reason.trim()) return setErr(t('fin.errReason'));
    const entry = move.entry_id;
    const why = reason.trim();
    onOpenChange(false);
    undoable({ title: move.entry_no ? t('fin.reverseQueued', { no: move.entry_no }) : t('fin.reverseQueuedBare'), done: t('fin.reversed'), run: () => rpc('reverse_entry', { p_entry: entry, p_reason: why }), onDone });
  }
  return (
    <Dialog
      open={!!move}
      onOpenChange={onOpenChange}
      title={t('fin.reverse')}
      description={move ? `${move.entry_no ? `#${move.entry_no} · ` : ''}${t(`fin.src.${move.source_type}`)} · ${f.money(move.amount)}` : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="danger" onClick={submit}>
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
