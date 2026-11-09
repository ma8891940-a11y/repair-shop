import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ClipboardList } from 'lucide-react';
import { useMe } from './auth';
import { openingProgress } from '../lib/opening';

/** لوحة التحكم (صاحب المحل): تقدم جرد المحل أول مرة، لحد ما يخلّص. بيختفي بعدها */
export function OpeningCard() {
  const { t } = useTranslation();
  const { shop } = useMe();
  const p = openingProgress(shop.extras);
  if (p.done) return null;
  const pct = Math.round((p.count * 100) / p.total);
  return (
    <Link to="/opening" className="glass lift mb-4 flex items-center gap-4 rounded-lg px-4 py-3" data-testid="opening-card">
      <ClipboardList className="size-5 shrink-0 text-accent" aria-hidden />
      <div className="min-w-0 flex-1">
        <div className="text-sm font-semibold text-fg">{t('opening.cardTitle')}</div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-sunken" role="progressbar" aria-valuemin={0} aria-valuemax={p.total} aria-valuenow={p.count} aria-label={t('opening.cardTitle')}>
          <div className="h-full rounded-full bg-accent transition-[width] duration-200" style={{ width: `${pct}%` }} />
        </div>
      </div>
      <span className="num shrink-0 text-sm text-fg-2" data-testid="opening-card-count">
        {t('opening.cardCount', { n: p.count, total: p.total })}
      </span>
    </Link>
  );
}
