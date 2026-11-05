import { describe, expect, it } from 'vitest';
import { formatPounds, parsePounds, sumPiasters } from './money';
import { normalizeEgyptPhone, toInternational } from './phone';
import { isValidImei, normalizeImei } from './imei';
import { STATUSES, TRANSITIONS, canTransition, nextStatusesFor } from './status';
import { cairoDay, cairoDayEnd, cairoDayStart, cairoOffsetMinutes, daysSince } from './dates';
import { diffChanges } from './audit';
import { checkPassword, isEmail } from './password';
import { COUNTRIES, REGIONS } from './regions';
import { computeDashboard, computeSeries, isLate, lastDays } from './dashboard';
import { buildSearchFilter, sanitizeSearch } from './search';

describe('الفلوس بالقروش', () => {
  it('يحوّل الجنيه لقروش من غير أعداد عشرية', () => {
    expect(parsePounds('150')).toBe(15000);
    expect(parsePounds('150.5')).toBe(15050);
    expect(parsePounds('150.50')).toBe(15050);
    expect(parsePounds('0.1')).toBe(10);
    expect(parsePounds('0.29')).toBe(29); // 0.29*100 في float = 28.999999999999996
    expect(parsePounds('1,250')).toBe(125000);
    expect(parsePounds(' 75 ')).toBe(7500);
  });
  it('يقبل الأرقام العربية والفاصلة العربية', () => {
    expect(parsePounds('١٥٠')).toBe(15000);
    expect(parsePounds('١٥٠٫٧٥')).toBe(15075);
  });
  it('يرفض المدخلات الغلط', () => {
    expect(parsePounds('')).toBeNull();
    expect(parsePounds('abc')).toBeNull();
    expect(parsePounds('-5')).toBeNull();
    expect(parsePounds('1.234')).toBeNull();
    expect(parsePounds('1e3')).toBeNull();
    expect(parsePounds('999999999')).toBeNull();
  });
  it('يعرض القروش بالجنيه', () => {
    expect(formatPounds(15050)).toBe('150.50');
    expect(formatPounds(15000)).toBe('150');
    expect(formatPounds(5)).toBe('0.05');
    expect(formatPounds(123456700)).toBe('1,234,567');
  });
  it('يجمع ويتجاهل null ويرفض الكسور', () => {
    expect(sumPiasters([100, null, 250, undefined])).toBe(350);
    expect(() => sumPiasters([1.5])).toThrow();
    expect(() => formatPounds(0.5)).toThrow();
  });
});

describe('رقم الموبايل المصري', () => {
  it('يوحّد الصيغ المختلفة', () => {
    expect(normalizeEgyptPhone('01012345678')).toBe('01012345678');
    expect(normalizeEgyptPhone('+20 101 234 5678')).toBe('01012345678');
    expect(normalizeEgyptPhone('00201112345678')).toBe('01112345678');
    expect(normalizeEgyptPhone('201212345678')).toBe('01212345678');
    expect(normalizeEgyptPhone('٠١٥١٢٣٤٥٦٧٨')).toBe('01512345678');
    expect(normalizeEgyptPhone('1012345678')).toBe('01012345678');
  });
  it('يرفض الأرقام الغلط', () => {
    expect(normalizeEgyptPhone('0101234567')).toBeNull();
    expect(normalizeEgyptPhone('01312345678')).toBeNull();
    expect(normalizeEgyptPhone('0223456789')).toBeNull();
    expect(normalizeEgyptPhone('')).toBeNull();
  });
  it('صيغة واتساب الدولية', () => {
    expect(toInternational('01012345678')).toBe('201012345678');
  });
});

describe('IMEI', () => {
  it('يتحقق برقم Luhn', () => {
    expect(isValidImei('490154203237518')).toBe(true);
    expect(isValidImei('49-015420-323751-8')).toBe(true);
    expect(isValidImei('490154203237519')).toBe(false);
    expect(isValidImei('12345')).toBe(false);
  });
  it('ينضّف الرقم', () => {
    expect(normalizeImei('٤٩٠ 154-203')).toBe('490154203');
  });
});

describe('حالات الجهاز', () => {
  it('فيه 10 حالات بالظبط وكل حالة ليها قواعد انتقال', () => {
    expect(STATUSES).toHaveLength(10);
    for (const s of STATUSES) {
      expect(TRANSITIONS[s]).toBeDefined();
      for (const t of TRANSITIONS[s]) expect(STATUSES).toContain(t);
    }
  });
  it('مسار الشغل الطبيعي مسموح', () => {
    const path = ['received', 'inspecting', 'in_repair', 'repaired', 'ready', 'delivered'] as const;
    for (let i = 0; i < path.length - 1; i++) expect(canTransition(path[i], path[i + 1])).toBe(true);
  });
  it('ممنوع القفز أو الرجوع من التسليم لأي حاجة غير الضمان', () => {
    expect(canTransition('received', 'delivered')).toBe(false);
    expect(canTransition('delivered', 'in_repair')).toBe(false);
    expect(canTransition('delivered', 'warranty_return')).toBe(true);
  });
  it('الفني ما يقدرش يسلّم', () => {
    expect(nextStatusesFor('ready', 'technician')).toEqual([]);
    expect(nextStatusesFor('ready', 'reception')).toEqual(['delivered']);
  });
});

