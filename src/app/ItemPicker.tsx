import { useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { PackagePlus, Search } from 'lucide-react';
import { byCode, searchItems } from '../lib/itemSearch';
import type { StockRow } from './ledgerApi';
import { useFormat } from '../i18n/format';
import { cn } from '../ui/cn';

/**
 * خانة الصنف (البيع، والشراء، والمرتجعات، والهالك، والجرد، وقطع الجهاز):
 * - بتكتب والنتايج بتظهر وانت بتكتب: بالاسم أو النوع أو الماركة أو الموديل أو الجودة أو الباركود، ولو جزء من الكلمة، وبالعربي أو الإنجليزي.
 * - كل نتيجة جنبها الكمية المتاحة وسعر البيع. الأسهم وEnter للاختيار، والباركود (القارئ بيكتب ويدوس Enter) بيختار على طول.
 * - لو مش موجود: "إضافة صنف جديد «...»" (onCreate) بيفتح فورم صغير في نفس النافذة.
 */
export function ItemPicker({ items, value, onPick, onCreate, createDenied = false, onlyInStock = false, showPrice = true, label, testid = 'item-picker', autoFocus, className }: {
  items: StockRow[];
  value: string;
  onPick: (item: StockRow) => void;
  onCreate?: (typed: string) => void;
  /** الموظف مالوش "إضافة صنف جديد": لو مفيش نتايج بيظهرله يطلب من صاحب المحل */
  createDenied?: boolean;
  onlyInStock?: boolean;
  showPrice?: boolean;
  label?: string;
  testid?: string;
  autoFocus?: boolean;
  className?: string;
}) {
  const { t } = useTranslation();
  const f = useFormat();
  const picked = items.find((i) => i.id === value) ?? null;
  const [q, setQ] = useState(picked?.name ?? '');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const menuId = useId();
  const box = useRef<HTMLDivElement | null>(null);
  const input = useRef<HTMLInputElement | null>(null);
  // لو الاختيار اتغير من برّه (اختيار سطر، أو صنف جديد اتعمل): الخانة بتكتب اسمه
  useEffect(() => {
    if (picked) setQ(picked.name);
    else if (!value) setQ('');
  }, [picked?.id, picked?.name, value]); // eslint-disable-line react-hooks/exhaustive-deps

  const typing = !picked || q !== picked.name;
  const shown = useMemo(() => searchItems(items, typing ? q : '', 30), [items, q, typing]);
  const canCreate = !!onCreate && typing && q.trim().length > 0;
  const count = shown.length + (canCreate ? 1 : 0);
  useEffect(() => setActive(0), [q, open]);

  const choose = (it: StockRow) => {
    if (onlyInStock && it.qty <= 0) return;
    onPick(it);
    setQ(it.name);
    setOpen(false);
  };

  // القايمة فوق الصفحة (أو جوه النافذة) عشان ما تتقصش
  const [host, setHost] = useState<HTMLElement | null>(null);
  const [pos, setPos] = useState<{ top: number; left: number; width: number } | null>(null);
  useLayoutEffect(() => {
    if (!open) return;
    const place = () => {
      const r = box.current?.getBoundingClientRect();
      if (!r) return;
      const h = (box.current?.closest('[role="dialog"]') as HTMLElement | null) ?? document.body;
      const o = h === document.body ? { top: 0, left: 0 } : h.getBoundingClientRect();
      setHost(h);
      const next = { top: Math.round(r.bottom + 4 - o.top), left: Math.round(r.left - o.left), width: Math.round(Math.max(r.width, 280)) };
      setPos((c) => (c && c.top === next.top && c.left === next.left && c.width === next.width ? c : next));
    };
    place();
    window.addEventListener('scroll', place, true);
    window.addEventListener('resize', place);
    return () => {
      window.removeEventListener('scroll', place, true);
      window.removeEventListener('resize', place);
    };
  }, [open]);

  return (
    <div ref={box} className={cn('relative', className)} onBlur={() => setOpen(false)}>
      <Search className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
      <input
        ref={input}
        autoFocus={autoFocus}
        value={q}
        onChange={(e) => {
          setQ(e.target.value);
          setOpen(true);
        }}
        onFocus={(e) => {
          setOpen(true);
          e.currentTarget.select();
        }}
        onKeyDown={(e) => {
          if (e.key === 'ArrowDown') {
            e.preventDefault();
            setOpen(true);
            return setActive((a) => (count ? (a + 1) % count : 0));
          }
          if (e.key === 'ArrowUp') {
            e.preventDefault();
            return setActive((a) => (count ? (a <= 0 ? count - 1 : a - 1) : 0));
          }
          if (e.key === 'Escape' && open) {
            e.preventDefault();
            e.stopPropagation();
            return setOpen(false);
          }
          if (e.key === 'Enter' && (open || typing)) {
            // الباركود بالظبط: يختار على طول
            const hit = byCode(items, q);
            if (hit) {
              e.preventDefault();
              return choose(hit);
            }
            if (!open || !count) return;
            e.preventDefault();
            if (active < shown.length) return choose(shown[active]);
            if (canCreate) {
              setOpen(false);
              return onCreate!(q.trim());
            }
          }
        }}
        role="combobox"
        aria-label={label ?? t('inv.cols.name')}
        aria-expanded={open}
        aria-controls={menuId}
        aria-autocomplete="list"
        aria-activedescendant={open && count ? `${menuId}-${active}` : undefined}
        autoComplete="off"
        placeholder={t('picker.placeholder')}
        className="h-9 w-full rounded-md border border-line bg-sunken/60 pe-3 ps-9 text-base text-fg placeholder:text-fg-3 focus:border-accent focus:bg-sunken focus:outline-none focus:shadow-[0_0_0_3px_var(--accent-soft)]"
        data-testid={testid}
      />
      {open &&
        pos &&
        host &&
        (count > 0 || q.trim()) &&
        createPortal(
          <ul
            id={menuId}
            role="listbox"
            onMouseDown={(e) => e.preventDefault()}
            style={{ position: 'fixed', top: pos.top, left: pos.left, width: pos.width }}
            dir={document.documentElement.dir || 'rtl'}
            className="glass-strong z-[60] max-h-72 overflow-y-auto rounded-md p-1 text-sm shadow-2"
            data-testid={`${testid}-menu`}
          >
            {shown.map((it, k) => {
              const off = onlyInStock && it.qty <= 0;
              return (
                <li key={it.id} id={`${menuId}-${k}`} role="option" aria-selected={active === k} aria-disabled={off || undefined}>
                  <button
                    type="button"
                    tabIndex={-1}
                    onClick={() => choose(it)}
                    className={cn('flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-start', active === k && 'bg-accent-soft', off ? 'cursor-not-allowed opacity-50' : 'hover:bg-raised/60')}
                    data-testid="picker-option"
                  >
                    <span className="min-w-0 flex-1 truncate text-fg">
                      <bdi>{it.name}</bdi>
                    </span>
                    <span className={cn('num shrink-0 text-2xs', it.qty > 0 ? 'text-fg-2' : 'text-danger')} data-testid="picker-qty">
                      {t('picker.qty', { n: f.number(it.qty) })}
                    </span>
                    {showPrice && it.sale_price != null && (
                      <span className="num shrink-0 text-2xs text-fg-3" data-testid="picker-price">
                        {f.money(it.sale_price)}
                      </span>
                    )}
                  </button>
                </li>
              );
            })}
            {!shown.length && (
              <li className={cn('px-2 py-1.5 text-xs', createDenied && !onCreate ? 'text-warn' : 'text-fg-3')} data-testid={createDenied && !onCreate ? 'picker-ask-owner' : undefined}>
                {createDenied && !onCreate ? t('picker.askOwner') : t('picker.none')}
              </li>
            )}
            {canCreate && (
              <li id={`${menuId}-${shown.length}`} role="option" aria-selected={active === shown.length}>
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => {
                    setOpen(false);
                    onCreate!(q.trim());
                  }}
                  className={cn('flex w-full items-center gap-1.5 rounded-sm px-2 py-1.5 text-start text-accent', active === shown.length && 'bg-accent-soft')}
                  data-testid="picker-create"
                >
                  <PackagePlus className="size-4" aria-hidden /> {t('picker.create', { v: q.trim() })}
                </button>
              </li>
            )}
          </ul>,
          host,
        )}
    </div>
  );
}
