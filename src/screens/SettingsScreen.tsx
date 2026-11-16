import { useEffect, useState, type ReactNode } from 'react';
import { useSearchParams } from 'react-router';
import * as Tabs from '@radix-ui/react-tabs';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { Banknote, CreditCard, Landmark, Languages, Moon, Smartphone, Sparkles, Sun, Wallet, Zap, type LucideIcon } from 'lucide-react';
import { useMe } from '../app/auth';
import { usePrefs } from '../app/prefs';
import { PageHeader } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { PAYMENT_METHODS, type PaymentMethod } from '../lib/regions';
import { Button } from '../ui/Button';
import { Panel } from '../ui/Panel';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { MessagesTab } from './settings/MessagesTab';
import { LedgerTab } from './settings/LedgerTab';
import { TechTab } from './settings/TechTab';
import { BackupTab } from './settings/BackupTab';
import { IdentityTab } from './settings/IdentityTab';
import { PlanUsage } from '../app/PlanUsage';
import { ExtrasTab } from './settings/ExtrasTab';
import { InventoryTab } from './settings/InventoryTab';
import { AlertsTab } from './settings/AlertsTab';
import { AppBrandTab } from './settings/AppBrandTab';
import { PrintersTab } from './settings/PrintersTab';
import { ChecksTab } from './settings/ChecksTab';
import { SecurityTab } from './settings/SecurityTab';
import { MotionStatus } from './settings/MotionStatus';
import { LogoAnimPicker } from './settings/LogoAnimPicker';
import { cn } from '../ui/cn';
import { ListsTab } from './settings/ListsTab';
import { PrintTab } from './settings/PrintTab';
import { BranchesTab } from './settings/BranchesTab';
import { RolesTab } from './settings/RolesTab';
import { AssistantTab } from './settings/AssistantTab';
import { PublicUrlPanel } from './settings/PublicUrlPanel';
import { useOnline } from '../ui/useOnline';

const PAY_ICON: Record<PaymentMethod, LucideIcon> = { cash: Banknote, card: CreditCard, bank_transfer: Landmark, wallet: Wallet, instapay: Zap, installments: Smartphone };

export function SettingsScreen() {
  const { t } = useTranslation();
  const { profile } = useMe();
  const owner = profile.role === 'owner';
  // ?tab=tech وغيرها (من القايمة الجانبية): التبويب ده يفتح على طول
  const [params] = useSearchParams();
  const [tab, setTab] = useState(owner ? 'shop' : 'appearance');
  const wanted = params.get('tab');
  useEffect(() => {
    if (wanted) setTab(wanted);
  }, [wanted]);
  // البند 14: الإعدادات بتتحفظ على السيرفر، فمن غير نت بتتقفل بهدوء (إلا المظهر، ده على الجهاز) وبتتفتح لوحدها
  const online = useOnline();
  const tabs = (owner ? ['shop', 'app', 'branches', 'roles', 'payments', 'tech', 'ledger', 'inventory', 'alerts', 'lists', 'print', 'printers', 'checks', 'security', 'assistant', 'messages', 'extras', 'backup', 'appearance'] : ['appearance']) as string[];
  return (
    <div className="max-w-4xl">
      <PageHeader title={t('settings.title')} />
      {!online && tab !== 'appearance' && (
        <div className="mb-3" data-testid="settings-offline">
          <Alert tone="info">{t('offline.settings')}</Alert>
        </div>
      )}
      <Tabs.Root value={tab} onValueChange={setTab}>
        <Tabs.List className="glass mb-4 inline-flex max-w-full flex-wrap gap-0.5 rounded-md p-1" aria-label={t('settings.title')}>
          {tabs.map((k) => (
            <Tabs.Trigger key={k} value={k} className={cn('relative h-8 whitespace-nowrap rounded-sm px-3.5 text-sm transition-colors', tab === k ? 'text-fg' : 'text-fg-3 hover:text-fg')}>
              {tab === k && <motion.span layoutId="settings-tab" className="absolute inset-0 rounded-sm border border-glass-border-strong bg-raised" transition={{ duration: 0.18 }} />}
              <span className="relative">{t(`settings.tabs.${k}`)}</span>
            </Tabs.Trigger>
          ))}
        </Tabs.List>
        {owner && (
          <Tabs.Content value="shop" className="flex flex-col gap-4">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <PlanUsage />
            <PublicUrlPanel />
            <IdentityTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="branches">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <BranchesTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="roles">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <RolesTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="print">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <PrintTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="assistant">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <AssistantTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="lists">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <ListsTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="payments">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <PaymentsTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="backup">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <BackupTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="tech">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <TechTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="ledger">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <LedgerTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="printers">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <PrintersTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="security">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
              <SecurityTab />
            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="checks">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
              <ChecksTab />
            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="app">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <AppBrandTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="alerts">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <AlertsTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="inventory">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <InventoryTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="extras">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <ExtrasTab />            </fieldset>
          </Tabs.Content>
        )}
        {owner && (
          <Tabs.Content value="messages">
            <fieldset disabled={!online} className="m-0 min-w-0 border-0 p-0">
            <MessagesTab />            </fieldset>
          </Tabs.Content>
        )}
        <Tabs.Content value="appearance">
          <AppearanceTab />
        </Tabs.Content>
      </Tabs.Root>
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
      <Button variant="primary" needsNet loading={busy} onClick={() => void save()} className="self-start">
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
      <LogoAnimPicker />
      <MotionStatus />
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
