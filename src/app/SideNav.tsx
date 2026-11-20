import { useCallback, useEffect, useMemo, useState } from 'react';
import { NavLink, useLocation } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import {
  BarChart3, Bot, Boxes, ChevronDown, LayoutGrid, ClipboardCheck, ClipboardList, Clock, Contact, Film, Gauge, Handshake, History, Landmark, MessagesSquare, PackageMinus, PackagePlus,
  Receipt, Settings, ShieldCheck, ShoppingCart, Smartphone, Star, Store, TrendingUp, Truck, Users, Wallet, Wrench, type LucideIcon,
} from 'lucide-react';
import { useMe } from './auth';
import { favoriteEntries, groupOf, isActiveEntry, type NavEntry, type NavGroup, type NavGroupKey } from './navGroups';
import type { ShortcutDef } from './shortcutsRegistry';
import { Tip } from '../ui/Tooltip';
import { cn } from '../ui/cn';

export const NAV_ICONS: Record<string, LucideIcon> = {
  BarChart3, Bot, Boxes, LayoutGrid, ClipboardCheck, ClipboardList, Clock, Contact, Film, Gauge, Handshake, History, Landmark, MessagesSquare, PackageMinus, PackagePlus,
  Receipt, Settings, ShieldCheck, ShoppingCart, Smartphone, Store, TrendingUp, Truck, Users, Wallet, Wrench,
};

const readJson = <T,>(k: string, fallback: T): T => {
  try {
    const v = localStorage.getItem(k);
    return v ? (JSON.parse(v) as T) : fallback;
  } catch {
    return fallback;
  }
};
const writeJson = (k: string, v: unknown) => {
  try {
    localStorage.setItem(k, JSON.stringify(v));
  } catch {
    /* التخزين ممكن يكون مقفول */
  }
};

/** المجموعات المفتوحة والمفضلة: بتتحفظ للمستخدم ده على الجهاز ده */
export function useNavPrefs(groups: NavGroup[]) {
  const { profile } = useMe();
  const kOpen = `nav-open:${profile.id}`;
  const kFav = `nav-favs:${profile.id}`;
  const [open, setOpen] = useState<NavGroupKey[]>(() => readJson(kOpen, ['repair'] as NavGroupKey[]));
  const [favs, setFavs] = useState<string[]>(() => readJson(kFav, [] as string[]));
  const location = useLocation();
  // المجموعة اللي فيها الصفحة الحالية بتفتح لوحدها
  const current = groupOf(groups, location.pathname, location.search);
  useEffect(() => {
    if (current && current !== 'top' && !open.includes(current)) setOpen((o) => [...o, current]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current]);
  useEffect(() => writeJson(kOpen, open), [kOpen, open]);
  useEffect(() => writeJson(kFav, favs), [kFav, favs]);
  const toggleGroup = useCallback((g: NavGroupKey) => setOpen((o) => (o.includes(g) ? o.filter((x) => x !== g) : [...o, g])), []);
  const toggleFav = useCallback((k: string) => setFavs((f) => (f.includes(k) ? f.filter((x) => x !== k) : [...f, k])), []);
  const favItems = useMemo(() => favoriteEntries(groups, favs), [groups, favs]);
  return { open, toggleGroup, favs, favItems, toggleFav };
}

/** الشريط الجانبي (كمبيوتر): المفضلة، وبعدين المجموعات */
export function SideNav({ groups, shortcuts }: { groups: NavGroup[]; shortcuts: ShortcutDef[] }) {
  const { t } = useTranslation();
  const { open, toggleGroup, favs, favItems, toggleFav } = useNavPrefs(groups);
  const combo = (id?: string) => shortcuts.find((s) => s.id === id)?.combos[0];
  const top = groups.find((g) => g.key === 'top');
  return (
    <nav className="flex flex-1 flex-col gap-1 overflow-y-auto px-2 pb-2" aria-label={t('nav.menu')} data-testid="side-nav">
      {top?.items.map((i) => (
        <SideLink key={i.key} item={i} shortcut={combo(i.shortcut)} fav={favs.includes(i.key)} onFav={() => toggleFav(i.key)} />
      ))}
      {favItems.length > 0 && (
        <section className="mt-1" data-testid="nav-favorites">
          <div className="px-3 pb-0.5 pt-1.5 text-2xs font-medium text-fg-3">{t('navGroups.favorites')}</div>
          {favItems.map((i) => (
            <SideLink key={`fav-${i.key}`} item={i} shortcut={combo(i.shortcut)} fav onFav={() => toggleFav(i.key)} />
          ))}
        </section>
      )}
      {groups
        .filter((g) => g.key !== 'top')
        .map((g) => {
          const isOpen = open.includes(g.key);
          return (
            <section key={g.key} data-testid={`nav-group-${g.key}`}>
              <button
                type="button"
                onClick={() => toggleGroup(g.key)}
                aria-expanded={isOpen}
                className="flex h-8 w-full items-center gap-1.5 rounded-md px-3 text-2xs font-medium text-fg-3 hover:bg-raised/50 hover:text-fg-2"
              >
                <ChevronDown className={cn('size-3.5 transition-transform duration-150', !isOpen && 'ltr:-rotate-90 rtl:rotate-90')} aria-hidden />
                <span className="flex-1 text-start">{t(`navGroups.${g.key}`)}</span>
              </button>
              {isOpen && (
                <div className="flex flex-col gap-0.5">
                  {g.items.map((i) => (
                    <SideLink key={i.key} item={i} shortcut={combo(i.shortcut)} fav={favs.includes(i.key)} onFav={() => toggleFav(i.key)} />
                  ))}
                </div>
              )}
            </section>
          );
        })}
    </nav>
  );
}

function SideLink({ item, shortcut, fav, onFav }: { item: NavEntry; shortcut?: string; fav: boolean; onFav: () => void }) {
  const { t, i18n } = useTranslation();
  const location = useLocation();
  const active = isActiveEntry(item, location.pathname, location.search);
  const Icon = NAV_ICONS[item.icon] ?? Gauge;
  const label = t(`nav.${item.key}`);
  const link = (
    <NavLink
      to={item.to}
      end={item.end}
      aria-current={active ? 'page' : undefined}
      className={cn('group relative flex h-9 flex-1 items-center gap-2.5 rounded-md px-3 text-sm transition-colors duration-150', active ? 'text-fg' : 'text-fg-2 hover:bg-raised/50 hover:text-fg')}
      data-testid={`nav-${item.key}`}
    >
      {active && (
        <motion.span layoutId="nav-active" className="absolute inset-0 rounded-md border border-[rgb(var(--accent-rgb)/0.25)] bg-accent-soft" transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}>
          <span className="absolute inset-y-2 start-0 w-[3px] rounded-full bg-accent shadow-[0_0_10px_var(--accent-glow)]" />
        </motion.span>
      )}
      <Icon className={cn('relative size-4 shrink-0', active ? 'text-accent' : 'text-fg-3 group-hover:text-fg-2')} aria-hidden />
      <span className="relative flex-1 truncate">{label}</span>
    </NavLink>
  );
  return (
    <div className="group/row flex items-center">
      {shortcut ? (
        <Tip label={label} shortcut={shortcut} side={i18n.dir() === 'rtl' ? 'left' : 'right'}>
          {link}
        </Tip>
      ) : (
        link
      )}
      <button
        type="button"
        onClick={onFav}
        aria-pressed={fav}
        aria-label={fav ? t('navGroups.unpin', { name: label }) : t('navGroups.pin', { name: label })}
        title={fav ? t('navGroups.unpin', { name: label }) : t('navGroups.pin', { name: label })}
        className={cn('grid size-7 shrink-0 place-items-center rounded-sm transition-opacity hover:bg-raised focus-visible:opacity-100', fav ? 'text-accent opacity-100' : 'text-fg-3 opacity-0 group-hover/row:opacity-100')}
        data-testid={`pin-${item.key}`}
      >
        <Star className={cn('size-3.5', fav && 'fill-current')} aria-hidden />
      </button>
    </div>
  );
}

