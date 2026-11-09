/**
 * اللي بيتبعت للمساعد من كل مكان (S3): حقول محددة، ونصوص متنضّفة، ومن غير اسم العميل ولا رقمه ولا عنوانه.
 * السيرفر بينضّف تاني وبياخد الحقول المسموحة بس (supabase/functions/_shared/kinds.ts).
 * وكمان الاقتراحات المحلية (من تاريخ المحل) اللي شغالة من غير نت ولا مفتاح.
 */
import { scrub } from './aiScrub';

const clean = (s: string | null | undefined, names: string[], max: number) => scrub(s ?? '', names).slice(0, max);

// ---------- الاستلام: اقتراحات من تاريخ المحل ----------
export interface PastDevice {
  brand: string;
  model: string;
  issue: string | null;
  final_cost: number | null;
}
export interface IssueHint {
  issue: string;
  count: number;
  /** متوسط التكلفة النهائية بالقروش (عدد صحيح، مقرّب لأقرب جنيه) */
  cost: number | null;
}

const norm = (s: string) => s.trim().replace(/\s+/g, ' ').toLowerCase();

/** أكتر الأعطال لنفس الماركة والموديل في المحل، ومتوسط تكلفتها (أعداد صحيحة بس) */
export function intakeHints(past: PastDevice[], brand: string, model: string, max = 5): IssueHint[] {
  const b = norm(brand);
  const m = norm(model);
  if (!m) return [];
  const groups = new Map<string, { issue: string; count: number; sum: number; n: number }>();
  for (const d of past) {
    if (norm(d.brand) !== b || norm(d.model) !== m || !d.issue?.trim()) continue;
    const k = norm(d.issue);
    const g = groups.get(k) ?? { issue: d.issue.trim(), count: 0, sum: 0, n: 0 };
    g.count++;
    if (d.final_cost != null && Number.isSafeInteger(Number(d.final_cost))) {
      g.sum += Number(d.final_cost);
      g.n++;
    }
    groups.set(k, g);
  }
  return [...groups.values()]
    .sort((x, y) => y.count - x.count || x.issue.localeCompare(y.issue))
    .slice(0, max)
    .map((g) => ({ issue: g.issue, count: g.count, cost: g.n ? Math.round(g.sum / g.n / 100) * 100 : null }));
}

export function intakeBody(o: { brand: string; model: string; issue: string; hints: IssueHint[]; names: string[] }) {
  return {
    device: clean(`${o.brand} ${o.model}`, o.names, 80),
    issue: clean(o.issue, o.names, 300),
    history: o.hints.map((h) => ({ issue: clean(h.issue, o.names, 120), count: h.count, cost: h.cost })),
  };
}

/** رد الاستلام: وصف العطل، وتكلفة تقريبية بالقروش (من جنيهات صحيحة)، وأسئلة للعميل */
export function readIntakeAnswer(v: Record<string, unknown> | null): { issue: string; cost: number | null; questions: string[] } | null {
  if (!v || typeof v.issue !== 'string' || !v.issue.trim()) return null;
  const n = (x: unknown) => (typeof x === 'number' && Number.isFinite(x) && x >= 0 ? Math.round(x) : null);
  const lo = n(v.cost_min);
  const hi = n(v.cost_max);
  const pounds = lo != null && hi != null ? Math.round((lo + hi) / 2) : (hi ?? lo);
  return {
    issue: v.issue.trim().slice(0, 300),
    cost: pounds != null ? pounds * 100 : null,
    questions: (Array.isArray(v.questions) ? v.questions : []).filter((q): q is string => typeof q === 'string').slice(0, 5),
  };
}

// ---------- المخزون: اقتراحات الشراء ----------
export interface StockItem {
  id: string;
  name: string;
  qty: number;
  min_qty: number | null;
  avg_cost: number | null;
  /** اللي اتباع/اتركب آخر 30 يوم */
  sold30?: number;
  supplier_id?: string | null;
}

/** الكمية المقترحة: تكفّي الحد الأدنى مرتين أو بيع شهر، أيهم أكتر (أعداد صحيحة) */
export function suggestQty(i: StockItem): number {
  const min = Math.max(0, i.min_qty ?? 0);
  const need = Math.max(min * 2, i.sold30 ?? 0) - Math.max(0, Math.floor(i.qty));
  return need > 0 ? need : 0;
}

export function purchaseSuggestions(items: StockItem[]): { item: StockItem; qty: number }[] {
  return items
    .map((item) => ({ item, qty: suggestQty(item) }))
    .filter((x) => x.qty > 0 && (x.item.qty <= (x.item.min_qty ?? 0) || (x.item.sold30 ?? 0) > x.item.qty))
    .sort((a, b) => b.qty - a.qty);
}

export function purchaseBody(items: StockItem[]) {
  return {
    items: items.slice(0, 40).map((i) => ({ name: scrub(i.name).slice(0, 60), qty: Math.floor(i.qty), min: i.min_qty ?? 0, sold30: i.sold30 ?? 0, cost: i.avg_cost != null ? Math.round(i.avg_cost) : null })),
  };
}

