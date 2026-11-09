import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from './cn';
import { Tip } from './Tooltip';
import { useOnline } from './useOnline';
import { useTranslation } from 'react-i18next';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'outline';
type Size = 'sm' | 'md' | 'lg' | 'icon';

const variants: Record<Variant, string> = {
  primary:
    'bg-accent text-on-accent font-semibold hover:bg-accent-hover shadow-[0_0_0_1px_rgb(var(--accent-rgb)/0.6),0_8px_24px_-8px_var(--accent-glow),inset_0_1px_0_rgb(255_255_255/0.25)]',
  secondary: 'glass text-fg hover:border-glass-border-strong hover:bg-raised',
  outline: 'bg-transparent text-fg border border-line-strong hover:border-accent hover:text-accent',
  ghost: 'bg-transparent text-fg-2 hover:bg-raised/70 hover:text-fg',
  danger: 'bg-danger-soft text-danger border border-[color-mix(in_srgb,var(--danger)_40%,transparent)] hover:bg-[color-mix(in_srgb,var(--danger)_18%,transparent)]',
};

const sizes: Record<Size, string> = {
  sm: 'h-7 px-2.5 text-sm gap-1.5 rounded-sm',
  md: 'h-9 px-3.5 text-base gap-2 rounded-md',
  lg: 'h-11 px-5 text-md gap-2 rounded-md',
  icon: 'h-9 w-9 justify-center rounded-md',
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  icon?: ReactNode;
  shortcut?: string;
  tip?: string;
  /** البند 14: العملية دي محتاجة نت: من غير نت الزرار بيتقفل بهدوء ومعاه السبب، وبيتفتح لوحده لما النت يرجع */
  needsNet?: boolean;
}

/** زرار برد فعل ضغط (بيصغر شوية) وتوهج للزرار الأساسي */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'secondary', size = 'md', loading, icon, shortcut, tip, className, children, disabled, type = 'button', needsNet, ...rest },
  ref,
) {
  const online = useOnline();
  const { t } = useTranslation();
  const offline = !!needsNet && !online;
  if (offline) tip = t('offline.needsNet');
  const btn = (
    <button
      ref={ref}
      type={type}
      data-variant={variant}
      data-offline={offline || undefined}
      disabled={disabled || loading || offline}
      aria-busy={loading || undefined}
      className={cn(
        'relative inline-flex select-none items-center whitespace-nowrap transition-[background-color,border-color,color,transform] duration-150 ease-out',
        'active:scale-[0.97] disabled:pointer-events-none disabled:opacity-50',
        variants[variant],
        sizes[size],
        className,
      )}
      {...rest}
    >
      {loading ? <Loader2 className="size-4 animate-spin" aria-hidden /> : icon}
      {children}
    </button>
  );
  // الزرار المقفول ما بيستقبلش hover، فالسبب على العنصر اللي حواليه
  if (offline)
    return (
      <span className="inline-flex" title={tip} data-testid="needs-net">
        {btn}
      </span>
    );
  if (!shortcut && !tip) return btn;
  return (
    <Tip label={tip ?? (typeof children === 'string' ? children : '')} shortcut={shortcut}>
      {btn}
    </Tip>
  );
});
