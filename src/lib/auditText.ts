/**
 * البند 11: سجل النشاط بجمل عربي مفهومة، وكل سطر فيه رابط للحاجة اللي اتغيّرت.
 * ممنوع يظهر في الواجهة العربي أي اسم جدول أو عمود أو كلمة إنجليزي من قاعدة البيانات:
 * - الجداول والعمليات والحقول ليها ترجمة. اللي مالوش ترجمة بيظهر بكلمة عامة ("سجل"، "عملية")، مش باسمه.
 * - الحقول التقنية (المعرّفات، والأوقات الداخلية، والتوكن) ما بتظهرش أصلًا.
 */
export interface AuditRow {
  id: string;
  actor_id: string | null;
  action: string;
  entity: string;
  entity_id: string | null;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  created_at: string;
}

/** الحقول اللي ما ليهاش معنى لصاحب المحل (معرّفات، وتوكن، وأوقات داخلية...) */
export function isTechnicalField(k: string): boolean {
  return /^(id|shop_id|created_at|updated_at|idem_key|tracking_token|intake_signature|keywords|steps|extras|search_text)$/.test(k) || /_id$/.test(k) || /(hash|token|secret|encrypted|cipher|nonce)/.test(k);
}

type T = (key: string, opts?: Record<string, unknown>) => string;

/** الترجمة أو "" لو مفيش (من غير ما يرجع المفتاح الإنجليزي أبدًا) */
const tr = (t: T, key: string, opts: Record<string, unknown> = {}) => {
  const v = t(key, { ...opts, defaultValue: '' });
  return v && v !== key ? v : '';
};

export function entityLabel(t: T, entity: string): string {
  return tr(t, `audit.entities.${entity}`) || t('audit.entities._other');
}
export function actionLabel(t: T, action: string): string {
  return tr(t, `audit.actions.${action}`) || t('audit.actions._other');
}
export function fieldLabel(t: T, field: string): string {
  return tr(t, `audit.fields.${field}`);
}

/** المرجع اللي بيتعرف بيه السطر: رقم الطلب، أو الاسم، أو رقم القيد.
 *  الحسابات والمسارات والتخصصات الأساسية ليها كود (salaries_payable، micro...) بيتترجم، وعمره ما بيظهر كده */
export function refOf(r: AuditRow, t?: T): string {
  const v = (r.after ?? r.before ?? {}) as Record<string, unknown>;
  for (const k of ['order_no', 'name', 'full_name', 'label']) if (typeof v[k] === 'string' && v[k]) return String(v[k]);
  if (typeof v.entry_no === 'number' || typeof v.entry_no === 'string') return `#${v.entry_no}`;
  if (typeof v.code === 'string' && v.code && t) {
    const ns = r.entity === 'accounts' ? 'ledger.acc' : r.entity === 'routes' ? 'tech.routes' : r.entity === 'specialties' ? 'tech.spec' : '';
    return ns ? tr(t, `${ns}.${v.code}`) : '';
  }
  return '';
}

/** رابط للحاجة نفسها (لو ليها شاشة) */
export function linkOf(r: AuditRow): string | null {
  const v = (r.after ?? r.before ?? {}) as Record<string, unknown>;
  const id = r.entity_id;
  const dev = typeof v.device_id === 'string' ? v.device_id : null;
  switch (r.entity) {
    case 'devices':
      return id ? `/devices/${id}` : null;
    case 'device_costs':
    case 'device_notes':
    case 'device_photos':
    case 'device_passcodes':
    case 'device_checks':
    case 'repair_steps':
    case 'status_log':
    case 'quote_decisions':
      return dev ? `/devices/${dev}` : null;
    case 'customers':
      return id ? `/customers/${id}` : null;
    case 'journal_entries':
      return id ? `/finance/entry/${id}` : null;
    case 'payments':
      return typeof v.entry_id === 'string' ? `/finance/entry/${v.entry_id}` : dev ? `/devices/${dev}` : null;
    case 'accounts':
      return id && v.kind === 'cashbox' ? `/finance/cashbox/${id}` : '/finance';
    case 'suppliers':
      return id ? `/finance/supplier/${id}` : null;
    case 'partners':
      return id ? `/finance/partner/${id}` : '/partners';
    case 'items':
    case 'purchases':
    case 'stock_moves':
      return '/inventory';
    case 'profiles':
    case 'staff_invites':
      return '/users';
    case 'shops':
    case 'shop_branding':
    case 'issue_presets':
    case 'labor_rates':
    case 'message_templates':
      return '/settings';
    case 'shop_lists':
      return '/settings?tab=lists';
    case 'routes':
    case 'specialties':
      return '/settings?tab=tech';
    default:
      return null;
  }
}

export interface Change {
  field: string;
  label: string;
  before: unknown;
  after: unknown;
}

/** التغييرات اللي تتقري: الحقول التقنية بتتشال، واللي مالوش ترجمة بيتعدّ بس ("وبيانات تانية") */
export function readableChanges(t: T, before: Record<string, unknown> | null, after: Record<string, unknown> | null): { changes: Change[]; other: number } {
  if (!before || !after) return { changes: [], other: 0 };
  const changes: Change[] = [];
  let other = 0;
  for (const k of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (isTechnicalField(k)) continue;
    if (JSON.stringify(before[k] ?? null) === JSON.stringify(after[k] ?? null)) continue;
    const label = fieldLabel(t, k);
    if (label) changes.push({ field: k, label, before: before[k], after: after[k] });
    else other++;
  }
  return { changes, other };
}

/** الجملة: "أحمد غيّر حالة الجهاز 2026-0002 من «تحت الفحص» لـ «جاهز»" وهكذا */
export function auditSentence(t: T, r: AuditRow, who: string, show: (field: string, v: unknown) => string): string {
  const what = entityLabel(t, r.entity);
  const ref = refOf(r, t);
  const target = ref ? `${what} ${ref}` : what;
  // تغيير الحالة له جملة لوحده
  if (r.action === 'update' && r.before && r.after && r.before.status !== r.after.status && r.entity === 'devices') {
    return t('audit.sentence.status', { who, target, from: show('status', r.before.status), to: show('status', r.after.status) });
  }
  if (r.action === 'update' && r.before && r.after && !r.before.deleted_at && r.after.deleted_at) return t('audit.sentence.soft_delete', { who, target });
  const key = tr(t, `audit.sentence.${r.action}`, { who, target }) ? `audit.sentence.${r.action}` : 'audit.sentence._other';
  return t(key, { who, target, action: actionLabel(t, r.action) });
}
