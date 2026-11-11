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
export type Perms = Record<string, string[]>;
export type BranchKind = 'repair' | 'sales' | 'both';
export interface NavAccess {
  role: 'owner' | 'reception' | 'technician' | 'marketing';
  isAdmin: boolean;
  /** P: صلاحيات المستخدم الفعلية (من my_perms). من غيرها = اللي الدور الأساسي بيعمله */
  perms?: Perms | null;
  /** P: نوع الفرع الشغال ("كل الفروع" = both) */
  branchKind?: BranchKind;
}

/** المستخدم ليه الصلاحية دي؟ (صاحب المحل دايمًا، ومن غير جدول = الدور الأساسي) */
export function can(perms: Perms | null | undefined, section: string, op = 'view'): boolean {
  if (!perms) return true;
  return (perms[section] ?? []).includes(op);
}

/** القسم ده موجود في نوع الفرع ده؟ صيانة بس: من غير مبيعات. مبيعات بس: من غير استلام وأجهزة وفنيين */
export function branchHas(kind: BranchKind | undefined, section: string): boolean {
  if (kind === 'repair') return section !== 'sales';
  if (kind === 'sales') return !['devices', 'intake', 'technicians'].includes(section);
  return true;
}

/**
 * P (المرحلة التانية): صلاحية بيديها صاحب المحل للموظف زيادة على دوره (المشتريات، والوضع المالي، والتقارير...).
 * صاحب المحل دايمًا. الموظف: لازم الجدول يكون وصل ومعلّم فيه، والفني عمره ما بياخدها (ما يشوفش أسعار ولا أرباح).
 * نفس القاعدة في قاعدة البيانات (grant_require).
 */
export function granted(role: string, perms: Perms | null | undefined, section: string, op = 'view'): boolean {
  if (role === 'owner') return true;
  if (role !== 'reception' || !perms) return false;
  return (perms[section] ?? []).includes(op);
}

// كل بند في القايمة ← القسم والعملية اللي بيحتاجها
const NEEDS: Record<string, [string, string]> = {
  work: ['devices', 'view'],
  intake: ['intake', 'add'],
  devices: ['devices', 'view'],
  technicians: ['technicians', 'view'],
  videos: ['devices', 'view'],
  sale: ['sales', 'add'],
  inventory: ['inventory', 'view'],
  drawer: ['cashbox', 'view'],
  customers: ['customers', 'view'],
};

export function navGroups({ role, isAdmin, perms, branchKind }: NavAccess): NavGroup[] {
  const owner = role === 'owner';
  const front = owner || role === 'reception';
  const tech = role === 'technician';
  const staff = role !== 'marketing';
  const g = (section: string, op = 'view') => granted(role, perms, section, op);
  const e = (show: boolean, item: NavEntry) => {
    const need = NEEDS[item.key];
    // المخزون: بيظهر لو بيشوف المخزون أو بيبيع
    const allowed = !need || can(perms, need[0], need[1]) || (item.key === 'inventory' && can(perms, 'sales', 'view'));
    const inBranch = !need || branchHas(branchKind, need[0]);
    return show && allowed && inBranch ? [item] : [];
  };
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
        ...e(g('purchases', 'add'), { key: 'purchases', to: '/inventory?do=purchase', path: '/inventory?do=purchase', icon: 'Truck' }),
        ...e(g('inventory', 'delete'), { key: 'returns', to: '/inventory?do=write_off', path: '/inventory?do=write_off', icon: 'PackageMinus' }),
      ],
    },
    {
      key: 'finance',
      items: [
        ...e(g('finance'), { key: 'finance', to: '/finance', path: '/finance', end: true, icon: 'Landmark', shortcut: 'nav.finance' }),
        ...e(g('finance'), { key: 'cashboxes', to: '/finance?focus=cashboxes', path: '/finance?focus=cashboxes', icon: 'Wallet' }),
        ...e(front && !owner, { key: 'drawer', to: '/drawer', path: '/drawer', icon: 'Wallet' }),
        ...e(g('expenses', 'add'), { key: 'expenses', to: '/finance?do=expense', path: '/finance?do=expense', icon: 'Receipt' }),
        ...e(owner, { key: 'partners', to: '/partners', path: '/partners', icon: 'Handshake' }),
      ],
    },
    {
      key: 'people',
      items: [
        ...e(front, { key: 'customers', to: '/customers', path: '/customers', icon: 'Contact', shortcut: 'nav.customers' }),
        ...e(g('purchases'), { key: 'suppliers', to: '/inventory?tab=suppliers', path: '/inventory?tab=suppliers', icon: 'Store' }),
      ],
    },
    {
      key: 'reports',
      items: [
        ...e(g('reports'), { key: 'reports', to: '/reports', path: '/reports', icon: 'BarChart3' }),
        ...e(g('audit'), { key: 'audit', to: '/audit', path: '/audit', icon: 'History' }),
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
