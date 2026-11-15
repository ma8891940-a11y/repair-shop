import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { BarChart3, Boxes, CalendarDays, Contact, Handshake, Receipt, Scale, Truck, Users, type LucideIcon } from 'lucide-react';
import { Panel, PanelHeader } from '../../ui/Panel';
import { usePerms } from '../perms';

/** البند 8: تقارير جاهزة بدوسة واحدة، بنفس الفترة المختارة */
export function ReadyReports({ query, lastDay }: { query: string; lastDay: string }) {
  const { t } = useTranslation();
  const { grant } = usePerms();
  // P: الموظف بيشوف التقارير اللي ليه صلاحيتها بس (المرتبات والشركاء لصاحب المحل)
  const allow: Record<string, boolean> = { employees: grant('staff'), partners: grant('partners'), inventory: grant('reports'), tech: grant('reports') };
  const all: { k: string; to: string; icon: LucideIcon }[] = [
    { k: 'day', to: `/print/day/${lastDay}`, icon: CalendarDays },
    { k: 'pl', to: `/finance/pl${query}`, icon: Receipt },
    { k: 'trial', to: '/finance/trial', icon: Scale },
    { k: 'customers', to: '/finance/balances/customers', icon: Contact },
    { k: 'suppliers', to: '/finance/balances/suppliers', icon: Truck },
    { k: 'employees', to: '/finance/balances/employees', icon: Users },
    { k: 'inventory', to: `/inventory${query}${query.length > 1 ? '&' : ''}tab=summary`, icon: Boxes },
    { k: 'tech', to: `/reports${query}`, icon: BarChart3 },
    { k: 'partners', to: '/partners', icon: Handshake },
  ];
  const items = all.filter((x) => allow[x.k] ?? true);
  return (
    <Panel className="mt-4" data-testid="ready-reports">
      <PanelHeader title={t('ready.title')} />
      <div className="grid gap-2 p-3 sm:grid-cols-2 lg:grid-cols-4">
        {items.map(({ k, to, icon: Icon }) => (
          <Link key={k} to={to} className="glass lift flex items-start gap-2.5 rounded-md p-3" data-testid={`ready-${k}`}>
            <Icon className="mt-0.5 size-4 shrink-0 text-accent" aria-hidden />
            <span className="min-w-0">
              <span className="block text-sm font-medium text-fg">{t(`ready.items.${k}.t`)}</span>
              <span className="block text-2xs text-fg-3">{t(`ready.items.${k}.d`)}</span>
            </span>
          </Link>
        ))}
      </div>
    </Panel>
  );
}
