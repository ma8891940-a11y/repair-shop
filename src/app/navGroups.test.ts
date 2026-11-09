import { describe, expect, it } from 'vitest';
import { favoriteEntries, groupOf, isActiveEntry, navGroups } from './navGroups';

const keys = (r: Parameters<typeof navGroups>[0]) => navGroups(r).flatMap((g) => g.items.map((i) => i.key));

describe('القايمة الجانبية في مجموعات بالصلاحيات', () => {
  it('صاحب المحل بيشوف كل المجموعات بالترتيب', () => {
    expect(navGroups({ role: 'owner', isAdmin: false }).map((g) => g.key)).toEqual(['top', 'repair', 'sales', 'finance', 'people', 'reports', 'settings']);
  });
  it('الاستقبال: من غير المالية والتقارير والشركاء والموردين، وبيشوف الدرج بتاعه', () => {
    const k = keys({ role: 'reception', isAdmin: false });
    for (const x of ['finance', 'partners', 'reports', 'audit', 'suppliers', 'purchases', 'stocktake', 'expenses', 'technicians', 'team', 'admin', 'assistant']) expect(k, x).not.toContain(x);
    for (const x of ['intake', 'devices', 'sale', 'inventory', 'drawer', 'customers', 'settings']) expect(k, x).toContain(x);
  });
  it('الفني: شغله والأجهزة والمخزون والمساعد، من غير فلوس ولا عملاء ولا بيع', () => {
    const k = keys({ role: 'technician', isAdmin: false });
    expect(k).toEqual(expect.arrayContaining(['work', 'devices', 'inventory', 'assistant', 'videos']));
    for (const x of ['intake', 'customers', 'sale', 'finance', 'drawer', 'partners', 'reports', 'suppliers']) expect(k, x).not.toContain(x);
    // مجموعات فاضية ما بتظهرش
    expect(navGroups({ role: 'technician', isAdmin: false }).map((g) => g.key)).not.toContain('finance');
  });
  it('المشرف بس بيشوف لوحة المشرف، وكل بند ليه مفتاح واحد في المجموعة بتاعته', () => {
    expect(keys({ role: 'owner', isAdmin: true })).toContain('admin');
    expect(keys({ role: 'owner', isAdmin: false })).not.toContain('admin');
  });
  it('البند النشط والمجموعة المفتوحة (?do= بيفرّق بين بيع والمخزون)، والمفضلة بالصلاحيات', () => {
    const g = navGroups({ role: 'owner', isAdmin: false });
    const all = g.flatMap((x) => x.items);
    const inv = all.find((i) => i.key === 'inventory')!;
    const sale = all.find((i) => i.key === 'sale')!;
    expect(isActiveEntry(inv, '/inventory', '')).toBe(true);
    expect(isActiveEntry(inv, '/inventory', '?do=sale')).toBe(false);
    expect(isActiveEntry(sale, '/inventory', '?do=sale')).toBe(true);
    expect(isActiveEntry(all.find((i) => i.key === 'devices')!, '/devices/abc', '')).toBe(false);
    expect(groupOf(g, '/partners', '')).toBe('finance');
    expect(groupOf(g, '/intake', '')).toBe('repair');
    const rec = navGroups({ role: 'reception', isAdmin: false });
    expect(favoriteEntries(rec, ['finance', 'intake']).map((i) => i.key)).toEqual(['intake']);
  });
});
