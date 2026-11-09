import { useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Sparkles } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useMe } from './auth';
import { loadAssistantState } from './AssistantPanel';
import { canUse, readAssistant, type AssistArea } from '../lib/assistantSettings';
import { addSensitive, deepScrub, sensitiveNames } from '../lib/assistPayloads';
import type { AssistantState } from '../lib/assistantStatus';
import { Button } from '../ui/Button';
import { Panel, PanelHeader } from '../ui/Panel';
import { cn } from '../ui/cn';

/**
 * المساعد في البرنامج كله (S3): كل مكان بيبعت نوع سؤال (kind) بحقول محددة، من غير أي بيانات عميل.
 * الاقتراح ما بيتنفذش لوحده أبدًا: بيظهر، والمستخدم يدوس "تطبيق" لو عايزه.
 * لو مفيش نت أو مفيش مفتاح: رسالة هادية، والدليل المدمج والاقتراحات المحلية شغالين.
 */
export type AssistKind = 'diagnose' | 'intake' | 'purchase' | 'finance_qa' | 'finance_week' | 'whatsapp' | 'report' | 'screen';
export type AssistError = 'off' | 'limit' | 'forbidden' | 'no-key' | 'offline' | 'unavailable';
export type AssistResult = { ok: true; answer: string; left: number | null } | { ok: false; error: AssistError };

export async function askAssistant(kind: AssistKind, body: Record<string, unknown>): Promise<AssistResult> {
  if (!navigator.onLine) return { ok: false, error: 'offline' };
  try {
    // آخر حماية: أي اسم عميل ظاهر على الشاشة، وأي رقم أو إيميل، بيتشال من كل النصوص قبل ما الطلب يخرج
    const { data, error } = await supabase.functions.invoke('assistant', { body: { ...deepScrub(body, sensitiveNames()), kind } });
    if (error) {
      const res = (error as { context?: Response }).context;
      let code = '';
      try {
        code = res && typeof res.json === 'function' ? String(((await res.clone().json()) as { error?: string }).error ?? '') : '';
      } catch {
        code = '';
      }
      if (!res) return { ok: false, error: 'offline' };
      if (code === 'E_PLAN_LIMIT') return { ok: false, error: 'limit' };
      if (code === 'E_AI_OFF') return { ok: false, error: 'off' };
      if (code === 'E_FORBIDDEN') return { ok: false, error: 'forbidden' };
      if (code === 'E_AI_DISABLED' || res.status === 503) return { ok: false, error: 'no-key' };
      return { ok: false, error: 'unavailable' };
    }
    const d = data as { answer?: string; left?: number | null };
    return d?.answer ? { ok: true, answer: String(d.answer), left: d.left ?? null } : { ok: false, error: 'unavailable' };
  } catch {
    return { ok: false, error: navigator.onLine ? 'unavailable' : 'offline' };
  }
}

/** الشاشة بتسجّل أسماء العملاء اللي ظاهرة عليها، عشان ما تخرجش للمساعد أبدًا */
export function useSensitiveNames(names: (string | null | undefined)[]) {
  const key = names.filter(Boolean).join('\u0001');
  useEffect(() => addSensitive(key ? key.split('\u0001') : []), [key]);
}

/** المستخدم ده يقدر يستخدم المساعد في المكان ده؟ (حسب إعدادات صاحب المحل ودوره) */
export function useAssistAllowed(area: AssistArea): boolean {
  const { shop, profile } = useMe();
  return canUse(readAssistant(shop.extras), area, profile.role);
}

/** حالة السيرفر (مفتاح، ومنشور، ونت) مرة واحدة */
export function useAssistServer(): AssistantState | null {
  const [state, setState] = useState<AssistantState | null>(null);
  useEffect(() => {
    let live = true;
    void loadAssistantState().then((v) => live && setState(v));
    const on = () => void loadAssistantState().then((v) => live && setState(v));
    window.addEventListener('online', on);
    window.addEventListener('offline', on);
    return () => {
      live = false;
      window.removeEventListener('online', on);
      window.removeEventListener('offline', on);
    };
  }, []);
  return state;
}

/** رسالة هادية بسطر واحد: محتاج إنترنت / محتاج مفتاح / الحد خلص... */
export function AssistNote({ state }: { state: AssistantState | AssistError | null }) {
  const { t } = useTranslation();
  if (!state || state === 'on') return null;
  const key = state === 'no-function' ? 'no-key' : state;
  return (
    <p className="text-xs text-fg-3" data-testid="assist-note" data-state={key}>
      {t(`assist.note.${key}`)}
    </p>
  );
}

/**
 * صندوق المساعد: زرار "اسأل"، والرد، وأزرار التطبيق اللي المكان بيحددها.
 * build بيرجع الطلب (من غير بيانات عميل). render بيرسم الرد ومعاه "تطبيق".
 * fallback: اللي بيظهر دايمًا (اقتراحات محلية أو الدليل المدمج) حتى من غير نت أو مفتاح.
 */
export function AssistBox({
  area,
  kind,
  title,
  askLabel,
  build,
  render,
  fallback,
  privacy,
  testid,
  className,
  compact,
}: {
  area: AssistArea;
  kind: AssistKind;
  title: string;
  askLabel: string;
  build: () => Record<string, unknown> | null;
  render: (answer: string) => ReactNode;
  fallback?: ReactNode;
  privacy?: string;
  testid: string;
  className?: string;
  compact?: boolean;
}) {
  const { t } = useTranslation();
  const allowed = useAssistAllowed(area);
  const server = useAssistServer();
  const [busy, setBusy] = useState(false);
  const [answer, setAnswer] = useState<string | null>(null);
  const [err, setErr] = useState<AssistError | null>(null);
  if (!allowed) return fallback ? <div className={className}>{fallback}</div> : null;
  async function ask() {
    const body = build();
    if (!body) return;
    setBusy(true);
    setErr(null);
    setAnswer(null);
    const r = await askAssistant(kind, body);
    setBusy(false);
    if (r.ok) setAnswer(r.answer);
    else setErr(r.error);
  }
  const ready = server === 'on';
  const inner = (
    <div className={cn('flex flex-col gap-2', compact ? '' : 'p-4')} data-testid={testid}>
      {privacy && <p className="text-2xs text-fg-3">{privacy}</p>}
      <div className="flex flex-wrap items-center gap-2">
        <Button size="sm" variant={ready ? 'primary' : 'secondary'} icon={<Sparkles className="size-4" />} loading={busy} disabled={!ready} onClick={() => void ask()} data-testid={`${testid}-ask`}>
          {askLabel}
        </Button>
        <AssistNote state={err ?? server} />
      </div>
      {answer && (
        <div className="rounded-md border border-glass-border bg-sunken/40 p-3 text-sm text-fg" data-testid={`${testid}-answer`}>
          {render(answer)}
          <p className="mt-2 text-2xs text-fg-3">{t('assist.applyHint')}</p>
        </div>
      )}
      {fallback}
    </div>
  );
  if (compact) return <div className={className}>{inner}</div>;
  return (
    <Panel className={className}>
      <PanelHeader title={title} />
      {inner}
    </Panel>
  );
}
