import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { NavLink, useLocation, useNavigate, useOutlet } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ClipboardList, Gauge, Sparkles, History, Languages, LogOut, Moon, PackagePlus, Search, Settings, Users, type LucideIcon } from 'lucide-react';
import { useAuth, useMe } from './auth';
import { usePrefs } from './prefs';
import { useShortcuts } from './shortcuts';
import { Mark } from '../ui/Logo';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Tip } from '../ui/Tooltip';
import { Kbd } from '../ui/Kbd';
import { CommandPalette, type Command } from '../ui/CommandPalette';
import { CircuitField } from '../ui/fx/CircuitField';
import { useToast } from '../ui/Toast';
import { supabase } from '../lib/supabase';
import { cn } from '../ui/cn';

interface NavItem {
  to: string;
  key: string;
  icon: LucideIcon;
  shortcut?: string;
  end?: boolean;
  show: boolean;
}

/** الاتصال اللحظي (Realtime) للمحل كله: أي شاشة تقدر تسمع للتغييرات */
type Listener = () => void;
const LiveCtx = createContext<{ live: boolean; subscribe: (fn: Listener) => () => void }>({ live: false, subscribe: () => () => {} });
export const useLive = () => useContext(LiveCtx);

/** بتنادي fn (بتأخير بسيط عشان التغييرات المتتالية تتجمع) لما أي جهاز أو سعر أو حالة تتغير في المحل */
export function useLiveRefresh(fn: () => void) {
  const { subscribe } = useLive();
  const ref = useRef(fn);
  ref.current = fn;
  useEffect(() => {
    let tm = 0;
    const off = subscribe(() => {
      clearTimeout(tm);
      tm = window.setTimeout(() => ref.current(), 350);
    });
    return () => {
      clearTimeout(tm);
      off();
    };
  }, [subscribe]);
}

