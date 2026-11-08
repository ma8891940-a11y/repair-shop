import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { rpc } from './ledgerApi';
import { useUndoable } from './correct';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Field, Textarea } from '../ui/Field';

export type DeleteKind = 'customer' | 'supplier' | 'item' | 'device';

/**
 * حذف ناعم بتأكيد و"تراجع": الحاجة بتختفي من القوايم، والبيانات القديمة بتفضل زي ما هي.
 * قاعدة البيانات بترفض الحذف لو هيبوّظ رصيد (عليه فلوس، أو في المخزون)، والرسالة بتقول ليه.
 */
export function DeleteDialog({ target, onOpenChange, onDone }: { target: { kind: DeleteKind; id: string; name: string } | null; onOpenChange: (v: boolean) => void; onDone?: () => void }) {
  const { t } = useTranslation();
  const undoable = useUndoable();
  const [reason, setReason] = useState('');
  useEffect(() => setReason(''), [target]);
  function confirm() {
    if (!target) return;
    const { kind, id, name } = target;
    const why = reason.trim() || null;
    onOpenChange(false);
    undoable({ title: t('del.queued', { name }), done: t('del.done', { name }), run: () => rpc('soft_delete', { p_kind: kind, p_id: id, p_reason: why }), onDone });
  }
  return (
    <Dialog
      open={!!target}
      onOpenChange={onOpenChange}
      title={target ? t('del.title', { name: target.name }) : ''}
      description={t('del.text')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="danger" onClick={confirm} data-testid="delete-confirm">
            {t('del.confirm')}
          </Button>
        </>
      }
    >
      <Field label={t('del.reasonOpt')}>
        <Textarea rows={2} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} />
      </Field>
    </Dialog>
  );
}
