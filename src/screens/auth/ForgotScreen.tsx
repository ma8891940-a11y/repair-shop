import { useEffect, useState, type FormEvent } from 'react';
import { Link, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { supabase } from '../../lib/supabase';
import { errorMessage, retryAfterSeconds } from '../../lib/errors';
import { checkPassword, isEmail } from '../../lib/password';
import { useAuth } from '../../app/auth';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { OtpInput } from '../../ui/OtpInput';
import { useToast } from '../../ui/Toast';
import { AuthLayout } from './AuthLayout';

const ICONS = ['phone', 'tool', 'receipt', 'chip'] as const;

/** نسيت كلمة السر: الإيميل ← كود أو رابط (حسب قالب Supabase) ← كلمة سر جديدة (NewPasswordScreen) */
export function ForgotScreen() {
  const { t } = useTranslation();
  const [email, setEmail] = useState<string>((useLocation().state as { email?: string } | null)?.email ?? '');
  const [sent, setSent] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [cooldown, setCooldown] = useState(0);
  useEffect(() => {
    if (cooldown <= 0) return;
    const tm = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(tm);
  }, [cooldown]);
  const mail = email.trim().toLowerCase();

  async function send(e?: FormEvent) {
    e?.preventDefault();
    if (busy || cooldown > 0) return;
    setError(null);
    if (!isEmail(mail)) return setError(t('register.emailInvalid'));
    setBusy(true);
    const { error: er } = await supabase.auth.resetPasswordForEmail(mail, { redirectTo: `${window.location.origin}${window.location.pathname}` });
    setBusy(false);
    if (er) {
      setCooldown(retryAfterSeconds(er) ?? 0);
      return setError(errorMessage(er));
    }
    setSent(true);
    setCode('');
    setCooldown(60);
  }
  async function verify(token: string) {
    setBusy(true);
    setError(null);
    // لو تمام: حدث PASSWORD_RECOVERY بيفتح شاشة كلمة السر الجديدة
    const { error: er } = await supabase.auth.verifyOtp({ email: mail, token, type: 'recovery' });
    setBusy(false);
    if (!er) return;
    setCode('');
    setError(errorMessage(er));
  }

  return (
    <AuthLayout asideIcon={[...ICONS]} asideTitle={t('forgot.title')} asideText={t('forgot.sub')}>
      <div className="glass edge-glow shadow-3 relative flex flex-col gap-4 rounded-2xl p-7" data-testid="forgot-screen">
        <div>
          <h1 className="text-xl font-semibold text-fg">{t('forgot.title')}</h1>
          <p className="mt-1 text-sm text-fg-3">{sent ? t('forgot.sent', { email: mail }) : t('forgot.sub')}</p>
        </div>
        {sent ? (
          <>
            <OtpInput
              value={code}
              onChange={(v) => {
                setCode(v);
                if (v.length === 6) void verify(v);
              }}
              label={t('register.codeLabel')}
              invalid={!!error}
              disabled={busy}
            />
            {error && <Alert tone="danger">{error}</Alert>}
            <div className="flex items-center justify-center gap-3 text-sm">
              <button type="button" disabled={cooldown > 0 || busy} onClick={() => void send()} className="font-medium text-accent hover:underline disabled:text-fg-3 disabled:no-underline">
                {cooldown > 0 ? t('register.resendIn', { s: cooldown }) : t('register.resend')}
              </button>
              <button type="button" onClick={() => (setSent(false), setError(null))} className="text-fg-3 hover:text-fg">
                {t('register.changeEmail')}
              </button>
            </div>
          </>
        ) : (
          <form onSubmit={(e) => void send(e)} className="flex flex-col gap-4" noValidate>
            <Field label={t('login.email')}>
              <Input type="email" dir="ltr" autoComplete="email" autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@example.com" className="h-11 text-start" />
            </Field>
            {error && <Alert tone="danger">{error}</Alert>}
            <Button type="submit" variant="primary" size="lg" loading={busy} disabled={cooldown > 0} className="w-full justify-center">
              {cooldown > 0 ? t('register.resendIn', { s: cooldown }) : t('forgot.send')}
            </Button>
          </form>
        )}
        <Link to="/" className="text-center text-sm text-fg-3 hover:text-fg">
          {t('forgot.back')}
        </Link>
      </div>
    </AuthLayout>
  );
}

/** داخل من كود أو رابط استعادة: لازم كلمة سر جديدة الأول. والأجهزة التانية بتخرج */
export function NewPasswordScreen() {
  const { t } = useTranslation();
  const { signOut, endRecovery } = useAuth();
  const toast = useToast();
  const [pw, setPw] = useState('');
  const [pw2, setPw2] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function save(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setError(null);
    if (!checkPassword(pw).rules.len) return setError(t('errors.weakPassword'));
    if (pw !== pw2) return setError(t('register.mismatch'));
    setBusy(true);
    const { error: er } = await supabase.auth.updateUser({ password: pw });
    if (er) {
      setBusy(false);
      return setError(/different from the old/i.test(er.message) ? t('forgot.same') : errorMessage(er));
    }
    await supabase.auth.signOut({ scope: 'others' });
    toast({ tone: 'ok', title: t('forgot.done') });
    endRecovery();
  }
  return (
    <AuthLayout asideIcon={[...ICONS]} asideTitle={t('forgot.newTitle')} asideText={t('forgot.newSub')}>
      <form onSubmit={(e) => void save(e)} noValidate className="glass edge-glow shadow-3 relative flex flex-col gap-4 rounded-2xl p-7" data-testid="new-password-screen">
        <div>
          <h1 className="text-xl font-semibold text-fg">{t('forgot.newTitle')}</h1>
          <p className="mt-1 text-sm text-fg-3">{t('forgot.newSub')}</p>
        </div>
        <Field label={t('register.password')} hint={t('errors.weakPassword')}>
          <Input type="password" dir="ltr" autoComplete="new-password" autoFocus value={pw} onChange={(e) => setPw(e.target.value)} className="h-11 text-start" />
        </Field>
        <Field label={t('register.password2')}>
          <Input type="password" dir="ltr" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} className="h-11 text-start" />
        </Field>
        {error && <Alert tone="danger">{error}</Alert>}
        <Button type="submit" variant="primary" size="lg" loading={busy} className="w-full justify-center">
          {t('forgot.save')}
        </Button>
        <button type="button" onClick={() => void signOut()} className="text-sm text-fg-3 hover:text-fg">
          {t('forgot.back')}
        </button>
      </form>
    </AuthLayout>
  );
}
