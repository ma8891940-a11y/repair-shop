import { useState, type FormEvent, type KeyboardEvent } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowRight, Eye, EyeOff } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
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

  const onKey = (e: KeyboardEvent) => setCaps(e.getModifierState?.('CapsLock') ?? false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !password) {
      setAttempt((a) => a + 1);
      return setError(t('login.missing'));
    }
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    setBusy(false);
    if (error) {
      setAttempt((a) => a + 1);
      setError(errorMessage(error));
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
          {error && (
            <div key={attempt}>
              <Alert tone="danger">{error}</Alert>
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
