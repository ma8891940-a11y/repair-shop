import * as RD from '@radix-ui/react-dialog';
import { X } from 'lucide-react';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from './cn';

/** لوح جانبي (تفاصيل من غير ما تسيب الشاشة): بيطلع من آخر السطر، وعلى الموبايل بياخد الشاشة كلها */
export function Sheet({ open, onOpenChange, title, description, actions, children, testid }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  children?: ReactNode;
  testid?: string;
}) {
  const { t, i18n } = useTranslation();
  return (
    <RD.Root open={open} onOpenChange={onOpenChange}>
      <RD.Portal>
        <RD.Overlay className="fixed inset-0 z-40 bg-[rgb(4_8_10/0.45)] backdrop-blur-[2px] data-[state=open]:animate-[fade-in_160ms_ease-out]" />
        <RD.Content
          dir={i18n.dir()}
          data-testid={testid}
          className={cn(
            'glass-strong fixed inset-y-0 end-0 z-50 flex w-full flex-col rounded-none border-y-0 border-e-0 focus:outline-none sm:w-[min(92vw,560px)]',
            'data-[state=open]:animate-[sheet-in_220ms_cubic-bezier(0.2,0.8,0.2,1)]',
          )}
        >
          <div className="flex shrink-0 items-start justify-between gap-3 border-b border-glass-border px-5 py-4">
            <div className="min-w-0">
              <RD.Title className="text-md font-semibold text-fg">{title}</RD.Title>
              {description && <RD.Description className="mt-1 text-sm text-fg-3">{description}</RD.Description>}
            </div>
            <div className="flex shrink-0 items-center gap-1">
              {actions}
              <RD.Close className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-fg" aria-label={t('common.close')}>
                <X className="size-4" />
              </RD.Close>
            </div>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
        </RD.Content>
      </RD.Portal>
    </RD.Root>
  );
}
