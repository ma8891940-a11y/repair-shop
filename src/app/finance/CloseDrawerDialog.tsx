import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { parsePounds } from '../../lib/money';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { useMe } from '../auth';
import { opId, rpc } from '../ledgerApi';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Textarea } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

/**
 * تقفيل الدرج: الموظف بيعدّ الفلوس ويكتب المبلغ. المتوقع بيتحسب في قاعدة البيانات لحظة التقفيل،
 * والفرق بيتسجل قيد عجز أو زيادة باسمه. الاستقبال ما بتشوفش المتوقع قبل ما تكتب العدّ (عدّ أعمى).
 */
export function CloseDrawerDialog({ open, onOpenChange, cashboxId, name, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; cashboxId: string; name: string; onDone?: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const toast = useToast();
  const [counted, setCounted] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [result, setResult] = useState<{ expected: number; counted: number; diff: number } | null>(null);
  const [id, setId] = useState(opId);
  useEffect(() => {
    if (open) {
      setId(opId());
      setCounted('');
      setNote('');
      setErr(null);
      setResult(null);
    }
  }, [open]);

  async function submit() {
    const c = counted.trim() === '0' ? 0 : parsePounds(counted);
    if (c == null) return setErr(t('fin.errAmount'));
    setBusy(true);
    setErr(null);
    try {
      const r = await rpc<{ expected: number; counted: number; diff: number }>('close_drawer', { p_id: id, p_cashbox: cashboxId, p_counted: c, p_note: note.trim() || null });
      setResult(r);
      toast({ tone: r.diff === 0 ? 'ok' : 'warn', title: t('fin.closed') });
      onDone?.();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  const cur = f.currency(shop.currency);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('fin.closeDrawer')}
      description={name}
      footer={
        result ? (
          <Button variant="primary" onClick={() => onOpenChange(false)}>
            {t('common.close')}
          </Button>
        ) : (
          <>
            <Button variant="ghost" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="primary" loading={busy} onClick={() => void submit()}>
              {t('fin.closeNow')}
            </Button>
          </>
        )
      }
    >
      {result ? (
        <div className="grid grid-cols-3 gap-2 text-center" data-testid="drawer-result">
          <Cell label={t('fin.expected')} value={`${f.money(result.expected)} ${cur}`} />
          <Cell label={t('fin.counted')} value={`${f.money(result.counted)} ${cur}`} />
          <Cell label={result.diff < 0 ? t('fin.shortage') : result.diff > 0 ? t('fin.overage') : t('fin.diff')} value={`${f.money(result.diff)} ${cur}`} tone={result.diff < 0 ? 'text-danger' : result.diff > 0 ? 'text-warn' : 'text-ok'} />
        </div>
      ) : (
        <form
          className="flex flex-col gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          <p className="text-sm text-fg-2">{t('fin.closeHint')}</p>
          <Field label={t('fin.counted')}>
            <Input autoFocus dir="ltr" inputMode="decimal" mono value={counted} onChange={(e) => setCounted(e.target.value)} placeholder="0" suffix={cur} className="text-start text-md" />
          </Field>
          <Field label={t('fin.note')}>
            <Textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
          </Field>
          {err && <Alert tone="danger">{err}</Alert>}
          <button type="submit" hidden />
        </form>
      )}
    </Dialog>
  );
}

function Cell({ label, value, tone = 'text-fg' }: { label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-md border border-glass-border bg-sunken/40 px-2 py-2">
      <div className="readout-label">{label}</div>
      <div className={`num mt-0.5 text-sm font-semibold ${tone}`}>{value}</div>
    </div>
  );
}
