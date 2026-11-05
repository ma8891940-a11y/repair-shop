import { useEffect, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import type { Role } from '../../lib/status';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { AuthLayout } from './AuthLayout';

interface Invite {
  shop_name: string;
  role: Role;
}

/** موظف معاه دعوة: بيكتب اسمه وينضم للمحل. ولو مفيش دعوة، بنقوله يعمل إيه. */
export function JoinScreen({ blocked }: { blocked: boolean }) {
  const { t } = useTranslation();
  const { refresh, signOut, session } = useAuth();
  const [invite, setInvite] = useState<Invite | null | undefined>(undefined);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (blocked) return;
    void supabase.rpc('my_pending_invite').then(({ data, error: e }) => {
      if (e) setError(errorMessage(e));
      const row = Array.isArray(data) ? data[0] : null;
      setInvite(row ? (row as Invite) : null);
    });
  }, [blocked]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return setError(t('common.required'));
    setBusy(true);
    const { error: be } = await supabase.rpc('bootstrap_account', { p_full_name: name.trim(), p_shop_name: null });
    setBusy(false);
    if (be) return setError(errorMessage(be));
    await refresh();
  }

  return (
    <AuthLayout asideIcon="shield" asideTitle={t('onboarding.sideTitle')} asideText={t('onboarding.sideText')}>
      <div className="glass edge-glow relative shadow-3 rounded-2xl p-7">
        {blocked ? (
          <div className="flex flex-col gap-3">
            <h1 className="text-xl font-semibold">{t('onboarding.blocked')}</h1>
            <p className="text-sm text-fg-2">{t('onboarding.blockedText')}</p>
            <Button onClick={() => void signOut()}>{t('common.signOut')}</Button>
          </div>
        ) : invite === undefined ? (
          <div className="flex flex-col gap-3">
            <Skeleton className="h-7 w-40" />
            <Skeleton className="h-11 w-full" />
          </div>
        ) : !invite ? (
          <div className="flex flex-col gap-3">
            <h1 className="text-xl font-semibold">{t('onboarding.noInvite')}</h1>
            <p className="num text-xs text-fg-3" dir="ltr">
              {session?.user.email}
            </p>
            <p className="text-sm text-fg-2">{t('onboarding.noInviteText')}</p>
            <Button onClick={() => void signOut()}>{t('common.signOut')}</Button>
          </div>
        ) : (
          <form onSubmit={submit} className="flex flex-col gap-4">
            <h1 className="text-xl font-semibold">{t('onboarding.joinTitle')}</h1>
            <Alert tone="info">{t('onboarding.inviteFrom', { shop: invite.shop_name, role: t(`roles.${invite.role}`) })}</Alert>
            <Field label={t('onboarding.name')} required>
              <Input autoFocus value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            </Field>
            {error && <Alert tone="danger">{error}</Alert>}
            <div className="flex justify-between gap-2">
              <Button variant="ghost" onClick={() => void signOut()}>
                {t('common.signOut')}
              </Button>
              <Button type="submit" variant="primary" loading={busy}>
                {t('onboarding.join')}
              </Button>
            </div>
          </form>
        )}
      </div>
    </AuthLayout>
  );
}
