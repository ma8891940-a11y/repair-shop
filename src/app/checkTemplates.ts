import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { normalizeTemplate, templateFor, type BrandKey, type TemplateItem } from '../lib/checks';

export type CustomTemplates = Partial<Record<BrandKey, TemplateItem[]>>;
interface Row {
  id: string;
  brand: BrandKey;
  branch_id: string | null;
  items: unknown;
}

// نسخة واحدة في الذاكرة لكل المحل (بتتحدّث بعد الحفظ من الإعدادات)، ومن غير نت بنستخدم القوالب الجاهزة
let cache: { rows: Row[] } | null = null;
const listeners = new Set<() => void>();

async function fetchRows(): Promise<Row[]> {
  const { data, error } = await supabase.from('check_templates').select('id, brand, branch_id, items').is('deleted_at', null);
  if (error) throw error;
  return (data ?? []) as Row[];
}

export function invalidateCheckTemplates() {
  cache = null;
  for (const l of listeners) l();
}

/** C2: قوالب الفحص اللي صاحب المحل عدّلها (الماركات التانية بالقالب الجاهز) */
export function useCheckTemplates() {
  const [rows, setRows] = useState<Row[] | null>(cache?.rows ?? null);
  const load = useCallback(async () => {
    try {
      const r = cache?.rows ?? (await fetchRows());
      cache = { rows: r };
      setRows(r);
    } catch {
      setRows([]);
    }
  }, []);
  useEffect(() => {
    void load();
    listeners.add(load);
    return () => {
      listeners.delete(load);
    };
  }, [load]);
  return { rows, custom: customFor(rows ?? [], null), loading: rows === null };
}

/** قوالب فرع: قالب الفرع بيكسب قالب المحل، والماركات التانية بالجاهز */
export function customFor(rows: Row[], branch: string | null | undefined): CustomTemplates {
  const out: CustomTemplates = {};
  for (const r of rows) if (!r.branch_id) out[r.brand] = normalizeTemplate(r.items);
  if (branch) for (const r of rows) if (r.branch_id === branch) out[r.brand] = normalizeTemplate(r.items);
  return out;
}

/** قالب الفحص لجهاز بماركته وفرعه */
export function useDeviceTemplate(brand: string | null | undefined, branch?: string | null): TemplateItem[] {
  const { rows } = useCheckTemplates();
  return templateFor(brand, customFor(rows ?? [], branch));
}

/** اسم البند: اللي كتبه صاحب المحل، أو المحفوظ مع الفحص، أو اسم البند الجاهز */
export function useItemLabel() {
  const { t } = useTranslation();
  return useCallback(
    (key: string, labels?: Record<string, string> | null, template?: TemplateItem[]) =>
      labels?.[key] ?? template?.find((i) => i.key === key)?.label ?? t(`checks.items.${key}`, { defaultValue: key }),
    [t],
  );
}
