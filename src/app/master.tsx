import { useEffect, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { KeyRound } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { openers, settle } from './masterAsk';
import { Dialog } from '../ui/Dialog';
import { Field, Input } from '../ui/Field';
import { Button } from '../ui/Button';
import { Alert } from '../ui/Feedback';

/**
 * C3: نافذة كلمة السر الرئيسية. لما عملية حساسة ترجع E_MASTER_REQUIRED، بتظهر نافذة الكلمة،
 * ولو اتكتبت صح العملية بتتعاد مرة واحدة. الفتح 5 دقايق لحساب اللي على الجهاز ده بس.
 */
export function MasterPrompt() {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const [pw, setPw] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    const o = () => setOpen(true);
    openers.add(o);
    return () => {
      openers.delete(o);
    };
  }, []);
  const done = (ok: boolean) => {
    settle(ok);
    setOpen(false);
    setPw('');
    setErr(null);
  };
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    const { data, error } = await supabase.rpc('verify_master', { p_password: pw });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    const st = (data as { status?: string } | null)?.status;
    if (st === 'wrong') return setErr(t('master.wrong'));
    done(true);
  }
  return (
    <Dialog open={open} onOpenChange={(v) => !v && done(false)} title={t('master.title')} description={t('master.ask')} guard={false}>
      <form onSubmit={(e) => void submit(e)} className="flex flex-col gap-3" data-testid="master-prompt">
        <Field label={t('master.label')}>
          <Input type="password" autoComplete="off" value={pw} onChange={(e) => setPw(e.target.value)} autoFocus data-testid="master-input" />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => done(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" variant="primary" loading={busy} disabled={!pw} icon={<KeyRound className="size-4" />} data-testid="master-submit">
            {t('master.unlock')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
