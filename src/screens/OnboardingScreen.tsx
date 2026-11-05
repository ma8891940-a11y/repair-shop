import { useEffect, useState, type FormEvent } from 'react';
import { motion } from 'motion/react';
import { Store, UserPlus } from 'lucide-react';
import { useAuth } from '../app/auth';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';
import { ROLE_LABELS } from '../lib/types';
import type { Role } from '../lib/status';
import { Button } from '../ui/Button';
import { Field, Input } from '../ui/Field';
import { Alert, Skeleton } from '../ui/Feedback';
import { Mark } from '../ui/Logo';

interface Invite {
  shop_name: string;
  role: Role;
}

/** أول دخول: يا ينضم لمحل بدعوة، يا يعمل محل جديد ويبقى صاحبه */
export function OnboardingScreen({ blocked, loadError }: { blocked: boolean; loadError: string | null }) {
  const { refresh, signOut, session } = useAuth();
  const [invite, setInvite] = useState<Invite | null | undefined>(undefined);
  const [fullName, setFullName] = useState('');
  const [shopName, setShopName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(loadError);

  useEffect(() => {
    if (blocked) return;
    void supabase.rpc('my_pending_invite').then(({ data, error }) => {
      if (error) setError(arabicError(error));
      const row = Array.isArray(data) ? data[0] : null;
      setInvite(row ? (row as Invite) : null);
    });
  }, [blocked]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!fullName.trim()) return setError('اكتب اسمك');
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

  return (
    <div className="bg-grid flex min-h-dvh items-center justify-center bg-bg px-4">
      <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.22 }} className="w-full max-w-[420px]">
        <div className="mb-5 flex justify-center">
          <Mark size={36} />
        </div>
        <div className="rounded-xl border border-line bg-surface shadow-2">
          {blocked ? (
            <div className="flex flex-col gap-4 p-6">
              <h1 className="text-lg font-semibold">الحساب موقوف</h1>
              <p className="text-sm text-fg-2">صاحب المحل أوقف الحساب ده. كلّمه لو ده حصل بالغلط.</p>
              <Button onClick={() => void signOut()}>خروج</Button>
            </div>
          ) : invite === undefined ? (
            <div className="flex flex-col gap-3 p-6">
              <Skeleton className="h-6 w-40" />
              <Skeleton className="h-4 w-64" />
              <Skeleton className="h-9 w-full" />
            </div>
          ) : (
            <form onSubmit={submit} className="flex flex-col gap-4 p-6">
              <div className="flex items-start gap-3">
                <div className="grid size-10 shrink-0 place-items-center rounded-md border border-line bg-raised text-accent">
                  {invite ? <UserPlus className="size-5" /> : <Store className="size-5" />}
                </div>
                <div>
                  <h1 className="text-lg font-semibold">{invite ? 'الانضمام للمحل' : 'إعداد المحل'}</h1>
                  <p className="num mt-0.5 text-xs text-fg-3" dir="ltr">
                    {session?.user.email}
                  </p>
                </div>
              </div>
              {invite ? (
                <Alert tone="info">
                  عندك دعوة من <b>{invite.shop_name}</b> بدور <b>{ROLE_LABELS[invite.role]}</b>.
                </Alert>
              ) : (
                <p className="text-sm text-fg-2">هنعمل محلك وتبقى أنت صاحبه. الاسم مؤقت وتقدر تغيّره بعدين من الإعدادات.</p>
              )}
              <Field label="اسمك" required>
                <Input autoFocus value={fullName} onChange={(e) => setFullName(e.target.value)} maxLength={120} />
              </Field>
              {!invite && (
                <Field label="اسم المحل" hint="لو سبته فاضي هيبقى «محل الصيانة»">
                  <Input value={shopName} onChange={(e) => setShopName(e.target.value)} placeholder="محل الصيانة" maxLength={120} />
                </Field>
              )}
              {error && <Alert tone="danger">{error}</Alert>}
              <div className="flex items-center justify-between gap-2 pt-1">
                <Button variant="ghost" onClick={() => void signOut()}>
                  خروج
                </Button>
                <Button type="submit" variant="primary" loading={busy}>
                  {invite ? 'انضم للمحل' : 'ابدأ'}
                </Button>
              </div>
            </form>
          )}
        </div>
      </motion.div>
    </div>
  );
}
