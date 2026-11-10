import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Plus, X } from 'lucide-react';
import { useListLabel, useShopList, type ListItem, type ListKey } from './lists';
import { useToast } from '../ui/Toast';

/** "×" صغيرة جنب زرار من القايمة: إزالة من القائمة (بتأكيد). لصاحب المحل ولللي هو سمحلهم بس */
export function ChipRemove({ list, item, onRemove, label: given }: { list?: ListKey; item?: ListItem; onRemove?: () => Promise<boolean>; label?: string }) {
  const { t } = useTranslation();
  const toast = useToast();
  const label = useListLabel();
  const sl = useShopList(list ?? 'brands');
  const [ask, setAsk] = useState(false);
  const name = given ?? (list && item ? label(list, item.value) : '');
  // نفس صلاحية القوايم (صاحب المحل واللي هو سمحلهم)
  if (!sl.canEdit) return null;
  const go = async () => {
    const ok = onRemove ? await onRemove() : list && item ? await sl.remove(item) : false;
    if (ok) toast({ tone: 'ok', title: t('lists.removed', { v: name }) });
    setAsk(false);
  };
  return ask ? (
    <span className="inline-flex items-center gap-1 rounded-full border border-[color-mix(in_srgb,var(--danger)_40%,transparent)] px-1.5 py-0.5 text-2xs text-fg-2" data-testid="chip-remove-ask">
      {t('lists.removeConfirm')}
      <button type="button" onClick={() => void go()} aria-label={t('lists.remove', { v: name })} className="rounded-full p-0.5 text-danger hover:bg-danger-soft" data-testid="chip-remove-yes">
        <Check className="size-3" aria-hidden />
      </button>
      <button type="button" onClick={() => setAsk(false)} aria-label={t('lists.removeNo')} className="rounded-full p-0.5 text-fg-3 hover:text-fg">
        <X className="size-3" aria-hidden />
      </button>
    </span>
  ) : (
    <button type="button" onClick={() => setAsk(true)} aria-label={t('lists.remove', { v: name })} title={t('lists.remove', { v: name })} className="-ms-1 rounded-full p-0.5 text-fg-3 hover:text-danger" data-testid="chip-remove">
      <X className="size-3" aria-hidden />
    </button>
  );
}

/** "+" في آخر الزراير: بند جديد في القايمة من نفس المكان */
export function ChipAdd({ list, parent = null, onAdd, placeholder }: { list?: ListKey; parent?: string | null; onAdd?: (v: string) => Promise<boolean>; placeholder?: string }) {
  const { t } = useTranslation();
  const toast = useToast();
  const sl = useShopList(list ?? 'brands');
  const [open, setOpen] = useState(false);
  const [v, setV] = useState('');
  if (!sl.canEdit) return null;
  const go = async () => {
    const x = v.trim();
    if (!x) return setOpen(false);
    const ok = onAdd ? await onAdd(x) : await sl.add(x, parent);
    if (ok) {
      toast({ tone: 'ok', title: t('lists.added', { v: x }) });
      setV('');
      setOpen(false);
    }
  };
  if (!open)
    return (
      <button type="button" onClick={() => setOpen(true)} className="inline-flex h-7 items-center gap-1 rounded-full border border-dashed border-line px-2.5 text-xs text-fg-3 hover:border-accent hover:text-accent" data-testid={`chip-add-${list ?? 'custom'}`}>
        <Plus className="size-3" aria-hidden /> {t('lists.add')}
      </button>
    );
  return (
    <span className="inline-flex items-center gap-1">
      <input
        autoFocus
        value={v}
        onChange={(e) => setV(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            e.preventDefault();
            void go();
          } else if (e.key === 'Escape') {
            e.preventDefault();
            setOpen(false);
          }
        }}
        onBlur={() => !v.trim() && setOpen(false)}
        maxLength={60}
        placeholder={placeholder ?? t('lists.newItem')}
        aria-label={placeholder ?? t('lists.newItem')}
        className="h-7 w-36 rounded-full border border-line bg-sunken/60 px-2.5 text-xs text-fg focus:border-accent focus:outline-none"
        data-testid={`chip-add-input-${list ?? 'custom'}`}
      />
      <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => void go()} aria-label={t('lists.add')} className="rounded-full p-1 text-accent hover:bg-accent-soft">
        <Check className="size-3.5" aria-hidden />
      </button>
    </span>
  );
}
