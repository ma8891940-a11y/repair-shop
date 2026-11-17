/**
 * وقت إشعارات الجهاز (من/لحد، بتوقيت القاهرة) من إعدادات المحل.
 * نفس قواعد push_window وpush_window_open في قاعدة البيانات (0058_web_push.sql)، واختبار بيتأكد إنهم متطابقين.
 */
export interface PushWindow {
  from: number;
  to: number;
}

const hour = (v: unknown, def: number) => {
  const n = Number(v);
  return v == null || v === '' || !Number.isInteger(n) ? def : Math.min(Math.max(n, 0), 24);
};

export function readPushWindow(extras: unknown): PushWindow {
  const r = extras && typeof extras === 'object' ? (extras as Record<string, unknown>).reminders : null;
  const o = r && typeof r === 'object' ? (r as Record<string, unknown>) : {};
  return { from: hour(o.push_from, 9), to: hour(o.push_to, 21) };
}

/** الساعة h (0-23) جوه الوقت؟ من = لحد يعني طول اليوم، ومن أكبر من لحد يعني بيعدّي نص الليل */
export function windowOpen(w: PushWindow, h: number): boolean {
  if (w.from === w.to || (w.from === 0 && w.to === 24)) return true;
  if (w.from < w.to) return h >= w.from && h < w.to;
  return h >= w.from || h < w.to;
}
