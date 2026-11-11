import { Suspense, createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { NavLink, useLocation, useOutlet } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { Gauge, Keyboard, Sparkles, Languages, LogOut, Moon, Search, Menu } from 'lucide-react';
import { useAuth, useMe } from './auth';
import { usePrefs } from './prefs';
import { useShortcuts } from './shortcuts';
import { effectiveShortcuts, type ShortcutAction } from './shortcutsRegistry';
import { navGroups, type NavEntry } from './navGroups';
import { MoreNav, NAV_ICONS, SideNav, useNavPrefs } from './SideNav';
import { ScreenAssist } from './assist/ScreenAssist';
import { LeaveGuardHost, useGuardedNavigate } from './leaveGuard';
import { ShortcutsDialog } from './ShortcutsDialog';
import { openMotionDiag } from './diagShortcut';
import { AppLogo } from '../ui/Logo';
import { Skeleton } from '../ui/Feedback';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Tip } from '../ui/Tooltip';
import { Kbd } from '../ui/Kbd';
import { CommandPalette, type Command } from '../ui/CommandPalette';
import { useBackground } from './stage';
import { useToast } from '../ui/Toast';
import { Dialog } from '../ui/Dialog';
import { ConnectionBadge } from './ConnectionBadge';
import { BranchSwitcher } from './BranchSwitcher';
import { NotificationsBell } from './NotificationsBell';
import { usePerms } from './perms';
import { useBranch } from './branch';
import { supabase } from '../lib/supabase';
import { cn } from '../ui/cn';

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

/** لحظة تحميل شاشة لسه ما اتحمّلتش (شكل الشاشة نفسها من غير بيانات) */
function ScreenLoading() {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-4" role="status" aria-label={t('app.loading')} data-testid="screen-loading">
      <Skeleton className="h-7 w-48" />
      <Skeleton className="h-4 w-72" />
      <div className="grid gap-3 sm:grid-cols-3">
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
      </div>
      <Skeleton className="h-64" />
    </div>
  );
}

