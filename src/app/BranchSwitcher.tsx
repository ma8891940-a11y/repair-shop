import { useTranslation } from 'react-i18next';
import { Building2 } from 'lucide-react';
import { useBranch } from './branch';
import { useMe } from './auth';
import { Tip } from '../ui/Tooltip';
import { cn } from '../ui/cn';

/**
 * مبدّل الفروع (فوق): بيظهر بس لو المحل فيه أكتر من فرع.
 * "كل الفروع" لصاحب المحل: القوايم والتقارير بتجمّع كل الفروع، والعمليات بتتسجل على آخر فرع اتختار.
 */
export function BranchSwitcher({ className }: { className?: string }) {
  const { t } = useTranslation();
  const { profile } = useMe();
  const b = useBranch();
  if (!b.multi) return null;
  const owner = profile.role === 'owner';
  const tip = b.view === 'all' && b.working ? t('branch.workingOn', { name: b.working.name }) : t('branch.switcher');
  return (
    <Tip label={tip}>
      <label className={cn('glass relative flex h-9 items-center gap-1.5 rounded-md ps-2.5 text-sm text-fg-2 focus-within:border-accent', className)}>
        <Building2 className="size-4 shrink-0 text-fg-3" aria-hidden />
        <span className="sr-only">{t('branch.switcher')}</span>
        <select
          value={b.view}
          onChange={(e) => b.setView(e.target.value)}
          className="h-full max-w-[150px] cursor-pointer appearance-none truncate bg-transparent pe-3 text-sm text-fg focus:outline-none"
          data-testid="branch-switcher"
        >
          {owner && <option value="all">{t('branch.all')}</option>}
          {b.mine.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name}
            </option>
          ))}
        </select>
      </label>
    </Tip>
  );
}

/** اسم الفرع كشارة صغيرة (في القوايم لما العرض "كل الفروع") */
export function BranchTag({ id, className }: { id: string | null | undefined; className?: string }) {
  const b = useBranch();
  if (!b.multi || !id) return null;
  return (
    <span className={cn('inline-flex items-center gap-1 rounded-sm border border-glass-border px-1.5 py-px text-2xs text-fg-3', className)} data-testid="branch-tag">
      <Building2 className="size-3" aria-hidden />
      {b.name(id)}
    </span>
  );
}
