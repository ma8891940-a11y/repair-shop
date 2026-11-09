import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { PLACEHOLDERS, TEMPLATE_KEYS, fillTemplate, type TemplateKey } from '../../lib/messages';
import { useTemplates } from '../../app/messaging';
import { useMe } from '../../app/auth';
import { Button } from '../../ui/Button';
import { Field, Textarea } from '../../ui/Field';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/** صاحب المحل بيعدّل قوالب رسايل واتساب. "رجّع الافتراضي" بيعمل soft delete للقالب المعدّل. */
export function MessagesTab() {
  const { t } = useTranslation();
  const { shop } = useMe();
  const toast = useToast();
  const tpl = useTemplates();
  const [key, setKey] = useState<TemplateKey>('received');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const current = tpl.get(key);
  useEffect(() => setBody(current), [current, key]);

  // معاينة ببيانات تجريبية
  const sample = useMemo(
    () => ({ name: t('settingsMsg.sample.name'), order: '2026-0042', device: 'iPhone 13', status: t('status.ready'), cost: `1,250 ${t(`currency.${shop.currency}`)}`, link: 'https://…/#/t/…', shop: shop.name, tech: t('settingsMsg.sample.tech'), days: '12', warranty: '2026-12-31' }),
    [t, shop],
  );

  async function write(patch: { body: string; deleted_at: string | null }) {
    setErr(null);
    setBusy(true);
    const { data: existing, error: e1 } = await supabase.from('message_templates').select('id').eq('key', key).maybeSingle();
    const { error } = e1
      ? { error: e1 }
      : existing
        ? await supabase.from('message_templates').update(patch).eq('id', existing.id)
        : patch.deleted_at
          ? { error: null }
          : await supabase.from('message_templates').insert({ id: crypto.randomUUID(), shop_id: shop.id, key, body: patch.body });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('settings.saved') });
    tpl.reload();
  }

  const empty = body.trim().length === 0;
  const custom = tpl.custom[key] !== undefined;
  return (
    <div className="grid gap-4 md:grid-cols-[200px_minmax(0,1fr)]">
      <Panel className="p-1.5">
        <div role="tablist" aria-orientation="vertical" aria-label={t('settingsMsg.tab')} className="flex flex-col gap-0.5">
          {TEMPLATE_KEYS.map((k) => (
            <button
              key={k}
              type="button"
              role="tab"
              aria-selected={k === key}
              onClick={() => setKey(k)}
              className={cn('flex h-9 items-center justify-between rounded-sm px-3 text-start text-sm transition-colors', k === key ? 'bg-accent-soft text-fg' : 'text-fg-2 hover:bg-raised/60')}
            >
              {t(`wa.keys.${k}`)}
              {tpl.custom[k] !== undefined && <span className="size-1.5 rounded-full bg-accent" aria-label={t('settingsMsg.custom')} />}
            </button>
          ))}
        </div>
      </Panel>
      <div className="flex min-w-0 flex-col gap-4">
        <Panel className="p-4">
          <p className="mb-3 text-xs text-fg-3">{t('settingsMsg.hint')}</p>
          <Field label={t(`wa.keys.${key}`)} error={empty ? t('settingsMsg.empty') : undefined}>
            <Textarea id="tpl-body" rows={5} maxLength={1000} value={body} onChange={(e) => setBody(e.target.value)} />
          </Field>
          <div className="mt-3">
            <div className="readout-label mb-1.5">{t('wa.placeholders')}</div>
            <div className="flex flex-wrap gap-1.5">
              {PLACEHOLDERS.map((p) => (
                <button key={p} type="button" onClick={() => setBody((b) => `${b}{${p}}`)} className="num h-6 rounded-xs border border-line px-2 text-2xs text-fg-2 hover:border-accent hover:text-fg" dir="ltr">
                  {`{${p}}`}
                </button>
              ))}
            </div>
          </div>
        </Panel>
        <Panel>
          <PanelHeader title={t('wa.preview')} />
          <p className="whitespace-pre-wrap p-4 text-sm text-fg-2" data-testid="tpl-preview">
            {fillTemplate(body, sample)}
          </p>
        </Panel>
        {err && <Alert tone="danger">{err}</Alert>}
        <div className="flex flex-wrap gap-2">
          <Button variant="primary" needsNet loading={busy} disabled={empty || body === current} onClick={() => void write({ body, deleted_at: null })}>
            {t('common.save')}
          </Button>
          <Button disabled={!custom || busy} onClick={() => void write({ body: current, deleted_at: new Date().toISOString() })}>
            {t('settingsMsg.reset')}
          </Button>
        </div>
      </div>
    </div>
  );
}
