import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { BookOpen, Bot, Send } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { assistantPayload } from '../lib/aiScrub';
import { deepScrub, sensitiveNames } from '../lib/assistPayloads';
import { matchFaults, type FaultKey } from '../lib/faultGuide';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Alert } from '../ui/Feedback';
import { useMe } from './auth';
import { assistantState, type AssistantState } from '../lib/assistantStatus';
import { canUse, readAssistant } from '../lib/assistantSettings';

// حالة المساعد على السيرفر: بنسأل مرة واحدة في كل فتحة للبرنامج (ولو ما اشتغلش بنسأل تاني المرة الجاية)
let stateOnce: Promise<AssistantState> | null = null;
export function loadAssistantState(): Promise<AssistantState> {
  stateOnce ??= supabase.functions
    .invoke('assistant', { body: { status: true } })
    .then(({ data, error }) => {
      const ctx = (error as { context?: { status?: number } } | null)?.context;
      return assistantState({ data: error ? null : (data as { enabled?: boolean }), status: ctx?.status ?? null, networkError: !!error && !ctx, online: navigator.onLine });
    })
    .catch(() => assistantState({ networkError: true, online: navigator.onLine }))
    .then((v) => {
      if (v !== 'on') stateOnce = null;
      return v;
    });
  return stateOnce;
}

/** سبب إن المساعد مش شغال، بالعربي، وخطوات الحل لصاحب المحل (الفني بيتقاله يكلّم صاحب المحل) */
export function AssistantStateNote({ state }: { state: AssistantState }) {
  const { t } = useTranslation();
  const { profile } = useMe();
  if (state === 'on') return null;
  const owner = profile.role === 'owner';
  return (
    <div data-testid="assistant-disabled" data-state={state}>
      <Alert tone={state === 'offline' ? 'info' : 'warn'} title={t(`assistant.state.${state}.title`)}>
        <p>{t(`assistant.state.${state}.why`)}</p>
        {state !== 'offline' &&
          (owner ? (
            <ol className="mt-2 list-decimal space-y-0.5 ps-5 text-xs">
              {(t(`assistant.state.${state}.steps`, { returnObjects: true }) as string[]).map((st) => (
                <li key={st}>
                  <bdi>{st}</bdi>
                </li>
              ))}
            </ol>
          ) : (
            <p className="mt-1 text-xs">{t('assistant.askOwner')}</p>
          ))}
      </Alert>
    </div>
  );
}

/**
 * المساعد الذكي في صفحة الجهاز (Gemini المجاني من السيرفر): بيبعت الموديل ووصف العطل بس، متنضّفين من أي بيانات عميل.
 * لو مفيش مفتاح على السيرفر: مقفول برسالة واضحة. ودليل الأعطال المدمج (مجاني ومن غير نت) متاح دايمًا.
 */
export function AssistantPanel({ brand, model, issue, names }: { brand: string; model: string; issue: string; names: string[] }) {
  const { t } = useTranslation();
  const [busy, setBusy] = useState(false);
  const [answer, setAnswer] = useState<string | null>(null);
  const [guide, setGuide] = useState<FaultKey[] | null>(null);
  const [note, setNote] = useState<string | null>(null);
  // حالة المساعد على السيرفر (null = لسه بنسأل)
  const [state, setState] = useState<AssistantState | null>(null);
  // صاحب المحل ممكن يقفل التشخيص أو يقفله على الفنيين (الإعدادات ← المساعد). الدليل المدمج شغال دايمًا
  const { shop, profile } = useMe();
  const allowed = canUse(readAssistant(shop.extras), 'tech', profile.role);
  const enabled = state === null ? null : state === 'on' && allowed;

  useEffect(() => {
    let live = true;
    void loadAssistantState().then((v) => live && setState(v));
    return () => {
      live = false;
    };
  }, []);

  function showGuide() {
    const keys = matchFaults(issue);
    setGuide(keys.length ? keys.slice(0, 2) : []);
  }

  async function ask() {
    setBusy(true);
    setAnswer(null);
    setGuide(null);
    setNote(null);
    try {
      const { data, error } = await supabase.functions.invoke('assistant', { body: { ...deepScrub(assistantPayload({ brand, model, issue, names }), sensitiveNames()), kind: 'diagnose' } });
      if (error || !data?.answer) throw error ?? new Error('E_AI_UNAVAILABLE');
      setAnswer(String(data.answer));
    } catch (e) {
      const ctx = (e as { context?: { status?: number } })?.context;
      let code = '';
      try {
        code = String((((await (ctx as Response | undefined)?.clone().json()) ?? {}) as { error?: string }).error ?? '');
      } catch {
        code = '';
      }
      setNote(code === 'E_AI_OFF' ? t('assist.note.off') : ctx?.status === 403 ? t('assistant.limit') : ctx?.status === 503 ? t('assistant.disabled') : t('assistant.offlineGuide'));
      showGuide();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel>
      <PanelHeader title={t('assistant.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-2xs text-fg-3">{t('assistant.privacy')}</p>
        {state && allowed && <AssistantStateNote state={state} />}
        {!allowed && <p className="text-xs text-fg-3" data-testid="assist-off-here">{t('assist.note.off')}</p>}
        <div className="flex flex-wrap gap-2">
          {enabled && (
            <Button size="sm" variant="primary" loading={busy} icon={busy ? undefined : <Send className="size-4" />} onClick={() => void ask()} disabled={!issue.trim()}>
              {t('assistant.ask')}
            </Button>
          )}
          <Button size="sm" icon={<BookOpen className="size-4" />} onClick={showGuide}>
            {t('assistant.guide')}
          </Button>
        </div>
        {answer && (
          <div className="whitespace-pre-wrap rounded-md border border-glass-border bg-sunken/40 p-3 text-sm text-fg" data-testid="assistant-answer">
            <Bot className="mb-1 size-4 text-accent" aria-hidden />
            {answer}
          </div>
        )}
        {note && <Alert tone="info">{note}</Alert>}
        {guide && (
          <div className="flex flex-col gap-3" data-testid="assistant-guide">
            {guide.length === 0 && <p className="text-sm text-fg-3">{t('assistant.noMatch')}</p>}
            {guide.map((k) => (
              <div key={k} className="rounded-md border border-glass-border p-3 text-sm">
                <div className="font-semibold text-fg">{t(`guide.${k}.title`)}</div>
                <div className="mt-1 text-2xs font-medium text-fg-3">{t('assistant.causes')}</div>
                <p className="text-fg-2">{t(`guide.${k}.causes`)}</p>
                <div className="mt-1 text-2xs font-medium text-fg-3">{t('assistant.steps')}</div>
                <p className="whitespace-pre-wrap text-fg-2">{t(`guide.${k}.steps`)}</p>
                {t(`guide.${k}.warn`, { defaultValue: '' }) && <p className="mt-1 text-2xs text-warn">{t(`guide.${k}.warn`)}</p>}
              </div>
            ))}
          </div>
        )}
      </div>
    </Panel>
  );
}
