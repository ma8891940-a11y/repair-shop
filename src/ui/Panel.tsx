import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from './cn';

/** لوح زجاجي (المستوى التاني). elevated = المستوى التالت (لوح مرفوع) */
export function Panel({ className, elevated, glow, ...rest }: HTMLAttributes<HTMLDivElement> & { elevated?: boolean; glow?: boolean }) {
  return <div className={cn('relative rounded-lg', elevated ? 'glass-strong' : 'glass', glow && 'edge-glow', className)} {...rest} />;
}

export function PanelHeader({ title, index, actions, className }: { title: ReactNode; index?: string; actions?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex items-center justify-between gap-3 border-b border-glass-border px-4 py-3', className)}>
      <div className="flex min-w-0 items-center gap-2.5">
        {index && (
          <span className="num grid h-5 min-w-7 place-items-center rounded-xs border border-[rgb(var(--accent-rgb)/0.3)] bg-accent-soft px-1 text-2xs text-accent">
            {index}
          </span>
        )}
        <h2 className="truncate text-sm font-semibold text-fg">{title}</h2>
      </div>
      {actions}
    </div>
  );
}
