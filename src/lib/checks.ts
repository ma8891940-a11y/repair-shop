/** بنود الفحص السريع (الأسماء في الترجمة: checks.items.*) */
export const CHECK_ITEMS = ['wifi', 'bluetooth', 'front_camera', 'rear_camera', 'fingerprint', 'speaker', 'mic', 'charging', 'screen_touch', 'network'] as const;
export type CheckItem = (typeof CHECK_ITEMS)[number];
export type CheckValue = 'ok' | 'fail' | 'na';
export type CheckItems = Partial<Record<CheckItem, CheckValue>>;

export interface CheckDiff {
  item: CheckItem;
  intake: CheckValue | undefined;
  delivery: CheckValue | undefined;
  /** كان شغال وقت الاستلام وبقى عطلان وقت التسليم: ده اللي بيحمي المحل في الخلاف */
  regressed: boolean;
  fixed: boolean;
}

export function compareChecks(intake: CheckItems | null | undefined, delivery: CheckItems | null | undefined): CheckDiff[] {
  return CHECK_ITEMS.map((item) => {
    const a = intake?.[item];
    const b = delivery?.[item];
    return { item, intake: a, delivery: b, regressed: a === 'ok' && b === 'fail', fixed: a === 'fail' && b === 'ok' };
  });
}

export function checkSummary(items: CheckItems | null | undefined): { ok: number; fail: number; na: number; total: number } {
  const v = Object.values(items ?? {});
  return { ok: v.filter((x) => x === 'ok').length, fail: v.filter((x) => x === 'fail').length, na: v.filter((x) => x === 'na').length, total: CHECK_ITEMS.length };
}
