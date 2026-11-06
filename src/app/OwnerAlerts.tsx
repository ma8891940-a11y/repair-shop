import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { AlertTriangle, HandCoins } from 'lucide-react';
import { useLoad } from './useLoad';
import { useMe } from './auth';
import { useLiveRefresh } from './AppShell';
import { rpc, type StockRow } from './ledgerApi';
import { useFormat } from '../i18n/format';
import { cn } from '../ui/cn';

/** لوحة التحكم (صاحب المحل): النواقص والديون المستحقة من نظرة، وكل واحد بيفتح تفاصيله */
export function OwnerAlerts() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const { data, reload } = useLoad(async () => {
    const [items, debts] = await Promise.all([rpc<StockRow[]>('items_stock'), rpc<{ balance: number }[]>('party_balances', { p_kind: 'customers' })]);
    const pos = debts.map((d) => Number(d.balance)).filter((b) => b > 0);
    return { short: items.filter((i) => i.short).length, debtors: pos.length, debt: pos.reduce((a, b) => a + b, 0) };
  }, []);
  useLiveRefresh(reload);
  if (!data) return null;
  return (
    <div className="mb-4 grid gap-3 sm:grid-cols-2">
      <Link to="/inventory" className={cn('glass lift flex items-center gap-3 rounded-lg px-4 py-3', data.short > 0 && 'border-[color-mix(in_srgb,var(--warn)_40%,var(--glass-border))]')} data-testid="alert-short">
        <AlertTriangle className={cn('size-5', data.short > 0 ? 'text-warn' : 'text-fg-3')} aria-hidden />
        <span className="flex-1 text-sm text-fg">{t('dashboard.shortages')}</span>
        <span className="num text-lg text-fg">{f.number(data.short)}</span>
      </Link>
      <Link to="/finance/balances/customers" className="glass lift flex items-center gap-3 rounded-lg px-4 py-3" data-testid="alert-debts">
        <HandCoins className={cn('size-5', data.debt > 0 ? 'text-warn' : 'text-fg-3')} aria-hidden />
        <span className="flex-1 text-sm text-fg">{t('dashboard.debts', { n: data.debtors })}</span>
        <span className="num text-lg text-fg">
          {f.money(data.debt)} <span className="font-sans text-2xs text-fg-3">{f.currency(shop.currency)}</span>
        </span>
      </Link>
    </div>
  );
}
