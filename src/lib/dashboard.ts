import { cairoDay, daysSince } from './dates';
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
