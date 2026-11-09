import { useState, type FormEvent } from 'react';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { MailPlus, UserCheck, UserX, X } from 'lucide-react';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { PageHeader } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { isEmail } from '../lib/password';
import type { Profile } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';
import { Field, Input, Select } from '../ui/Field';
import { Panel, PanelHeader } from '../ui/Panel';
import { Alert, EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Dialog } from '../ui/Dialog';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';
import { Checkbox } from '../ui/Checkbox';

interface Invite {
  id: string;
  email: string;
  full_name: string;
  role: 'reception' | 'technician' | 'marketing';
  created_at: string;
}

export function TeamScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile: me } = useMe();
  const toast = useToast();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<'reception' | 'technician' | 'marketing'>('reception');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [sent, setSent] = useState<string | null>(null);
  const [suspend, setSuspend] = useState<Profile | null>(null);

  const { data, error, loading, reload } = useLoad(async () => {
    const [u, i] = await Promise.all([
      supabase.from('profiles').select('id, shop_id, full_name, email, role, deleted_at, can_correct').order('created_at'),
      supabase.from('staff_invites').select('id, email, full_name, role, created_at').is('accepted_at', null).is('deleted_at', null).order('created_at'),
    ]);
    return { users: must(u) as Profile[], invites: must(i) as Invite[] };
  }, []);

  async function invite(e: FormEvent) {
    e.preventDefault();
    setErr(null);
    setSent(null);
    if (!name.trim()) return setErr(t('common.required'));
    if (!isEmail(email)) return setErr(t('register.emailInvalid'));
    setBusy(true);
    const em = email.trim().toLowerCase();
    const { error: ie } = await supabase.from('staff_invites').insert({ id: crypto.randomUUID(), shop_id: me.shop_id, email: em, full_name: name.trim(), role });
    setBusy(false);
    if (ie) return setErr(/staff_invites_open/.test(ie.message) ? t('team.dupInvite') : errorMessage(ie));
    setSent(t('team.sentText', { name: name.trim(), email: em }));
    setName('');
    setEmail('');
    reload();
  }

  async function setActive(u: Profile, active: boolean) {
    const { error: ue } = await supabase.from('profiles').update({ deleted_at: active ? null : new Date().toISOString() }).eq('id', u.id);
    setSuspend(null);
    if (ue) return toast({ tone: 'danger', title: errorMessage(ue) });
    toast({ tone: 'ok', title: active ? t('team.activate') : t('team.suspend'), description: u.full_name });
    reload();
  }

  async function setCorrect(u: Profile, on: boolean) {
    const { error: ge } = await supabase.rpc('set_can_correct', { p_user: u.id, p_on: on });
    if (ge) return toast({ tone: 'danger', title: errorMessage(ge) });
    toast({ tone: 'ok', title: t(on ? 'team.canCorrectOn' : 'team.canCorrectOff', { name: u.full_name }) });
    reload();
  }

  async function cancelInvite(i: Invite) {
    const { error: ce } = await supabase.from('staff_invites').update({ deleted_at: new Date().toISOString() }).eq('id', i.id);
    if (ce) return toast({ tone: 'danger', title: errorMessage(ce) });
    toast({ tone: 'ok', title: t('team.canceled') });
    reload();
  }

  return (
    <div className="max-w-5xl">
      <PageHeader title={t('team.title')} sub={t('team.sub')} />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
        <Panel elevated glow className="self-start">
          <PanelHeader index="01" title={t('team.invite')} actions={<MailPlus className="size-4 text-accent" aria-hidden />} />
          <form onSubmit={invite} className="flex flex-col gap-3 p-4" noValidate>
            <Field label={t('team.name')} required>
              <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            </Field>
            <Field label={t('team.email')} required>
              <Input type="email" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} className="text-start" />
            </Field>
            <Field label={t('team.role')}>
              <Select value={role} onChange={(e) => setRole(e.target.value as 'reception' | 'technician' | 'marketing')}>
                <option value="reception">{t('roles.reception')}</option>
                <option value="technician">{t('roles.technician')}</option>
                <option value="marketing">{t('roles.marketing')}</option>
              </Select>
            </Field>
            {err && <Alert tone="danger">{err}</Alert>}
            {sent && (
              <Alert tone="ok" title={t('team.sent')}>
                {sent}
              </Alert>
            )}
            <Button type="submit" variant="primary" needsNet loading={busy} className="self-start">
              {t('team.send')}
            </Button>
          </form>
        </Panel>

        <div className="flex min-w-0 flex-col gap-4">
          {error ? (
            <Panel>
              <ErrorState message={error} onRetry={reload} />
            </Panel>
          ) : loading ? (
            <Panel className="flex flex-col gap-2 p-4">
              {[0, 1, 2].map((k) => (
                <Skeleton key={k} className="h-12 w-full" />
              ))}
            </Panel>
          ) : (
            <>
              {data!.invites.length > 0 && (
                <Panel>
                  <PanelHeader index="02" title={t('team.pending')} />
                  <ul className="divide-y divide-glass-border">
                    {data!.invites.map((i) => (
                      <li key={i.id} className="flex items-center gap-3 px-4 py-2.5 text-sm">
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-fg">{i.full_name}</div>
                          <div className="num truncate text-2xs text-fg-3" dir="ltr">
                            {i.email}
                          </div>
                        </div>
                        <span className="text-xs text-fg-2">{t(`roles.${i.role}`)}</span>
                        <span className="hidden text-2xs text-fg-3 sm:inline">{f.date(i.created_at)}</span>
                        <Button size="sm" variant="ghost" icon={<X className="size-3.5" />} onClick={() => void cancelInvite(i)}>
                          {t('team.cancel')}
                        </Button>
                      </li>
                    ))}
                  </ul>
                </Panel>
              )}
              <Panel>
                <PanelHeader index={data!.invites.length > 0 ? '03' : '02'} title={t('team.members')} />
                {data!.users.length <= 1 && data!.invites.length === 0 ? (
                  <EmptyState line="shield" title={t('team.empty')} />
                ) : null}
                <ul className="divide-y divide-glass-border">
                  {data!.users.map((u, k) => (
                    <motion.li key={u.id} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: k * 0.03 }} className="flex items-center gap-3 px-4 py-3 text-sm">
                      <div className={cn('grid size-9 shrink-0 place-items-center rounded-md border border-glass-border bg-raised font-semibold', u.deleted_at ? 'text-fg-3' : 'text-fg-2')}>{u.full_name.trim().charAt(0)}</div>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-fg">
                          {u.full_name} {u.id === me.id && <span className="text-2xs text-accent">({t('team.you')})</span>}
                        </div>
                        <div className="num truncate text-2xs text-fg-3" dir="ltr">
                          {u.email}
                        </div>
                      </div>
                      <span className="text-xs text-fg-2">{t(`roles.${u.role}`)}</span>
                      {u.role === 'reception' && !u.deleted_at && (
                        <span title={t('team.canCorrectHint')} data-testid="can-correct">
                          <Checkbox checked={!!u.can_correct} onChange={(v) => void setCorrect(u, v)} label={<span className="text-xs text-fg-2">{t('team.canCorrect')}</span>} />
                        </span>
                      )}
                      <span className={cn('rounded-full border px-2 py-0.5 text-2xs', u.deleted_at ? 'border-[color-mix(in_srgb,var(--danger)_35%,transparent)] text-danger' : 'border-[color-mix(in_srgb,var(--ok)_35%,transparent)] text-ok')}>
                        {u.deleted_at ? t('team.suspended') : t('team.active')}
                      </span>
                      {u.id !== me.id &&
                        (u.deleted_at ? (
                          <Button size="sm" variant="ghost" icon={<UserCheck className="size-3.5" />} onClick={() => void setActive(u, true)}>
                            {t('team.activate')}
                          </Button>
                        ) : (
                          <Button size="sm" variant="ghost" icon={<UserX className="size-3.5" />} onClick={() => setSuspend(u)}>
                            {t('team.suspend')}
                          </Button>
                        ))}
                    </motion.li>
                  ))}
                </ul>
              </Panel>
            </>
          )}
        </div>
      </div>
      <Dialog
        open={!!suspend}
        onOpenChange={(v) => !v && setSuspend(null)}
        title={t('team.suspendTitle')}
        description={suspend ? t('team.suspendText', { name: suspend.full_name }) : ''}
        footer={
          <>
            <Button variant="ghost" onClick={() => setSuspend(null)}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" onClick={() => suspend && void setActive(suspend, false)}>
              {t('team.suspend')}
            </Button>
          </>
        }
      />
    </div>
  );
}
