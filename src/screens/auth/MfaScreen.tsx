import { useEffect, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { ShieldCheck } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { useAuth } from '../../app/auth';
import { AuthLayout } from './AuthLayout';
import { OtpInput } from '../../ui/OtpInput';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';

/** C3: الخطوة التانية من 2FA بعد كلمة السر: الكود (6 أرقام) من تطبيق التحقق على الموبايل */
export function MfaScreen() {
  const { t } = useTranslation();
  const { signOut, refresh } = useAuth();
  const [factor, setFactor] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    void supabase.auth.mfa.listFactors().then(({ data }) => setFactor(data?.totp.find((f) => f.status === 'verified')?.id ?? null));
  }, []);
  async function submit(e?: FormEvent) {
    e?.preventDefault();
    if (!factor || code.length !== 6) return;
    setBusy(true);
    setErr(null);
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: factor, code });
    setBusy(false);
    if (error) {
      setCode('');
      return setErr(/invalid|expired/i.test(error.message) ? t('mfa.wrong') : errorMessage(error));
    }
    await refresh();
  }
  useEffect(() => {
    if (code.length === 6) void submit();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code]);
  return (
    <AuthLayout asideIcon={['chip', 'tool', 'receipt', 'phone']} asideTitle={t('mfa.title')} asideText={t('mfa.sub')}>
      <form onSubmit={(e) => void submit(e)} className="glass edge-glow shadow-3 relative flex flex-col gap-4 rounded-2xl p-7" data-testid="mfa-screen">
        <div>
          <h1 className="flex items-center gap-2 text-xl font-semibold text-fg">
            <ShieldCheck className="size-5 text-accent" aria-hidden /> {t('mfa.title')}
          </h1>
          <p className="mt-1 text-sm text-fg-3">{t('mfa.sub')}</p>
        </div>
        <OtpInput value={code} onChange={setCode} label={t('mfa.code')} invalid={!!err} disabled={busy} />
        {err && <Alert tone="danger">{err}</Alert>}
        <Button type="submit" variant="primary" size="lg" loading={busy} disabled={code.length !== 6 || !factor} className="w-full justify-center">
          {t('mfa.verify')}
        </Button>
        <button type="button" onClick={() => void signOut()} className="text-sm text-fg-3 hover:text-fg">
          {t('mfa.other')}
        </button>
      </form>
    </AuthLayout>
  );
}
