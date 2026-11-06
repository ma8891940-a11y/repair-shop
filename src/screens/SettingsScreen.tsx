import { useState, type ReactNode } from 'react';
import * as Tabs from '@radix-ui/react-tabs';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { Banknote, Building2, CreditCard, ImagePlus, Landmark, Languages, Moon, Smartphone, Sparkles, Sun, Wallet, Zap, type LucideIcon } from 'lucide-react';
import { useMe } from '../app/auth';
import { usePrefs } from '../app/prefs';
import { PageHeader } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { PAYMENT_METHODS, type PaymentMethod } from '../lib/regions';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { Panel, PanelHeader } from '../ui/Panel';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { MessagesTab } from './settings/MessagesTab';
import { cn } from '../ui/cn';

const PAY_ICON: Record<PaymentMethod, LucideIcon> = { cash: Banknote, card: CreditCard, bank_transfer: Landmark, wallet: Wallet, instapay: Zap, installments: Smartphone };

export function SettingsScreen() {
  const { t } = useTranslation();
  const { profile } = useMe();
  const owner = profile.role === 'owner';
  const [tab, setTab] = useState(owner ? 'shop' : 'appearance');
  const tabs = (owner ? ['shop', 'payments', 'messages', 'appearance'] : ['appearance']) as string[];
  return (
    <div className="max-w-4xl">
      <PageHeader title={t('settings.title')} />
      <Tabs.Root value={tab} onValueChange={setTab}>
        <Tabs.List className="glass mb-4 inline-flex rounded-md p-1" aria-label={t('settings.title')}>
          {tabs.map((k) => (
            <Tabs.Trigger key={k} value={k} className={cn('relative h-8 rounded-sm px-3.5 text-sm transition-colors', tab === k ? 'text-fg' : 'text-fg-3 hover:text-fg')}>
              {tab === k && <motion.span layoutId="settings-tab" className="absolute inset-0 rounded-sm border border-glass-border-strong bg-raised" transition={{ duration: 0.18 }} />}
              <span className="relative">{t(`settings.tabs.${k}`)}</span>
            </Tabs.Trigger>
          ))}
        </Tabs.List>
        {owner && (
          <Tabs.Content value="shop">
            <ShopTab />
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="payments">
            <PaymentsTab />
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="messages">
            <MessagesTab />
          </Tabs.Content>
        )}
        <Tabs.Content value="appearance">
          <AppearanceTab />
        </Tabs.Content>
      </Tabs.Root>
    </div>
  );
}

function ShopTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const [name, setName] = useState(shop.name);
  const [phone, setPhone] = useState(shop.phone ?? '');
  const [address, setAddress] = useState(shop.address ?? '');
  const [terms, setTerms] = useState(shop.receipt_terms);
  const [warranty, setWarranty] = useState(String(shop.warranty_days));
  const [logo, setLogo] = useState<{ file: File; url: string } | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const current = shop.logo_path ? supabase.storage.from('shop-logos').getPublicUrl(shop.logo_path).data.publicUrl : null;

  async function save() {
    setErr(null);
    const days = Number(warranty);
    if (!Number.isInteger(days) || days < 0 || days > 3650) return setErr(t('settings.warrantyBad'));
    if (!name.trim()) return setErr(t('common.required'));
    setBusy(true);
    try {
      let logo_path = shop.logo_path;
      if (logo) {
        const ext = logo.file.type === 'image/png' ? 'png' : logo.file.type === 'image/webp' ? 'webp' : 'jpg';
        logo_path = `${shop.id}/logo-${crypto.randomUUID()}.${ext}`;
        const up = await supabase.storage.from('shop-logos').upload(logo_path, logo.file, { contentType: logo.file.type });
        if (up.error) throw up.error;
      }
      const { error } = await supabase
        .from('shops')
        .update({ name: name.trim(), phone: phone.trim() || null, address: address.trim() || null, receipt_terms: terms, warranty_days: days, logo_path })
        .eq('id', shop.id);
      if (error) throw error;
      toast({ tone: 'ok', title: t('settings.saved') });
      setLogo(null);
      await refresh();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <Panel>
        <PanelHeader index="01" title={t('settings.shopSec')} />
        <div className="grid gap-3 p-4 sm:grid-cols-[96px_minmax(0,1fr)]">
          <label className="group relative grid size-24 cursor-pointer place-items-center overflow-hidden rounded-xl border border-dashed border-line-strong bg-sunken/50 hover:border-accent">
            {logo || current ? <img src={logo?.url ?? current!} alt="" className="size-full object-contain p-2" /> : <Building2 className="size-7 text-fg-3" aria-hidden />}
            <span className="absolute inset-x-0 bottom-0 flex items-center justify-center gap-1 bg-[rgb(0_0_0/0.55)] py-0.5 text-2xs text-white opacity-0 transition-opacity group-hover:opacity-100">
              <ImagePlus className="size-3" /> {t('settings.logoChange')}
            </span>
            <input
              type="file"
              accept="image/png,image/jpeg,image/webp"
              className="sr-only"
              aria-label={t('settings.logo')}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) setLogo({ file, url: URL.createObjectURL(file) });
                e.target.value = '';
              }}
            />
          </label>
          <div className="grid gap-3">
            <p className="text-xs text-fg-3">{t('settings.shopHint')}</p>
            <Field label={t('settings.name')} required>
              <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            </Field>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label={t('settings.phone')}>
                <Input dir="ltr" mono value={phone} onChange={(e) => setPhone(e.target.value)} className="text-start" />
              </Field>
              <Field label={t('settings.address')}>
                <Input value={address} onChange={(e) => setAddress(e.target.value)} />
              </Field>
            </div>
          </div>
        </div>
      </Panel>
      <Panel>
        <PanelHeader index="02" title={t('settings.terms')} />
        <div className="grid gap-3 p-4">
          <Field label={t('settings.terms')} hint={t('settings.termsHint')}>
            <Textarea rows={5} value={terms} onChange={(e) => setTerms(e.target.value)} />
          </Field>
          <Field label={t('settings.warranty')} className="max-w-xs">
            <Input type="number" min={0} max={3650} dir="ltr" mono value={warranty} onChange={(e) => setWarranty(e.target.value)} className="text-start" />
          </Field>
        </div>
      </Panel>
      {err && <Alert tone="danger">{err}</Alert>}
      <Button variant="primary" loading={busy} onClick={() => void save()} className="self-start">
        {t('common.save')}
      </Button>
    </div>
  );
}

function PaymentsTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const [methods, setMethods] = useState<PaymentMethod[]>(shop.payment_methods as PaymentMethod[]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function save() {
    if (methods.length === 0) return setErr(t('register.pickOne'));
    setErr(null);
    setBusy(true);
    const { error } = await supabase.from('shops').update({ payment_methods: methods }).eq('id', shop.id);
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('settings.saved') });
    await refresh();
  }
  return (
    <div className="flex flex-col gap-4">
      <Panel className="p-4">
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3" role="group" aria-label={t('settings.tabs.payments')}>
          {PAYMENT_METHODS.map((m) => {
            const on = methods.includes(m);
            const Icon = PAY_ICON[m];
            return (
              <button
                key={m}
                type="button"
                role="checkbox"
                aria-checked={on}
                onClick={() => setMethods((c) => (on ? c.filter((x) => x !== m) : [...c, m]))}
                className={cn('lift flex flex-col items-start gap-1 rounded-lg border p-3 text-start', on ? 'border-[rgb(var(--accent-rgb)/0.6)] bg-accent-soft' : 'border-glass-border bg-sunken/40 hover:bg-raised/60')}
              >
                <Icon className={cn('size-5', on ? 'text-accent' : 'text-fg-3')} aria-hidden />
                <span className="text-sm font-medium text-fg">{t(`payments.${m}`)}</span>
                <span className="text-2xs text-fg-3">{t(`payments.${m}_d`)}</span>
              </button>
            );
          })}
        </div>
      </Panel>
      {err && <Alert tone="danger">{err}</Alert>}
      <Button variant="primary" loading={busy} onClick={() => void save()} className="self-start">
        {t('common.save')}
      </Button>
    </div>
  );
}

function AppearanceTab() {
  const { t } = useTranslation();
  const { theme, setTheme, lang, setLang, effects, setEffects } = usePrefs();
  const toast = useToast();
  return (
    <div className="flex flex-col gap-4">
      <Row icon={theme === 'dark' ? Moon : Sun} title={t('settings.theme')}>
        <Seg value={theme} onChange={(v) => setTheme(v as 'dark' | 'light')} options={[['dark', t('register.themeDark')], ['light', t('register.themeLight')]]} label={t('settings.theme')} />
      </Row>
      <Row icon={Languages} title={t('settings.language')}>
        <Seg value={lang} onChange={(v) => setLang(v as 'ar' | 'en')} options={[['ar', t('prefs.langAr')], ['en', t('prefs.langEn')]]} label={t('settings.language')} />
      </Row>
      <Row icon={Sparkles} title={t('prefs.effects')} hint={t('settings.effectsHint')}>
        <button
          type="button"
          role="switch"
          aria-checked={effects}
          aria-label={t('prefs.effects')}
          onClick={() => {
            setEffects(!effects);
            toast({ tone: 'info', title: !effects ? t('prefs.effectsOn') : t('prefs.effectsOff') });
          }}
          className={cn('relative h-7 w-12 shrink-0 rounded-full border transition-colors', effects ? 'border-accent bg-accent' : 'border-line-strong bg-sunken')}
        >
          <motion.span layout className={cn('absolute top-0.5 size-5 rounded-full shadow-1', effects ? 'end-0.5 bg-on-accent' : 'start-0.5 bg-fg-3')} transition={{ duration: 0.18 }} />
        </button>
      </Row>
    </div>
  );
}

function Row({ icon: Icon, title, hint, children }: { icon: LucideIcon; title: string; hint?: string; children: ReactNode }) {
  return (
    <Panel className="flex items-center gap-4 p-4">
      <span className="grid size-9 shrink-0 place-items-center rounded-md border border-glass-border bg-sunken/50 text-accent">
        <Icon className="size-4" aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-sm font-medium text-fg">{title}</div>
        {hint && <div className="mt-0.5 text-xs text-fg-3">{hint}</div>}
      </div>
      {children}
    </Panel>
  );
}

function Seg({ value, onChange, options, label }: { value: string; onChange: (v: string) => void; options: [string, string][]; label: string }) {
  return (
    <div className="flex rounded-md border border-glass-border bg-sunken/60 p-0.5" role="radiogroup" aria-label={label}>
      {options.map(([k, l]) => (
        <button key={k} type="button" role="radio" aria-checked={value === k} onClick={() => onChange(k)} className={cn('relative h-7 rounded-sm px-3 text-xs transition-colors', value === k ? 'text-fg' : 'text-fg-3 hover:text-fg')}>
          {value === k && <motion.span layoutId={`seg-${label}`} className="absolute inset-0 rounded-sm bg-raised shadow-1" transition={{ duration: 0.18 }} />}
          <span className="relative" lang={k === 'en' ? 'en' : k === 'ar' ? 'ar' : undefined}>
            {l}
          </span>
        </button>
      ))}
    </div>
  );
}
