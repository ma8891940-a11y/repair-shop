import { forwardRef, useEffect, useId, useLayoutEffect, useMemo, useRef, useState, type InputHTMLAttributes } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { Plus, X } from 'lucide-react';
import { useListLabel, useShopList, type ListKey } from './lists';
import { Input } from '../ui/Field';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, 'value' | 'onChange' | 'list'> & {
  list: ListKey;
  value: string;
  onChange: (v: string) => void;
  parent?: string | null;
  mono?: boolean;
  /** data-testid للخانة (والقايمة بتاخد نفس الاسم + "-menu") */
  testid?: string;
};

/**
 * خانة بقايمة ملء سريع (الماركة، والموديل، والتصنيف، والقطعة، والسبب...):
 * - بتقترح من القايمة وانت بتكتب، والأسهم وEnter بيختاروا، وEsc بيقفل.
 * - جنب كل بند "إزالة من القائمة" (بتأكيد)، وتحت "إضافة «...» للقائمة" لو اللي اتكتب مش موجود.
 *   الإضافة والحذف لصاحب المحل ولللي هو سمحلهم (الإعدادات ← القوائم).
 * - القايمة واحدة للمحل: اللي بيتضاف هنا بيظهر في كل شاشة بتستخدم نفس القايمة، ولكل الموظفين.
 * - الحذف بيخفي البند من الاختيار بس: الأجهزة والأصناف القديمة اللي عليها القيمة دي ما بتتغيرش.
 */
