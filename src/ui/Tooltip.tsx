import * as RT from '@radix-ui/react-tooltip';
import type { ReactNode } from 'react';
import { Kbd } from './Kbd';

export const TooltipProvider = ({ children }: { children: ReactNode }) => (
  <RT.Provider delayDuration={350} skipDelayDuration={150}>
    {children}
  </RT.Provider>
);

export function Tip({ label, shortcut, children, side = 'bottom' }: { label: ReactNode; shortcut?: string; children: ReactNode; side?: 'top' | 'bottom' | 'left' | 'right' }) {
  return (
    <RT.Root>
      <RT.Trigger asChild>{children}</RT.Trigger>
      <RT.Portal>
        <RT.Content
          side={side}
          sideOffset={6}
          className="z-50 flex items-center gap-2 rounded-sm border border-line-strong bg-overlay px-2 py-1 text-xs text-fg shadow-2 data-[state=delayed-open]:animate-[fade-in_140ms_ease-out] data-[state=instant-open]:animate-[fade-in_100ms_ease-out]"
        >
          {label}
          {shortcut && <Kbd>{shortcut}</Kbd>}
        </RT.Content>
      </RT.Portal>
    </RT.Root>
  );
}
