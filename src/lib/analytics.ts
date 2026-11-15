/**
 * U3: مؤشرات أداء الفروع ونقاط القوة والضعف، من الأرقام نفسها (من غير ذكاء اصطناعي، عشان تشتغل دايمًا).
 * المبالغ بالقروش (أعداد صحيحة)، والنسب بالـ basis points (1% = 100) عشان مفيش أعداد عشرية في الحسابات.
 */
export interface KpiRaw {
  branch_id: string;
  revenue: number;
  cogs: number;
  opex: number;
  invoices: number;
  devices_in: number;
  devices_out: number;
  repair_minutes: number;
  returns: number;
  stock_value: number;
  stale_value: number;
  stale_items: number;
  receivables: number;
  receivables_60: number;
  goal_revenue: number | null;
  goal_profit: number | null;
}

export interface Kpi extends KpiRaw {
  profit: number;
  /** هامش الربح (bp) */
  margin: number | null;
  /** متوسط الفاتورة (قروش) */
  avgInvoice: number | null;
  /** متوسط مدة الإصلاح (دقايق) */
  avgRepair: number | null;
  /** نسبة المرتجعات والضمان من المسلّم (bp) */
  returnRate: number | null;
  /** نسبة المصروفات للإيرادات (bp) */
  expenseRatio: number | null;
  /** دوران المخزون في الفترة: تكلفة المبيعات ÷ قيمة المخزون (×100) */
  turnover: number | null;
  /** نسبة البضاعة الراكدة من قيمة المخزون (bp) */
  staleShare: number | null;
}

const bp = (a: number, b: number) => (b > 0 ? Math.round((a * 10000) / b) : null);
const div = (a: number, b: number) => (b > 0 ? Math.round(a / b) : null);

export const toNum = (r: Record<string, unknown>): KpiRaw => ({
  branch_id: String(r.branch_id),
  revenue: Number(r.revenue ?? 0),
  cogs: Number(r.cogs ?? 0),
  opex: Number(r.opex ?? 0),
  invoices: Number(r.invoices ?? 0),
  devices_in: Number(r.devices_in ?? 0),
  devices_out: Number(r.devices_out ?? 0),
  repair_minutes: Number(r.repair_minutes ?? 0),
  returns: Number(r.returns ?? 0),
  stock_value: Number(r.stock_value ?? 0),
  stale_value: Number(r.stale_value ?? 0),
  stale_items: Number(r.stale_items ?? 0),
  receivables: Number(r.receivables ?? 0),
  receivables_60: Number(r.receivables_60 ?? 0),
  goal_revenue: r.goal_revenue == null ? null : Number(r.goal_revenue),
  goal_profit: r.goal_profit == null ? null : Number(r.goal_profit),
});

export function derive(r: KpiRaw): Kpi {
  const profit = r.revenue - r.cogs - r.opex;
  return {
    ...r,
    profit,
    margin: bp(profit, r.revenue),
    avgInvoice: div(r.revenue, r.invoices),
    avgRepair: div(r.repair_minutes, r.devices_out),
    returnRate: bp(r.returns, r.devices_out),
    expenseRatio: bp(r.opex, r.revenue),
    turnover: r.stock_value > 0 ? Math.round((r.cogs * 100) / r.stock_value) : null,
    staleShare: bp(r.stale_value, r.stock_value),
  };
}

/** المجموع: الأرقام الخام بتتجمع، والنسب بتتحسب من المجموع (مش متوسط النسب) */
export function total(rows: KpiRaw[]): Kpi {
  const keys = ['revenue', 'cogs', 'opex', 'invoices', 'devices_in', 'devices_out', 'repair_minutes', 'returns', 'stock_value', 'stale_value', 'stale_items', 'receivables', 'receivables_60'] as const;
  const sum = Object.fromEntries(keys.map((k) => [k, rows.reduce((a, r) => a + r[k], 0)])) as Record<(typeof keys)[number], number>;
  const goals = (k: 'goal_revenue' | 'goal_profit') => (rows.some((r) => r[k] != null) ? rows.reduce((a, r) => a + (r[k] ?? 0), 0) : null);
  return derive({ branch_id: 'all', ...sum, goal_revenue: goals('goal_revenue'), goal_profit: goals('goal_profit') });
}