export const ListCombo = forwardRef<HTMLInputElement, Props>(function ListCombo({ list, value, onChange, parent = null, testid, className, onKeyDown, onFocus, onBlur, ...rest }, ref) {
  const { t } = useTranslation();
  const toast = useToast();
  const label = useListLabel();
  const { items, canEdit, add, remove } = useShopList(list);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const [asking, setAsking] = useState<string | null>(null);
  const menuId = useId();
  const box = useRef<HTMLDivElement | null>(null);
  // القايمة في طبقة فوق الصفحة (عشان ما تتقصش جوه جدول بيعمل scroll)، تحت الخانة بالظبط
  // جوه نافذة: القايمة جوه النافذة نفسها (النافذة بتعتبر أي ضغطة برّاها قفل)، وإلا في الصفحة
  const [host, setHost] = useState<HTMLElement | null>(null);
  const [pos, setPos] = useState<{ top: number; left: number; width: number; up: boolean; bottom: number } | null>(null);
  useLayoutEffect(() => {
    if (!open) return;
    const place = () => {
      const r = box.current?.getBoundingClientRect();
      if (!r) return;
      const h = (box.current?.closest('[role="dialog"]') as HTMLElement | null) ?? document.body;
      // النافذة متحركة بـ transform، فالـ fixed جواها بيتحسب من أولها
      const o = h === document.body ? { top: 0, left: 0, height: window.innerHeight } : h.getBoundingClientRect();
      const up = r.bottom + 260 > window.innerHeight && r.top > 260;
      setHost(h);
      setPos({ top: (up ? r.top - 4 : r.bottom + 4) - o.top, bottom: o.top + o.height - (r.top - 4), left: r.left - o.left, width: Math.max(r.width, 200), up });
    };
    place();
    window.addEventListener('scroll', place, true);
    window.addEventListener('resize', place);
    return () => {
      window.removeEventListener('scroll', place, true);
      window.removeEventListener('resize', place);
    };
  }, [open]);

  const mine = useMemo(() => items.filter((i) => i.parent === parent), [items, parent]);
  const q = value.trim().toLowerCase();
  const shown = useMemo(() => mine.filter((i) => !q || label(list, i.value).toLowerCase().includes(q) || i.value.toLowerCase().includes(q)).slice(0, 50), [mine, q, label, list]);
  const exact = mine.some((i) => i.value.toLowerCase() === q || label(list, i.value).toLowerCase() === q);
  const canAdd = canEdit && !!q && !exact;
  useEffect(() => setActive(-1), [q, open]);

  const pick = (v: string) => {
    onChange(label(list, v));
    setOpen(false);
    setAsking(null);
  };
  const doAdd = async () => {
    const v = value.trim();
    if (await add(v, parent)) {
      toast({ tone: 'ok', title: t('lists.added', { v }) });
      setOpen(false);
    }
  };
  const doRemove = async (v: string) => {
    const item = mine.find((i) => i.value === v);
    if (item && (await remove(item))) toast({ tone: 'ok', title: t('lists.removed', { v: label(list, v) }) });
    setAsking(null);
  };

  return (
    <div
      ref={box}
      className="relative"
      // كل زراير القايمة بتمنع الخانة إنها تفقد التركيز، فالـ blur هنا معناه إن المستخدم خرج من الخانة
      onBlur={() => {
        setOpen(false);
        setAsking(null);
      }}
    >
      <Input
        ref={ref}
        {...rest}
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={(e) => {
          setOpen(true);
          onFocus?.(e);
        }}
        onBlur={onBlur}
        onKeyDown={(e) => {
          if (open && (shown.length || canAdd)) {
            const n = shown.length + (canAdd ? 1 : 0);
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              return setActive((a) => (a + 1) % n);
            }
            if (e.key === 'ArrowUp') {
              e.preventDefault();
              return setActive((a) => (a <= 0 ? n - 1 : a - 1));
            }
            if (e.key === 'Enter' && active >= 0) {
              // Enter بيختار البند (ومش بينقل للخانة اللي بعدها ولا بيحفظ)
              e.preventDefault();
              if (active < shown.length) return pick(shown[active].value);
              return void doAdd();
            }
          }
          if (e.key === 'Escape' && open) {
            e.preventDefault();
            e.stopPropagation();
            return setOpen(false);
          }
          onKeyDown?.(e);
        }}
        role="combobox"
        aria-expanded={open}
        aria-controls={menuId}
        aria-autocomplete="list"
        aria-activedescendant={active >= 0 ? `${menuId}-${active}` : undefined}
        autoComplete="off"
        className={className}
        data-testid={testid}
      />
      {open && pos && host && (shown.length > 0 || canAdd) && createPortal(
        <ul
          id={menuId}
          role="listbox"
          dir={document.documentElement.dir || 'rtl'}
          onMouseDown={(e) => e.preventDefault()}
          style={{ position: 'fixed', top: pos.up ? undefined : pos.top, bottom: pos.up ? pos.bottom : undefined, left: pos.left, width: pos.width }}
          className="glass-strong z-[60] max-h-64 overflow-y-auto rounded-md p-1 text-sm shadow-2"
          data-testid={testid ? `${testid}-menu` : undefined}
        >
          {shown.map((i, k) => (
            <li
              key={i.value}
              id={`${menuId}-${k}`}
              role="option"
              aria-selected={active === k}
              className={cn('flex items-center gap-1 rounded-sm', active === k && 'bg-accent-soft')}
              data-testid="list-option"
            >
              {asking === i.value ? (
                <div className="flex w-full flex-wrap items-center gap-1.5 px-2 py-1.5 text-xs text-fg-2">
                  <span className="flex-1">{t('lists.removeAsk', { v: label(list, i.value) })}</span>
                  <button type="button" onClick={() => void doRemove(i.value)} className="rounded-sm bg-danger-soft px-2 py-0.5 text-danger" data-testid="list-option-remove-yes">
                    {t('lists.removeYes')}
                  </button>
                  <button type="button" onClick={() => setAsking(null)} className="rounded-sm px-2 py-0.5 text-fg-2 hover:text-fg">
                    {t('lists.removeNo')}
                  </button>
                </div>
              ) : (
                <>
                  <button type="button" tabIndex={-1} onMouseDown={(e) => e.preventDefault()} onClick={() => pick(i.value)} className="min-w-0 flex-1 truncate px-2 py-1.5 text-start text-fg hover:text-accent">
                    <bdi>{label(list, i.value)}</bdi>
                  </button>
                  {canEdit && (
                    <button
                      type="button"
                      onClick={() => setAsking(i.value)}
                      aria-label={t('lists.remove', { v: label(list, i.value) })}
                      title={t('lists.remove', { v: label(list, i.value) })}
                      className="grid size-7 shrink-0 place-items-center rounded-sm text-fg-3 hover:bg-raised hover:text-danger"
                      data-testid="list-option-remove"
                    >
                      <X className="size-3.5" aria-hidden />
                    </button>
                  )}
                </>
              )}
            </li>
          ))}
          {canAdd && (
            <li id={`${menuId}-${shown.length}`} role="option" aria-selected={active === shown.length} className={cn('rounded-sm', active === shown.length && 'bg-accent-soft')}>
              <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => void doAdd()} className="flex w-full items-center gap-1.5 px-2 py-1.5 text-start text-accent" data-testid={`inline-add-${list}`}>
                <Plus className="size-3.5" aria-hidden /> {t('lists.addInline', { v: value.trim() })}
              </button>
            </li>
          )}
        </ul>,
        host,
      )}
    </div>
  );
});
