import { Fragment, forwardRef, useImperativeHandle, useRef, useState, type KeyboardEvent, type SelectHTMLAttributes } from 'react';
import { useTranslation } from 'react-i18next';
import * as Menu from '@radix-ui/react-dropdown-menu';
import { Check, ChevronDown } from 'lucide-react';
import { cn } from './cn';

type Opt = { value: string; text: string; disabled: boolean; group: string; divider: boolean };
export type SelectMenuProps = SelectHTMLAttributes<HTMLSelectElement> & {
  /** خانة بحث جوه القايمة لو الاختيارات أكتر من العدد ده */
  searchOver?: number;
  wrapClassName?: string;
};

const readOptions = (s: HTMLSelectElement): Opt[] =>
  [...s.options].map((o) => ({
    value: o.value,
    text: o.text,
    disabled: o.disabled,
    group: o.parentElement instanceof HTMLOptGroupElement ? o.parentElement.label : '',
    divider: o.dataset.divider === 'true',
  }));

/**
 * قايمة الاختيار بشكل التطبيق في كل الشاشات. الـ select الأصلي فاضل (القيمة والعنوان وقارئ الشاشة والفورم)،
 * والقايمة نفسها Radix بألوان الثيم بدل قايمة المتصفح، وعلى الموبايل بتفتح من تحت.
 * `data-divider` على option = خط بعده.
 */
export const SelectMenu = forwardRef<HTMLSelectElement, SelectMenuProps>(function SelectMenu({ className, wrapClassName, searchOver = Infinity, children, onKeyDown, ...rest }, ref) {
  const { t, i18n } = useTranslation();
  const sel = useRef<HTMLSelectElement>(null);
  useImperativeHandle(ref, () => sel.current!);
  const [opts, setOpts] = useState<Opt[] | null>(null);
  const [q, setQ] = useState('');
  const close = () => {
    setOpts(null);
    setQ('');
  };
  const open = () => {
    const s = sel.current!;
    if (s.matches(':disabled')) return;
    setOpts(readOptions(s));
  };
  const pick = (v: string) => {
    const s = sel.current!;
    if (s.value === v) return;
    s.value = v;
    s.dispatchEvent(new Event('change', { bubbles: true }));
  };
  const keys = (e: KeyboardEvent<HTMLSelectElement>) => {
    onKeyDown?.(e);
    if (e.defaultPrevented || e.ctrlKey || e.metaKey || !['Enter', ' ', 'ArrowDown', 'ArrowUp', 'F4'].includes(e.key)) return;
    e.preventDefault();
    open();
  };
  const searchable = !!opts && opts.length > searchOver;
  const needle = q.trim().toLowerCase();
  const shown = (opts ?? []).filter((o) => !needle || o.text.toLowerCase().includes(needle));
  return (
    <Menu.Root open={!!opts} onOpenChange={(v) => !v && close()} dir={i18n.dir() as 'rtl' | 'ltr'}>
      <div className={cn('relative cursor-pointer', wrapClassName ?? 'inline-block max-w-full')} title={rest.title} onClick={open}>
        <Menu.Trigger asChild disabled>
          <span className="pointer-events-none absolute inset-0" aria-hidden />
        </Menu.Trigger>
        {/* اللمسة والضغطة للغلاف، فقايمة المتصفح ما بتفتحش */}
        <select ref={sel} className={cn('pointer-events-none appearance-none truncate', className)} onKeyDown={keys} {...rest}>
          {children}
        </select>
        <ChevronDown className="pointer-events-none absolute end-2 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
      </div>
      <Menu.Portal>
        <Menu.Content
          align="start"
          sideOffset={4}
          collisionPadding={8}
          // الضغطة جوه القايمة ما توصلش للغلاف (React بيطلّع الأحداث من الـ Portal)
          onClick={(e) => e.stopPropagation()}
          onCloseAutoFocus={(e) => {
            e.preventDefault();
            sel.current?.focus();
          }}
          ref={(el: HTMLDivElement | null) => {
            if (!el || el.dataset.ready) return;
            el.dataset.ready = '1';
            // على اللمس: من غير تركيز على البحث عشان الكيبورد ما يفتحش لوحده
            const search = window.matchMedia('(pointer: fine)').matches ? el.querySelector<HTMLElement>('[data-select-search]') : null;
            requestAnimationFrame(() => (search ?? el.querySelector<HTMLElement>('[data-state=checked]'))?.focus());
          }}
          aria-label={rest['aria-label'] ?? sel.current?.labels?.[0]?.textContent ?? undefined}
          className="select-menu z-[70] max-h-[min(60dvh,var(--radix-dropdown-menu-content-available-height))] min-w-[var(--radix-dropdown-menu-trigger-width)] max-w-[92vw] overflow-y-auto rounded-md border border-line-strong bg-overlay p-1 text-fg shadow-2"
          data-testid={rest['data-testid' as keyof typeof rest] ? `${String(rest['data-testid' as keyof typeof rest])}-menu` : 'select-menu'}
        >
          {searchable && (
            <input
              data-select-search
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  e.currentTarget.parentElement?.querySelector<HTMLElement>('[role=menuitemradio]')?.focus();
                }
                // الكتابة ما تتاخدش كبحث سريع من القايمة
                if (e.key !== 'Escape') e.stopPropagation();
              }}
              placeholder={t('nav.search')}
              aria-label={t('nav.search')}
              className="mb-1 h-11 w-full rounded-sm border border-line bg-sunken px-2.5 text-base text-fg placeholder:text-fg-3 focus:border-accent focus:outline-none sm:h-9"
            />
          )}
          <Menu.RadioGroup value={sel.current?.value ?? ''} onValueChange={pick}>
            {shown.map((o, i) => (
              <Fragment key={`${o.value}-${i}`}>
                {o.group && o.group !== shown[i - 1]?.group && <Menu.Label className="px-2.5 py-1 text-xs text-fg-3">{o.group}</Menu.Label>}
                <Menu.RadioItem
                  value={o.value}
                  disabled={o.disabled}
                  className="flex min-h-11 cursor-pointer select-none items-center gap-2 rounded-sm px-2.5 text-base text-fg outline-none data-[disabled]:cursor-default data-[highlighted]:bg-accent-soft data-[state=checked]:font-semibold data-[disabled]:opacity-50 sm:min-h-8 sm:text-sm"
                >
                  <span className="flex size-4 shrink-0 items-center">
                    <Menu.ItemIndicator>
                      <Check className="size-4 text-accent" aria-hidden />
                    </Menu.ItemIndicator>
                  </span>
                  <span className="min-w-0 break-words">{o.text}</span>
                </Menu.RadioItem>
                {o.divider && !needle && <Menu.Separator className="my-1 h-px bg-line" />}
              </Fragment>
            ))}
          </Menu.RadioGroup>
          {!shown.length && <p className="px-2.5 py-2 text-sm text-fg-3">{t('lists.noMatch')}</p>}
        </Menu.Content>
      </Menu.Portal>
    </Menu.Root>
  );
});
