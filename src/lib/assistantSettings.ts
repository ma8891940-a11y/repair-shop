/**
 * إعدادات المساعد (shops.extras.assistant). نفس الافتراضي في قاعدة البيانات (0033 assistant_settings)،
 * وفيه اختبار بيقارنهم. قاعدة البيانات هي اللي بتطبّقهم فعلًا، والشاشة بتعرضهم بس.
 */
export const AREAS = ['tech', 'intake', 'inventory', 'finance', 'customers', 'reports', 'screen'] as const;
export type AssistArea = (typeof AREAS)[number];

export interface AssistantSettings {
  enabled: boolean;
  areas: Record<AssistArea, boolean>;
  staff: { reception: boolean; technician: boolean };
  /** حد يومي للمحل (null = حد الخطة) */
  daily: number | null;
}

export const DEFAULT_ASSISTANT: AssistantSettings = {
  enabled: true,
  areas: { tech: true, intake: true, inventory: true, finance: false, customers: true, reports: true, screen: true },
  staff: { reception: true, technician: true },
  daily: null,
};

/** مين يقدر يستخدم كل مكان حسب دوره (نفس assistant_area_roles في قاعدة البيانات) */
export const AREA_ROLES: Record<AssistArea, ('owner' | 'reception' | 'technician')[]> = {
  tech: ['owner', 'reception', 'technician'],
  screen: ['owner', 'reception', 'technician'],
  intake: ['owner', 'reception'],
  customers: ['owner', 'reception'],
  inventory: ['owner'],
  finance: ['owner'],
  reports: ['owner'],
};

export function readAssistant(extras: unknown): AssistantSettings {
  const a = ((extras && typeof extras === 'object' ? (extras as Record<string, unknown>).assistant : null) ?? {}) as Record<string, unknown>;
  const b = (v: unknown, d: boolean) => (typeof v === 'boolean' ? v : d);
  const areas = (a.areas ?? {}) as Record<string, unknown>;
  const staff = (a.staff ?? {}) as Record<string, unknown>;
  return {
    enabled: b(a.enabled, DEFAULT_ASSISTANT.enabled),
    areas: Object.fromEntries(AREAS.map((k) => [k, b(areas[k], DEFAULT_ASSISTANT.areas[k])])) as Record<AssistArea, boolean>,
    staff: { reception: b(staff.reception, true), technician: b(staff.technician, true) },
    daily: typeof a.daily === 'number' && Number.isFinite(a.daily) && a.daily >= 0 ? Math.floor(a.daily) : null,
  };
}

/** المستخدم ده يقدر يستخدم المكان ده؟ (للعرض بس: القاعدة بتتأكد تاني) */
export function canUse(s: AssistantSettings, area: AssistArea, role: string): boolean {
  if (!s.enabled || !s.areas[area]) return false;
  if (!(AREA_ROLES[area] as string[]).includes(role)) return false;
  return role === 'owner' || (role === 'reception' ? s.staff.reception : role === 'technician' ? s.staff.technician : false);
}
