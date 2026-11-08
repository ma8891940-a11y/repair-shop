import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useLoad } from './useLoad';
import { rpc } from './ledgerApi';
import { useFormat } from '../i18n/format';
import { Alert } from '../ui/Feedback';

/** مشكلة لقاها فحص السلامة في قاعدة البيانات (integrity_report) */
export interface IntegrityIssue {
  kind: 'entry_unbalanced' | 'entry_missing_side' | 'inventory_ledger' | 'item_value' | 'stock_entry' | 'payment_entry' | 'party_missing' | 'shop_mismatch';
  amount: number;
  entry_id?: string;
  entry_no?: number;
  item_id?: string;
  item?: string;
  qty?: number;
  ledger?: number;
  stock?: number;
}

/** مكان المشكلة: القيد نفسه، أو المخزون */
export function issueLink(i: IntegrityIssue) {
  if (i.entry_id) return `/finance/entry/${i.entry_id}`;
  return '/inventory';
}

/**
 * فحص السلامة التلقائي (صاحب المحل بس): كل مرة الشاشة تفتح بيتأكد إن كل قيد متوازن، والمخزون مطابق للدفتر،
 * وكل دفعة مطابقة لقيدها. ولو فيه أي فرق بيظهر تنبيه أحمر بالمكان والمبلغ بالظبط، مع زرار يفتح العملية.
 */
export function IntegrityAlert({ className }: { className?: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { data } = useLoad(() => rpc<IntegrityIssue[]>('integrity_report'), []);
  if (!data?.length) return null;
  const shown = data.slice(0, 5);
  return (
    <Alert tone="danger" className={className} title={t('integrity.title', { n: data.length })}>
      <ul className="mt-1 space-y-1.5" data-testid="integrity-issues">
        {shown.map((i, n) => (
          <li key={n} className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <span className="min-w-0 flex-1" data-testid="integrity-issue">
              {t(`integrity.kind.${i.kind}`, { no: i.entry_no ?? '', item: i.item ?? '', amount: f.money(i.amount), qty: f.number(i.qty ?? 0) })}
            </span>
            <Link to={issueLink(i)} className="inline-flex h-7 items-center rounded-md border border-[color-mix(in_srgb,var(--danger)_50%,transparent)] px-2.5 text-xs font-medium text-fg hover:border-danger" data-testid="integrity-open">
              {i.entry_id ? t('integrity.openEntry') : t('integrity.openInventory')}
            </Link>
          </li>
        ))}
      </ul>
      {data.length > shown.length && <p className="mt-1.5 text-xs">{t('integrity.more', { n: data.length - shown.length })}</p>}
      <p className="mt-1.5 text-xs">{t('integrity.hint')}</p>
    </Alert>
  );
}
