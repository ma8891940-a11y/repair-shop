// حالات الجهاز العشرة (الحالة 9 في المواصفات اتقسمت لحالتين بقرار صاحب المشروع)
// مهم: نفس قواعد الانتقال موجودة في قاعدة البيانات (دالة is_valid_transition)،
// ولو اتغيّرت هنا لازم تتغيّر هناك كمان. فيه اختبار بيتأكد إنهم متطابقين.

export const STATUSES = [
  'received',
  'inspecting',
  'awaiting_approval',
  'awaiting_part',
  'in_repair',
  'repaired',
  'ready',
  'delivered',
  'warranty_return',
  'unrepairable',
] as const;

export type DeviceStatus = (typeof STATUSES)[number];

export const STATUS_LABELS: Record<DeviceStatus, string> = {
  received: 'تم الاستلام',
  inspecting: 'جاري الفحص',
  awaiting_approval: 'في انتظار موافقة العميل',
  awaiting_part: 'في انتظار قطعة غيار',
  in_repair: 'جاري الصيانة',
  repaired: 'تم الإصلاح',
  ready: 'جاهز للاستلام',
  delivered: 'تم التسليم',
  warranty_return: 'مرتجع (ضمان)',
  unrepairable: 'لم يُصلَّح',
};

export const TRANSITIONS: Record<DeviceStatus, readonly DeviceStatus[]> = {
  received: ['inspecting', 'unrepairable'],
  inspecting: ['awaiting_approval', 'awaiting_part', 'in_repair', 'unrepairable'],
  awaiting_approval: ['in_repair', 'awaiting_part', 'unrepairable'],
  awaiting_part: ['in_repair', 'unrepairable'],
  in_repair: ['repaired', 'awaiting_part', 'unrepairable'],
  repaired: ['ready', 'in_repair'],
  ready: ['delivered'],
  delivered: ['warranty_return'],
  warranty_return: ['inspecting', 'in_repair'],
  unrepairable: ['delivered'],
};

export type Role = 'owner' | 'reception' | 'technician';

export function isStatus(v: unknown): v is DeviceStatus {
  return typeof v === 'string' && (STATUSES as readonly string[]).includes(v);
}

export function canTransition(from: DeviceStatus, to: DeviceStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

/** الأزرار اللي تظهر للمستخدم حسب دوره. الفني ما يسلّمش أجهزة. */
export function nextStatusesFor(from: DeviceStatus, role: Role): DeviceStatus[] {
  return TRANSITIONS[from].filter((to) => !(role === 'technician' && to === 'delivered'));
}

/** الحالات اللي معناها إن الجهاز لسه "تحت الصيانة" جوه المحل */
export const UNDER_REPAIR: readonly DeviceStatus[] = [
  'received',
  'inspecting',
  'awaiting_approval',
  'awaiting_part',
  'in_repair',
  'repaired',
  'warranty_return',
];
