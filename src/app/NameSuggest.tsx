import { useLayoutEffect, useMemo, useRef, useState, type ClipboardEvent, type KeyboardEvent } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { searchItems } from '../lib/itemSearch';
import type { StockRow } from './ledgerApi';
import { useFormat } from '../i18n/format';
import { cn } from '../ui/cn';

/**
 * خانة اسم الصنف في جدول الجرد: الكتابة واللصق والتنقل زي Excel بيفضلوا زي ما هم،
 * وتحتها اقتراحات من الأصناف الموجودة وانت بتكتب (نفس البحث: جزء من الكلمة، عربي أو إنجليزي).
 * السهم لتحت بيدخل في الاقتراحات لو ظاهرة، وEnter بيختار، وEsc بيقفلها والأسهم ترجع تتنقل في الجدول.
 */
export function NameSuggest({ items, value, onChange, onPick, onKeyDown, onPaste, cell, label, className }: {
  items: StockRow[];
  value: string;
  onChange: (v: string) => void;
  onPick: (it: StockRow) => void;
  onKeyDown: (e: KeyboardEvent<HTMLInputElement>) => void;
  onPaste: (e: ClipboardEvent<HTMLInputElement>) => void;
  cell: string;
  label: string;
  className?: string;
}) {
  const { t } = useTranslation();
  const f = useFormat();
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const box = useRef<HTMLInputElement | null>(null);
  const shown = useMemo(() => (value.trim() ? searchItems(items, value, 8).filter((i) => i.name !== value.trim()) : []), [items, value]);
  const visible = open && shown.length > 0;
  const [pos, setPos] = useState<{ top: number; left: number; width: number } | null>(null);
  useLayoutEffect(() => {
    if (!visible) return;
    const r = box.current?.getBoundingClientRect();
    if (r) setPos({ top: r.bottom + 2, left: r.left, width: Math.max(r.width, 260) });
  }, [visible, value]);
  const pick = (it: StockRow) => {
    onPick(it);
    setOpen(false);
    setActive(-1);
  };
  return (
    <>
      <input
        ref={box}
        data-cell={cell}
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
          setActive(-1);
        }}
        onBlur={() => setOpen(false)}
        onKeyDown={(e) => {
          if (visible) {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              return setActive((a) => Math.min(a + 1, shown.length - 1));
            }
            if (e.key === 'ArrowUp' && active >= 0) {
              e.preventDefault();
              return setActive((a) => a - 1);
            }
            if (e.key === 'Enter' && active >= 0) {
              e.preventDefault();
              return pick(shown[active]);
            }
            if (e.key === 'Escape') {
              e.preventDefault();
              e.stopPropagation();
              return setOpen(false);
            }
          }
          onKeyDown(e);
        }}
        onPaste={onPaste}
        aria-label={label}
        aria-autocomplete="list"
        autoComplete="off"
        className={className}
      />
      {visible &&
        pos &&
        createPortal(
          <ul
            role="listbox"
            onMouseDown={(e) => e.preventDefault()}
            style={{ position: 'fixed', top: pos.top, left: pos.left, width: pos.width }}
            dir={document.documentElement.dir || 'rtl'}
            className="glass-strong z-[60] max-h-60 overflow-y-auto rounded-md p-1 text-sm shadow-2"
            data-testid="name-suggest"
          >
            {shown.map((it, k) => (
              <li key={it.id} role="option" aria-selected={active === k}>
                <button type="button" tabIndex={-1} onClick={() => pick(it)} className={cn('flex w-full items-center gap-2 rounded-sm px-2 py-1 text-start hover:bg-raised/60', active === k && 'bg-accent-soft')}>
                  <span className="min-w-0 flex-1 truncate text-fg">
                    <bdi>{it.name}</bdi>
                  </span>
                  <span className="num text-2xs text-fg-3">{t('picker.qty', { n: f.number(it.qty) })}</span>
                </button>
              </li>
            ))}
          </ul>,
          document.body,
        )}
    </>
  );
}
