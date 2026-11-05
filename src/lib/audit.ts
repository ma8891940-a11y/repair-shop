// عرض سجل النشاط: الفرق بين القيمة قبل وبعد (أسماء العمليات في ملفات الترجمة)
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
