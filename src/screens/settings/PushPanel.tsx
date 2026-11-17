import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { BellRing } from 'lucide-react';
import { useMe } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { disablePush, enablePush, pushState, sendTestPush, type PushState } from '../../lib/push';
import { readPushWindow } from '../../lib/pushWindow';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Select } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

const HOURS = Array.from({ length: 25 }, (_, h) => h);

/**
 * N المرحلة التانية: إشعارات على الجهاز (Web Push). نفس إشعارات الجرس، بتوصل حتى والبرنامج مقفول.
 * كل مستخدم بيفعّلها لجهازه هو. وصاحب المحل بيحدد وقت الإشعارات للمحل كله.
 */
export function PushPanel() {
  const { t, i18n } = useTranslation();
  const { shop, profile, refresh } = useMe();
  const toast = useToast();
  const owner = profile.role === 'owner';
  const [state, setState] = useState<PushState | null>(null);
  const [note, setNote] = useState<{ tone: 'danger' | 'info'; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const w = readPushWindow(shop.extras);
  const [from, setFrom] = useState(String(w.from));
  const [to, setTo] = useState(String(w.to));
  useEffect(() => {
    setFrom(String(w.from));
    setTo(String(w.to));
  }, [w.from, w.to]);

  useEffect(() => {
    let live = true;
    void pushState().then((s) => live && setState(s));
    return () => {
      live = false;
    };
  }, []);

  async function enable() {
    setNote(null);
    setBusy(true);
    try {
      const r = await enablePush(i18n.language);
      if (r === 'on') {
        setState('on');
        toast({ tone: 'ok', title: t('push.enabled') });
      } else if (r === 'denied') {
        setState('denied');
      } else if (r === 'unsupported') {
        setState('unsupported');
      } else {
        setNote({ tone: 'info', text: t('push.notConfigured') });
      }
    } catch (e) {
      setNote({ tone: 'danger', text: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }
  async function disable() {
    setNote(null);
    setBusy(true);
    await disablePush();
    setBusy(false);
    setState('off');
    toast({ tone: 'ok', title: t('push.disabled') });
  }
  async function test() {
    setNote(null);
    setBusy(true);
    try {
      const r = await sendTestPush();
      setNote({ tone: 'info', text: r.devices ? t('push.testSent') : t('push.testNone') });
    } catch {
      setNote({ tone: 'info', text: t('push.notConfigured') });
    } finally {
      setBusy(false);
    }
  }
  async function saveWindow() {
    setNote(null);
    const raw = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const prev = (raw.reminders && typeof raw.reminders === 'object' ? raw.reminders : {}) as Record<string, unknown>;
    const { error } = await supabase
      .from('shops')
      .update({ extras: { ...raw, reminders: { ...prev, push_from: Number(from), push_to: Number(to) } } })
      .eq('id', shop.id);
    if (error) return setNote({ tone: 'danger', text: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }

  return (
    <Panel data-testid="push-settings">
      <PanelHeader title={t('push.section')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('push.hint')}</p>
        {state === null ? (
          <Skeleton className="h-9 w-64" />
        ) : state === 'unsupported' ? (
          <Alert tone="info">{t('push.unsupported')}</Alert>
        ) : state === 'denied' ? (
          <Alert tone="danger">{t('push.denied')}</Alert>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <span className="flex items-center gap-1.5 text-sm text-fg-2" data-testid="push-state" data-state={state}>
              <BellRing className={state === 'on' ? 'size-4 text-accent' : 'size-4 text-fg-3'} aria-hidden />
              {t(state === 'on' ? 'push.on' : 'push.off')}
            </span>
            {state === 'on' ? (
              <>
                <Button size="sm" loading={busy} onClick={() => void test()} data-testid="push-test">
                  {t('push.sendTest')}
                </Button>
                <Button size="sm" variant="ghost" disabled={busy} onClick={() => void disable()} data-testid="push-disable">
                  {t('push.disable')}
                </Button>
              </>
            ) : (
              <Button size="sm" variant="primary" loading={busy} onClick={() => void enable()} data-testid="push-enable">
                {t('push.enable')}
              </Button>
            )}
          </div>
        )}
        {note && <Alert tone={note.tone}>{note.text}</Alert>}
        {owner && (
          <div className="flex flex-wrap items-end gap-2 border-t border-line pt-3">
            <Field label={t('push.from')} hint={t('push.window')}>
              <Select value={from} onChange={(e) => setFrom(e.target.value)} className="w-28" data-testid="push-from">
                {HOURS.slice(0, 24).map((h) => (
                  <option key={h} value={h}>
                    {t('push.hour', { h: String(h).padStart(2, '0') })}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t('push.to')}>
              <Select value={to} onChange={(e) => setTo(e.target.value)} className="w-28" data-testid="push-to">
                {HOURS.slice(1).map((h) => (
                  <option key={h} value={h}>
                    {t('push.hour', { h: String(h).padStart(2, '0') })}
                  </option>
                ))}
              </Select>
            </Field>
            <Button variant="primary" onClick={() => void saveWindow()} className="mb-5" data-testid="push-window-save">
              {t('common.save')}
            </Button>
            <p className="w-full text-2xs text-fg-3">{t('push.windowHint')}</p>
          </div>
        )}
      </div>
    </Panel>
  );
}
