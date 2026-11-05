import { useEffect, useState, type FormEvent } from 'react';
import { useAuth } from '../auth/AuthContext';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';
import { ROLE_LABELS } from '../lib/types';
import type { Role } from '../lib/status';

interface Invite {
  shop_name: string;
  role: Role;
}

/** أول دخول: يا إما ينضم لمحل بدعوة، يا إما يعمل محل جديد ويبقى صاحبه */
export function OnboardingPage({ blocked, loadError }: { blocked: boolean; loadError: string | null }) {
  const { refresh, signOut, session } = useAuth();
  const [invite, setInvite] = useState<Invite | null | undefined>(undefined);
  const [fullName, setFullName] = useState('');
  const [shopName, setShopName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(loadError);

  useEffect(() => {
    if (blocked) return;
    supabase.rpc('my_pending_invite').then(({ data, error }) => {
      if (error) setError(arabicError(error));
      const row = Array.isArray(data) ? data[0] : null;
      setInvite(row ? (row as Invite) : null);
    });
  }, [blocked]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error } = await supabase.rpc('bootstrap_account', {
      p_full_name: fullName.trim(),
      p_shop_name: invite ? null : shopName.trim() || null,
    });
    setBusy(false);
    if (error) return setError(arabicError(error));
    await refresh();
  }

  if (blocked) {
    return (
      <div className="center-screen">
        <div className="card narrow">
          <h1>الحساب موقوف</h1>
          <p>صاحب المحل أوقف الحساب ده. كلّمه لو ده حصل بالغلط.</p>
          <button onClick={() => void signOut()}>خروج</button>
        </div>
      </div>
    );
  }

  if (invite === undefined) return <div className="center-screen">جاري التحميل...</div>;

  return (
    <div className="center-screen">
      <form className="card narrow" onSubmit={submit}>
        <h1>{invite ? 'الانضمام للمحل' : 'إعداد المحل'}</h1>
        <p className="muted" dir="ltr" style={{ textAlign: 'right' }}>
          {session?.user.email}
        </p>
        {invite ? (
          <div className="alert info">
            عندك دعوة من <b>{invite.shop_name}</b> بدور <b>{ROLE_LABELS[invite.role]}</b>.
          </div>
        ) : (
          <p>أول مرة تدخل، فهنعمل محلك وتبقى أنت صاحبه. تقدر تغيّر الاسم بعدين من الإعدادات.</p>
        )}
        <label>
          اسمك
          <input required value={fullName} onChange={(e) => setFullName(e.target.value)} autoFocus maxLength={120} />
        </label>
        {!invite && (
          <label>
            اسم المحل (مؤقت)
            <input value={shopName} onChange={(e) => setShopName(e.target.value)} placeholder="محل الصيانة" maxLength={120} />
          </label>
        )}
        {error && <div className="alert error">{error}</div>}
        <button type="submit" className="primary" disabled={busy}>
          {busy ? 'لحظة...' : invite ? 'انضم' : 'ابدأ'}
        </button>
        <button type="button" className="link" onClick={() => void signOut()}>
          خروج
        </button>
      </form>
    </div>
  );
}
