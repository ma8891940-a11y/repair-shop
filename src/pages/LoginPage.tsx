import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';

export function LoginPage() {
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [password2, setPassword2] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    const em = email.trim().toLowerCase();
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
          setInfo('اتعمل الحساب. افتح الإيميل ودوس على رابط التأكيد، وبعدين ارجع سجّل دخول.');
          setMode('login');
        }
      }
    } catch (err) {
      setError(arabicError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="center-screen">
      <form className="card narrow" onSubmit={submit}>
        <h1>{mode === 'login' ? 'تسجيل الدخول' : 'حساب جديد'}</h1>
        <label>
          الإيميل
          <input type="email" dir="ltr" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
        </label>
        <label>
          كلمة السر
          <input
            type="password"
            dir="ltr"
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        {mode === 'signup' && (
          <label>
            تأكيد كلمة السر
            <input type="password" dir="ltr" autoComplete="new-password" required value={password2} onChange={(e) => setPassword2(e.target.value)} />
          </label>
        )}
        {error && <div className="alert error">{error}</div>}
        {info && <div className="alert info">{info}</div>}
        <button type="submit" className="primary" disabled={busy}>
          {busy ? 'لحظة...' : mode === 'login' ? 'دخول' : 'إنشاء الحساب'}
        </button>
        <button
          type="button"
          className="link"
          onClick={() => {
            setMode(mode === 'login' ? 'signup' : 'login');
            setError(null);
          }}
        >
          {mode === 'login' ? 'أول مرة؟ اعمل حساب جديد' : 'عندك حساب؟ سجّل دخول'}
        </button>
        {mode === 'signup' && (
          <p className="muted small">
            لو صاحب المحل بعت لك دعوة، اعمل الحساب بنفس الإيميل اللي في الدعوة وهتدخل على المحل تلقائيًا.
          </p>
        )}
      </form>
    </div>
  );
}
