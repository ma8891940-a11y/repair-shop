import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { assistantPayload, scrub } from './aiScrub';
import { matchFaults } from './faultGuide';

describe('المساعد الذكي: من غير بيانات العميل', () => {
  it('بيشيل أرقام الموبايل والـ IMEI والإيميل والروابط والأسماء (حتى بالأرقام العربية)', () => {
    const s = scrub('العميل أحمد علي رقمه ٠١٠١٢٣٤٥٦٧٨ والـ IMEI 490154203237518 وإيميله a.b@x.com ولينك https://x.co/y', ['أحمد علي']);
    expect(s).not.toMatch(/\d{7,}/);
    expect(s).not.toContain('أحمد علي');
    expect(s).not.toContain('a.b@x.com');
    expect(s).not.toContain('https://');
    expect(s).toContain('[number]');
    expect(s).toContain('[name]');
    expect(scrub('010 1234 5678')).toBe('[number]');
  });
  it('اسم العميل بيتشال كامل أو أي جزء منه (زي الاسم الأول بس)', () => {
    const s = scrub('سامح قال إن الجهاز وقع، وأخوه عبد الله جابه', ['سامح عبد الله']);
    expect(s).not.toContain('سامح');
    expect(s).not.toContain('عبد الله');
    expect(s).toContain('الجهاز وقع');
  });
  it('بيسيب الكلام الفني زي ما هو (موديلات وأرقام قصيرة)', () => {
    expect(scrub('Samsung A54 الشاشة فيها خطوط بعد وقعة من 2 متر، والبطارية 85%')).toBe('Samsung A54 الشاشة فيها خطوط بعد وقعة من 2 متر، والبطارية 85%');
  });
  it('الطلب فيه الموديل ووصف العطل بس، ومتنضّفين', () => {
    const p = assistantPayload({ brand: 'iPhone', model: '13', issue: 'مش بيشحن، رقم العميل 01099998888 والعميلة منى', names: ['منى'] });
    expect(Object.keys(p).sort()).toEqual(['device', 'issue']);
    expect(p.issue).not.toContain('01099998888');
    expect(p.issue).not.toContain('منى');
  });
  it('نفس كود التنضيف في الواجهة وفي الـ Edge Function', () => {
    const root = join(__dirname, '..', '..');
    expect(readFileSync(join(root, 'supabase/functions/_shared/scrub.ts'), 'utf8')).toBe(readFileSync(join(root, 'src/lib/aiScrub.ts'), 'utf8'));
  });
});

describe('دليل الأعطال المدمج', () => {
  it('بيتعرف على العطل من الوصف، والأكتر تطابقًا الأول', () => {
    expect(matchFaults('مش بيشحن والشاحن سخن')[0]).toBe('no_charge');
    expect(matchFaults('وقع في مية ومش بيفتح')).toEqual(expect.arrayContaining(['water', 'no_power']));
    expect(matchFaults('Screen broken')).toEqual(['screen']);
    expect(matchFaults('حاجة غريبة')).toEqual([]);
  });
});