describe('التواريخ بتوقيت القاهرة', () => {
  it('الساعة 11 بالليل UTC تبقى اليوم اللي بعده في القاهرة', () => {
    expect(cairoDay('2026-11-04T23:30:00Z')).toBe('2026-11-05');
    expect(cairoDay('2026-11-04T20:00:00Z')).toBe('2026-11-04');
  });
  it('بيراعي التوقيت الصيفي في مصر', () => {
    expect(cairoOffsetMinutes(new Date('2026-01-15T12:00:00Z'))).toBe(120);
    expect(cairoOffsetMinutes(new Date('2026-07-15T12:00:00Z'))).toBe(180);
    expect(cairoDayStart('2026-01-15').toISOString()).toBe('2026-01-14T22:00:00.000Z');
    expect(cairoDayStart('2026-07-15').toISOString()).toBe('2026-07-14T21:00:00.000Z');
    expect(cairoDayEnd('2026-12-31').toISOString()).toBe('2026-12-31T22:00:00.000Z');
  });
  it('يحسب الأيام', () => {
    expect(daysSince('2026-11-01T10:00:00Z', new Date('2026-11-09T10:00:01Z'))).toBe(8);
  });
});

describe('لوحة التحكم', () => {
  const now = new Date('2026-11-05T12:00:00Z');
  const dev = (o: Partial<Parameters<typeof computeDashboard>[0][number]>) => ({
    status: 'received' as const,
    received_at: '2026-11-05T08:00:00Z',
    delivered_at: null,
    final_cost: null,
    ...o,
  });

  it('يحسب المربعات الخمسة', () => {
    const stats = computeDashboard(
      [
        dev({}),
        dev({ status: 'in_repair', received_at: '2026-10-20T08:00:00Z' }),
        dev({ status: 'ready', received_at: '2026-11-01T08:00:00Z' }),
        dev({ status: 'delivered', received_at: '2026-10-01T08:00:00Z', delivered_at: '2026-11-05T09:00:00Z', final_cost: 25000 }),
        dev({ status: 'delivered', received_at: '2026-11-05T07:00:00Z', delivered_at: '2026-11-05T10:00:00Z', final_cost: 15050 }),
        dev({ status: 'delivered', received_at: '2026-11-01T07:00:00Z', delivered_at: '2026-11-04T10:00:00Z', final_cost: 99900 }),
      ],
      now,
    );
    expect(stats).toEqual({ today: 2, underRepair: 2, ready: 1, late: 1, revenueToday: 40050 });
  });
  it('المتأخر أكتر من 7 أيام بس، والمتسلّم مش متأخر', () => {
    expect(isLate({ status: 'in_repair', received_at: '2026-10-29T12:00:00Z' }, now)).toBe(false);
    expect(isLate({ status: 'in_repair', received_at: '2026-10-28T11:00:00Z' }, now)).toBe(true);
    expect(isLate({ status: 'delivered', received_at: '2026-01-01T00:00:00Z' }, now)).toBe(false);
  });
  it('جهاز اتسلّم بعد نص الليل بتوقيت القاهرة يتحسب في اليوم الجديد', () => {
    const s = computeDashboard(
      [dev({ status: 'delivered', delivered_at: '2026-11-04T22:30:00Z', final_cost: 1000 })],
      now,
    );
    expect(s.revenueToday).toBe(1000);
  });
});

describe('تنضيف البحث', () => {
  it('يشيل الرموز اللي ممكن تكسر الفلتر', () => {
    expect(sanitizeSearch('ahmed,status.eq.x')).toBe('ahmed status eq x');
    expect(sanitizeSearch('(a)*%')).toBe('a');
    expect(sanitizeSearch('٢٠٢٦-٠٠٠١')).toBe('2026-0001');
  });
  it('يبني الفلتر', () => {
    expect(buildSearchFilter('010', ['phone', 'imei'])).toBe('phone.ilike.*010*,imei.ilike.*010*');
    expect(buildSearchFilter('  ,, ', ['phone'])).toBeNull();
  });
});

