// نصوص إشعارات الجهاز: نفس كلام الجرس، والفلوس من غير كسور، والملخّص، والروابط جوه البرنامج بس، والوقت
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildPushTexts } from '../../scripts/build-push-texts.mjs';
import { TEXTS } from '../../supabase/functions/push/texts';
import { dateText, fill, messageFor, moneyText, planMessages, testMessage, type DueRow } from '../../supabase/functions/_shared/pushText';
import { readPushWindow, windowOpen } from './pushWindow';
import ar from '../i18n/ar.json';

const row = (o: Partial<DueRow> = {}): DueRow => ({
  sub_id: 's1', endpoint: 'https://push.example.com/1', p256dh: 'k', auth: 'a', locale: 'ar',
  key: 'inst:1:late', kind: 'overdue', args: { name: 'أحمد', amount: 125050, due: '2026-11-14' }, link: '/finance/customer/1', token: 'f'.repeat(32), ...o,
});
const ack = { url: 'https://x.supabase.co/rest/v1/rpc/push_ack', key: 'anon' };

describe('نصوص إشعارات الجهاز', () => {
  it('ملف النصوص بتاع الـ Edge Function محدّث من الترجمة (npm run db:setup-file)', () => {
    expect(readFileSync('supabase/functions/push/texts.ts', 'utf8')).toBe(buildPushTexts());
    expect(TEXTS.ar.kinds).toEqual(ar.notify.kinds);
  });

  it('الفلوس بالقروش لنص من غير أي كسور عشرية في الحساب', () => {
    expect(moneyText(125050)).toBe('1,250.50');
    expect(moneyText(100)).toBe('1');
    expect(moneyText(123456789000)).toBe('1,234,567,890');
    expect(moneyText(-5)).toBe('-0.05');
    expect(moneyText(1.5)).toBe('');
    expect(dateText('2026-11-14')).toBe('14/11/2026');
    expect(fill('{{a}} و {{ b }} و {{c}}', { a: 1, b: 'x' })).toBe('1 و x و ');
  });

  it('الإشعار بلغة الجهاز، وزرار "اتقرا" بالـ token بس، والرابط جوه البرنامج بس', () => {
    const m = messageFor(TEXTS, row(), ack);
    expect(m).toMatchObject({ title: 'قسط متأخر', body: 'أحمد: قسط متأخر 1,250.50 (ميعاده كان 14/11/2026)', url: '/finance/customer/1', lang: 'ar', dir: 'rtl', tag: 'inst:1:late' });
    expect(m.actions.map((a) => a.action)).toEqual(['open', 'read']);
    expect(m.ack).toEqual({ ...ack, token: 'f'.repeat(32) });
    const en = messageFor(TEXTS, row({ locale: 'en', token: null }), ack);
    expect(en).toMatchObject({ title: 'Overdue installment', lang: 'en', dir: 'ltr' });
    expect(en.actions.map((a) => a.action)).toEqual(['open']);
    expect(en.ack).toBeUndefined();
    for (const link of ['https://evil.example/x', '//evil.example', 'javascript:alert(1)', '/x?y=<z>', null]) {
      expect(messageFor(TEXTS, row({ link }), ack).url, String(link)).toBe('/');
    }
  });

  it('أكتر من 3 جديدين لنفس الجهاز: إشعار واحد ملخّص. والأجهزة كل واحد لوحده', () => {
    const many = [1, 2, 3, 4].map((i) => row({ key: `k${i}` }));
    const out = planMessages(TEXTS, [...many, row({ sub_id: 's2', endpoint: 'https://push.example.com/2', locale: 'en' })], ack);
    expect(out).toHaveLength(2);
    expect(out[0].message).toMatchObject({ tag: 'summary', body: 'عندك 4 تنبيهات جديدة. افتح البرنامج تشوفها.', url: '/' });
    expect(out[1]).toMatchObject({ sub: { id: 's2' }, message: { lang: 'en', title: 'Overdue installment' } });
    expect(planMessages(TEXTS, many.slice(0, 3), ack)).toHaveLength(3);
    expect(testMessage(TEXTS, 'en')).toMatchObject({ title: 'Notification test', tag: 'test' });
  });
});

describe('وقت الإشعارات', () => {
  it('الافتراضي من 9 لـ 9 بالليل، والقيم الغلط بترجع للافتراضي أو للحد', () => {
    expect(readPushWindow(null)).toEqual({ from: 9, to: 21 });
    expect(readPushWindow({ reminders: { push_from: 7, push_to: 23 } })).toEqual({ from: 7, to: 23 });
    expect(readPushWindow({ reminders: { push_from: -3, push_to: 99 } })).toEqual({ from: 0, to: 24 });
    expect(readPushWindow({ reminders: { push_from: 'x', push_to: 1.5 } })).toEqual({ from: 9, to: 21 });
  });
  it('مفتوح/مقفول: عادي، وبيعدّي نص الليل، وطول اليوم', () => {
    const w = { from: 9, to: 21 };
    expect([8, 9, 20, 21].map((h) => windowOpen(w, h))).toEqual([false, true, true, false]);
    expect([21, 23, 0, 1, 2, 12].map((h) => windowOpen({ from: 22, to: 2 }, h))).toEqual([false, true, true, true, false, false]);
    expect(windowOpen({ from: 5, to: 5 }, 3)).toBe(true);
    expect(windowOpen({ from: 0, to: 24 }, 23)).toBe(true);
  });
});
