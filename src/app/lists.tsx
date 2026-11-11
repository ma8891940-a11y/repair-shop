import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus } from 'lucide-react';
import { useMe } from './auth';
import itemLists from '../data/itemLists.json';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { cacheGet, cacheSet, enqueue, isNetworkError, localDb } from '../offline/outbox';
import { getBranchHeader } from '../lib/branchHeader';
import { useToast } from '../ui/Toast';

/**
 * القوايم اللي بيديرها صاحب المحل (الإعدادات ← القوايم).
 * - القيمة نفسها هي اللي بتتخزن في البيانات (نص)، فحذف بند بيخفيه من الاختيار بس، والقديم زي ما هو.
 * - قبل أول تعديل: البرنامج بيستخدم القوايم الافتراضية. وأول تعديل بينسخها للمحل، فصاحب المحل يقدر يمسح منها كمان.
 * - القيم الافتراضية أكواد (زي "sim") ليها اسم مترجم. اللي صاحب المحل بيضيفه بيتعرض زي ما اتكتب.
 */
export type ListKey = 'brands' | 'models' | 'device_types' | 'accessories' | 'colors' | 'conditions' | 'issues' | 'parts' | 'item_types' | 'qualities' | 'item_categories' | 'write_off_reasons' | 'return_reasons' | 'sub_statuses';
export const LIST_KEYS: ListKey[] = ['brands', 'models', 'device_types', 'accessories', 'colors', 'conditions', 'issues', 'parts', 'item_types', 'qualities', 'item_categories', 'write_off_reasons', 'return_reasons', 'sub_statuses'];

/** أنواع الأصناف والجودة الافتراضية (من البحث في السوق المصري، docs/RESEARCH.md). بتتخزن نص زي ما هي */
export const PART_TYPES: string[] = itemLists.part_types;
export const ACCESSORY_TYPES: string[] = itemLists.accessory_types;
export const QUALITIES: string[] = itemLists.qualities;

export const LIST_DEFAULTS: Record<ListKey, string[]> = {
  brands: ['Samsung', 'iPhone', 'Xiaomi', 'Oppo', 'Realme', 'Infinix', 'Vivo', 'Honor', 'Huawei', 'Tecno'],
  models: [],
  accessories: ['sim', 'case', 'sd', 'charger', 'earphones', 'box'],
  colors: ['black', 'white', 'blue', 'green', 'gold', 'silver'],
  conditions: ['scratches', 'cracked_back', 'dented', 'bent', 'clean'],
  item_categories: ['screens', 'batteries', 'charging', 'cases', 'chargers', 'cables'],
  write_off_reasons: ['broken', 'defective', 'lost', 'expired'],
  sub_statuses: [],
  device_types: ['phone', 'tablet', 'watch', 'laptop', 'other'],
  // زراير "+ عطل" في الاستلام
  issues: ['screen', 'battery', 'charging', 'software', 'water', 'speaker', 'mic', 'camera', 'dead'],
  parts: ['screen', 'battery', 'charging_port', 'back_glass', 'camera', 'speaker', 'mic'],
  return_reasons: ['changed_mind', 'defective', 'wrong_item', 'duplicate'],
  item_types: [...PART_TYPES, ...ACCESSORY_TYPES],
  qualities: QUALITIES,
};

/** مين يقدر يضيف ويشيل من القوايم: صاحب المحل دايمًا، والأدوار اللي اختارها (shops.extras.lists_edit) */
export function readListsEdit(extras: unknown): string[] {
  const v = extras && typeof extras === 'object' ? (extras as Record<string, unknown>).lists_edit : null;
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
}
export function canEditLists(role: string, extras: unknown): boolean {
  return role === 'owner' || readListsEdit(extras).includes(role);
}

export interface ListItem {
  id: string | null;
  value: string;
  parent: string | null;
}

/** اسم البند المعروض: الكود الافتراضي مترجم، وغيره زي ما اتكتب */
export function useListLabel() {
  const { t } = useTranslation();
  return useCallback(
    (list: ListKey, value: string) => (list === 'accessories' ? t(`intake.acc.${value}`, { defaultValue: value }) : list === 'issues' ? t(`intake.quick.${value}`, { defaultValue: value }) : list === 'brands' || list === 'models' || list === 'item_types' || list === 'qualities' ? value : t(`lists.values.${list}.${value}`, { defaultValue: value })),
    [t],
  );
}

const changed = 'gawalak:lists-changed';

type Row = ListItem & { deleted: boolean };
const cacheKey = (shop: string, list: ListKey) => `list:${shop}:${list}`;
const offline = () => typeof navigator !== 'undefined' && !navigator.onLine;

/**
 * بنود قايمة (الساري بس)، وإضافة وحذف. القايمة واحدة للمحل كله: اللي بيتضاف من أي شاشة بيظهر في كل مكان ولكل الموظفين.
 * من غير نت: آخر نسخة محفوظة على الجهاز، والإضافة والحذف بيتسجلوا على الجهاز وبيتبعتوا لما النت يرجع.
 */