export function AppShell() {
  const { t } = useTranslation();
  const { profile, shop } = useMe();
  const { signOut, isAdmin } = useAuth();
  const { toggleTheme, toggleLang, effects, setEffects } = usePrefs();
  const toast = useToast();
  // التنقل من القايمة والاختصارات ولوحة الأوامر بيسأل الأول لو فيه بيانات ما اتحفظتش (البند 9)
  const navigate = useGuardedNavigate();
  const location = useLocation();
  const outlet = useOutlet();
  const [palette, setPalette] = useState(false);
  const [more, setMore] = useState(false);
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
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'journal_entries', filter }, emit)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'payments', filter }, emit)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'repair_steps', filter }, emit)
      .subscribe((status) => setLive(status === 'SUBSCRIBED'));
    return () => {
      setLive(false);
      void supabase.removeChannel(ch);
    };
  }, [shop.id]);
  // جوه البرنامج: نفس خطوط الخلفية، ثابتة وأهدى (الأداء)
  useBackground('still');
  const owner = profile.role === 'owner';
  const front = profile.role === 'owner' || profile.role === 'reception';

  // القايمة في مجموعات بالصلاحيات (src/app/navGroups.ts)
  // P: القايمة بالصلاحيات الفعلية ونوع الفرع الشغال ("كل الفروع" = كل الأقسام)
  const { perms, grant } = usePerms();
  const br = useBranch();
  const branchKind = br.multi && br.view === 'all' ? 'both' : (br.working?.kind ?? 'both');
  const groups = useMemo(
    () => navGroups({ role: profile.role as 'owner' | 'reception' | 'technician' | 'marketing', isAdmin, perms, branchKind }),
    [profile.role, isAdmin, perms, branchKind],
  );
  const nav: NavEntry[] = useMemo(() => groups.flatMap((g) => g.items).filter((n, k, a) => a.findIndex((x) => x.key === n.key) === k), [groups]);
  const keys = useMemo(() => effectiveShortcuts((shop.extras as { shortcuts?: unknown } | null)?.shortcuts), [shop.extras]);
  const comboOf = (id?: ShortcutAction) => keys.find((k) => k.id === id)?.combos[0];
  const [help, setHelp] = useState(false);
  const { favItems } = useNavPrefs(groups);

  const toggleEffects = () => {
    setEffects(!effects);
    toast({ tone: 'info', title: !effects ? t('prefs.effectsOn') : t('prefs.effectsOff') });
  };

  const commands: Command[] = useMemo(
    () => [
      ...nav.map((n) => {
        const I = NAV_ICONS[n.icon] ?? Gauge;
        return { id: `nav-${n.key}`, label: t(`nav.${n.key}`), icon: <I className="size-4" />, shortcut: comboOf(n.shortcut), run: () => navigate(n.to) };
      }),
      { id: 'theme', label: t('palette.toggleTheme'), icon: <Moon className="size-4" />, shortcut: comboOf('theme'), run: toggleTheme },
      { id: 'lang', label: t('palette.toggleLang'), icon: <Languages className="size-4" />, shortcut: comboOf('lang'), run: toggleLang },
      { id: 'shortcuts', label: t('shortcuts.title'), icon: <Keyboard className="size-4" />, shortcut: '?', run: () => setHelp(true) },
      { id: 'effects', label: t('palette.toggleEffects'), icon: <Sparkles className="size-4" />, run: toggleEffects },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, navigate, toggleTheme, toggleLang, effects, front, owner, nav, keys],
  );

  // كل الاختصارات من src/app/shortcutsRegistry.ts (وتعديلات صاحب المحل)
  const shortcuts = useMemo(() => {
    const go = (to: string, ok = true) => () => ok && navigate(to);
    const run: Record<ShortcutAction, () => void> = {
      'nav.dashboard': go('/'),
      'nav.intake': go('/intake', front),
      'nav.devices': go('/devices'),
      'nav.customers': go('/customers', front),
      'nav.finance': go('/finance', grant('finance')),
      'nav.inventory': go('/inventory'),
      palette: () => setPalette((v) => !v),
      theme: () => toggleTheme(),
      lang: () => toggleLang(),
      help: () => setHelp((v) => !v),
      diag: () => openMotionDiag(),
    };
    return keys
      .filter((k) => k.id !== 'diag') // شاشة التشخيص ليها مستمع لوحدها (MotionDiagPanel)
      .flatMap((k) => k.combos.map((combo) => ({ combo, handler: run[k.id], allowInInputs: k.inInputs, outsideInputsOnly: !k.inInputs })));
  }, [keys, navigate, front, grant, toggleTheme, toggleLang]);
  useShortcuts(shortcuts);

  return (
    <LiveCtx.Provider value={{ live, subscribe }}>
      <div className="relative flex min-h-dvh">

        {/* الشريط الجانبي (كمبيوتر) */}
        <aside className="glass sticky top-0 z-20 hidden h-dvh w-[236px] shrink-0 flex-col rounded-none border-y-0 border-s-0 md:flex">
          <div className="flex items-center gap-2.5 px-4 pb-3 pt-4">
            <AppLogo height={34} shared />
            <div className="min-w-0">
              <div className="truncate text-sm font-semibold text-fg">{shop.name}</div>
              <div className="readout-label">{t('app.tagline')}</div>
            </div>
          </div>
          <div className="mx-4 mb-2 h-px bg-gradient-to-l from-transparent via-[rgb(var(--accent-rgb)/0.35)] to-transparent" />
          <SideNav groups={groups} shortcuts={keys} />
          <div className="border-t border-glass-border p-3">
            <div className="mb-2 flex items-center gap-1">
              <ThemeToggle />
              <LangToggle />
              <Tip label={t('shortcuts.title')} shortcut="?">
                <button type="button" onClick={() => setHelp(true)} aria-label={t('shortcuts.title')} className="grid size-9 place-items-center rounded-md text-fg-2 transition-colors hover:bg-raised/70 hover:text-fg" data-testid="open-shortcuts">
                  <Keyboard className="size-4" />
                </button>
              </Tip>
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
              <AppLogo height={26} shared />
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
                {(comboOf('palette') ?? 'Ctrl+K').split('+').map((k) => (
                  <Kbd key={k}>{k}</Kbd>
                ))}
              </span>
            </button>
            <div className="ms-auto flex shrink-0 items-center gap-1 sm:gap-2">
              <BranchSwitcher />
              {profile.role !== 'marketing' && <NotificationsBell />}
              <ConnectionBadge live={live} />
              <div className="flex items-center md:hidden">
                {profile.role !== 'marketing' && <ScreenAssist placement="header" />}
                <LangToggle />
                <ThemeToggle />
              </div>
            </div>
          </header>

          <main className="flex-1 px-4 pb-24 pt-5 md:px-6 md:pb-20">
            {/* دخول الشاشة بحركة خفيفة. من غير انتظار خروج الشاشة القديمة (mode="wait" كان ممكن يعلّق الصفحة فاضية لو التنقل كان سريع) */}
            <motion.div key={location.pathname} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2, ease: [0.2, 0.8, 0.2, 1] }}>
              {/* الشاشة لو لسه بتتحمّل (نادر: الأساسية بتتحمّل في الخلفية بعد الدخول) */}
              <Suspense fallback={<ScreenLoading />}>{outlet}</Suspense>
            </motion.div>
          </main>
        </div>

        {/* شريط سفلي (موبايل) */}
        <nav aria-label={t('nav.menu')} className="glass fixed inset-x-0 bottom-0 z-30 flex rounded-none border-x-0 border-b-0 pb-[env(safe-area-inset-bottom)] md:hidden">
          {/* أول 4: المفضلة لو فيه، وإلا أهم الشاشات */}
          {(favItems.length ? favItems : nav.filter((n) => ['work', 'dashboard', 'devices', 'intake', 'customers'].includes(n.key))).slice(0, 4).map((n) => {
            const I = NAV_ICONS[n.icon] ?? Gauge;
            return (
              <NavLink key={n.key} to={n.to} end={n.end} className={({ isActive }) => cn('flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs transition-colors', isActive ? 'text-accent' : 'text-fg-3')}>
                <I className="size-5" aria-hidden />
                {t(`nav.${n.key}`)}
              </NavLink>
            );
          })}
          <button type="button" onClick={() => setMore(true)} aria-haspopup="dialog" className="flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs text-fg-3">
            <Menu className="size-5" aria-hidden />
            {t('nav.more')}
          </button>
        </nav>

        {/* "المزيد" على الموبايل: باقي القائمة والخروج */}
        <Dialog open={more} onOpenChange={setMore} title={t('nav.more')}>
          <nav aria-label={t('nav.more')} className="flex flex-col gap-3">
            <MoreNav groups={groups} onPick={() => setMore(false)} />
            <button type="button" onClick={() => void signOut()} className="flex items-center justify-center gap-2 rounded-md border border-glass-border p-3 text-xs text-fg-2 hover:text-danger">
              <LogOut className="size-4 rtl:-scale-x-100" aria-hidden />
              {t('common.signOut')}
            </button>
          </nav>
        </Dialog>

        {profile.role !== 'marketing' && <ScreenAssist placement="float" />}
        <LeaveGuardHost />
        <ShortcutsDialog open={help} onOpenChange={setHelp} shortcuts={keys} />
        <CommandPalette open={palette} onOpenChange={setPalette} commands={commands} showCustomer={front} onOpenDevice={(id) => navigate(`/devices/${id}`)} />
      </div>
    </LiveCtx.Provider>
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
