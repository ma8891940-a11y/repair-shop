import type { ReactNode } from 'react';
import { cn } from './cn';

export function Kbd({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <kbd
      dir="ltr"
      className={cn(
        'num inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-xs border border-line-strong bg-sunken px-1 text-2xs text-fg-2',
        className,
      )}
    >
      {children}
    </kbd>
  );
}
