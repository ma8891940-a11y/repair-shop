import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { rpc } from '../../app/ledgerApi';
import { AssistantStateNote } from '../../app/AssistantPanel';
import { useAssistServer } from '../../app/assist';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { toLatinDigits } from '../../lib/digits';
import { AREAS, readAssistant, type AssistantSettings, type AssistArea } from '../../lib/assistantSettings';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { Button } from '../../ui/Button';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/**
 * الإعدادات ← المساعد (صاحب المحل): تشغيل عام، وكل مكان لوحده، ومين من الموظفين يستخدمه، وحد يومي.
 * المالية مقفولة افتراضيًا ومعاها تنبيه الطبقة المجانية. كل ده بيتطبق في قاعدة البيانات نفسها (ai_take_area).
 */
export function AssistantTab() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const server = useAssistServer();
  const s = readAssistant(shop.extras);
  const [usage, setUsage] = useState<{ used: number; limit: number; plan_limit: number } | null>(null);
  const [daily, setDaily] = useState(s.daily == null ? '' : String(s.daily));
  useEffect(() => {
    void rpc<{ used: number; limit: number; plan_limit: number }>('assistant_info').then(setUsage).catch(() => undefined);
  }, [shop.extras]);

  async function save(patch: Partial<AssistantSettings>) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const next = { ...s, ...patch };
    const { error } = await supabase.from('shops').update({ extras: { ...ex, assistant: next } }).eq('id', shop.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  const area = (a: AssistArea, v: boolean) => void save({ areas: { ...s.areas, [a]: v } });

  return (
    <div className="flex flex-col gap-4" data-testid="assistant-settings">
      <Panel>
        <PanelHeader index="01" title={t('assistSet.status')} />
        <div className="flex flex-col gap-3 p-4">
          {server === 'on' ? <Alert tone="ok">{t('assistSet.ready')}</Alert> : server ? <AssistantStateNote state={server} /> : null}
          <p className="text-xs text-fg-3">{t('assistSet.setup')}</p>
          {usage && (
            <p className="text-sm text-fg-2" data-testid="assistant-usage">
              {t('assistSet.usage', { used: f.number(usage.used), limit: f.number(usage.limit) })}
            </p>
          )}
        </div>
      </Panel>
      <Panel>
        <PanelHeader index="02" title={t('assistSet.where')} />
        <div className="flex flex-col gap-3 p-4">
          <Checkbox checked={s.enabled} onChange={(v) => void save({ enabled: v })} label={t('assistSet.enabled')} />
          <div className={cn('ms-7 grid gap-3 sm:grid-cols-2', !s.enabled && 'pointer-events-none opacity-50')}>
            {AREAS.map((a) => (
              <div key={a}>
                <Checkbox checked={s.areas[a]} onChange={(v) => area(a, v)} label={t(`assistSet.areas.${a}`)} />
                <p className="ms-7 mt-0.5 text-2xs text-fg-3">{t(`assistSet.areaHints.${a}`)}</p>
              </div>
            ))}
          </div>
          <Alert tone="warn" title={t('assistSet.financeWarnTitle')}>
            {t('assistSet.financeWarn')}
          </Alert>
          <p className="text-2xs text-fg-3">{t('assistSet.never')}</p>
        </div>
      </Panel>
      <Panel>
        <PanelHeader index="03" title={t('assistSet.who')} />
        <div className="flex flex-col gap-3 p-4">
          <Checkbox checked={s.staff.reception} onChange={(v) => void save({ staff: { ...s.staff, reception: v } })} label={t('assistSet.staff.reception')} />
          <Checkbox checked={s.staff.technician} onChange={(v) => void save({ staff: { ...s.staff, technician: v } })} label={t('assistSet.staff.technician')} />
          <p className="text-2xs text-fg-3">{t('assistSet.whoHint')}</p>
        </div>
      </Panel>
      <Panel>
        <PanelHeader index="04" title={t('assistSet.limit')} />
        <form
          className="flex flex-wrap items-end gap-2 p-4"
          onSubmit={(e) => {
            e.preventDefault();
            const v = toLatinDigits(daily.trim());
            if (v && !/^\d{1,5}$/.test(v)) return toast({ tone: 'danger', title: t('assistSet.limitBad') });
            void save({ daily: v ? Number(v) : null });
          }}
        >
          <Field label={t('assistSet.limitLabel')} hint={usage ? t('assistSet.limitHint', { n: f.number(usage.plan_limit) }) : undefined}>
            <Input value={daily} onChange={(e) => setDaily(e.target.value)} inputMode="numeric" className="w-32" mono data-testid="assistant-daily" />
          </Field>
          <Button type="submit" variant="primary" needsNet>
            {t('common.save')}
          </Button>
        </form>
      </Panel>
    </div>
  );
}
