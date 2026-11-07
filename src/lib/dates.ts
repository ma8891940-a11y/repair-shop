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

// عرض التاريخ والوقت: src/lib/datetime.ts (دالة واحدة للبرنامج كله)

const offsetFmt = new Intl.DateTimeFormat('en-US', { timeZone: SHOP_TZ, timeZoneName: 'longOffset' });

/** فرق توقيت القاهرة عن UTC بالدقايق في لحظة معيّنة (120 شتاءً، 180 صيفًا) */
export function cairoOffsetMinutes(at: Date): number {
  const part = offsetFmt.formatToParts(at).find((p) => p.type === 'timeZoneName')?.value ?? 'GMT+02:00';
  const m = /GMT([+-])(\d{2}):?(\d{2})?/.exec(part);
  if (!m) return 120;
  const sign = m[1] === '-' ? -1 : 1;
  return sign * (Number(m[2]) * 60 + Number(m[3] ?? 0));
}

/** بداية اليوم (نص الليل بتوقيت القاهرة) كلحظة UTC. day بصيغة YYYY-MM-DD */
export function cairoDayStart(day: string): Date {
  const [y, mo, d] = day.split('-').map(Number);
  const utcMidnight = Date.UTC(y, mo - 1, d);
  const offset = cairoOffsetMinutes(new Date(utcMidnight + 12 * 3_600_000));
  return new Date(utcMidnight - offset * 60_000);
}

/** بداية اليوم اللي بعده */
export function cairoDayEnd(day: string): Date {
  const [y, mo, d] = day.split('-').map(Number);
  const next = new Date(Date.UTC(y, mo - 1, d + 1)).toISOString().slice(0, 10);
  return cairoDayStart(next);
}
