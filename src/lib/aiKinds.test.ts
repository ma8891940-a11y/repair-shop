import { describe, expect, it } from 'vitest';
import { buildRequest, KIND_AREA, KINDS, parseJsonAnswer } from '../../supabase/functions/_shared/kinds';

// S3: كل نوع سؤال بيخرج منه الحقول المسموحة بس، ومن غير أي بيانات عميل
const PHONE = '01099998888';
const leak = (s: string) => [PHONE, '0109 999 8888', 'ahmed@x.com', 'http://x.y/z', '356938035643809'].some((x) => s.includes(x));
const dirty = `مش بيشحن، كلّم العميل على ${PHONE} أو 0109 999 8888 أو ahmed@x.com http://x.y/z IMEI 356938035643809`;

describe('أنواع أسئلة المساعد', () => {
  it('كل نوع ليه مكان، والمكان هو اللي قاعدة البيانات بتتأكد منه', () => {
    expect(KIND_AREA).toEqual({ diagnose: 'tech', intake: 'intake', purchase: 'inventory', finance_qa: 'finance', finance_week: 'finance', whatsapp: 'customers', report: 'reports', screen: 'screen' });
    expect(buildRequest({ kind: 'admin', issue: 'x' })).toBeNull();
    // من غير kind: التشخيص (الطلب القديم بيفضل شغال)
    expect(buildRequest({ device: 'A54', issue: 'شاشة' })?.kind).toBe('diagnose');
  });

  it('مفيش رقم ولا إيميل ولا رابط ولا IMEI بيخرج، في أي حقل نصي، في كل الأنواع', () => {
    const bodies: Record<string, unknown>[] = [
      { kind: 'diagnose', device: `A54 ${PHONE}`, issue: dirty, name: 'أحمد', phone: PHONE, address: 'شارع 9' },
      { kind: 'intake', device: 'A54', issue: dirty, history: [{ issue: dirty, count: 2, cost: 50000 }], customer: { name: 'أحمد', phone: PHONE } },
      { kind: 'purchase', items: [{ name: `شاشة ${PHONE}`, qty: 1, min: 3, sold30: 4, cost: 30000 }] },
      { kind: 'finance_qa', question: dirty, numbers: { cash: 100000, profit: 5000, phone: PHONE } },
      { kind: 'finance_week', numbers: { revenue: 100000 }, previous: { revenue: 90000 } },
      { kind: 'whatsapp', purpose: 'ready', device_status: 'ready', note: dirty, name: 'أحمد', phone: PHONE },
      { kind: 'report', title: 'الفنيين', period: '1-7', rows: [{ label: `فني 1 ${PHONE}`, values: [{ k: 'devices', n: 3 }, { k: 'revenue', n: 150000, money: true }] }] },
      { kind: 'screen', screen: 'devices', question: dirty, context: [{ k: 'ready', n: 4 }] },
    ];
    expect(bodies.map((b) => b.kind)).toEqual([...KINDS]);
    for (const b of bodies) {
      const r = buildRequest(b);
      expect(r, String(b.kind)).not.toBeNull();
      expect(leak(r!.user), String(b.kind)).toBe(false);
      // الحقول اللي مش مسموحة (اسم، عنوان) ما بتوصلش أصلًا
      expect(r!.user).not.toContain('أحمد');
      expect(r!.user).not.toContain('شارع 9');
    }
  });

  it('الأرقام: أعداد صحيحة بس، والفلوس بتروح بالجنيه، والمفاتيح المالية المسموحة بس', () => {
    const r = buildRequest({ kind: 'finance_qa', question: 'الربح كام؟', numbers: { profit: 123456, cash: 10.5, secret: 99, receivables: '5000' } })!;
    expect(r.user).toContain('profit: 1235');
    expect(r.user).not.toContain('cash');
    expect(r.user).not.toContain('secret');
    expect(r.user).not.toContain('receivables');
    expect(buildRequest({ kind: 'finance_qa', question: 'x', numbers: {} })).toBeNull();
  });

  it('الردود اللي محتاجة "تطبيق" بتطلب JSON، والباقي نص', () => {
    expect(buildRequest({ kind: 'intake', device: 'A54' })!.json).toBe(true);
    expect(buildRequest({ kind: 'purchase', items: [{ name: 'بطارية', qty: 0 }] })!.json).toBe(true);
    expect(buildRequest({ kind: 'whatsapp', purpose: 'ready' })!.json).toBe(false);
    expect(parseJsonAnswer('```json\n{"issue": "شاشة", "cost_min": 500}\n```')).toEqual({ issue: 'شاشة', cost_min: 500 });
    expect(parseJsonAnswer('مش JSON')).toBeNull();
    expect(parseJsonAnswer('[1,2]')).toBeNull();
  });

  it('الشاشة: اسم شاشة مش معروف بيتحول "other"، والسياق أرقام بس', () => {
    const r = buildRequest({ kind: 'screen', screen: '<script>', question: 'أعمل إيه؟', context: [{ k: 'x', n: 'نص' }, { k: 'late', n: 2 }] })!;
    expect(r.user).toContain('الشاشة: other');
    expect(r.user).toContain('late: 2');
    expect(r.user).not.toContain('x: نص');
  });
});
