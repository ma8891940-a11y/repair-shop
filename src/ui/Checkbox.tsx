import * as RC from '@radix-ui/react-checkbox';
import { Check } from 'lucide-react';
import { useId, type ReactNode } from 'react';
import { cn } from './cn';

export function Checkbox({ checked, onChange, label, className }: { checked: boolean; onChange: (v: boolean) => void; label: ReactNode; className?: string }) {
  const id = useId();
  return (
    <div className={cn('flex items-center gap-2', className)}>
      <RC.Root
        id={id}
        checked={checked}
        onCheckedChange={(v) => onChange(v === true)}
        className="grid size-4 place-items-center rounded-xs border border-line-strong bg-sunken transition-colors data-[state=checked]:border-accent data-[state=checked]:bg-accent"
      >
        <RC.Indicator>
          <Check className="size-3 text-on-accent" strokeWidth={3} />
        </RC.Indicator>
      </RC.Root>
      <label htmlFor={id} className="cursor-pointer text-sm text-fg">
        {label}
      </label>
    </div>
  );
}

/** زرار شكل "شريحة" بيتفعّل ويتقفل (للملحقات وأي اختيارات متعددة سريعة) */
export function ChipToggle({ pressed, onChange, children }: { pressed: boolean; onChange: (v: boolean) => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-pressed={pressed}
      onClick={() => onChange(!pressed)}
      className={cn(
        'inline-flex h-7 items-center gap-1.5 rounded-full border px-3 text-sm transition-[background-color,border-color,color] duration-150',
        pressed
          ? 'border-accent bg-accent-soft text-fg'
          : 'border-line bg-transparent text-fg-2 hover:border-line-strong hover:text-fg',
      )}
    >
      <span className={cn('size-1.5 rounded-full transition-colors', pressed ? 'bg-accent' : 'bg-line-strong')} aria-hidden />
      {children}
    </button>
  );
}
