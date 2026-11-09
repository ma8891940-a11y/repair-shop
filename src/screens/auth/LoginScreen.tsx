import { useEffect, useState, type FormEvent, type KeyboardEvent } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowRight, Eye, EyeOff } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage, retryAfterSeconds } from '../../lib/errors';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { AuthLayout } from './AuthLayout';

export function LoginScreen() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [caps, setCaps] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  // الإيميل لسه ما اتأكدش: بنعرض إعادة إرسال رسالة التأكيد
  const [unconfirmed, setUnconfirmed] = useState(false);
  const [resent, setResent] = useState(false);
  // رابط تأكيد قديم أو اتستخدم قبل كده: Supabase بيرجّع الخطأ في العنوان (#error_code=otp_expired...)
  const [linkError, setLinkError] = useState<string | null>(null);
  useEffect(() => {
    const h = window.location.hash;
    if (!/error_code=|error_description=/.test(h)) return;
    const q = new URLSearchParams(h.replace(/^#\/?/, ''));
    const code = q.get('error_code') ?? '';
    setLinkError(/expired|otp/i.test(code) ? t('login.linkExpired') : t('login.linkFailed'));
    // نشيل الخطأ من العنوان عشان التنقل يرجع طبيعي
    window.history.replaceState(window.history.state, '', `${window.location.pathname}${window.location.search}#/`);
  }, [t]);

  // البند 13: "ابعت تاني" بعداد (60 ثانية، أو اللي Supabase بيقوله)
  const [cooldown, setCooldown] = useState(0);
  useEffect(() => {
    if (cooldown <= 0) return;
    const tm = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(tm);
  }, [cooldown]);
  async function resendConfirm() {
    const { error: re } = await supabase.auth.resend({ type: 'signup', email: email.trim().toLowerCase(), options: { emailRedirectTo: `${window.location.origin}${window.location.pathname}` } });
    if (re) {
      const wait = retryAfterSeconds(re);
      if (wait) setCooldown(wait);
      return setError(errorMessage(re));
    }
    setResent(true);
    setCooldown(60);
  }

  const onKey = (e: KeyboardEvent) => setCaps(e.getModifierState?.('CapsLock') ?? false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !password) {
      setAttempt((a) => a + 1);
      return setError(t('login.missing'));
    }
    setBusy(true);
    setUnconfirmed(false);
    setResent(false);
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    setBusy(false);
    if (error) {
      setAttempt((a) => a + 1);
      setError(errorMessage(error));
      setUnconfirmed(/Email not confirmed|email_not_confirmed/i.test(`${error.message} ${(error as { code?: string }).code ?? ''}`));
    }
  }

  return (
    <AuthLayout asideIcon={['phone', 'tool', 'receipt', 'chip']} asideTitle={t('login.sideTitle')} asideText={t('login.sideText')}>
      <div className="glass edge-glow relative shadow-3 rounded-2xl">
        <div className="px-7 pb-2 pt-7">
          <h1 className="text-xl font-semibold text-fg">{t('login.title')}</h1>
          <p className="mt-1 text-sm text-fg-3">{t('login.subtitle')}</p>
        </div>
        <form onSubmit={submit} className="flex flex-col gap-4 px-7 py-5" noValidate>
          <Field label={t('login.email')}>
            <Input type="email" dir="ltr" autoComplete="email" autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@example.com" className="h-11 text-start" />
          </Field>
          <Field
            label={t('login.password')}
            hint={caps ? t('login.caps') : undefined}
            aside={
              <button type="button" onClick={() => setShow((s) => !s)} className="flex items-center gap-1 text-xs text-fg-3 hover:text-fg" aria-pressed={show}>
                {show ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
                {show ? t('login.hide') : t('login.show')}
              </button>
            }
          >
            <Input type={show ? 'text' : 'password'} dir="ltr" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} onKeyUp={onKey} className="h-11 text-start" />
          </Field>
          {linkError && !error && <Alert tone="warn">{linkError}</Alert>}
          {error && (
            <div key={attempt}>
              <Alert tone="danger">{error}</Alert>
            </div>
          )}
          {unconfirmed && (
            <div className="flex flex-wrap items-center gap-2 text-sm text-fg-2" data-testid="unconfirmed">
              <span>{resent ? t('login.resent') : t('login.unconfirmedHint')}</span>
              {cooldown > 0 ? (
                <span className="text-fg-3 tabular-nums" data-testid="resend-countdown">
                  {t('login.resendIn', { s: cooldown })}
                </span>
              ) : (
                <button type="button" onClick={() => void resendConfirm()} className="font-medium text-accent hover:underline" data-testid="resend-confirm">
                  {t('login.resendConfirm')}
                </button>
              )}
            </div>
          )}
          <Button type="submit" variant="primary" size="lg" loading={busy} className="mt-1 w-full justify-center">
            {t('login.submit')}
            {!busy && <ArrowRight className="size-4 rtl:-scale-x-100" aria-hidden />}
          </Button>
        </form>
        <div className="border-t border-glass-border px-7 py-4 text-center text-sm text-fg-3">
          {t('login.noAccount')}{' '}
          <Link to="/register" className="font-medium text-accent underline-offset-4 hover:underline">
            {t('login.newShop')}
          </Link>
          <div className="mt-1.5 text-xs">
            {t('register.invite.link')}{' '}
            <Link to="/join" className="font-medium text-accent underline-offset-4 hover:underline">
              {t('register.invite.linkCta')}
            </Link>
          </div>
        </div>
      </div>
    </AuthLayout>
  );
}
