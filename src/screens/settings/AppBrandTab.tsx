import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Copy, ImagePlus, RotateCcw } from 'lucide-react';
import { useMe } from '../../app/auth';
import { readAppBrand } from '../../app/appBrand';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { accentVars, contrast, hexToRgb, BG_DARK, BG_LIGHT } from '../../lib/accent';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Input } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import defaultLogo from '../../assets/app-logo.png';

/** بيصغّر اللوجو لحد 256 بكسل (PNG) عشان يتحفظ مع الإعدادات ويفتح من غير نت */
async function shrink(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = url;
    await img.decode();
    const k = Math.min(1, 256 / Math.max(img.naturalWidth, img.naturalHeight));
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(img.naturalWidth * k));
    c.height = Math.max(1, Math.round(img.naturalHeight * k));
    c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
    return c.toDataURL('image/png');
  } finally {
    URL.revokeObjectURL(url);
  }
}

/**
 * U4: الإعدادات ← تطبيقي: اسم التطبيق ولوجوه ولون الإبراز بتوع صاحب المحل.
 * بيظهروا في الافتتاحية والدخول والشريط الجانبي وعنوان التبويب وأيقونة المتصفح والتثبيت.
 * "جوالك" ولوجوه الافتراضي لو ما اتغيروش.
 */
export function AppBrandTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const cur = readAppBrand(shop.extras);
  const [name, setName] = useState(cur.name ?? '');
  const [logo, setLogo] = useState<string | null>(cur.logo ?? null);
  const [accent, setAccent] = useState(cur.accent ?? '');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  useEffect(() => {
    setName(cur.name ?? '');
    setLogo(cur.logo ?? null);
    setAccent(cur.accent ?? '');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shop.extras]);
  const v = accent ? accentVars(accent) : null;
  const adjusted = !!v && (v.dark['--accent'] !== accent.toLowerCase() || v.light['--accent'] !== accent.toLowerCase());
  async function save() {
    setErr(null);
    if (name.trim().length > 40) return setErr(t('appBrand.errName'));
    if (accent && !hexToRgb(accent)) return setErr(t('appBrand.errColor'));
    setBusy(true);
    const raw = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const app = { name: name.trim() || null, logo: logo || null, accent: accent || null };
    const { error } = await supabase.from('shops').update({ extras: { ...raw, app } }).eq('id', shop.id);
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    await refresh();
    setSaved(true);
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  const link = `${window.location.origin}${window.location.pathname}#/?shop=${shop.id}`;
  return (
    <Panel data-testid="app-brand-settings">
      <PanelHeader title={t('settings.tabs.app')} />
      <div className="flex flex-col gap-4 p-4">
        <p className="text-xs text-fg-3">{t('appBrand.hint')}</p>
        <Field label={t('appBrand.name')} hint={t('appBrand.nameHint')}>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={40} placeholder={t('app.name')} data-testid="app-name" />
        </Field>
        <div className="flex flex-wrap items-center gap-3">
          <div className="grid h-16 w-20 place-items-center overflow-hidden rounded-md border border-dashed border-line-strong bg-sunken/50">
            <img src={logo || defaultLogo} alt="" className="max-h-14 max-w-[72px] object-contain" />
          </div>
          <label className="w-fit">
            <span className="glass inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-sm px-3 text-sm text-fg hover:border-glass-border-strong">
              <ImagePlus className="size-4" /> {t('appBrand.logo')}
            </span>
            <input
              type="file"
              accept="image/png,image/jpeg,image/webp,image/svg+xml"
              className="sr-only"
              data-testid="app-logo-file"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) void shrink(f).then(setLogo, () => setErr(t('identity.errType')));
              }}
            />
          </label>
          {logo && (
            <Button size="sm" variant="ghost" icon={<RotateCcw className="size-4" />} onClick={() => setLogo(null)}>
              {t('appBrand.defaultLogo')}
            </Button>
          )}
        </div>
        <div className="flex flex-wrap items-end gap-3">
          <Field label={t('appBrand.accent')} hint={t('appBrand.accentHint')}>
            <div className="flex items-center gap-2">
              <input type="color" value={accent || '#38d6f0'} onChange={(e) => setAccent(e.target.value)} aria-label={t('appBrand.accent')} className="h-9 w-12 cursor-pointer rounded-md border border-line bg-transparent" data-testid="app-accent" />
              <Input mono dir="ltr" value={accent} onChange={(e) => setAccent(e.target.value.trim())} placeholder="#38d6f0" className="w-28" />
              {accent && (
                <Button size="sm" variant="ghost" onClick={() => setAccent('')}>
                  {t('appBrand.defaultAccent')}
                </Button>
              )}
            </div>
          </Field>
          {v && (
            <div className="flex gap-2 text-2xs" aria-label={t('appBrand.preview')}>
              {(['dark', 'light'] as const).map((m) => (
                <span key={m} className="rounded-md px-2 py-1" style={{ background: m === 'dark' ? '#0b0f12' : '#eef3f9', color: v[m]['--accent'], border: `1px solid ${v[m]['--accent']}` }}>
                  {t(`appBrand.mode.${m}`)} {contrast(hexToRgb(v[m]['--accent'])!, m === 'dark' ? BG_DARK : BG_LIGHT).toFixed(1)}:1
                </span>
              ))}
            </div>
          )}
        </div>
        {adjusted && <Alert tone="info">{t('appBrand.adjusted')}</Alert>}
        {err && <Alert tone="danger">{err}</Alert>}
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="app-brand-save">
            {t('common.save')}
          </Button>
        </div>
        {saved && <Alert tone="info">{t('appBrand.reinstall')}</Alert>}
        <div className="rounded-md border border-glass-border p-3 text-xs">
          <div className="mb-1 text-fg-2">{t('appBrand.link')}</div>
          <div className="flex items-center gap-2">
            <code className="num min-w-0 flex-1 truncate text-fg" dir="ltr" data-testid="app-link">
              {link}
            </code>
            <Button size="sm" variant="ghost" icon={<Copy className="size-4" />} onClick={() => void navigator.clipboard?.writeText(link).then(() => toast({ tone: 'ok', title: t('appBrand.copied') }))}>
              {t('appBrand.copy')}
            </Button>
          </div>
        </div>
      </div>
    </Panel>
  );
}
