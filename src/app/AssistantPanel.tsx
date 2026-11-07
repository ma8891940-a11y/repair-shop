import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { BookOpen, Bot, Send } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { assistantPayload } from '../lib/aiScrub';
import { matchFaults, type FaultKey } from '../lib/faultGuide';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Alert } from '../ui/Feedback';

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
  // المساعد متفعّل على السيرفر؟ (null = لسه بنسأل)
  const [enabled, setEnabled] = useState<boolean | null>(null);

  useEffect(() => {
    let live = true;
    supabase.functions
      .invoke('assistant', { body: { status: true } })
      .then(({ data, error }) => live && setEnabled(!error && data?.enabled === true))
      .catch(() => live && setEnabled(false));
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
      const { data, error } = await supabase.functions.invoke('assistant', { body: assistantPayload({ brand, model, issue, names }) });
      if (error || !data?.answer) throw error ?? new Error('E_AI_UNAVAILABLE');
      setAnswer(String(data.answer));
    } catch (e) {
      const ctx = (e as { context?: { status?: number } })?.context;
      setNote(ctx?.status === 403 ? t('assistant.limit') : ctx?.status === 503 ? t('assistant.disabled') : t('assistant.offlineGuide'));
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
        {enabled === false && (
          <div data-testid="assistant-disabled">
            <Alert tone="info">{t('assistant.disabled')}</Alert>
          </div>
        )}
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
