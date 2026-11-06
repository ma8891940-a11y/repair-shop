import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Bot, Send } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { assistantPayload } from '../lib/aiScrub';
import { matchFaults, type FaultKey } from '../lib/faultGuide';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Textarea } from '../ui/Field';
import { Alert } from '../ui/Feedback';

/**
 * المساعد الذكي في صفحة الجهاز: بيبعت نوع الجهاز والعطل والسؤال بس (متنضّفين من أي بيانات عميل).
 * لو المساعد مش مفعّل أو مفيش نت أو الحد اليومي خلص: دليل الأعطال المدمج (مجاني).
 */
export function AssistantPanel({ brand, model, issue, names }: { brand: string; model: string; issue: string; names: string[] }) {
  const { t } = useTranslation();
  const [q, setQ] = useState('');
  const [busy, setBusy] = useState(false);
  const [answer, setAnswer] = useState<string | null>(null);
  const [guide, setGuide] = useState<FaultKey[] | null>(null);
  const [note, setNote] = useState<string | null>(null);

  async function ask() {
    const question = q.trim() || t('assistant.defaultQ');
    setBusy(true);
    setAnswer(null);
    setGuide(null);
    setNote(null);
    const payload = assistantPayload({ brand, model, issue, question, names });
    try {
      const { data, error } = await supabase.functions.invoke('assistant', { body: payload });
      if (error || !data?.answer) throw error ?? new Error('E_AI_DISABLED');
      setAnswer(String(data.answer));
    } catch (e) {
      // الدليل المدمج
      const ctx = (e as { context?: { status?: number } })?.context;
      setNote(ctx?.status === 403 ? t('assistant.limit') : t('assistant.offlineGuide'));
      const keys = matchFaults(`${issue} ${question}`);
      setGuide(keys.length ? keys.slice(0, 2) : []);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel>
      <PanelHeader title={t('assistant.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-2xs text-fg-3">{t('assistant.privacy')}</p>
        <Textarea rows={2} value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('assistant.placeholder')} aria-label={t('assistant.ask')} maxLength={800} />
        <Button size="sm" loading={busy} icon={busy ? undefined : <Send className="size-4" />} onClick={() => void ask()} className="self-start">
          {t('assistant.ask')}
        </Button>
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
