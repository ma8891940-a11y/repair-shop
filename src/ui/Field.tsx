import {
  cloneElement,
  forwardRef,
  isValidElement,
  useId,
  type InputHTMLAttributes,
  type ReactElement,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react';
import { ChevronDown } from 'lucide-react';
import { cn } from './cn';

const control =
  'w-full rounded-md border border-line bg-sunken/60 text-fg transition-[border-color,box-shadow,background-color] duration-150 ' +
  'hover:border-line-strong focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)] ' +
  'aria-[invalid=true]:border-danger aria-[invalid=true]:shadow-[0_0_0_3px_var(--danger-soft)] disabled:opacity-60';

type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  mono?: boolean;
  /** كلمة صغيرة جوه الحقل في آخره (مثل "ج.م") */
  suffix?: ReactNode;
  /** عنصر قبل الحقل في نفس السطر (مثل اختيار نوع القفل) */
  leading?: ReactNode;
};

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input({ className, mono, suffix, leading, ...rest }, ref) {
  // الوحدة (ج.م) بتتحط في بداية السطر العربي (يمين)، والرقم اتجاهه LTR فبيبدأ من الشمال، فما يتداخلوش
  const input = <input ref={ref} className={cn(control, 'h-9 px-3 text-base', mono && 'num', suffix ? 'ps-12' : '', className)} {...rest} />;
  const withSuffix = suffix ? (
    <div className="relative min-w-0">
      {input}
      <span className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-sm text-fg-3">{suffix}</span>
    </div>
  ) : (
    input
  );
  if (!leading) return withSuffix;
  return (
    <div className="flex min-w-0 gap-2">
      {leading}
      <div className="min-w-0 flex-1">{withSuffix}</div>
    </div>
  );
});

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(function Textarea(
  { className, rows = 3, ...rest },
  ref,
) {
  return <textarea ref={ref} rows={rows} className={cn(control, 'resize-y px-3 py-2 text-base', className)} {...rest} />;
});

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function Select(
  { className, children, ...rest },
  ref,
) {
  return (
    <div className="relative">
      <select ref={ref} className={cn(control, 'h-9 appearance-none pe-8 ps-3 text-base', className)} {...rest}>
        {children}
      </select>
      <ChevronDown className="pointer-events-none absolute end-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
    </div>
  );
});

interface FieldProps {
  label: ReactNode;
  hint?: ReactNode;
  error?: string | null;
  required?: boolean;
  className?: string;
  /** عنصر واحد (Input/Textarea/Select) بياخد id وaria تلقائيًا */
  children: ReactElement<{ id?: string; 'aria-invalid'?: boolean; 'aria-describedby'?: string; required?: boolean }>;
  aside?: ReactNode;
}

/** حقل كامل: عنوان + الحقل + تلميح أو خطأ، ومربوطين ببعض لقارئ الشاشة */
export function Field({ label, hint, error, required, className, children, aside }: FieldProps) {
  const autoId = useId();
  const id = (isValidElement(children) && children.props.id) || autoId;
  const descId = `${id}-desc`;
  const child = isValidElement(children)
    ? cloneElement(children, {
        id,
        required,
        'aria-invalid': error ? true : undefined,
        'aria-describedby': hint || error ? descId : undefined,
      })
    : children;
  return (
    <div className={cn('flex min-w-0 flex-col gap-1', className)}>
      <div className="flex items-baseline justify-between gap-2">
        <label htmlFor={id} className="text-sm font-medium text-fg-2">
          {label}
          {required && <span className="ms-0.5 text-accent" aria-hidden>*</span>}
        </label>
        {aside}
      </div>
      {child}
      {(error || hint) && (
        <p id={descId} className={cn('text-xs', error ? 'text-danger' : 'text-fg-3')} role={error ? 'alert' : undefined}>
          {error || hint}
        </p>
      )}
    </div>
  );
}
