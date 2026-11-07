/**
 * حالة الحركة دلوقتي (لشاشة التشخيص Ctrl+Shift+D): بتتحدّث من الخلفية والحارس، ومن غير أي إرسال لأي مكان.
 */
export type GuardState = 'waiting' | 'measuring' | 'off-dev' | 'off';
export interface MotionDiag {
  /** الخلفية بترسم حركة دلوقتي فعلًا */
  moving: boolean;
  /** live = الافتتاحية والدخول، still = جوه البرنامج (ثابتة بالتصميم)، off = الطباعة */
  mode: 'live' | 'still' | 'off';
  reduced: boolean;
  autoStill: boolean;
  hidden: boolean;
  guard: GuardState;
  /** آخر قراءة للحارس */
  fps: number | null;
  work: number | null;
  capped: boolean;
}
export const motionDiag: MotionDiag = { moving: false, mode: 'live', reduced: false, autoStill: false, hidden: false, guard: 'waiting', fps: null, work: null, capped: false };

export type StopReason = 'reduced' | 'auto' | 'inside' | 'hidden' | 'print' | null;
/** ليه الخلفية واقفة (أو null لو شغالة) */
export function stopReason(d: Pick<MotionDiag, 'moving' | 'mode' | 'reduced' | 'autoStill' | 'hidden'>): StopReason {
  if (d.reduced) return 'reduced';
  if (d.autoStill) return 'auto';
  if (d.mode === 'off') return 'print';
  if (d.mode === 'still') return 'inside';
  if (d.hidden) return 'hidden';
  return null;
}
