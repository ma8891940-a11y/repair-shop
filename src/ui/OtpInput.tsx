import { useRef, type ClipboardEvent, type KeyboardEvent } from 'react';
import { motion } from 'motion/react';
import { toLatinDigits } from '../lib/digits';
import { cn } from './cn';

/**
 * كود من 6 خانات: بيقفز للخانة اللي بعدها تلقائيًا، وBackspace بيرجع، والأسهم بتتنقل،
 * ولصق الكود كله مرة واحدة بيملا الخانات. الأرقام العربية بتتحول لإنجليزي.
 */
export function OtpInput({ value, onChange, length = 6, invalid, disabled, label }: { value: string; onChange: (v: string) => void; length?: number; invalid?: boolean; disabled?: boolean; label: string }) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const digits = Array.from({ length }, (_, i) => value[i] ?? '');

  const setAt = (i: number, d: string) => {
    const arr = digits.slice();
    arr[i] = d;
    onChange(arr.join('').slice(0, length));
  };
  const focus = (i: number) => refs.current[Math.max(0, Math.min(length - 1, i))]?.focus();

  const onPaste = (e: ClipboardEvent<HTMLInputElement>) => {
    const text = toLatinDigits(e.clipboardData.getData('text')).replace(/\D/g, '').slice(0, length);
    if (!text) return;
    e.preventDefault();
    onChange(text);
    focus(text.length >= length ? length - 1 : text.length);
  };

  const onKey = (i: number, e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !digits[i]) {
      e.preventDefault();
      setAt(Math.max(0, i - 1), '');
      focus(i - 1);
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      focus(i - 1);
    } else if (e.key === 'ArrowRight') {
      e.preventDefault();
      focus(i + 1);
    }
  };

  return (
    <motion.div
      role="group"
      aria-label={label}
      dir="ltr"
      className="flex justify-center gap-2"
      animate={invalid ? { x: [0, -7, 7, -5, 5, -2, 0] } : { x: 0 }}
      transition={{ duration: 0.36 }}
    >
      {digits.map((d, i) => (
        <input
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          value={d}
          disabled={disabled}
          inputMode="numeric"
          autoComplete={i === 0 ? 'one-time-code' : 'off'}
          aria-label={`${label} ${i + 1}`}
          maxLength={length}
          onPaste={onPaste}
          onKeyDown={(e) => onKey(i, e)}
          onFocus={(e) => e.target.select()}
          onChange={(e) => {
            const v = toLatinDigits(e.target.value).replace(/\D/g, '');
            if (v.length > 1) {
              // لصق أو إكمال تلقائي من الموبايل
              onChange((digits.slice(0, i).join('') + v).slice(0, length));
              focus(i + v.length);
              return;
            }
            setAt(i, v);
            if (v) focus(i + 1);
          }}
          className={cn(
            'num size-12 rounded-md border bg-sunken/70 text-center text-xl text-fg transition-[border-color,box-shadow] duration-150 focus:outline-none sm:size-14',
            d ? 'border-[rgb(var(--accent-rgb)/0.5)]' : 'border-line',
            'focus:border-accent focus:shadow-[0_0_0_3px_var(--accent-soft),0_0_18px_-4px_var(--accent-glow)]',
            invalid && 'border-danger',
          )}
        />
      ))}
    </motion.div>
  );
}
