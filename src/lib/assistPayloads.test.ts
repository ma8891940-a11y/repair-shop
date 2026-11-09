import { describe, expect, it } from 'vitest';
import { addSensitive, deepScrub, sensitiveNames, anonymizeRows, financeNumbers, intakeBody, intakeHints, purchaseBody, purchaseSuggestions, readIntakeAnswer, readPurchaseAnswer, suggestQty, whatsappBody } from './assistPayloads';

// S3: اللي بيخرج من المتصفح للمساعد: من غير اسم العميل ولا رقمه، والاقتراحات المحلية بأعداد صحيحة
const NAME = 'أحمد السيد';
const NAME2 = 'سامح عبد الله';
const PHONE = '01099998888';

describe('الاستلام', () => {
  const past = [
    { brand: 'Samsung', model: 'A54', issue: 'شاشة مكسورة', final_cost: 150_000 },
    { brand: 'samsung', model: ' a54 ', issue: 'شاشة  مكسورة', final_cost: 170_050 },
    { brand: 'Samsung', model: 'A54', issue: 'مش بيشحن', final_cost: null },
    { brand: 'Apple', model: 'A54', issue: 'شاشة مكسورة', final_cost: 999_900 },
  ];
  it('أكتر عطل للموديل ده في المحل، ومتوسط تكلفته بالقروش (مقرّب لجنيه، عدد صحيح)', () => {
    const h = intakeHints(past, 'Samsung', 'A54');
    expect(h[0]).toEqual({ issue: 'شاشة مكسورة', count: 2, cost: 160_000 });
    expect(h[1]).toEqual({ issue: 'مش بيشحن', count: 1, cost: null });
    expect(h.every((x) => x.cost == null || Number.isSafeInteger(x.cost))).toBe(true);
    expect(intakeHints(past, 'Samsung', '')).toEqual([]);
  });
  it('الطلب: من غير اسم العميل ولا رقمه حتى لو مكتوبين في العطل', () => {
    const b = JSON.stringify(intakeBody({ brand: 'Samsung', model: 'A54', issue: `${NAME} بيقول مش بيشحن، رقمه ${PHONE}`, hints: [{ issue: `أحمد كان عنده شاشة ${PHONE}`, count: 1, cost: 100 }], names: [NAME] }));
    expect(b).not.toContain('أحمد');
    expect(b).not.toContain(PHONE);
    expect(b).toContain('مش بيشحن');
  });
  it('الرد: التكلفة بتتحول قروش من جنيهات صحيحة، والرد الغلط بيتجاهل', () => {
    expect(readIntakeAnswer({ issue: ' شاشة ', cost_min: 1500, cost_max: 1800, questions: ['امتى وقع؟', 3] })).toEqual({ issue: 'شاشة', cost: 165_000, questions: ['امتى وقع؟'] });
    expect(readIntakeAnswer({ issue: 'x', cost_min: 1499.6 })).toEqual({ issue: 'x', cost: 150_000, questions: [] });
    expect(readIntakeAnswer({ cost_min: 1 })).toBeNull();
    expect(readIntakeAnswer(null)).toBeNull();
  });
});

describe('الشراء', () => {
  const items = [
    { id: '1', name: 'بطارية A54', qty: 1, min_qty: 3, avg_cost: 30_000, sold30: 2 },
    { id: '2', name: 'شاشة A54', qty: 5, min_qty: 2, avg_cost: 90_000, sold30: 9 },
    { id: '3', name: 'جراب', qty: 10, min_qty: 2, avg_cost: 2_000, sold30: 1 },
  ];
  it('الكمية: تكفّي الحد الأدنى مرتين أو بيع شهر', () => {
    expect(suggestQty(items[0])).toBe(5);
    expect(suggestQty(items[1])).toBe(4);
    expect(suggestQty(items[2])).toBe(0);
    expect(purchaseSuggestions(items).map((x) => [x.item.id, x.qty])).toEqual([
      ['1', 5],
      ['2', 4],
    ]);
  });
  it('الرد: أصناف موجودة بس وكميات صحيحة', () => {
    const r = readPurchaseAnswer({ lines: [{ name: 'بطارية A54', qty: 4.4, why: 'ناقصة' }, { name: 'صنف مش موجود', qty: 3 }, { name: 'شاشة A54', qty: -2 }], note: 'تمام' }, items);
    expect(r.lines.map((l) => [l.item.id, l.qty])).toEqual([['1', 4]]);
    expect(r.note).toBe('تمام');
    expect(purchaseBody(items).items[0]).toEqual({ name: 'بطارية A54', qty: 1, min: 3, sold30: 2, cost: 30_000 });
  });
});

describe('المالية وواتساب والتقارير', () => {
  it('المالية: أرقام مجمّعة صحيحة بس من القايمة المسموحة', () => {
    expect(financeNumbers({ cash: 100, profit: '250', revenue: 1.5, expenses: null } as never)).toEqual({ cash: 100, profit: 250 });
  });
  it('واتساب: من غير اسم ولا رقم', () => {
    const b = JSON.stringify(whatsappBody({ purpose: 'ready', status: 'ready', note: `قول لـ ${NAME} يتصل على ${PHONE}`, names: [NAME] }));
    expect(b).not.toContain('أحمد');
    expect(b).not.toContain(PHONE);
  });
  it('التقارير: أسماء الفنيين بتتشفّر في الطلب، وبترجع في الرد', () => {
    const { rows, restore } = anonymizeRows([{ label: 'محمد علي', values: [{ k: 'devices', n: 3 }, { k: 'bad', n: 1.5 }] }, { label: 'علي', values: [] }], ['محمد علي', 'علي'], 'فني');
    expect(rows[0].label).toBe('فني 1');
    expect(rows[1].label).toBe('فني 2');
    expect(rows[0].values).toEqual([{ k: 'devices', n: 3 }]);
    expect(JSON.stringify(rows)).not.toContain('محمد');
    expect(restore('فني 1 أحسن من فني 2')).toBe('محمد علي أحسن من علي');
  });
});

describe('آخر حماية قبل الخروج', () => {
  it('أسماء العملاء الظاهرة على الشاشة والأرقام بتتشال من كل النصوص، حتى المتداخلة', () => {
    const off = addSensitive([NAME2, null, ' ']);
    const off2 = addSensitive([NAME2]);
    expect(sensitiveNames()).toEqual([NAME2]);
    const out = deepScrub({ question: `العميل ${NAME2} رقمه ${PHONE}`, rows: [{ label: `سامح ${PHONE}`, n: 5 }], ok: true }, sensitiveNames());
    const j = JSON.stringify(out);
    expect(j).not.toContain('سامح');
    expect(j).not.toContain(PHONE);
    expect(out.rows[0].n).toBe(5);
    expect(out.ok).toBe(true);
    off();
    expect(sensitiveNames()).toEqual([NAME2]);
    off2();
    expect(sensitiveNames()).toEqual([]);
  });
});
