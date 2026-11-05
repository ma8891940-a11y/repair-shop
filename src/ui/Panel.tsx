import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from './cn';

/** اللوح الأساسي: سطح جرافيت بحافة رفيعة ولمعة خفيفة من فوق */
export function Panel({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('rounded-lg border border-line bg-surface shadow-1', className)} {...rest} />;
}

export function PanelHeader({
  title,
  index,
  actions,
  className,
}: {
  title: ReactNode;
  /** رقم القسم الصغير (01، 02...) زي لوحات الأجهزة */
  index?: string;
  actions?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('flex items-center justify-between gap-3 border-b border-line px-4 py-2.5', className)}>
      <div className="flex items-center gap-2.5">
        {index && <span className="num text-2xs text-accent">{index}</span>}
        <h2 className="text-sm font-semibold text-fg">{title}</h2>
      </div>
      {actions}
    </div>
  );
}

export function PanelBody({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-4', className)} {...rest} />;
}
