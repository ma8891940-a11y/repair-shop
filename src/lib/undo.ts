/** مدة "تراجع" قبل ما الحذف أو الإلغاء يتنفذ فعلًا */
export const UNDO_MS = 5000;

/**
 * عملية بتتأجل لحد ما مدة التراجع تخلص. لو المستخدم داس "تراجع" قبلها، ما بتتنفذش خالص (ولا بتوصل لقاعدة البيانات).
 * ولو الصفحة اتقفلت قبل المدة، بتتنفذ على طول (عشان ما تضيعش).
 */
export function deferUndoable(run: () => void, ms = UNDO_MS, target: Pick<Window, 'addEventListener' | 'removeEventListener'> | null = typeof window === 'undefined' ? null : window) {
  let state: 'pending' | 'done' | 'undone' = 'pending';
  const fire = () => {
    if (state !== 'pending') return;
    state = 'done';
    clearTimeout(timer);
    target?.removeEventListener('pagehide', fire);
    run();
  };
  const timer = setTimeout(fire, ms);
  target?.addEventListener('pagehide', fire);
  return {
    /** تراجع: بيرجع true لو لحق قبل التنفيذ */
    undo() {
      if (state !== 'pending') return false;
      state = 'undone';
      clearTimeout(timer);
      target?.removeEventListener('pagehide', fire);
      return true;
    },
    /** نفّذ دلوقتي */
    flush: fire,
    get state() {
      return state;
    },
  };
}
