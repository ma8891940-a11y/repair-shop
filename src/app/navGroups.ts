import type { ShortcutAction } from './shortcutsRegistry';

/**
 * القايمة الجانبية في مجموعات بتتفتح وتتقفل. كل بند بيظهر بس لو المستخدم ليه صلاحية عليه
 * (ولما الفروع تتبني: لو نوع الفرع فيه القسم ده). اللي لسه ما اتبناش (زي الأقساط) بيتضاف هنا لما يتبني.
 */
export type NavGroupKey = 'top' | 'repair' | 'sales' | 'finance' | 'people' | 'reports' | 'settings';
export interface NavEntry {
  key: string;
  to: string;
  /** للمقارنة بالصفحة الحالية من غير ?do= */
  path: string;
  end?: boolean;
  icon: string;
  shortcut?: ShortcutAction;
}
export interface NavGroup {
  key: NavGroupKey;
  items: NavEntry[];
}
export interface NavAccess {
  role: 'owner' | 'reception' | 'technician' | 'marketing';
  isAdmin: boolean;
}

export function navGroups({ role, isAdmin }: NavAccess): NavGroup[] {
  const owner = role === 'owner';
  const front = owner || role === 'reception';
  const tech = role === 'technician';
  const staff = role !== 'marketing';
  const e = (show: boolean, item: NavEntry) => (show ? [item] : []);
  const groups: NavGroup[] = [
    {
      key: 'top',
      items: [
        ...e(tech, { key: 'work', to: '/work', path: '/work', icon: 'Wrench' }),
        ...e(staff, { key: 'dashboard', to: '/', path: '/', end: true, icon: 'Gauge', shortcut: 'nav.dashboard' }),
        ...e(owner || tech, { key: 'assistant', to: '/assistant', path: '/assistant', icon: 'Bot' }),
      ],
    },
    {
      key: 'repair',
      items: [
        ...e(front, { key: 'intake', to: '/intake', path: '/intake', icon: 'PackagePlus', shortcut: 'nav.intake' }),
        ...e(staff, { key: 'devices', to: '/devices', path: '/devices', end: true, icon: 'ClipboardList', shortcut: 'nav.devices' }),
        ...e(owner, { key: 'technicians', to: '/settings?tab=tech', path: '/settings?tab=tech', icon: 'Wrench' }),
        ...e(role !== 'reception', { key: 'videos', to: '/videos', path: '/videos', icon: 'Film' }),
        ...e(staff, { key: 'community', to: '/community', path: '/community', icon: 'MessagesSquare' }),
      ],
    },
    {
      key: 'sales',
      items: [
        ...e(front, { key: 'sale', to: '/inventory?do=sale', path: '/inventory?do=sale', icon: 'ShoppingCart' }),
        ...e(staff, { key: 'inventory', to: '/inventory', path: '/inventory', icon: 'Boxes', shortcut: 'nav.inventory' }),
        ...e(owner, { key: 'stocktake', to: '/opening', path: '/opening', icon: 'ClipboardCheck' }),
        ...e(owner, { key: 'purchases', to: '/inventory?do=purchase', path: '/inventory?do=purchase', icon: 'Truck' }),
        ...e(owner, { key: 'returns', to: '/inventory?do=write_off', path: '/inventory?do=write_off', icon: 'PackageMinus' }),
      ],
    },
    {
      key: 'finance',
      items: [
        ...e(owner, { key: 'finance', to: '/finance', path: '/finance', end: true, icon: 'Landmark', shortcut: 'nav.finance' }),
        ...e(owner, { key: 'cashboxes', to: '/finance?focus=cashboxes', path: '/finance?focus=cashboxes', icon: 'Wallet' }),
        ...e(front && !owner, { key: 'drawer', to: '/drawer', path: '/drawer', icon: 'Wallet' }),
        ...e(owner, { key: 'expenses', to: '/finance?do=expense', path: '/finance?do=expense', icon: 'Receipt' }),
        ...e(owner, { key: 'partners', to: '/partners', path: '/partners', icon: 'Handshake' }),
      ],
    },
    {
      key: 'people',
      items: [
        ...e(front, { key: 'customers', to: '/customers', path: '/customers', icon: 'Contact', shortcut: 'nav.customers' }),
        ...e(owner, { key: 'suppliers', to: '/inventory?tab=suppliers', path: '/inventory?tab=suppliers', icon: 'Store' }),
      ],
    },
    {
      key: 'reports',
      items: [
        ...e(owner, { key: 'reports', to: '/reports', path: '/reports', icon: 'BarChart3' }),
        ...e(owner, { key: 'audit', to: '/audit', path: '/audit', icon: 'History' }),
      ],
    },
    {
      key: 'settings',
      items: [
        { key: 'settings', to: '/settings', path: '/settings', icon: 'Settings' },
        ...e(owner, { key: 'team', to: '/users', path: '/users', icon: 'Users' }),
        ...e(isAdmin, { key: 'admin', to: '/admin', path: '/admin', icon: 'ShieldCheck' }),
      ],
    },
  ];
  return groups.filter((g) => g.items.length > 0);
}

/** البند ده هو الصفحة الحالية؟ (?do= و?tab= بيفرّقوا بين البنود اللي على نفس الشاشة) */
export function isActiveEntry(item: NavEntry, pathname: string, search: string): boolean {
  const [p, q] = item.path.split('?');
  if (q) return pathname === p && new URLSearchParams(search).toString() === new URLSearchParams(q).toString();
  if (pathname !== p && !(!item.end && pathname.startsWith(`${p}/`))) return false;
  return !search || !/(^|[?&])(do|tab|focus)=/.test(search);
}

/** المجموعة اللي فيها الصفحة الحالية (عشان تبقى مفتوحة) */
export function groupOf(groups: NavGroup[], pathname: string, search: string): NavGroupKey | null {
  for (const g of groups) if (g.items.some((i) => isActiveEntry(i, pathname, search))) return g.key;
  return null;
}

/** المفضلة: بنود موجودة بس (لو الصلاحية اتشالت، البند بيختفي من المفضلة كمان) */
export function favoriteEntries(groups: NavGroup[], favs: string[]): NavEntry[] {
  const all = new Map(groups.flatMap((g) => g.items).map((i) => [i.key, i]));
  return favs.map((k) => all.get(k)).filter((x): x is NavEntry => !!x);
}
