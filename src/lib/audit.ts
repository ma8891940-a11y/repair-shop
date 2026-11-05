// عرض سجل النشاط بكلام مفهوم
export const ENTITY_LABELS: Record<string, string> = {
  shops: 'إعدادات المحل',
  profiles: 'مستخدم',
  staff_invites: 'دعوة موظف',
  customers: 'عميل',
  devices: 'جهاز',
  device_costs: 'تكلفة جهاز',
  device_photos: 'صورة جهاز',
  device_notes: 'ملاحظة داخلية',
};

export const ACTION_LABELS: Record<string, string> = {
  insert: 'إضافة',
  update: 'تعديل',
  soft_delete: 'حذف',
  create_shop: 'إنشاء المحل',
  join: 'انضمام موظف',
};

const IGNORED = new Set(['updated_at', 'created_at', 'id', 'shop_id']);

export interface Change {
  field: string;
  before: unknown;
  after: unknown;
}

/** يطلّع الحقول اللي اتغيّرت بين قبل وبعد */
export function diffChanges(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
): Change[] {
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after ?? {})]);
  const out: Change[] = [];
  for (const k of keys) {
    if (IGNORED.has(k)) continue;
    const b = before?.[k] ?? null;
    const a = after?.[k] ?? null;
    if (JSON.stringify(b) !== JSON.stringify(a)) out.push({ field: k, before: b, after: a });
  }
  return out;
}
