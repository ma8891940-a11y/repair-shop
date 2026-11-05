import * as RD from '@radix-ui/react-dialog';
import { X } from 'lucide-react';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from './cn';

/** نافذة (المستوى الرابع): زجاج قوي فوق خلفية مغبّشة */
export function Dialog({ open, onOpenChange, title, description, children, footer, className }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: ReactNode;
  description?: ReactNode;
  children?: ReactNode;
  footer?: ReactNode;
  className?: string;
}) {
  const { t, i18n } = useTranslation();
  return (
    <RD.Root open={open} onOpenChange={onOpenChange}>
      <RD.Portal>
        <RD.Overlay className="fixed inset-0 z-40 bg-[rgb(4_8_10/0.55)] backdrop-blur-[3px] data-[state=open]:animate-[fade-in_160ms_ease-out]" />
        <RD.Content
          dir={i18n.dir()}
          className={cn(
            'glass-strong fixed left-1/2 top-1/2 z-50 w-[min(92vw,460px)] -translate-x-1/2 -translate-y-1/2 rounded-xl focus:outline-none',
            'data-[state=open]:animate-[pop-in_200ms_cubic-bezier(0.2,0.8,0.2,1)]',
            className,
          )}
        >
          <div className="flex items-start justify-between gap-4 border-b border-glass-border px-5 py-4">
            <div>
              <RD.Title className="text-md font-semibold text-fg">{title}</RD.Title>
              {description && <RD.Description className="mt-1 text-sm text-fg-3">{description}</RD.Description>}
            </div>
            <RD.Close className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-fg" aria-label={t('common.close')}>
              <X className="size-4" />
            </RD.Close>
          </div>
          {children && <div className="px-5 py-4">{children}</div>}
          {footer && <div className="flex justify-end gap-2 border-t border-glass-border px-5 py-3">{footer}</div>}
        </RD.Content>
      </RD.Portal>
    </RD.Root>
  );
}
