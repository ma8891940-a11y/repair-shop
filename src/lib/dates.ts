// كل حسابات "النهارده" بتوقيت القاهرة، مش بتوقيت جهاز المستخدم ولا UTC.
export const SHOP_TZ = 'Africa/Cairo';

const dayFmt = new Intl.DateTimeFormat('en-CA', {
  timeZone: SHOP_TZ,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** يرجع تاريخ اليوم بتوقيت القاهرة بصيغة YYYY-MM-DD */
export function cairoDay(d: Date | string): string {
  return dayFmt.format(typeof d === 'string' ? new Date(d) : d);
}

/** عدد الأيام الكاملة اللي عدّت من وقت معيّن */
export function daysSince(from: Date | string, now: Date): number {
  const ms = now.getTime() - (typeof from === 'string' ? new Date(from) : from).getTime();
  return Math.floor(ms / 86_400_000);
}

const displayFmt = new Intl.DateTimeFormat('ar-EG', {
  timeZone: SHOP_TZ,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
});

export function formatDateTime(d: Date | string): string {
  return displayFmt.format(typeof d === 'string' ? new Date(d) : d);
}
