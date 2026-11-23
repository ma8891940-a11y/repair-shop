import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Archive, Plus } from 'lucide-react';
import { readPrint } from '../../lib/printPlan';
import { useMe } from '../../app/auth';
import { useLoad, must } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { saveExtras } from '../../app/shopExtras';
import { errorMessage } from '../../lib/errors';
import { readExtras, type Extras } from '../../lib/extras';
import { parsePounds } from '../../lib/money';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input } from '../../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

export interface Preset {
  id: string;
  label: string;
  issue: string;
  est_cost: number | null;
  sort: number;
}

/** الميزات الإضافية: مفتاح تشغيل لكل ميزة، والأعطال الجاهزة اللي بتظهر في الاستلام */
export function ExtrasTab() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const extras = readExtras(shop.extras);
  const [label, setLabel] = useState('');
  const [issue, setIssue] = useState('');
  const [price, setPrice] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const presets = useLoad(async () => must(await supabase.from('issue_presets').select('id, label, issue, est_cost, sort').is('deleted_at', null).order('sort').order('created_at')) as Preset[], []);

  async function toggle(k: keyof Extras, v: boolean) {
    const patch: Record<string, unknown> = { [k]: v };
    // "اطبع تلقائي" هو نفس خيار الإعدادات ← الطباعة
    if (k === 'auto_print') {
      // (S5) "اطبع تلقائي" هنا = الاستيكر والإيصال الورقي تلقائي بعد الاستلام (الإعدادات ← الطباعة فيها التفاصيل)
      const cur = readPrint(shop.extras);
      patch.print = { auto: { ...cur.auto, sticker: v, paper: v } };
    }
    const { error } = await saveExtras(patch, true);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  async function add() {
    setErr(null);
    if (!label.trim() || !issue.trim()) return setErr(t('extras.presetReq'));
    const cost = price.trim() ? parsePounds(price) : null;
    if (price.trim() && cost === null) return setErr(t('intake.estimateBad'));
    const { error } = await supabase.from('issue_presets').insert({ id: crypto.randomUUID(), shop_id: shop.id, label: label.trim(), issue: issue.trim(), est_cost: cost, sort: presets.data?.length ?? 0 });
    if (error) return setErr(errorMessage(error));
    setLabel('');
    setIssue('');
    setPrice('');
    presets.reload();
  }
  async function archive(p: Preset) {
    const { error } = await supabase.from('issue_presets').update({ deleted_at: new Date().toISOString() }).eq('id', p.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    presets.reload();
  }

  return (
    <div className="flex flex-col gap-4">
      <Panel>
        <PanelHeader title={t('extras.title')} />
        <div className="flex flex-col gap-4 p-4">
          {(['quick_issues', 'auto_print', 'day_summary', 'link_inventory'] as const).map((k) => (
            <div key={k}>
              <Checkbox checked={k === 'auto_print' ? readPrint(shop.extras).auto.sticker || readPrint(shop.extras).auto.paper : extras[k]} onChange={(v) => void toggle(k, v)} label={t(`extras.${k}.name`)} />
              <p className="ms-7 mt-0.5 text-2xs text-fg-3">{t(`extras.${k}.hint`)}</p>
            </div>
          ))}
        </div>
      </Panel>
      <Panel>
        <PanelHeader title={t('extras.presets')} />
        <div className="grid gap-3 p-4 sm:grid-cols-[1fr_2fr_auto_auto] sm:items-end">
          <Field label={t('extras.presetLabel')}>
            <Input value={label} onChange={(e) => setLabel(e.target.value)} maxLength={60} placeholder={t('extras.presetLabelPh')} />
          </Field>
          <Field label={t('extras.presetIssue')}>
            <Input value={issue} onChange={(e) => setIssue(e.target.value)} maxLength={300} />
          </Field>
          <Field label={t('extras.presetPrice')}>
            <Input dir="ltr" inputMode="decimal" mono value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0" className="w-28" />
          </Field>
          <Button icon={<Plus className="size-4" />} onClick={() => void add()}>
            {t('extras.add')}
          </Button>
          {err && <Alert tone="danger" className="sm:col-span-4">{err}</Alert>}
        </div>
        {presets.error ? (
          <ErrorState message={presets.error} onRetry={presets.reload} />
        ) : presets.loading ? (
          <Skeleton className="m-4 h-16" />
        ) : !presets.data?.length ? (
          <EmptyState line="chip" title={t('extras.noPresets')} />
        ) : (
          <ul className="divide-y divide-glass-border" data-testid="preset-list">
            {presets.data.map((p) => (
              <li key={p.id} className="flex items-center gap-3 px-4 py-2 text-sm">
                <span className="font-medium text-fg">{p.label}</span>
                <span className="min-w-0 flex-1 truncate text-fg-2">{p.issue}</span>
                <span className="num text-fg-2">{p.est_cost != null ? `${f.money(p.est_cost)} ${f.currency(shop.currency)}` : t('common.none')}</span>
                <button type="button" onClick={() => void archive(p)} className="rounded-sm p-1 text-fg-3 hover:text-danger" aria-label={t('extras.archive', { name: p.label })} title={t('extras.archive', { name: p.label })}>
                  <Archive className="size-4" aria-hidden />
                </button>
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </div>
  );
}
