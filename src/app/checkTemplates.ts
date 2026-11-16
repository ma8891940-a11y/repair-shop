import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { normalizeTemplate, templateFor, type BrandKey, type TemplateItem } from '../lib/checks';

export type CustomTemplates = Partial<Record<BrandKey, TemplateItem[]>>;
interface Row {
  id: string;
  brand: BrandKey;
  items: unknown;
}

// نسخة واحدة في الذاكرة لكل المحل (بتتحدّث بعد الحفظ من الإعدادات)، ومن غير نت بنستخدم القوالب الجاهزة
let cache: { rows: Row[] } | null = null;
const listeners = new Set<() => void>();

async function fetchRows(): Promise<Row[]> {
  const { data, error } = await supabase.from('check_templates').select('id, brand, items').is('deleted_at', null);
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
  const custom: CustomTemplates = Object.fromEntries((rows ?? []).map((r) => [r.brand, normalizeTemplate(r.items)]));
  return { rows, custom, loading: rows === null };
}

/** قالب الفحص لجهاز بماركته */
export function useDeviceTemplate(brand: string | null | undefined): TemplateItem[] {
  const { custom } = useCheckTemplates();
  return templateFor(brand, custom);
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
