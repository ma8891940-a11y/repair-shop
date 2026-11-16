import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { KeyRound, ShieldCheck, ShieldOff } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Input } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert, Skeleton } from '../../ui/Feedback';
import { OtpInput } from '../../ui/OtpInput';
import { useToast } from '../../ui/Toast';

/** C3: الإعدادات ← الأمان: كلمة السر الرئيسية للعمليات الحساسة، والتحقق بخطوتين لصاحب المحل */
export function SecurityTab() {
  return (
    <div className="flex flex-col gap-4">
      <MasterPanel />
      <MfaPanel />
    </div>
  );
}

function MasterPanel() {
  const { t } = useTranslation();
  const toast = useToast();
  const [has, setHas] = useState<boolean | null>(null);
  const [old, setOld] = useState('');
  const [pw, setPw] = useState('');
  const [pw2, setPw2] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const load = useCallback(async () => {
    const { data } = await supabase.rpc('has_master_password');
    setHas(Boolean(data));
  }, []);
  useEffect(() => {
    void load();
  }, [load]);

  async function save(remove: boolean) {
    setErr(null);
    if (!remove && pw.length < 6) return setErr(t('master.short'));
    if (!remove && pw !== pw2) return setErr(t('master.mismatch'));
    setBusy(true);
    const { data, error } = await supabase.rpc('set_master_password', { p_old: has ? old : null, p_new: remove ? '' : pw });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    if (data === 'wrong') return setErr(t('master.wrong'));
    setOld('');
    setPw('');
    setPw2('');
    toast({ tone: 'ok', title: remove ? t('master.removed') : t('master.saved') });
    await load();
  }

  return (
    <Panel data-testid="master-settings">
      <PanelHeader title={t('master.title')} actions={has != null && <span className={has ? 'text-xs text-ok' : 'text-xs text-fg-3'}>{has ? t('master.on') : t('master.off')}</span>} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('master.hint')}</p>
        {has === null ? (
          <Skeleton className="h-24 w-full" />
        ) : (
          <>
            {has && (
              <Field label={t('master.current')}>
                <Input type="password" autoComplete="off" value={old} onChange={(e) => setOld(e.target.value)} className="max-w-xs" data-testid="master-old" />
              </Field>
            )}
            <div className="flex flex-wrap gap-3">
              <Field label={has ? t('master.new') : t('master.label')} hint={t('master.short')}>
                <Input type="password" autoComplete="new-password" value={pw} onChange={(e) => setPw(e.target.value)} className="max-w-xs" data-testid="master-new" />
              </Field>
              <Field label={t('master.repeat')}>
                <Input type="password" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} className="max-w-xs" data-testid="master-repeat" />
              </Field>
            </div>
            {err && <Alert tone="danger">{err}</Alert>}
            <div className="flex flex-wrap gap-2">
              <Button variant="primary" loading={busy} onClick={() => void save(false)} icon={<KeyRound className="size-4" />} data-testid="master-save">
                {has ? t('master.change') : t('master.set')}
              </Button>
              {has && (
                <Button variant="ghost" disabled={busy || !old} onClick={() => void save(true)} data-testid="master-remove">
                  {t('master.remove')}
                </Button>
              )}
            </div>
          </>
        )}
      </div>
    </Panel>
  );
}

interface Factor {
  id: string;
  status: string;
}

function MfaPanel() {
  const { t } = useTranslation();
  const toast = useToast();
  const [factors, setFactors] = useState<Factor[] | null>(null);
  const [enroll, setEnroll] = useState<{ id: string; qr: string; secret: string } | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const load = useCallback(async () => {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (error) return setErr(errorMessage(error));
    setFactors((data?.totp ?? []) as Factor[]);
  }, []);
  useEffect(() => {
    void load();
  }, [load]);
  const active = factors?.find((f) => f.status === 'verified');

  async function start() {
    setErr(null);
    setBusy(true);
    // أي محاولة قديمة ما كملتش بتتشال الأول
    for (const f of factors ?? []) if (f.status !== 'verified') await supabase.auth.mfa.unenroll({ factorId: f.id });
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: `gawalak-${Date.now()}` });
    setBusy(false);
    if (error || !data) return setErr(errorMessage(error));
    setEnroll({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
  }
  async function confirm() {
    if (!enroll || code.length !== 6) return;
    setErr(null);
    setBusy(true);
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: enroll.id, code });
    setBusy(false);
    if (error) {
      setCode('');
      return setErr(/invalid|expired/i.test(error.message) ? t('mfa.wrong') : errorMessage(error));
    }
    setEnroll(null);
    setCode('');
    toast({ tone: 'ok', title: t('mfa.enabled') });
    await load();
  }
  async function disable() {
    if (!active) return;
    setErr(null);
    setBusy(true);
    const { error } = await supabase.auth.mfa.unenroll({ factorId: active.id });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('mfa.disabled') });
    await load();
  }

  return (
    <Panel data-testid="mfa-settings">
      <PanelHeader title={t('mfa.settingsTitle')} actions={factors && <span className={active ? 'text-xs text-ok' : 'text-xs text-fg-3'}>{active ? t('master.on') : t('master.off')}</span>} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('mfa.hint')}</p>
        {factors === null ? (
          <Skeleton className="h-16 w-full" />
        ) : active ? (
          <Button variant="ghost" loading={busy} onClick={() => void disable()} icon={<ShieldOff className="size-4" />} className="self-start" data-testid="mfa-disable">
            {t('mfa.disable')}
          </Button>
        ) : enroll ? (
          <div className="flex flex-col gap-3" data-testid="mfa-enroll">
            <p className="text-sm text-fg-2">{t('mfa.scan')}</p>
            <img src={enroll.qr} alt={t('mfa.qr')} className="size-44 rounded-lg bg-white p-2" />
            <p className="text-2xs text-fg-3">
              {t('mfa.manual')}{' '}
              <code className="num select-all text-fg" dir="ltr" data-testid="mfa-secret">
                {enroll.secret}
              </code>
            </p>
            <OtpInput value={code} onChange={setCode} label={t('mfa.code')} invalid={!!err} disabled={busy} />
            <Button variant="primary" loading={busy} disabled={code.length !== 6} onClick={() => void confirm()} className="self-start" data-testid="mfa-confirm">
              {t('mfa.verify')}
            </Button>
          </div>
        ) : (
          <Button variant="primary" loading={busy} onClick={() => void start()} icon={<ShieldCheck className="size-4" />} className="self-start" data-testid="mfa-enable">
            {t('mfa.enable')}
          </Button>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Panel>
  );
}
