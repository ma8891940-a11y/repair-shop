import * as RD from '@radix-ui/react-dialog';
import { X } from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from './cn';

/** نافذة (المستوى الرابع): زجاج قوي فوق خلفية مغبّشة */
export function Dialog({ open, onOpenChange, title, description, children, footer, className, guard = true }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: ReactNode;
  description?: ReactNode;
  children?: ReactNode;
  footer?: ReactNode;
  className?: string;
  /** البند 9: لو المستخدم كتب حاجة وداس Esc أو برّا النافذة أو ×، بيتسأل الأول (زرار "إلغاء" والحفظ بيقفلوا عادي) */
  guard?: boolean;
}) {
  const { t, i18n } = useTranslation();
  const [dirty, setDirty] = useState(false);
  const [asking, setAsking] = useState(false);
  useEffect(() => {
    setDirty(false);
    setAsking(false);
  }, [open]);
  const change = (v: boolean) => {
    if (!v && guard && dirty) return setAsking(true);
    onOpenChange(v);
  };
  return (
    <RD.Root open={open} onOpenChange={change}>
      <RD.Portal>
        <RD.Overlay className="fixed inset-0 z-40 bg-[rgb(4_8_10/0.55)] backdrop-blur-[3px] data-[state=open]:animate-[fade-in_160ms_ease-out]" />
        <RD.Content
          dir={i18n.dir()}
          // الخانات اللي بتتحفظ لوحدها (data-autosave، زي "رقم محفوظ") ما بتعتبرش بيانات مش محفوظة
          onInputCapture={(e) => guard && !(e.target as HTMLElement).closest?.('[data-autosave]') && setDirty(true)}
          className={cn(
            // مش أطول من الشاشة: العنوان والأزرار ثابتين، والمحتوى بيعمل scroll (مهم على الموبايل والفورمات الطويلة)
            'glass-strong fixed left-1/2 top-1/2 z-50 flex max-h-[calc(100dvh-1.5rem)] w-[min(92vw,460px)] -translate-x-1/2 -translate-y-1/2 flex-col rounded-xl focus:outline-none',
            'data-[state=open]:animate-[pop-in_200ms_cubic-bezier(0.2,0.8,0.2,1)]',
            className,
          )}
        >
          <div className="flex shrink-0 items-start justify-between gap-4 border-b border-glass-border px-5 py-4">
            <div>
              <RD.Title className="text-md font-semibold text-fg">{title}</RD.Title>
              {description && <RD.Description className="mt-1 text-sm text-fg-3">{description}</RD.Description>}
            </div>
            <RD.Close className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-fg" aria-label={t('common.close')}>
              <X className="size-4" />
            </RD.Close>
          </div>
          {children && <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>}
          {asking && (
            <div role="alertdialog" aria-live="assertive" className="flex shrink-0 flex-wrap items-center justify-between gap-2 border-t border-[color-mix(in_srgb,var(--warn)_40%,transparent)] bg-warn-soft px-5 py-2.5 text-sm text-fg" data-testid="dialog-unsaved">
              <span>{t('leave.dialog')}</span>
              <span className="flex gap-2">
                <button type="button" autoFocus onClick={() => setAsking(false)} className="h-8 rounded-md bg-accent px-3 text-sm font-semibold text-on-accent" data-testid="dialog-unsaved-stay">
                  {t('leave.stay')}
                </button>
                <button type="button" onClick={() => onOpenChange(false)} className="h-8 rounded-md border border-line-strong px-3 text-sm text-fg-2 hover:text-danger" data-testid="dialog-unsaved-close">
                  {t('leave.closeAnyway')}
                </button>
              </span>
            </div>
          )}
          {footer && <div className="flex shrink-0 justify-end gap-2 border-t border-glass-border px-5 py-3">{footer}</div>}
        </RD.Content>
      </RD.Portal>
    </RD.Root>
  );
}
