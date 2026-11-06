import { useMemo } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { periodRange, type Period, type PeriodKind } from '../../lib/ledger';
import { cn } from '../../ui/cn';

const KINDS: PeriodKind[] = ['today', 'week', 'month', 'custom'];

/** الفترة محفوظة في الرابط (?p=week&from=..&to=..)، عشان الرجوع والمشاركة يفضلوا على نفس الفترة */
export function usePeriod() {
  const [sp, setSp] = useSearchParams();
  const kind = (KINDS.includes(sp.get('p') as PeriodKind) ? sp.get('p') : 'month') as PeriodKind;
  const period: Period = { kind, from: sp.get('from') ?? undefined, to: sp.get('to') ?? undefined };
  const range = useMemo(() => periodRange(period, new Date()), [period.kind, period.from, period.to]); // eslint-disable-line react-hooks/exhaustive-deps
  const set = (p: Period) => {
    const n = new URLSearchParams(sp);
    n.set('p', p.kind);
    if (p.kind === 'custom') {
      if (p.from) n.set('from', p.from);
      if (p.to) n.set('to', p.to);
    } else {
      n.delete('from');
      n.delete('to');
    }
    setSp(n, { replace: true });
  };
  return { period, range, set, query: `?${sp.toString()}` };
}

export function PeriodFilter({ value, onChange }: { value: Period; onChange: (p: Period) => void }) {
  const { t } = useTranslation();
  const today = new Date().toISOString().slice(0, 10);
  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="glass inline-flex rounded-md p-1" role="radiogroup" aria-label={t('fin.period')}>
        {KINDS.map((k) => (
          <button
            key={k}
            type="button"
            role="radio"
            aria-checked={value.kind === k}
            onClick={() => onChange({ kind: k, from: value.from ?? today, to: value.to ?? today })}
            className={cn('h-7 rounded-sm px-3 text-sm transition-colors', value.kind === k ? 'bg-accent-soft text-fg' : 'text-fg-3 hover:text-fg')}
          >
            {t(`fin.periods.${k}`)}
          </button>
        ))}
      </div>
      {value.kind === 'custom' && (
        <div className="flex items-center gap-1.5 text-sm">
          <input type="date" aria-label={t('fin.fromDate')} value={value.from ?? today} onChange={(e) => onChange({ ...value, from: e.target.value })} className="num h-8 rounded-md border border-line bg-sunken/60 px-2 text-fg focus:border-accent focus:outline-none" />
          <span className="text-fg-3">{t('fin.until')}</span>
          <input type="date" aria-label={t('fin.toDate')} value={value.to ?? today} onChange={(e) => onChange({ ...value, to: e.target.value })} className="num h-8 rounded-md border border-line bg-sunken/60 px-2 text-fg focus:border-accent focus:outline-none" />
        </div>
      )}
    </div>
  );
}