/** "المزيد" على الموبايل: نفس المجموعات، بتتفتح وتتقفل */
export function MoreNav({ groups, onPick }: { groups: NavGroup[]; onPick: () => void }) {
  const { t } = useTranslation();
  const { open, toggleGroup, favItems } = useNavPrefs(groups);
  const location = useLocation();
  const tile = (i: NavEntry) => {
    const Icon = NAV_ICONS[i.icon] ?? Gauge;
    const active = isActiveEntry(i, location.pathname, location.search);
    return (
      <NavLink key={i.key} to={i.to} onClick={onPick} className={cn('flex flex-col items-center gap-1 rounded-md border border-glass-border p-3 text-center text-xs', active ? 'border-accent text-accent' : 'text-fg-2 hover:text-fg')} data-testid={`more-${i.key}`}>
        <Icon className="size-5" aria-hidden />
        {t(`nav.${i.key}`)}
      </NavLink>
    );
  };
  return (
    <div className="flex flex-col gap-3" data-testid="more-nav">
      {favItems.length > 0 && (
        <section>
          <div className="mb-1.5 text-2xs font-medium text-fg-3">{t('navGroups.favorites')}</div>
          <div className="grid grid-cols-3 gap-2">{favItems.map(tile)}</div>
        </section>
      )}
      {groups.map((g) => {
        const isOpen = g.key === 'top' || open.includes(g.key);
        return (
          <section key={g.key} data-testid={`more-group-${g.key}`}>
            {g.key !== 'top' && (
              <button type="button" onClick={() => toggleGroup(g.key)} aria-expanded={isOpen} className="mb-1.5 flex w-full items-center gap-1.5 text-2xs font-medium text-fg-3">
                <ChevronDown className={cn('size-3.5 transition-transform', !isOpen && 'ltr:-rotate-90 rtl:rotate-90')} aria-hidden />
                {t(`navGroups.${g.key}`)}
              </button>
            )}
            {isOpen && <div className="grid grid-cols-3 gap-2">{g.items.map(tile)}</div>}
          </section>
        );
      })}
    </div>
  );
}