/** التغيّر عن الفترة اللي فاتت (bp)، أو null لو مفيش أساس */
export const change = (cur: number, prev: number) => (prev !== 0 ? Math.round(((cur - prev) * 10000) / Math.abs(prev)) : null);

export interface Insight {
  kind: 'strength' | 'weakness';
  key: string;
  params: Record<string, string | number>;
}

/**
 * نقاط القوة والضعف لفرع مقارنة بالمحل كله (والفترة اللي فاتت).
 * pct = نسبة مئوية صحيحة جاهزة للعرض. الحدود: 5 نقط في الهامش والمصروفات والمرتجعات، و25% في مدة الإصلاح، و10% في نمو الإيرادات.
 */
export function insights(k: Kpi, all: Kpi, prev?: Kpi | null, opts: { top?: boolean } = {}): Insight[] {
  const out: Insight[] = [];
  const pts = (x: number) => Math.round(Math.abs(x) / 100);
  if (k.revenue <= 0 && k.devices_in === 0) return [{ kind: 'weakness', key: 'noActivity', params: {} }];
  if (opts.top) out.push({ kind: 'strength', key: 'topRevenue', params: {} });
  if (k.margin != null && all.margin != null) {
    const d = k.margin - all.margin;
    if (d <= -500) {
      // السبب: تكلفة البضاعة ولا المصروفات (اللي زايد عن المتوسط أكتر)
      const cogsGap = bp(k.cogs, k.revenue)! - (bp(all.cogs, all.revenue) ?? 0);
      const opexGap = (k.expenseRatio ?? 0) - (all.expenseRatio ?? 0);
      out.push({ kind: 'weakness', key: cogsGap >= opexGap ? 'marginLowCogs' : 'marginLowOpex', params: { pct: pts(d) } });
    } else if (d >= 500) out.push({ kind: 'strength', key: 'marginHigh', params: { pct: pts(d) } });
  }
  if (k.expenseRatio != null && all.expenseRatio != null && k.expenseRatio - all.expenseRatio >= 500) out.push({ kind: 'weakness', key: 'expensesHigh', params: { pct: pts(k.expenseRatio) } });
  if (k.avgRepair != null && all.avgRepair != null && all.avgRepair > 0) {
    const r = Math.round(((k.avgRepair - all.avgRepair) * 100) / all.avgRepair);
    if (r >= 25) out.push({ kind: 'weakness', key: 'repairSlow', params: { pct: r } });
    else if (r <= -25) out.push({ kind: 'strength', key: 'repairFast', params: { pct: -r } });
  }
  if (k.returnRate != null && k.returnRate - (all.returnRate ?? 0) >= 500) out.push({ kind: 'weakness', key: 'returnsHigh', params: { pct: pts(k.returnRate) } });
  if (k.staleShare != null && k.staleShare >= 3000) out.push({ kind: 'weakness', key: 'staleStock', params: { pct: pts(k.staleShare), n: k.stale_items } });
  if (k.receivables_60 > 0) out.push({ kind: 'weakness', key: 'oldDebts', params: { amount: k.receivables_60 } });
  if (prev) {
    const c = change(k.revenue, prev.revenue);
    if (c != null && c >= 1000) out.push({ kind: 'strength', key: 'growth', params: { pct: pts(c) } });
    else if (c != null && c <= -1000) out.push({ kind: 'weakness', key: 'decline', params: { pct: pts(c) } });
  }
  if (k.goal_revenue != null && k.goal_revenue > 0 && k.revenue >= k.goal_revenue) out.push({ kind: 'strength', key: 'goalHit', params: {} });
  return out;
}

/** ترتيب الفروع بصافي الربح (والإيرادات لو اتساووا) */
export function rank(rows: Kpi[]): Kpi[] {
  return [...rows].sort((a, b) => b.profit - a.profit || b.revenue - a.revenue);
}
