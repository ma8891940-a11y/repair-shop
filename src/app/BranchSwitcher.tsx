import { useTranslation } from 'react-i18next';
import { Building2 } from 'lucide-react';
import { useBranch } from './branch';
import { useMe } from './auth';
import { SelectMenu } from '../ui/SelectMenu';
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
      <span className={cn('glass relative flex h-9 items-center rounded-md text-sm text-fg-2 focus-within:border-accent', className)}>
        <Building2 className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
        <SelectMenu
          value={b.view}
          onChange={(e) => b.setView(e.target.value)}
          aria-label={t('branch.switcher')}
          searchOver={6}
          className="h-9 max-w-[38vw] rounded-md bg-transparent pe-7 ps-8 text-sm text-fg focus:outline-none sm:max-w-[260px]"
          data-testid="branch-switcher"
        >
          {owner && (
            <option value="all" data-divider="true">
              {t('branch.all')}
            </option>
          )}
          {b.mine.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name}
            </option>
          ))}
        </SelectMenu>
      </span>
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