export function AppShell() {
  const { t } = useTranslation();
  const { profile, shop } = useMe();
  const { signOut } = useAuth();
  const { toggleTheme, toggleLang, effects, setEffects } = usePrefs();
  const toast = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const outlet = useOutlet();
  const [palette, setPalette] = useState(false);
  const [live, setLive] = useState(false);
  const listeners = useRef(new Set<Listener>());
  const subscribe = useCallback((fn: Listener) => {
    listeners.current.add(fn);
    return () => void listeners.current.delete(fn);
  }, []);
  useEffect(() => {
    const emit = () => listeners.current.forEach((fn) => fn());
    const filter = `shop_id=eq.${shop.id}`;
    const ch = supabase
      .channel(`shop-${shop.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'devices', filter }, emit)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'device_costs', filter }, emit)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'status_log', filter }, emit)
      .subscribe((status) => setLive(status === 'SUBSCRIBED'));
    return () => {
      setLive(false);
      void supabase.removeChannel(ch);
    };
  }, [shop.id]);
  const owner = profile.role === 'owner';
  const front = profile.role !== 'technician';

  const nav: NavItem[] = [
    { to: '/', key: 'dashboard', icon: Gauge, shortcut: 'F1', end: true, show: true },
    { to: '/devices', key: 'devices', icon: ClipboardList, shortcut: 'F3', end: true, show: true },
    { to: '/intake', key: 'intake', icon: PackagePlus, shortcut: 'F2', show: front },
    { to: '/users', key: 'team', icon: Users, show: owner },
    { to: '/audit', key: 'audit', icon: History, show: owner },
    { to: '/settings', key: 'settings', icon: Settings, show: true },
  ].filter((n) => n.show);

  const toggleEffects = () => {
    setEffects(!effects);
    toast({ tone: 'info', title: !effects ? t('prefs.effectsOn') : t('prefs.effectsOff') });
  };

  const commands: Command[] = useMemo(
    () => [
      ...nav.map((n) => ({ id: `nav-${n.key}`, label: t(`nav.${n.key}`), icon: <n.icon className="size-4" />, shortcut: n.shortcut, run: () => navigate(n.to) })),
      { id: 'theme', label: t('palette.toggleTheme'), icon: <Moon className="size-4" />, shortcut: 'Ctrl+J', run: toggleTheme },
      { id: 'lang', label: t('palette.toggleLang'), icon: <Languages className="size-4" />, shortcut: 'Ctrl+L', run: toggleLang },
      { id: 'effects', label: t('palette.toggleEffects'), icon: <Sparkles className="size-4" />, run: toggleEffects },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, navigate, toggleTheme, toggleLang, effects, front, owner],
  );

  const shortcuts = useMemo(
    () => [
      { combo: 'F1', handler: () => navigate('/') },
      { combo: 'F2', handler: () => front && navigate('/intake') },
      { combo: 'F3', handler: () => setPalette(true) },
      { combo: 'Ctrl+K', handler: () => setPalette((v) => !v), allowInInputs: true },
      { combo: 'Ctrl+J', handler: () => toggleTheme(), allowInInputs: true },
      { combo: 'Ctrl+L', handler: () => toggleLang(), allowInInputs: true },
    ],
    [navigate, front, toggleTheme, toggleLang],
  );
  useShortcuts(shortcuts);

  return (
    <LiveCtx.Provider value={{ live, subscribe }}>
      <div className="relative flex min-h-dvh">
        <CircuitField className="fixed opacity-60" density={0.35} still />

        {/* الشريط الجانبي (كمبيوتر) */}
        <aside className="glass sticky top-0 z-20 hidden h-dvh w-[236px] shrink-0 flex-col rounded-none border-y-0 border-s-0 md:flex">
          <div className="flex items-center gap-2.5 px-4 pb-3 pt-4">
            <Mark size={32} />
            <div className="min-w-0">
              <div className="truncate text-sm font-semibold text-fg">{shop.name}</div>
              <div className="readout-label">{t('app.tagline')}</div>
            </div>
          </div>
          <div className="mx-4 mb-2 h-px bg-gradient-to-l from-transparent via-[rgb(var(--accent-rgb)/0.35)] to-transparent" />
          <nav className="flex flex-1 flex-col gap-0.5 px-2" aria-label={t('nav.menu')}>
            {nav.map((n) => (
              <SideLink key={n.to} item={n} label={t(`nav.${n.key}`)} />
            ))}
          </nav>
          <div className="border-t border-glass-border p-3">
            <div className="mb-2 flex items-center gap-1">
              <ThemeToggle />
              <LangToggle />
              <Tip label={t('prefs.effects')}>
                <button
                  type="button"
                  onClick={toggleEffects}
                  aria-pressed={effects}
                  aria-label={t('prefs.effects')}
                  className={cn('grid size-9 place-items-center rounded-md transition-colors hover:bg-raised/70', effects ? 'text-accent' : 'text-fg-2 hover:text-fg')}
                >
                  <Sparkles className="size-4" />
                </button>
              </Tip>
            </div>
            <div className="flex items-center gap-2.5">
              <div className="grid size-8 shrink-0 place-items-center rounded-md border border-glass-border bg-raised text-sm font-semibold text-fg-2">{profile.full_name.trim().charAt(0)}</div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm text-fg">{profile.full_name}</div>
                <div className="text-2xs text-fg-3">{t(`roles.${profile.role}`)}</div>
              </div>
              <Tip label={t('common.signOut')}>
                <button type="button" onClick={() => void signOut()} aria-label={t('common.signOut')} className="grid size-9 place-items-center rounded-md text-fg-3 transition-colors hover:bg-raised hover:text-danger">
                  <LogOut className="size-4 rtl:-scale-x-100" />
                </button>
              </Tip>
            </div>
          </div>
        </aside>

        <div className="relative z-10 flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-glass-border bg-[color-mix(in_srgb,var(--bg)_72%,transparent)] px-4 backdrop-blur-xl md:px-6">
            <div className="flex shrink-0 items-center gap-2 md:hidden">
              <Mark size={26} />
            </div>
            <button
              type="button"
              onClick={() => setPalette(true)}
              className="glass group flex h-9 min-w-0 flex-1 items-center gap-2.5 rounded-md px-3 text-sm text-fg-3 transition-[border-color] hover:border-glass-border-strong md:max-w-md"
              aria-label={t('nav.search')}
            >
              <Search className="size-4" aria-hidden />
              <span className="flex-1 truncate text-start">{front ? t('shell.searchPlaceholder') : t('shell.searchPlaceholderTech')}</span>
              <span className="hidden items-center gap-1 sm:flex">
                <Kbd>Ctrl</Kbd>
                <Kbd>K</Kbd>
              </span>
            </button>
            <div className="ms-auto flex shrink-0 items-center gap-1 sm:gap-2">
              <Tip label={live ? t('common.live') : t('common.offlineRealtime')}>
                <span className={cn('flex h-7 items-center gap-1.5 rounded-full border px-2.5 text-2xs font-medium', live ? 'border-[color-mix(in_srgb,var(--ok)_35%,transparent)] text-ok' : 'border-glass-border text-fg-3')}>
                  <span className="relative flex size-1.5">
                    {live && <span className="absolute inline-flex size-full animate-[ping-soft_1.8s_ease-out_infinite] rounded-full bg-ok" />}
                    <span className={cn('relative inline-flex size-1.5 rounded-full', live ? 'bg-ok' : 'bg-fg-3')} />
                  </span>
                  <span className="hidden sm:inline">{t('common.live')}</span>
                </span>
              </Tip>
              <div className="flex items-center md:hidden">
                <LangToggle />
                <ThemeToggle />
              </div>
            </div>
          </header>

          <main className="flex-1 px-4 pb-24 pt-5 md:px-6 md:pb-8">
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={location.pathname}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                transition={{ duration: 0.2, ease: [0.2, 0.8, 0.2, 1] }}
              >
                {outlet}
              </motion.div>
            </AnimatePresence>
          </main>
        </div>

        {/* شريط سفلي (موبايل) */}
        <nav aria-label={t('nav.menu')} className="glass fixed inset-x-0 bottom-0 z-30 flex rounded-none border-x-0 border-b-0 pb-[env(safe-area-inset-bottom)] md:hidden">
          {nav.slice(0, 4).map((n) => (
            <NavLink key={n.to} to={n.to} end={n.end} className={({ isActive }) => cn('flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs transition-colors', isActive ? 'text-accent' : 'text-fg-3')}>
              <n.icon className="size-5" aria-hidden />
              {t(`nav.${n.key}`)}
            </NavLink>
          ))}
          <button type="button" onClick={() => void signOut()} className="flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs text-fg-3">
            <LogOut className="size-5 rtl:-scale-x-100" aria-hidden />
            {t('common.signOut')}
          </button>
        </nav>

        <CommandPalette open={palette} onOpenChange={setPalette} commands={commands} showCustomer={front} onOpenDevice={(id) => navigate(`/devices/${id}`)} />
      </div>
    </LiveCtx.Provider>
  );
}

function SideLink({ item, label }: { item: NavItem; label: string }) {
  const { i18n } = useTranslation();
  const link = (
    <NavLink
      to={item.to}
      end={item.end}
      className={({ isActive }) =>
        cn('group relative flex h-9 items-center gap-2.5 rounded-md px-3 text-sm transition-colors duration-150', isActive ? 'text-fg' : 'text-fg-2 hover:bg-raised/50 hover:text-fg')
      }
    >
      {({ isActive }) => (
        <>
          {isActive && (
            <motion.span layoutId="nav-active" className="absolute inset-0 rounded-md border border-[rgb(var(--accent-rgb)/0.25)] bg-accent-soft" transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}>
              <span className="absolute inset-y-2 start-0 w-[3px] rounded-full bg-accent shadow-[0_0_10px_var(--accent-glow)]" />
            </motion.span>
          )}
          <item.icon className={cn('relative size-4 shrink-0', isActive ? 'text-accent' : 'text-fg-3 group-hover:text-fg-2')} aria-hidden />
          <span className="relative flex-1">{label}</span>
        </>
      )}
    </NavLink>
  );
  return item.shortcut ? (
    <Tip label={label} shortcut={item.shortcut} side={i18n.dir() === 'rtl' ? 'left' : 'right'}>
      {link}
    </Tip>
  ) : (
    link
  );
}

export function PageHeader({ title, sub, actions }: { title: ReactNode; sub?: ReactNode; actions?: ReactNode }) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-fg">{title}</h1>
        {sub && <div className="mt-0.5 text-sm text-fg-3">{sub}</div>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
