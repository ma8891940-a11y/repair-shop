import { useState, type FormEvent, type KeyboardEvent } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { ArrowLeft, Eye, EyeOff, LockKeyhole } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';
import { Button } from '../ui/Button';
import { Field, Input } from '../ui/Field';
import { Alert } from '../ui/Feedback';
import { Mark } from '../ui/Logo';
import { ThemeToggle } from '../ui/ThemeToggle';

type Mode = 'login' | 'signup';

export function LoginScreen() {
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [password2, setPassword2] = useState('');
  const [show, setShow] = useState(false);
  const [caps, setCaps] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const onKey = (e: KeyboardEvent) => setCaps(e.getModifierState?.('CapsLock') ?? false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    const em = email.trim().toLowerCase();
    if (!em || !password) return setError('اكتب الإيميل وكلمة السر');
    if (mode === 'signup') {
      if (password.length < 8) return setError('كلمة السر لازم تكون 8 حروف على الأقل');
      if (password !== password2) return setError('كلمتين السر مش زي بعض');
    }
    setBusy(true);
    try {
      if (mode === 'login') {
        const { error } = await supabase.auth.signInWithPassword({ email: em, password });
        if (error) throw error;
      } else {
        const { data, error } = await supabase.auth.signUp({ email: em, password });
        if (error) throw error;
        if (!data.session) {
          setInfo('اتعمل الحساب. افتح الإيميل ودوس رابط التأكيد، وبعدين سجّل دخول.');
          setMode('login');
          setPassword('');
          setPassword2('');
        }
      }
    } catch (err) {
      setError(arabicError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="bg-grid relative flex min-h-dvh flex-col bg-bg">
      <div className="flex items-center justify-between px-5 py-4">
        <div className="flex items-center gap-2.5">
          <Mark size={28} />
          <span className="text-sm font-semibold text-fg">إدارة الصيانة</span>
        </div>
        <ThemeToggle />
      </div>

      <div className="flex flex-1 items-center justify-center px-4 pb-16">
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}
          className="w-full max-w-[380px]"
        >
          <div className="rounded-xl border border-line bg-surface shadow-2">
            <div className="flex items-center justify-between border-b border-line px-6 py-4">
              <div>
                <h1 className="text-lg font-semibold text-fg">{mode === 'login' ? 'تسجيل الدخول' : 'حساب جديد'}</h1>
                <p className="mt-0.5 text-sm text-fg-3">
                  {mode === 'login' ? 'ادخل بحسابك عشان تكمّل شغلك' : 'أول حساب بيعمل محلك وتبقى صاحبه'}
                </p>
              </div>
              <div className="grid size-9 place-items-center rounded-md border border-line bg-raised text-accent">
                <LockKeyhole className="size-4" />
              </div>
            </div>

            <form onSubmit={submit} className="flex flex-col gap-4 px-6 py-5" noValidate>
              <Field label="الإيميل">
                <Input type="email" dir="ltr" autoComplete="email" autoFocus value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@example.com" className="text-start" />
              </Field>
              <Field
                label="كلمة السر"
                hint={caps ? 'زرار Caps Lock شغّال' : undefined}
                aside={
                  <button type="button" onClick={() => setShow((s) => !s)} className="flex items-center gap-1 text-xs text-fg-3 hover:text-fg" aria-pressed={show}>
                    {show ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
                    {show ? 'إخفاء' : 'إظهار'}
                  </button>
                }
              >
                <Input
                  type={show ? 'text' : 'password'}
                  dir="ltr"
                  autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyUp={onKey}
                  className="text-start"
                />
              </Field>
              <AnimatePresence initial={false}>
                {mode === 'signup' && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }} transition={{ duration: 0.18 }}>
                    <Field label="تأكيد كلمة السر" hint="8 حروف على الأقل">
                      <Input type={show ? 'text' : 'password'} dir="ltr" autoComplete="new-password" value={password2} onChange={(e) => setPassword2(e.target.value)} className="text-start" />
                    </Field>
                  </motion.div>
                )}
              </AnimatePresence>

              {error && <Alert tone="danger">{error}</Alert>}
              {info && <Alert tone="ok">{info}</Alert>}

              <Button type="submit" variant="primary" size="lg" loading={busy} className="mt-1 w-full justify-center">
                {mode === 'login' ? 'دخول' : 'إنشاء الحساب'}
                {!busy && <ArrowLeft className="size-4" aria-hidden />}
              </Button>
            </form>

            <div className="border-t border-line px-6 py-3.5 text-center text-sm text-fg-3">
              {mode === 'login' ? 'أول مرة؟ ' : 'عندك حساب؟ '}
              <button
                type="button"
                className="font-medium text-accent underline-offset-4 hover:underline"
                onClick={() => {
                  setMode(mode === 'login' ? 'signup' : 'login');
                  setError(null);
                  setInfo(null);
                }}
              >
                {mode === 'login' ? 'اعمل حساب جديد' : 'سجّل دخول'}
              </button>
            </div>
          </div>
          {mode === 'signup' && (
            <p className="mt-4 px-2 text-center text-xs text-fg-3">
              لو صاحب المحل بعت لك دعوة، اعمل الحساب بنفس الإيميل اللي في الدعوة وهتدخل على المحل تلقائيًا.
            </p>
          )}
        </motion.div>
      </div>
    </div>
  );
}
