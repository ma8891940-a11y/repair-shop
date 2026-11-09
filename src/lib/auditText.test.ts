import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import ar from '../i18n/ar.json';
import { auditSentence, entityLabel, isTechnicalField, linkOf, readableChanges, type AuditRow } from './auditText';

// البند 11: سجل النشاط بجمل عربي، ومفيش أي اسم جدول أو عمود أو إنجليزي في الواجهة العربي
const dir = new URL('../../supabase/migrations/', import.meta.url);
const sql = readdirSync(dir)
  .filter((f) => f.endsWith('.sql'))
  .sort()
  .map((f) => readFileSync(new URL(f, dir), 'utf8'))
  .join('\n');

/** كل الجداول وأعمدتها من ملفات قاعدة البيانات */
function schema(): Map<string, Set<string>> {
  const m = new Map<string, Set<string>>();
  for (const x of sql.matchAll(/create table (?:if not exists )?public\.(\w+)\s*\(([\s\S]*?)\n\);/g)) {
    const cols = new Set<string>();
    for (const line of x[2].split('\n')) {
      const c = /^\s+([a-z_][a-z0-9_]*)\s+(?!key\b)[a-z]/.exec(line);
      if (c && !['primary', 'unique', 'constraint', 'check', 'foreign', 'exclude'].includes(c[1])) cols.add(c[1]);
    }
    m.set(x[1], cols);
  }
  for (const x of sql.matchAll(/alter table (?:only )?public\.(\w+)\s+add column (?:if not exists )?([a-z_][a-z0-9_]*)/g)) m.get(x[1])?.add(x[2]);
  return m;
}

// ترجمة بسيطة من ملف العربي (نفس اللي الواجهة بتستخدمه)
const t = (key: string, o: Record<string, unknown> = {}) => {
  const v = key.split('.').reduce<unknown>((a, k) => (a && typeof a === 'object' ? (a as Record<string, unknown>)[k] : undefined), ar);
  if (typeof v !== 'string') return (o.defaultValue as string | undefined) ?? key;
  return v.replace(/\{\{(\w+)\}\}/g, (_, k: string) => String(o[k] ?? ''));
};
const LATIN = /[A-Za-z_]{2,}/g;
const allowed = (s: string) => (s.match(LATIN) ?? []).filter((w) => w !== 'IMEI');

const ACTIONS = ['insert', 'update', 'soft_delete', ...[...sql.matchAll(/insert into public\.audit_log\([^)]*\)\s*values\s*\([^,]+,[^,]+,\s*'([a-z_]+)'/g)].map((m) => m[1]).filter((a) => !a.endsWith('_')), 'customer_approved', 'customer_rejected', 'admin_suspend', 'admin_unsuspend', 'something_new'];

describe('سجل النشاط بالعربي', () => {
  const tables = schema();
  it('كل جدول ليه اسم عربي، وكل عملية ليها جملة', () => {
    expect(tables.size).toBeGreaterThan(40);
    const missing = [...tables.keys()].filter((tb) => !(ar.audit.entities as Record<string, string>)[tb]);
    expect(missing).toEqual([]);
    const known = Object.keys(ar.audit.sentence);
    const noSentence = [...new Set(ACTIONS)].filter((a) => a !== 'something_new' && !known.includes(a));
    expect(noSentence).toEqual([]);
  });

  it('كل جدول × كل عملية × كل عمود اتغيّر: الجملة والتفاصيل من غير أي إنجليزي ولا اسم جدول أو عمود', () => {
    const show = () => 'قيمة';
    const leaks: string[] = [];
    for (const [tb, cols] of [...tables, ['unknown_table', new Set(['weird_col'])] as const]) {
      const before = Object.fromEntries([...cols].map((c) => [c, 'قديم']));
      const after = Object.fromEntries([...cols].map((c) => [c, 'جديد']));
      for (const action of ACTIONS) {
        const r: AuditRow = { id: '1', actor_id: 'u', action, entity: tb, entity_id: 'x', before, after, created_at: '2026-11-09T10:00:00Z' };
        const { changes, other } = readableChanges(t, before, after);
        const text = [auditSentence(t, r, 'أحمد', show), ...changes.map((c) => c.label), other ? t('audit.otherChanges', { n: other }) : ''].join(' ');
        for (const w of allowed(text)) leaks.push(`${tb}/${action}: ${w}`);
        for (const c of changes) if (isTechnicalField(c.field)) leaks.push(`${tb}: technical ${c.field}`);
      }
    }
    expect(leaks).toEqual([]);
  });

  it('الجمل مفهومة: تغيير الحالة بقيمه، والحذف، والمرجع (رقم الطلب أو الاسم)، والرابط', () => {
    const show = (f: string, v: unknown) => (f === 'status' ? t(`status.${v}`) : String(v));
    const dev: AuditRow = { id: '1', actor_id: 'u', action: 'update', entity: 'devices', entity_id: 'd1', before: { status: 'received', order_no: '2026-0007' }, after: { status: 'ready', order_no: '2026-0007' }, created_at: '' };
    expect(auditSentence(t, dev, 'منى', show)).toBe('منى غيّر حالة الجهاز 2026-0007 من «تم الاستلام» لـ «جاهز للاستلام»');
    expect(linkOf(dev)).toBe('/devices/d1');
    const del: AuditRow = { ...dev, entity: 'customers', entity_id: 'c1', before: { name: 'سامح', deleted_at: null }, after: { name: 'سامح', deleted_at: '2026' } };
    expect(auditSentence(t, del, 'منى', show)).toBe('منى حذف العميل سامح');
    expect(linkOf(del)).toBe('/customers/c1');
    const pay: AuditRow = { id: '2', actor_id: null, action: 'insert', entity: 'payments', entity_id: 'p', before: null, after: { entry_id: 'e9', device_id: 'd1' }, created_at: '' };
    expect(linkOf(pay)).toBe('/finance/entry/e9');
    expect(entityLabel(t, 'nope')).toBe('سجل');
    const pc: AuditRow = { id: '3', actor_id: 'u', action: 'passcode_viewed', entity: 'device_passcodes', entity_id: 'x', before: null, after: { device_id: 'd1', order_no: '2026-0009' }, created_at: '' };
    expect(auditSentence(t, pc, 'كريم', show)).toBe('كريم شاف كلمة سر الجهاز 2026-0009');
    expect(linkOf(pc)).toBe('/devices/d1');
    // الحقول التقنية ما بتظهرش، واللي مالوش ترجمة بيتعدّ
    const ch = readableChanges(t, { id: 1, shop_id: 1, tracking_token: 'a', status: 'received', weird: 1 }, { id: 2, shop_id: 2, tracking_token: 'b', status: 'ready', weird: 2 });
    expect(ch.changes.map((c) => c.label)).toEqual(['الحالة']);
    expect(ch.other).toBe(1);
  });
});
