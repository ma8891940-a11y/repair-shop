// اختصار شاشة تشخيص الحركة: Ctrl+Alt+Shift+M (وCmd+Option+Shift+M على الماك).
// مش محجوز في Chrome ولا Edge (Ctrl+Shift+D كان محجوز لحفظ كل التبويبات في المفضلة).
// بيتقرا بالحرف الفعلي على الكيبورد (e.code)، فبيشتغل والكيبورد عربي.
export const DIAG_SHORTCUT = 'Ctrl+Alt+Shift+M';
/** حدث بيفتح الشاشة من غير اختصار (زرار "تشخيص الحركة" في الإعدادات ← المظهر) */
export const OPEN_DIAG_EVENT = 'gawalak:open-motion-diag';

export function isDiagShortcut(e: Pick<KeyboardEvent, 'ctrlKey' | 'metaKey' | 'altKey' | 'shiftKey' | 'code'>): boolean {
  return (e.ctrlKey || e.metaKey) && e.altKey && e.shiftKey && e.code === 'KeyM';
}

export function openMotionDiag() {
  window.dispatchEvent(new Event(OPEN_DIAG_EVENT));
}
