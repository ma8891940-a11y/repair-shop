import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Send } from 'lucide-react';
import { useLoad } from '../../app/useLoad';
import { rpc } from '../../app/ledgerApi';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Input } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { ChipToggle } from '../../ui/Checkbox';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

const EVENTS = ['intake', 'ready', 'delivered'] as const;
interface Status {
  configured: boolean;
  enabled?: boolean;
  chat?: string;
  events?: string[];
}

/** C8: إشعارات تيليجرام لصاحب المحل (اختياري ومجاني). الـ token بيتكتب ويتحفظ مشفّر، وما بيرجعش للشاشة */
export function TelegramPanel() {
  const { t } = useTranslation();
  const toast = useToast();
  const { data, reload } = useLoad(async () => (await rpc('telegram_status')) as Status, []);
  const [token, setToken] = useState('');
  const [chat, setChat] = useState<string | null>(null);
  const [events, setEvents] = useState<string[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const chatV = chat ?? data?.chat ?? '';
  const evV = events ?? data?.events ?? [...EVENTS];
  async function save() {
    setErr(null);
    setBusy(true);
    try {
      await rpc('set_telegram', { p_token: token.trim() || null, p_chat: chatV.trim(), p_events: evV });
      setToken('');
      toast({ tone: 'ok', title: t('settings.saved') });
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function test() {
    setErr(null);
    try {
      const ok = (await rpc('telegram_test')) as boolean;
      toast({ tone: ok ? 'ok' : 'warn', title: ok ? t('telegram.testSent') : t('telegram.testOff') });
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  async function off() {
    await rpc('disable_telegram');
    reload();
  }
  return (
    <Panel data-testid="telegram-settings">
      <PanelHeader title={t('telegram.title')} actions={data && <span className={data.enabled ? 'text-xs text-ok' : 'text-xs text-fg-3'}>{data.enabled ? t('master.on') : t('master.off')}</span>} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('telegram.hint')}</p>
        <ol className="list-decimal ps-5 text-xs text-fg-2">
          <li>{t('telegram.step1')}</li>
          <li>{t('telegram.step2')}</li>
          <li>{t('telegram.step3')}</li>
        </ol>
        {!data ? (
          <Skeleton className="h-24 w-full" />
        ) : (
          <>
            <div className="flex flex-wrap gap-3">
              <Field label={t('telegram.token')} hint={data.configured ? t('telegram.tokenKept') : undefined}>
                <Input type="password" autoComplete="off" dir="ltr" value={token} onChange={(e) => setToken(e.target.value)} placeholder={data.configured ? '••••••••' : '123456789:AA...'} className="w-72 max-w-full" data-testid="telegram-token" />
              </Field>
              <Field label={t('telegram.chat')}>
                <Input dir="ltr" value={chatV} onChange={(e) => setChat(e.target.value)} placeholder="123456789" className="w-44" data-testid="telegram-chat" />
              </Field>
            </div>
            <div className="flex flex-wrap gap-2" role="group" aria-label={t('telegram.events')}>
              {EVENTS.map((ev) => (
                <ChipToggle key={ev} pressed={evV.includes(ev)} onChange={(v) => setEvents(v ? [...evV, ev] : evV.filter((x) => x !== ev))}>
                  {t(`telegram.ev.${ev}`)}
                </ChipToggle>
              ))}
            </div>
            {err && <Alert tone="danger">{err}</Alert>}
            <div className="flex flex-wrap gap-2">
              <Button variant="primary" loading={busy} onClick={() => void save()} data-testid="telegram-save">
                {t('common.save')}
              </Button>
              {data.configured && (
                <Button onClick={() => void test()} icon={<Send className="size-4" />} data-testid="telegram-test">
                  {t('telegram.test')}
                </Button>
              )}
              {data.enabled && (
                <Button variant="ghost" onClick={() => void off()}>
                  {t('telegram.off')}
                </Button>
              )}
            </div>
          </>
        )}
      </div>
    </Panel>
  );
}