/** رد الشراء: أصناف موجودة بس (بالاسم بالظبط) وكميات صحيحة موجبة */
export function readPurchaseAnswer(v: Record<string, unknown> | null, items: StockItem[]): { lines: { item: StockItem; qty: number; why: string }[]; note: string } {
  const byName = new Map(items.map((i) => [scrub(i.name).slice(0, 60), i]));
  const lines = (Array.isArray(v?.lines) ? (v!.lines as unknown[]) : [])
    .map((l) => l as { name?: unknown; qty?: unknown; why?: unknown })
    .map((l) => ({ item: byName.get(String(l.name ?? '')), qty: typeof l.qty === 'number' && Number.isFinite(l.qty) ? Math.round(l.qty) : 0, why: typeof l.why === 'string' ? l.why.slice(0, 160) : '' }))
    .filter((l): l is { item: StockItem; qty: number; why: string } => !!l.item && l.qty > 0 && l.qty <= 10_000);
  return { lines, note: typeof v?.note === 'string' ? v.note.slice(0, 400) : '' };
}

// ---------- المالية: أرقام مجمّعة بس ----------
const FIN = ['cash', 'receivables', 'payables', 'inventory', 'revenue', 'expenses', 'profit', 'net_worth', 'delivered'] as const;
export function financeNumbers(p: Partial<Record<(typeof FIN)[number], number | string | null>>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k of FIN) {
    const v = Number(p[k]);
    if (p[k] != null && Number.isSafeInteger(v)) out[k] = v;
  }
  return out;
}

// ---------- واتساب: مسودة بمتغيرات من غير أي اسم ولا رقم ----------
export function whatsappBody(o: { purpose: string; status: string; tone?: string; note?: string; names: string[] }) {
  return { purpose: o.purpose.slice(0, 30), device_status: o.status.slice(0, 30), tone: (o.tone ?? '').slice(0, 30), note: clean(o.note, o.names, 200) };
}

// ---------- التقارير: أسماء الفنيين بتتشفّر (فني 1، فني 2) وبترجع في الرد ----------
export interface ReportRow {
  label: string;
  values: { k: string; n: number; money?: boolean }[];
}
export function anonymizeRows(rows: ReportRow[], names: string[], prefix: string): { rows: ReportRow[]; restore: (s: string) => string } {
  const map = new Map<string, string>();
  names.filter(Boolean).forEach((n, i) => map.set(n, `${prefix} ${i + 1}`));
  const hide = (s: string) => {
    let x = s;
    for (const [n, code] of [...map.entries()].sort((a, b) => b[0].length - a[0].length)) x = x.split(n).join(code);
    return scrub(x);
  };
  const out = rows.map((r) => ({ label: hide(r.label), values: r.values.filter((v) => Number.isSafeInteger(v.n)).map((v) => ({ ...v, k: v.k.slice(0, 30) })) }));
  const restore = (s: string) => {
    let x = s;
    // الأطول الأول (فني 12 قبل فني 1)
    for (const [n, code] of [...map.entries()].sort((a, b) => b[1].length - a[1].length)) x = x.split(code).join(n);
    return x;
  };
  return { rows: out, restore };
}

/** رد JSON من الموديل (ساعات بيلفّه في ```json): بيرجع object أو null. نفس parseJsonAnswer على السيرفر */
export function parseJsonAnswer(text: string): Record<string, unknown> | null {
  const m = /\{[\s\S]*\}/.exec(text.replace(/```(?:json)?/g, ''));
  if (!m) return null;
  try {
    const v = JSON.parse(m[0]);
    return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

// ---------- آخر حماية قبل ما أي طلب يخرج ----------
// أسماء العملاء اللي ظاهرة على الشاشة دلوقتي (الاستلام، وصفحة الجهاز، وملف العميل، والقوايم).
// أي نص في أي طلب للمساعد بيتنضّف منها ومن الأرقام والإيميلات، حتى لو المستخدم كتبها بنفسه في سؤال.
const onScreen = new Map<string, number>();
export function addSensitive(names: (string | null | undefined)[]): () => void {
  const list = names.map((n) => n?.trim() ?? '').filter((n) => n.length >= 2);
  for (const n of list) onScreen.set(n, (onScreen.get(n) ?? 0) + 1);
  return () => {
    for (const n of list) {
      const c = (onScreen.get(n) ?? 1) - 1;
      if (c <= 0) onScreen.delete(n);
      else onScreen.set(n, c);
    }
  };
}
export function sensitiveNames(): string[] {
  return [...onScreen.keys()];
}
/** كل النصوص جوه الطلب (حتى المتداخلة) متنضّفة. الأرقام والقيم المنطقية زي ما هي */
export function deepScrub<T>(v: T, names: string[]): T {
  if (typeof v === 'string') return scrub(v, names) as T;
  if (Array.isArray(v)) return v.map((x) => deepScrub(x, names)) as T;
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v as Record<string, unknown>).map(([k, x]) => [k, deepScrub(x, names)])) as T;
  return v;
}
