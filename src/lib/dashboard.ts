import { cairoDay, cairoDayEnd, daysSince } from './dates';
import { sumPiasters, type Piasters } from './money';
import { UNDER_REPAIR, type DeviceStatus } from './status';

export const LATE_AFTER_DAYS = 7;

export interface DashboardDevice {
  status: DeviceStatus;
  received_at: string;
  delivered_at: string | null;
  /** null لو المستخدم مش مسموح له يشوف الأسعار، أو لسه ما اتحددتش */
  final_cost: Piasters | null;
}

export interface DashboardStats {
  today: number;
  underRepair: number;
  ready: number;
  late: number;
  revenueToday: Piasters;
}

/** متأخر = لسه ما اتسلّمش للعميل، وعدّى عليه أكتر من 7 أيام من الاستلام */
export function isLate(d: Pick<DashboardDevice, 'status' | 'received_at'>, now: Date): boolean {
  return d.status !== 'delivered' && daysSince(d.received_at, now) > LATE_AFTER_DAYS;
}

export function computeDashboard(devices: DashboardDevice[], now: Date): DashboardStats {
  const todayKey = cairoDay(now);
  let today = 0;
  let underRepair = 0;
  let ready = 0;
  let late = 0;
  const revenue: Array<Piasters | null> = [];
  for (const d of devices) {
    if (cairoDay(d.received_at) === todayKey) today++;
    if (UNDER_REPAIR.includes(d.status)) underRepair++;
    if (d.status === 'ready') ready++;
    if (isLate(d, now)) late++;
    // إيراد اليوم = مجموع التكلفة النهائية للأجهزة اللي اتسلّمت النهارده
    if (d.status === 'delivered' && d.delivered_at && cairoDay(d.delivered_at) === todayKey) {
      revenue.push(d.final_cost);
    }
  }
  return { today, underRepair, ready, late, revenueToday: sumPiasters(revenue) };
}

/** صف من سجل الحالات (لحساب "بقى جاهز" في كل يوم) */
export interface StatusEvent {
  new_status: DeviceStatus;
  created_at: string;
}

export interface DashboardSeries {
  today: number[];
  underRepair: number[];
  ready: number[];
  late: number[];
  revenue: Piasters[];
}

/** آخر n يوم بتوقيت القاهرة (الأقدم الأول) */
export function lastDays(now: Date, n: number): string[] {
  const out: string[] = [];
  for (let i = n - 1; i >= 0; i--) out.push(cairoDay(new Date(now.getTime() - i * 86_400_000)));
  return [...new Set(out)];
}

/**
 * قيم آخر 14 يوم لكل كارت في لوحة التحكم (للـ sparkline).
 * - اليوم: عدد الأجهزة اللي اتسلّمت كل يوم.
 * - تحت الصيانة/متأخرة: عدد الأجهزة اللي كانت جوه المحل في آخر اليوم.
 * - جاهزة: عدد الأجهزة اللي بقت "جاهز" في اليوم ده (من سجل الحالات).
 * - الإيراد: مجموع التكلفة النهائية للأجهزة المسلّمة في اليوم ده.
 */
export function computeSeries(devices: DashboardDevice[], events: StatusEvent[], now: Date, n = 14): DashboardSeries {
  const days = lastDays(now, n);
  const idx = new Map(days.map((d, i) => [d, i]));
  const z = () => days.map(() => 0);
  const s: DashboardSeries = { today: z(), underRepair: z(), ready: z(), late: z(), revenue: z() };
  // نهاية كل يوم: نص الليل بتوقيت القاهرة، أو دلوقتي لو هو النهارده
  const ends = days.map((d, i) => (i === days.length - 1 ? now.getTime() : cairoDayEnd(d).getTime() - 1));
  for (const d of devices) {
    const r = idx.get(cairoDay(d.received_at));
    if (r !== undefined) s.today[r]++;
    const recT = new Date(d.received_at).getTime();
    const delT = d.delivered_at ? new Date(d.delivered_at).getTime() : Infinity;
    for (let i = 0; i < days.length; i++) {
      if (recT <= ends[i] && delT > ends[i]) {
        s.underRepair[i]++;
        if (ends[i] - recT > LATE_AFTER_DAYS * 86_400_000) s.late[i]++;
      }
    }
    if (d.status === 'delivered' && d.delivered_at) {
      const k = idx.get(cairoDay(d.delivered_at));
      if (k !== undefined && d.final_cost != null) s.revenue[k] = sumPiasters([s.revenue[k], d.final_cost]);
    }
  }
  for (const e of events) {
    if (e.new_status !== 'ready') continue;
    const k = idx.get(cairoDay(e.created_at));
    if (k !== undefined) s.ready[k]++;
  }
  return s;
}
