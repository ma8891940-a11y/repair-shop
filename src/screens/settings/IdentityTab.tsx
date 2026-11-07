import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ImagePlus, Trash2, Upload } from 'lucide-react';
import { useMe } from '../../app/auth';
import { BRANDING_COLUMNS, brandingChanged, ColorHeader, PoweredBy, ThermalHeader, useBranding, type Branding } from '../../app/brand/branding';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { checkLogoFile, logoUploadError, prepareLogoUpload, loadImage, renderColor, renderThermal, trimCanvas } from '../../lib/brandImage';
import { toLatinDigits } from '../../lib/digits';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input, Textarea } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

const SOCIALS = ['facebook', 'instagram', 'tiktok', 'website'] as const;

/** هوية المحل: كل اللي بيظهر للعميل وعلى الورق (اسم ولوجو المحل، مش التطبيق) */
export function IdentityTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const branding = useBranding();
  const b0 = branding.data ?? null;

  const [name, setName] = useState(shop.name);
  const [nameEn, setNameEn] = useState('');
  const [tagline, setTagline] = useState('');
  const [phone, setPhone] = useState(shop.phone ?? '');
  const [phones, setPhones] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [address, setAddress] = useState(shop.address ?? '');
  const [socials, setSocials] = useState<Record<string, string>>({});
  const [terms, setTerms] = useState(shop.receipt_terms);
  const [warranty, setWarranty] = useState(String(shop.warranty_days));
  const [poweredBy, setPoweredBy] = useState(false);
  // اللوجو
  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [zoom, setZoom] = useState(1);
  const [panX, setPanX] = useState(0);
  const [panY, setPanY] = useState(0);
  const [contrast, setContrast] = useState(50);
  const [customThermal, setCustomThermal] = useState<string | null>(null);
  const [removeLogo, setRemoveLogo] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  // مشكلة اللوجو نفسه (بتظهر جنب زرار الرفع، مش في آخر الصفحة)
  const [logoErr, setLogoErr] = useState<string | null>(null);
  // الصورة لسه بتتقري (الصور الكبيرة بتاخد وقت): الحفظ بيستنى، عشان ما يتحفظش اللوجو القديم
  const [picking, setPicking] = useState(false);

  useEffect(() => {
    if (!b0) return;
    setNameEn(b0.name_en ?? '');
    setTagline(b0.tagline ?? '');
    setPhones(b0.phones.join(t('common.sep')));
    setWhatsapp(b0.whatsapp ?? '');
    setSocials(b0.socials ?? {});
    setPoweredBy(b0.show_powered_by);
    setContrast(b0.thermal_contrast);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [b0?.id]);

  // معاينة حيّة للوجو الجديد (ملون + حراري)
  const preview = useMemo(() => {
    if (!img) return null;
    const color = trimCanvas(renderColor(img, zoom, panX, panY));
    return { color: color.toDataURL('image/png'), thermal: customThermal ?? trimCanvas(renderThermal(color, contrast)).toDataURL('image/png') };
  }, [img, zoom, panX, panY, contrast, customThermal]);
  // تغيير التباين للوجو القديم (من غير رفع جديد)
  const [oldThermal, setOldThermal] = useState<string | null>(null);
  useEffect(() => {
    if (img || !b0?.logo_color || b0.thermal_custom) return setOldThermal(null);
    if (contrast === b0.thermal_contrast) return setOldThermal(null);
    let off = false;
    void loadImage(b0.logo_color).then((im) => !off && setOldThermal(trimCanvas(renderThermal(im, contrast)).toDataURL('image/png')));
    return () => {
      off = true;
    };
  }, [contrast, img, b0]);

  const draft: Branding = {
    id: b0?.id ?? '',
    shop_id: shop.id,
    name_en: nameEn.trim() || null,
    tagline: tagline.trim() || null,
    phones: phones.split(/[,\u060C/]/).map((x) => toLatinDigits(x.trim())).filter(Boolean).slice(0, 4),
    whatsapp: toLatinDigits(whatsapp.trim()) || null,
    socials: Object.fromEntries(Object.entries(socials).filter(([, v]) => v.trim())),
    logo_path: b0?.logo_path ?? null,
    logo_color: removeLogo ? null : (preview?.color ?? b0?.logo_color ?? null),
    logo_thermal: removeLogo ? null : (preview?.thermal ?? customThermal ?? oldThermal ?? b0?.logo_thermal ?? null),
    thermal_contrast: contrast,
    thermal_custom: !!customThermal || (!preview && !!b0?.thermal_custom && !oldThermal),
    show_powered_by: poweredBy,
  };
  const draftShop = { ...shop, name: name.trim() || shop.name, phone: toLatinDigits(phone.trim()) || null, address: address.trim() || null };

  async function pickLogo(f: File) {
    setLogoErr(null);
    const c = checkLogoFile(f);
    if (c !== 'ok') return setLogoErr(t(c === 'type' ? 'identity.errType' : 'identity.errSize'));
    setPicking(true);
    try {
      setImg(await loadImage(f));
      setFile(f);
      setZoom(1);
      setPanX(0);
      setPanY(0);
      setCustomThermal(null);
      setRemoveLogo(false);
    } catch {
      setLogoErr(t('identity.errRead'));
    } finally {
      setPicking(false);
    }
  }
  async function pickThermal(f: File) {
    setLogoErr(null);
    const c = checkLogoFile(f);
    if (c !== 'ok') return setLogoErr(t(c === 'type' ? 'identity.errType' : 'identity.errSize'));
    // النسخة الحرارية الخاصة كمان بتتحول أبيض وأسود صريح عشان الطابعة
    const im = await loadImage(f);
    setCustomThermal(trimCanvas(renderThermal(im, contrast)).toDataURL('image/png'));
  }

  async function save() {
    if (picking) return;
    setErr(null);
    if (!name.trim()) return setErr(t('common.required'));
    const days = Number(toLatinDigits(warranty));
    if (!Number.isInteger(days) || days < 0 || days > 3650) return setErr(t('settings.warrantyBad'));
    setBusy(true);
    try {
      const logo_path = removeLogo ? null : draft.logo_path;
      const s = await supabase.from('shops').update({ name: draftShop.name, phone: draftShop.phone, address: draftShop.address, receipt_terms: terms, warranty_days: days }).eq('id', shop.id);
      if (s.error) throw s.error;
      // اللوجو اللي بيظهر في الإيصال والفاتورة وصفحة التتبع (ملون وحراري) بيتحفظ مع الهوية نفسها، فبيظهر على طول
      // حتى لو رفع النسخة الأصلية على Storage فشل
      const id = b0?.id || crypto.randomUUID();
      const row = { ...draft, logo_path, id };
      const r = b0 ? await supabase.from('shop_branding').update(row).eq('id', b0.id) : await supabase.from('shop_branding').insert(row);
      if (r.error) throw r.error;
      let warn: string | null = null;
      if (file && img) {
        // الأصل في Storage تحت shop_id بتاع المحل (خاص بيه)، متصغّر لو كبير
        try {
          const up0 = await prepareLogoUpload(file, img);
          const path = `${shop.id}/logo-${crypto.randomUUID()}.${up0.ext}`;
          const up = await supabase.storage.from('shop-logos').upload(path, up0.blob, { contentType: up0.type });
          if (up.error) throw up.error;
          const u2 = await supabase.from('shop_branding').update({ logo_path: path }).eq('id', id);
          if (u2.error) throw u2.error;
        } catch (e) {
          warn = t('identity.savedNoOriginal', { why: t(logoUploadError(e)) });
        }
      }
      if (warn) {
        setLogoErr(warn);
        toast({ tone: 'warn', title: t('settings.saved'), description: warn, duration: 10_000 });
      } else toast({ tone: 'ok', title: t('settings.saved') });
      brandingChanged();
      setImg(null);
      setFile(null);
      setCustomThermal(null);
      setRemoveLogo(false);
      branding.reload();
      await refresh();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  if (branding.loading) return <Skeleton className="h-64 w-full" />;
  const hasLogo = !!draft.logo_color;

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
      <div className="flex min-w-0 flex-col gap-4">
        <Panel>
          <PanelHeader index="01" title={t('identity.names')} />
          <div className="grid gap-3 p-4 sm:grid-cols-2">
            <Field label={t('identity.nameAr')} required>
              <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            </Field>
            <Field label={t('identity.nameEn')}>
              <Input dir="ltr" value={nameEn} onChange={(e) => setNameEn(e.target.value)} maxLength={120} className="text-start" />
            </Field>
            <Field label={t('identity.tagline')} hint={t('identity.taglineHint')} className="sm:col-span-2">
              <Input value={tagline} onChange={(e) => setTagline(e.target.value)} maxLength={120} />
            </Field>
          </div>
        </Panel>

        <Panel>
          <PanelHeader index="02" title={t('identity.logo')} />
          <div className="flex flex-col gap-3 p-4">
            <p className="text-xs text-fg-3">{t('identity.logoHint')}</p>
            <div className="flex flex-wrap items-center gap-2">
              <label className="inline-flex h-9 cursor-pointer items-center gap-2 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg">
                <ImagePlus className="size-4" aria-hidden /> {hasLogo ? t('identity.logoChange') : t('identity.logoPick')}
                <input type="file" accept="image/png,image/jpeg,image/svg+xml,image/webp" className="sr-only" aria-label={t('identity.logo')} onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void pickLogo(f); }} />
              </label>
              {hasLogo && (
                <Button size="sm" variant="ghost" icon={<Trash2 className="size-4" />} onClick={() => { setImg(null); setFile(null); setRemoveLogo(true); }}>
                  {t('identity.logoRemove')}
                </Button>
              )}
            </div>
            {logoErr && (
              <div data-testid="logo-error">
                <Alert tone="danger">{logoErr}</Alert>
              </div>
            )}
            {img && (
              <div className="grid gap-2 sm:grid-cols-3" data-testid="logo-crop">
                <Range label={t('identity.zoom')} min={1} max={4} step={0.05} value={zoom} onChange={setZoom} />
                <Range label={t('identity.panX')} min={-1} max={1} step={0.02} value={panX} onChange={setPanX} />
                <Range label={t('identity.panY')} min={-1} max={1} step={0.02} value={panY} onChange={setPanY} />
              </div>
            )}
            {hasLogo && (
              <div className="grid gap-3 rounded-md border border-glass-border p-3 sm:grid-cols-[minmax(0,1fr)_auto]">
                <div>
                  <div className="readout-label mb-1">{t('identity.thermal')}</div>
                  <Range label={t('identity.contrast')} min={0} max={100} step={1} value={contrast} onChange={setContrast} disabled={!!customThermal} />
                  <p className="mt-1 text-2xs text-fg-3">{t('identity.thermalHint')}</p>
                </div>
                <label className="inline-flex h-9 cursor-pointer items-center gap-2 self-end rounded-md border border-line px-3 text-xs text-fg-2 hover:border-accent hover:text-fg">
                  <Upload className="size-4" aria-hidden /> {t('identity.thermalUpload')}
                  <input type="file" accept="image/png,image/jpeg,image/svg+xml,image/webp" className="sr-only" aria-label={t('identity.thermalUpload')} onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void pickThermal(f); }} />
                </label>
              </div>
            )}
          </div>
        </Panel>

        <Panel>
          <PanelHeader index="03" title={t('identity.contact')} />
          <div className="grid gap-3 p-4 sm:grid-cols-2">
            <Field label={t('settings.phone')}>
              <Input dir="ltr" mono inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className="text-start" />
            </Field>
            <Field label={t('identity.phones')} hint={t('identity.phonesHint')}>
              <Input dir="ltr" mono value={phones} onChange={(e) => setPhones(e.target.value)} className="text-start" />
            </Field>
            <Field label={t('identity.whatsapp')}>
              <Input dir="ltr" mono inputMode="tel" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} className="text-start" />
            </Field>
            <Field label={t('settings.address')}>
              <Input value={address} onChange={(e) => setAddress(e.target.value)} />
            </Field>
            {SOCIALS.map((k) => (
              <Field key={k} label={t(`identity.socials.${k}`)}>
                <Input dir="ltr" value={socials[k] ?? ''} onChange={(e) => setSocials((s) => ({ ...s, [k]: e.target.value }))} placeholder={k === 'website' ? 'https://' : '@'} className="text-start" />
              </Field>
            ))}
          </div>
        </Panel>

        <Panel>
          <PanelHeader index="04" title={t('settings.terms')} />
          <div className="grid gap-3 p-4">
            <Field label={t('settings.terms')} hint={t('settings.termsHint')}>
              <Textarea rows={5} value={terms} onChange={(e) => setTerms(e.target.value)} />
            </Field>
            <Field label={t('settings.warranty')} className="max-w-xs">
              <Input type="number" min={0} max={3650} dir="ltr" mono value={warranty} onChange={(e) => setWarranty(e.target.value)} className="text-start" />
            </Field>
            <Checkbox checked={poweredBy} onChange={setPoweredBy} label={t('identity.poweredByToggle', { app: t('app.name') })} />
          </div>
        </Panel>
        {err && <Alert tone="danger">{err}</Alert>}
        <Button variant="primary" loading={busy || picking} onClick={() => void save()} className="self-start">
          {t('common.save')}
        </Button>
      </div>

      {/* المعاينة الحيّة: زي الورقة بالظبط (أبيض وأسود للحراري، وملون للفاتورة) */}
      <aside className="flex flex-col gap-3 lg:sticky lg:top-[72px] lg:self-start">
        <div className="readout-label">{t('identity.previewReceipt')}</div>
        <div className="mx-auto w-[76mm] max-w-full bg-white p-3 text-[12px] text-black shadow-2" data-testid="preview-receipt">
          <ThermalHeader shop={draftShop} b={draft} />
          <div className="mt-2 border-t border-dashed border-black pt-1 text-center font-mono text-[16px] font-bold" dir="ltr">
            2026-0042
          </div>
          <PoweredBy b={draft} />
        </div>
        <div className="readout-label">{t('identity.previewInvoice')}</div>
        <div className="origin-top-right scale-[0.62] bg-white p-5 text-[12px] text-black shadow-2 rtl:origin-top-right ltr:origin-top-left" style={{ width: '160%', marginBottom: '-38%' }} data-testid="preview-invoice">
          <ColorHeader shop={draftShop} b={draft} title={t('print.invoice')} sub="2026-0042" />
        </div>
      </aside>
    </div>
  );
}

function Range({ label, value, onChange, min, max, step, disabled }: { label: string; value: number; onChange: (v: number) => void; min: number; max: number; step: number; disabled?: boolean }) {
  return (
    <label className="flex flex-col gap-1 text-2xs text-fg-3">
      {label}
      <input type="range" min={min} max={max} step={step} value={value} disabled={disabled} onChange={(e) => onChange(Number(e.target.value))} className="accent-[var(--accent)]" />
    </label>
  );
}

export { BRANDING_COLUMNS };