export function useShopList(list: ListKey) {
  const { profile, shop } = useMe();
  const toast = useToast();
  const { t } = useTranslation();
  const [rows, setRows] = useState<Row[] | null>(null);
  const key = cacheKey(profile.shop_id, list);
  const load = useCallback(async () => {
    const { data, error } = await supabase.from('shop_lists').select('id, value, parent, deleted_at, sort, created_at').eq('list', list).order('sort').order('created_at');
    if (error) {
      const c = await cacheGet<Row[]>(localDb(), key).catch(() => null);
      return setRows(c ? c.value : null);
    }
    const next = (data ?? []).map((r) => ({ id: r.id as string, value: r.value as string, parent: (r.parent as string | null) ?? null, deleted: !!r.deleted_at }));
    setRows(next);
    void cacheSet(localDb(), key, next).catch(() => undefined);
  }, [list, key]);
  useEffect(() => {
    void load();
    const on = (e: Event) => (e as CustomEvent<string>).detail === list && void load();
    // اللي ضافه موظف تاني بيظهر لما ترجع للشاشة أو النت يرجع
    const again = () => void load();
    window.addEventListener(changed, on);
    window.addEventListener('focus', again);
    window.addEventListener('online', again);
    return () => {
      window.removeEventListener(changed, on);
      window.removeEventListener('focus', again);
      window.removeEventListener('online', again);
    };
  }, [load, list]);
  /** تغيير محلي (من غير نت): بيتحفظ على الجهاز على طول */
  const local = (f: (cur: Row[]) => Row[]) => {
    const base = rows && rows.length ? rows : LIST_DEFAULTS[list].map((value) => ({ id: null, value, parent: null, deleted: false }));
    const next = f(base);
    setRows(next);
    void cacheSet(localDb(), key, next).catch(() => undefined);
  };
  /** العملية بتتسجل في الطابور (من غير نت) */
  const queue = async (payload: Record<string, unknown>) => {
    await enqueue(localDb(), 'list', crypto.randomUUID(), payload, Date.now(), getBranchHeader());
    toast({ tone: 'warn', title: t('lists.queued') });
  };
  // ولا مرة اتعدّلت: الافتراضية
  const custom = !!rows && rows.length > 0;
  const items: ListItem[] = custom ? rows!.filter((r) => !r.deleted) : LIST_DEFAULTS[list].map((value) => ({ id: null, value, parent: null }));
  const canEdit = canEditLists(profile.role, shop.extras);

  /** أول تعديل: البنود الافتراضية بتتنسخ للمحل */
  const seedRows = () => LIST_DEFAULTS[list].map((value, i) => ({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), list, value, sort: i }));
  const seed = async () => {
    if (custom || !LIST_DEFAULTS[list].length) return;
    const { error } = await supabase.from('shop_lists').insert(seedRows());
    if (error && !/shop_lists_unique|duplicate/.test(error.message)) throw error;
  };
  const notify = () => window.dispatchEvent(new CustomEvent(changed, { detail: list }));

  const add = async (value: string, parent: string | null = null) => {
    const v = value.trim();
    if (!v) return false;
    if (items.some((i) => i.value.trim().toLowerCase() === v.toLowerCase() && i.parent === parent)) return true;
    const row = { id: crypto.randomUUID(), shop_id: crypto.randomUUID(), list, value: v, parent, sort: items.length + 1 };
    const goOffline = async () => {
      await queue({ op: 'add', row, seed: custom ? [] : seedRows() });
      local((cur) => [...cur, { id: row.id, value: v, parent, deleted: false }]);
      return true;
    };
    if (offline()) return goOffline();
    try {
      await seed();
      const { error } = await supabase.from('shop_lists').insert(row);
      if (error && !/shop_lists_unique|duplicate/.test(error.message)) throw error;
      notify();
      return true;
    } catch (e) {
      if (isNetworkError(e)) return goOffline();
      toast({ tone: 'danger', title: errorMessage(e) });
      return false;
    }
  };
  const remove = async (item: ListItem) => {
    const goOffline = async () => {
      await queue({ op: 'remove', list, value: item.value, parent: item.parent, seed: custom ? [] : seedRows() });
      local((cur) => cur.map((r) => (r.value === item.value && r.parent === item.parent ? { ...r, deleted: true } : r)));
      return true;
    };
    if (offline()) return goOffline();
    try {
      await seed();
      // بعد النسخ، البند الافتراضي بقى ليه id: بنمسحه بالقيمة
      let q = supabase.from('shop_lists').update({ deleted_at: new Date().toISOString() }).eq('list', list).eq('value', item.value).is('deleted_at', null);
      q = item.parent ? q.eq('parent', item.parent) : q.is('parent', null);
      const { error } = await q;
      if (error) throw error;
      notify();
      return true;
    } catch (e) {
      if (isNetworkError(e)) return goOffline();
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
