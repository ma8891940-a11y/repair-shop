import { useMemo, useState, type ReactNode } from 'react';
import { NavLink, useLocation, useNavigate, useOutlet } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import {
  ClipboardList,
  Gauge,
  History,
  LogOut,
  PackagePlus,
  Search,
  Settings,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { useAuth, useMe } from './auth';
import { useTheme } from './theme';
import { useShortcuts } from './shortcuts';
import { ROLE_LABELS } from '../lib/types';
import { Mark } from '../ui/Logo';
import { ThemeToggle } from '../ui/ThemeToggle';
import { Tip } from '../ui/Tooltip';
import { Kbd } from '../ui/Kbd';
import { cn } from '../ui/cn';

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  shortcut?: string;
  end?: boolean;
  show: boolean;
}

export function AppShell() {
  const { profile, shop } = useMe();
  const { signOut } = useAuth();
  const { toggle } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  // نثبّت محتوى كل شاشة وقت الانتقال، عشان الشاشة الجديدة ما تتبنيش مرتين وتمسح اللي اتكتب
  const outlet = useOutlet();
  const [q, setQ] = useState('');
  const owner = profile.role === 'owner';
  const front = profile.role !== 'technician';

  const nav: NavItem[] = [
    { to: '/', label: 'لوحة التحكم', icon: Gauge, shortcut: 'F1', end: true, show: true },
    { to: '/devices', label: 'الأجهزة', icon: ClipboardList, shortcut: 'F3', end: true, show: true },
    { to: '/intake', label: 'استلام جهاز', icon: PackagePlus, shortcut: 'F2', show: front },
    { to: '/users', label: 'الفريق', icon: Users, show: owner },
    { to: '/audit', label: 'سجل النشاط', icon: History, show: owner },
    { to: '/settings', label: 'الإعدادات', icon: Settings, show: owner },
  ].filter((n) => n.show);

  const shortcuts = useMemo(
    () => [
      { combo: 'F1', handler: () => navigate('/') },
      { combo: 'F2', handler: () => front && navigate('/intake') },
      { combo: 'F3', handler: () => document.getElementById('global-search')?.focus() },
      { combo: 'Ctrl+K', handler: () => document.getElementById('global-search')?.focus(), allowInInputs: true },
      { combo: 'Ctrl+J', handler: () => toggle(), allowInInputs: true },
    ],
    [navigate, front, toggle],
  );
  useShortcuts(shortcuts);

  return (
    <div className="flex min-h-dvh bg-bg">
      {/* الشريط الجانبي (كمبيوتر) */}
      <aside className="sticky top-0 hidden h-dvh w-[232px] shrink-0 flex-col border-e border-line bg-surface md:flex">
        <div className="flex items-center gap-2.5 px-4 pb-3 pt-4">
          <Mark size={30} />
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-fg">{shop.name}</div>
            <div className="readout-label">إدارة الصيانة</div>
          </div>
        </div>
        <div className="ruler mx-4 mb-2 opacity-70" />
        <nav className="flex flex-1 flex-col gap-0.5 px-2" aria-label="القائمة الرئيسية">
          {nav.map((n) => (
            <SideLink key={n.to} item={n} />
          ))}
        </nav>
        <div className="border-t border-line p-3">
          <div className="flex items-center gap-2.5">
            <div className="grid size-8 shrink-0 place-items-center rounded-md border border-line bg-raised text-sm font-semibold text-fg-2">
              {profile.full_name.trim().charAt(0)}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm text-fg">{profile.full_name}</div>
              <div className="text-2xs text-fg-3">{ROLE_LABELS[profile.role]}</div>
            </div>
            <ThemeToggle />
            <Tip label="خروج">
              <button
                type="button"
                onClick={() => void signOut()}
                aria-label="خروج"
                className="grid size-9 place-items-center rounded-md text-fg-3 transition-colors hover:bg-raised hover:text-danger"
              >
                <LogOut className="size-4" />
              </button>
            </Tip>
          </div>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* الشريط العلوي */}
        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-[color-mix(in_srgb,var(--bg)_86%,transparent)] px-4 backdrop-blur md:px-6">
          <div className="flex items-center gap-2 md:hidden">
            <Mark size={26} />
            <span className="max-w-[40vw] truncate text-sm font-semibold">{shop.name}</span>
          </div>
          <form
            role="search"
            className="relative ms-auto w-full max-w-md md:ms-0"
            onSubmit={(e) => {
              e.preventDefault();
              navigate(`/devices?q=${encodeURIComponent(q)}`);
              (document.activeElement as HTMLElement | null)?.blur();
            }}
          >
            <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
            <input
              id="global-search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={front ? 'رقم الطلب، الموبايل، الاسم، IMEI' : 'رقم الطلب، IMEI، الموديل'}
              aria-label="بحث في الأجهزة"
              className="h-9 w-full rounded-md border border-line bg-surface pe-16 ps-9 text-sm text-fg transition-[border-color,box-shadow] placeholder:text-fg-3 hover:border-line-strong focus:border-accent focus:shadow-[0_0_0_3px_var(--accent-soft)] focus:outline-none"
            />
            <span className="pointer-events-none absolute end-2 top-1/2 hidden -translate-y-1/2 items-center gap-1 sm:flex">
              <Kbd>Ctrl</Kbd>
              <Kbd>K</Kbd>
            </span>
          </form>
          <div className="flex items-center md:hidden">
            <ThemeToggle />
          </div>
        </header>

        <main className="flex-1 px-4 pb-24 pt-5 md:px-6 md:pb-8">
          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: 0.18, ease: [0.2, 0.8, 0.2, 1] }}
            >
              {outlet}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>

      {/* شريط سفلي (موبايل) */}
      <nav
        aria-label="القائمة"
        className="fixed inset-x-0 bottom-0 z-30 flex border-t border-line bg-surface pb-[env(safe-area-inset-bottom)] md:hidden"
      >
        {nav.slice(0, 4).map((n) => (
          <NavLink
            key={n.to}
            to={n.to}
            end={n.end}
            className={({ isActive }) =>
              cn('flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs transition-colors', isActive ? 'text-accent' : 'text-fg-3')
            }
          >
            <n.icon className="size-5" aria-hidden />
            {n.label}
          </NavLink>
        ))}
        <button type="button" onClick={() => void signOut()} className="flex flex-1 flex-col items-center gap-0.5 py-2 text-2xs text-fg-3">
          <LogOut className="size-5" aria-hidden />
          خروج
        </button>
      </nav>
    </div>
  );
}

function SideLink({ item }: { item: NavItem }) {
  const link = (
    <NavLink
      to={item.to}
      end={item.end}
      className={({ isActive }) =>
        cn(
          'group relative flex h-9 items-center gap-2.5 rounded-md px-3 text-sm transition-colors duration-150',
          isActive ? 'bg-raised text-fg' : 'text-fg-2 hover:bg-raised/60 hover:text-fg',
        )
      }
    >
      {({ isActive }) => (
        <>
          {isActive && (
            <motion.span
              layoutId="nav-indicator"
              className="absolute inset-y-1.5 start-0 w-[3px] rounded-full bg-accent shadow-[0_0_10px_var(--accent-glow)]"
              transition={{ duration: 0.2, ease: [0.2, 0.8, 0.2, 1] }}
            />
          )}
          <item.icon className={cn('size-4 shrink-0', isActive ? 'text-accent' : 'text-fg-3 group-hover:text-fg-2')} aria-hidden />
          <span className="flex-1">{item.label}</span>
        </>
      )}
    </NavLink>
  );
  return item.shortcut ? (
    <Tip label={item.label} shortcut={item.shortcut} side="left">
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
