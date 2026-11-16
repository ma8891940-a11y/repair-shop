import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowDown, ArrowUp, Plus, RotateCcw, X } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { BRANDS, BUILTIN_TEMPLATES, CHECK_ITEMS, EXTRA_ITEMS, customKey, normalizeTemplate, type BrandKey, type TemplateItem } from '../../lib/checks';
import { move } from '../../lib/printTemplate';
import { invalidateCheckTemplates, useCheckTemplates, useItemLabel } from '../../app/checkTemplates';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Input } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/** C2: الإعدادات ← قوايم الفحص: قالب لكل ماركة (يعدّله صاحب المحل)، و"رجّع الجاهز" */
export function ChecksTab() {
  const { t } = useTranslation();
  const toast = useToast();
  const label = useItemLabel();
  const { rows, custom, loading } = useCheckTemplates();
  const [brand, setBrand] = useState<BrandKey>('general');
  const [items, setItems] = useState<TemplateItem[]>(BUILTIN_TEMPLATES.general);
  const [extra, setExtra] = useState('');
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const row = rows?.find((r) => r.brand === brand) ?? null;
  // لما الماركة تتغير أو القوالب توصل: القالب المتخزّن أو الجاهز
  const stored = JSON.stringify(custom[brand] ?? null);
  useEffect(() => {
    setItems(custom[brand] ?? BUILTIN_TEMPLATES[brand]);
    setErr(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [brand, stored]);

  const used = new Set(items.map((i) => i.key));
  const available = [...CHECK_ITEMS, ...EXTRA_ITEMS].filter((k) => !used.has(k));
  const rename = (i: number, v: string) => setItems((l) => l.map((x, k) => (k === i ? { ...x, label: v } : x)));

  async function save() {
    setErr(null);
    const clean = normalizeTemplate(items.map((x) => (x.label?.trim() ? x : { key: x.key })));
    if (!clean.length) return setErr(t('checksTpl.empty'));
    if (clean.length !== items.length) return setErr(t('checksTpl.needName'));
    setBusy(true);
    const r = row
      ? await supabase.from('check_templates').update({ items: clean }).eq('id', row.id)
      : await supabase.from('check_templates').insert({ id: crypto.randomUUID(), brand, items: clean });
    setBusy(false);
    if (r.error) return setErr(errorMessage(r.error));
    invalidateCheckTemplates();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  async function reset() {
    setErr(null);
    if (row) {
      setBusy(true);
      const r = await supabase.from('check_templates').update({ deleted_at: new Date().toISOString() }).eq('id', row.id);
      setBusy(false);
      if (r.error) return setErr(errorMessage(r.error));
      invalidateCheckTemplates();
    }
    setItems(BUILTIN_TEMPLATES[brand]);
    toast({ tone: 'ok', title: t('checksTpl.resetDone') });
  }

  return (
    <Panel data-testid="checks-settings">
      <PanelHeader title={t('settings.tabs.checks')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('checksTpl.hint')}</p>
        <div className="flex flex-wrap gap-1" role="tablist" aria-label={t('checksTpl.brand')}>
          {BRANDS.map((b) => (
            <button
              key={b}
              type="button"
              role="tab"
              aria-selected={brand === b}
              onClick={() => setBrand(b)}
              className={cn('h-7 rounded-sm border px-2.5 text-xs focus-visible:outline-2 focus-visible:outline-accent', brand === b ? 'border-accent bg-accent-soft text-fg' : 'border-line text-fg-2 hover:text-fg')}
              data-testid={`tpl-brand-${b}`}
            >
              {t(`checksTpl.brands.${b}`)}
              {custom[b] && <span className="ms-1 text-accent" aria-label={t('checksTpl.edited')}>•</span>}
            </button>
          ))}
        </div>
        {loading ? (
          <Skeleton className="h-40 w-full" />
        ) : (
          <ol className="flex flex-col divide-y divide-line rounded-md border border-line" data-testid="tpl-items">
            {items.map((x, i) => (
              <li key={x.key} className="flex items-center gap-2 px-2 py-1.5" data-testid="tpl-item">
                <span className="num w-6 text-2xs text-fg-3">{i + 1}</span>
                {x.key.startsWith('c_') ? (
                  <Input value={x.label ?? ''} onChange={(e) => rename(i, e.target.value)} maxLength={60} className="h-7 min-w-0 flex-1 text-sm" aria-label={t('checksTpl.itemName', { n: i + 1 })} />
                ) : (
                  <span className="min-w-0 flex-1 truncate text-sm text-fg">{label(x.key, null, items)}</span>
                )}
                <button type="button" onClick={() => setItems((l) => move(l, i, i - 1))} disabled={i === 0} aria-label={t('checksTpl.up')} className="grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-raised hover:text-fg disabled:opacity-30">
                  <ArrowUp className="size-3.5" />
                </button>
                <button type="button" onClick={() => setItems((l) => move(l, i, i + 1))} disabled={i === items.length - 1} aria-label={t('checksTpl.down')} className="grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-raised hover:text-fg disabled:opacity-30">
                  <ArrowDown className="size-3.5" />
                </button>
                <button type="button" onClick={() => setItems((l) => l.filter((_, k) => k !== i))} aria-label={t('checksTpl.remove', { name: label(x.key, null, items) })} className="grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-danger-soft hover:text-danger">
                  <X className="size-3.5" />
                </button>
              </li>
            ))}
          </ol>
        )}
        <div className="flex flex-wrap items-center gap-2">
          {available.length > 0 && (
            <>
              <select value={extra} onChange={(e) => setExtra(e.target.value)} className="h-8 rounded-sm border border-line bg-sunken px-2 text-sm text-fg" aria-label={t('checksTpl.addReady')} data-testid="tpl-add-ready">
                <option value="">{t('checksTpl.addReady')}</option>
                {available.map((k) => (
                  <option key={k} value={k}>
                    {label(k)}
                  </option>
                ))}
              </select>
              <Button size="sm" disabled={!extra || items.length >= 40} onClick={() => (setItems((l) => [...l, { key: extra }]), setExtra(''))} icon={<Plus className="size-3.5" />}>
                {t('checksTpl.add')}
              </Button>
            </>
          )}
          <Input value={text} onChange={(e) => setText(e.target.value)} maxLength={60} placeholder={t('checksTpl.newPh')} className="h-8 w-48 text-sm" aria-label={t('checksTpl.new')} data-testid="tpl-new" />
          <Button size="sm" disabled={!text.trim() || items.length >= 40} onClick={() => (setItems((l) => [...l, { key: customKey(), label: text.trim() }]), setText(''))} icon={<Plus className="size-3.5" />} data-testid="tpl-new-add">
            {t('checksTpl.new')}
          </Button>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
        <div className="flex flex-wrap gap-2">
          <Button variant="primary" loading={busy} onClick={() => void save()} data-testid="tpl-save">
            {t('common.save')}
          </Button>
          <Button variant="ghost" disabled={busy} onClick={() => void reset()} icon={<RotateCcw className="size-3.5" />} data-testid="tpl-reset">
            {t('checksTpl.reset')}
          </Button>
        </div>
      </div>
    </Panel>
  );
}
