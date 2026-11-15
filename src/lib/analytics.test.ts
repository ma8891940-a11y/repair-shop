import { describe, expect, it } from 'vitest';
import { change, derive, insights, rank, total, type KpiRaw } from './analytics';

const raw = (p: Partial<KpiRaw>): KpiRaw => ({
  branch_id: 'x', revenue: 0, cogs: 0, opex: 0, invoices: 0, devices_in: 0, devices_out: 0, repair_minutes: 0, returns: 0,
  stock_value: 0, stale_value: 0, stale_items: 0, receivables: 0, receivables_60: 0, goal_revenue: null, goal_profit: null, ...p,
});

describe('مؤشرات أداء الفروع (حساب يدوي)', () => {
  // فرع أ: إيراد 10,000 ج، تكلفة 6,000، مصروفات 1,000 ← ربح 3,000 = 30%
  const a = raw({ branch_id: 'a', revenue: 1_000_000, cogs: 600_000, opex: 100_000, invoices: 40, devices_out: 10, repair_minutes: 10 * 1440, returns: 1, stock_value: 500_000, stale_value: 50_000, stale_items: 2 });
  // فرع ب: إيراد 5,000، تكلفة 4,000، مصروفات 500 ← ربح 500 = 10%
  const b = raw({ branch_id: 'b', revenue: 500_000, cogs: 400_000, opex: 50_000, invoices: 25, devices_out: 5, repair_minutes: 5 * 2880, returns: 1, stock_value: 200_000, stale_value: 100_000, stale_items: 5, receivables_60: 30_000 });
  it('المشتقات بالظبط', () => {
    const k = derive(a);
    expect(k.profit).toBe(300_000);
    expect(k.margin).toBe(3000); // 30%
    expect(k.avgInvoice).toBe(25_000); // 250 ج
    expect(k.avgRepair).toBe(1440); // يوم
    expect(k.returnRate).toBe(1000); // 10%
    expect(k.expenseRatio).toBe(1000);
    expect(k.turnover).toBe(120); // 1.2 مرة
    expect(k.staleShare).toBe(1000);
    expect(derive(raw({})).margin).toBeNull();
  });
  it('المجموع من الأرقام الخام (مش متوسط النسب)', () => {
    const t = total([a, b]);
    expect(t.revenue).toBe(1_500_000);
    expect(t.profit).toBe(350_000);
    expect(t.margin).toBe(2333); // 350/1500
    expect(t.avgRepair).toBe(Math.round((10 * 1440 + 5 * 2880) / 15));
  });
  it('نقاط القوة والضعف من الأرقام', () => {
    const t = total([a, b]);
    const ib = insights(derive(b), t);
    expect(ib.find((i) => i.key === 'marginLowCogs')?.params.pct).toBe(13); // 10% قصاد 23.33%
    expect(ib.some((i) => i.key === 'repairSlow')).toBe(true);
    expect(ib.find((i) => i.key === 'staleStock')?.params).toEqual({ pct: 50, n: 5 });
    expect(ib.find((i) => i.key === 'oldDebts')?.params.amount).toBe(30_000);
    const ia = insights(derive(a), t, derive(raw({ revenue: 800_000 })), { top: true });
    expect(ia.map((i) => i.key)).toEqual(expect.arrayContaining(['topRevenue', 'marginHigh', 'repairFast', 'growth']));
    expect(ia.every((i) => i.kind === 'strength')).toBe(true);
    expect(insights(derive(raw({})), t)).toEqual([{ kind: 'weakness', key: 'noActivity', params: {} }]);
  });
  it('الترتيب والتغيّر عن الفترة اللي فاتت', () => {
    expect(rank([derive(b), derive(a)]).map((k) => k.branch_id)).toEqual(['a', 'b']);
    expect(change(1_200, 1_000)).toBe(2000);
    expect(change(500, 0)).toBeNull();
  });
});
