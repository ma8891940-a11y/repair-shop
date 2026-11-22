/** R2: الحضور والانصراف في الواجهة. الدقايق والتأخير جايين محسوبين من قاعدة البيانات (attendance_rows)، وهنا عرض بس */
export interface AttendanceRow {
  id: string;
  profile_id: string;
  full_name: string;
  branch_id: string | null;
  clock_in: string;
  clock_out: string | null;
  minutes: number | null;
  late_minutes: number;
  note: string | null;
  fix_reason: string | null;
}

/** الدقايق (عدد صحيح) ← ساعات ودقايق للعرض */
export function hm(minutes: number | null | undefined): { h: number; m: number } | null {
  if (minutes == null || !Number.isFinite(minutes) || minutes < 0) return null;
  const total = Math.trunc(minutes);
  return { h: Math.floor(total / 60), m: total % 60 };
}

export interface PersonTotal {
  profile_id: string;
  full_name: string;
  days: number;
  minutes: number;
  late_minutes: number;
  open: number;
}

/** إجمالي كل موظف: عدد الأيام (بتوقيت القاهرة)، والدقايق (المقفول بس)، والتأخير، والمفتوح */
export function totalsByPerson(rows: AttendanceRow[]): PersonTotal[] {
  const by = new Map<string, PersonTotal & { daySet: Set<string> }>();
  for (const r of rows) {
    const t = by.get(r.profile_id) ?? { profile_id: r.profile_id, full_name: r.full_name, days: 0, minutes: 0, late_minutes: 0, open: 0, daySet: new Set<string>() };
    t.daySet.add(new Date(r.clock_in).toLocaleDateString('en-CA', { timeZone: 'Africa/Cairo' }));
    if (r.minutes == null) t.open += 1;
    else t.minutes += r.minutes;
    t.late_minutes += r.late_minutes ?? 0;
    by.set(r.profile_id, t);
  }
  return [...by.values()]
    .map(({ daySet, ...t }) => ({ ...t, days: daySet.size }))
    .sort((a, b) => b.minutes - a.minutes || a.full_name.localeCompare(b.full_name));
}