describe('سجل النشاط: الفرق بين قبل وبعد', () => {
  it('يطلّع الحقول اللي اتغيرت بس ويتجاهل updated_at', () => {
    expect(
      diffChanges(
        { final_cost: null, estimated_cost: 15000, updated_at: 'a', id: '1' },
        { final_cost: 17550, estimated_cost: 15000, updated_at: 'b', id: '1' },
      ),
    ).toEqual([{ field: 'final_cost', before: null, after: 17550 }]);
    expect(diffChanges(null, { name: 'x' })).toEqual([{ field: 'name', before: null, after: 'x' }]);
  });
});

describe('قيم الـ sparkline لآخر 14 يوم', () => {
  const now = new Date('2026-11-05T12:00:00Z');
  it('بيحسب كل يوم لوحده بتوقيت القاهرة', () => {
    const s = computeSeries(
      [
        { status: 'in_repair', received_at: '2026-11-05T08:00:00Z', delivered_at: null, final_cost: null },
        { status: 'delivered', received_at: '2026-11-03T08:00:00Z', delivered_at: '2026-11-04T10:00:00Z', final_cost: 15050 },
        { status: 'in_repair', received_at: '2026-10-20T08:00:00Z', delivered_at: null, final_cost: null },
      ],
      [{ new_status: 'ready', created_at: '2026-11-04T09:00:00Z' }, { new_status: 'repaired', created_at: '2026-11-04T09:00:00Z' }],
      now,
    );
    expect(s.today).toHaveLength(14);
    expect(s.today.at(-1)).toBe(1);
    expect(s.today.at(-3)).toBe(1);
    expect(s.revenue.at(-2)).toBe(15050);
    expect(s.ready.at(-2)).toBe(1);
    expect(s.underRepair.at(-1)).toBe(2); // الجهاز المسلّم امبارح مش جوه المحل النهارده
    expect(s.underRepair.at(-3)).toBe(2); // يوم 3: جهاز أكتوبر + جهاز يوم 3 (جهاز يوم 5 لسه ما دخلش)
    expect(s.underRepair.at(-2)).toBe(1); // يوم 4: الجهاز اتسلّم في نفس اليوم، فاضل جهاز أكتوبر بس
    expect(s.late.at(-1)).toBe(1);
    expect(s.revenue.every(Number.isInteger)).toBe(true);
  });
  it('آخر يوم هو النهارده', () => {
    expect(lastDays(now, 14).at(-1)).toBe('2026-11-05');
    expect(lastDays(now, 14)).toHaveLength(14);
  });
});

describe('قوة كلمة السر والإيميل', () => {
  it('بتقيس القوة صح', () => {
    expect(checkPassword('').score).toBe(0);
    expect(checkPassword('abc').score).toBe(0);
    expect(checkPassword('abcdefgh').score).toBe(1);
    expect(checkPassword('abcdefg1').score).toBe(2);
    expect(checkPassword('Abcdefg1').score).toBe(3);
    expect(checkPassword('Abcdefg1!').score).toBe(4);
    expect(checkPassword('Ab1!').score).toBe(1); // قصيرة: مهما كان فيها
    expect(checkPassword('Abcdefg1!').rules).toEqual({ len: true, num: true, case: true, sym: true });
  });
  it('بيتحقق من الإيميل', () => {
    expect(isEmail('a@b.co')).toBe(true);
    expect(isEmail(' owner@shop.com ')).toBe(true);
    expect(isEmail('a@b')).toBe(false);
    expect(isEmail('ab.com')).toBe(false);
    expect(isEmail('')).toBe(false);
  });
});

describe('البلاد', () => {
  it('مصر بتملا الجنيه وتوقيت القاهرة', () => {
    expect(REGIONS.EG).toEqual({ currency: 'EGP', tz: 'Africa/Cairo', dial: '+20' });
    for (const c of COUNTRIES) expect(REGIONS[c].currency).toMatch(/^[A-Z]{3}$/);
  });
});

describe('ترجمة أخطاء قاعدة البيانات', () => {
  it('الكود بيتحول لرسالة باللغة الحالية', async () => {
    const { errorMessage } = await import('./errors');
    const i18n = (await import('../i18n')).default;
    await i18n.changeLanguage('ar');
    expect(errorMessage({ message: 'E_FINAL_COST_REQUIRED' })).toBe('لازم تكتب التكلفة النهائية قبل التسليم');
    await i18n.changeLanguage('en');
    expect(errorMessage({ message: 'E_FINAL_COST_REQUIRED' })).toBe('Enter the final cost before delivery');
    expect(errorMessage({ message: 'Invalid login credentials' })).toBe('Wrong email or password');
    expect(errorMessage({ message: 'something weird' })).toBe('something weird');
    await i18n.changeLanguage('ar');
  });
});
