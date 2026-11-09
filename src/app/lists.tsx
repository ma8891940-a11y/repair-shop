import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus } from 'lucide-react';
import { useMe } from './auth';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useToast } from '../ui/Toast';

/**
 * القوايم اللي بيديرها صاحب المحل (الإعدادات ← القوايم).
 * - القيمة نفسها هي اللي بتتخزن في البيانات (نص)، فحذف بند بيخفيه من الاختيار بس، والقديم زي ما هو.
 * - قبل أول تعديل: البرنامج بيستخدم القوايم الافتراضية. وأول تعديل بينسخها للمحل، فصاحب المحل يقدر يمسح منها كمان.
 * - القيم الافتراضية أكواد (زي "sim") ليها اسم مترجم. اللي صاحب المحل بيضيفه بيتعرض زي ما اتكتب.
 */
export type ListKey = 'brands' | 'models' | 'accessories' | 'colors' | 'conditions' | 'item_categories' | 'write_off_reasons' | 'sub_statuses';
export const LIST_KEYS: ListKey[] = ['brands', 'models', 'accessories', 'colors', 'conditions', 'item_categories', 'write_off_reasons', 'sub_statuses'];

export const LIST_DEFAULTS: Record<ListKey, string[]> = {
  brands: ['Samsung', 'iPhone', 'Xiaomi', 'Oppo', 'Realme', 'Infinix', 'Vivo', 'Honor', 'Huawei', 'Tecno'],
  models: [],
  accessories: ['sim', 'case', 'sd', 'charger', 'earphones', 'box'],
  colors: ['black', 'white', 'blue', 'green', 'gold', 'silver'],
  conditions: ['scratches', 'cracked_back', 'dented', 'bent', 'clean'],
  item_categories: ['screens', 'batteries', 'charging', 'cases', 'chargers', 'cables'],
  write_off_reasons: ['broken', 'defective', 'lost', 'expired'],
  sub_statuses: [],
};

export interface ListItem {
  id: string | null;
  value: string;
  parent: string | null;
}

/** اسم البند المعروض: الكود الافتراضي مترجم، وغيره زي ما اتكتب */
export function useListLabel() {
  const { t } = useTranslation();
  return useCallback((list: ListKey, value: string) => (list === 'accessories' ? t(`intake.acc.${value}`, { defaultValue: value }) : list === 'brands' || list === 'models' ? value : t(`lists.values.${list}.${value}`, { defaultValue: value })), [t]);
}

const changed = 'gawalak:lists-changed';

/** بنود قايمة (الساري بس)، وإضافة وحذف. لو مفيش نت: القوايم الافتراضية */
export function useShopList(list: ListKey) {
  const { profile } = useMe();
  const toast = useToast();
  const [rows, setRows] = useState<(ListItem & { deleted: boolean })[] | null>(null);
  const load = useCallback(async () => {
    const { data, error } = await supabase.from('shop_lists').select('id, value, parent, deleted_at, sort, created_at').eq('list', list).order('sort').order('created_at');
    if (error) return setRows(null);
    setRows((data ?? []).map((r) => ({ id: r.id as string, value: r.value as string, parent: (r.parent as string | null) ?? null, deleted: !!r.deleted_at })));
  }, [list]);
  useEffect(() => {
    void load();
    const on = (e: Event) => (e as CustomEvent<string>).detail === list && void load();
    window.addEventListener(changed, on);
    return () => window.removeEventListener(changed, on);
  }, [load, list]);
  // ولا مرة اتعدّلت: الافتراضية
  const custom = !!rows && rows.length > 0;
  const items: ListItem[] = custom ? rows!.filter((r) => !r.deleted) : LIST_DEFAULTS[list].map((value) => ({ id: null, value, parent: null }));
  const canEdit = profile.role === 'owner';

  /** أول تعديل: البنود الافتراضية بتتنسخ للمحل */
  const seed = async () => {
    if (custom || !LIST_DEFAULTS[list].length) return;
    const { error } = await supabase.from('shop_lists').insert(LIST_DEFAULTS[list].map((value, i) => ({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), list, value, sort: i })));
    if (error && !/shop_lists_unique|duplicate/.test(error.message)) throw error;
  };
  const notify = () => window.dispatchEvent(new CustomEvent(changed, { detail: list }));

  const add = async (value: string, parent: string | null = null) => {
    const v = value.trim();
    if (!v) return false;
    if (items.some((i) => i.value.trim().toLowerCase() === v.toLowerCase() && i.parent === parent)) return true;
    try {
      await seed();
      const { error } = await supabase.from('shop_lists').insert({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), list, value: v, parent, sort: items.length + 1 });
      if (error && !/shop_lists_unique|duplicate/.test(error.message)) throw error;
      notify();
      return true;
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
      return false;
    }
  };
  const remove = async (item: ListItem) => {
    try {
      await seed();
      // بعد النسخ، البند الافتراضي بقى ليه id: بنمسحه بالقيمة
      const { error } = await supabase.from('shop_lists').update({ deleted_at: new Date().toISOString() }).eq('list', list).eq('value', item.value).is('deleted_at', null);
      if (error) throw error;
      notify();
      return true;
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
      return false;
    }
  };
  return { items, loading: rows === null && false, canEdit, add, remove, reload: load };
}

/**
 * "إضافة «...» للقائمة": بيظهر جنب أي خانة ليها قايمة، لو اللي اتكتب مش موجود فيها، ولصاحب المحل بس.
 */
export function InlineAdd({ list, value, parent = null }: { list: ListKey; value: string; parent?: string | null }) {
  const { t } = useTranslation();
  const toast = useToast();
  const { items, canEdit, add } = useShopList(list);
  const label = useListLabel();
  const v = value.trim();
  if (!canEdit || !v) return null;
  if (items.some((i) => i.parent === parent && (i.value.toLowerCase() === v.toLowerCase() || label(list, i.value).toLowerCase() === v.toLowerCase()))) return null;
  return (
    <button
      type="button"
      onClick={() => void add(v, parent).then((ok) => ok && toast({ tone: 'ok', title: t('lists.added', { v }) }))}
      className="mt-1 inline-flex items-center gap-1 rounded-sm text-2xs text-accent hover:underline"
      data-testid={`inline-add-${list}`}
    >
      <Plus className="size-3" aria-hidden /> {t('lists.addInline', { v })}
    </button>
  );
}

/** اقتراحات للخانة (datalist) من القايمة */
export function ListOptions({ id, list, parent = null }: { id: string; list: ListKey; parent?: string | null }) {
  const { items } = useShopList(list);
  const label = useListLabel();
  return (
    <datalist id={id}>
      {items
        .filter((i) => i.parent === parent)
        .map((i) => (
          <option key={i.value} value={label(list, i.value)} />
        ))}
    </datalist>
  );
}
