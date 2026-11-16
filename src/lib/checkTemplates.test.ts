import { describe, expect, it } from 'vitest';
import { BUILTIN_TEMPLATES, CHECK_ITEMS, brandKey, checkKeys, compareChecks, labelsOf, normalizeTemplate, templateFor } from './checks';

describe('C2: قوالب الفحص', () => {
  it('الماركة من اسم الجهاز بالعربي والإنجليزي، والباقي عام', () => {
    expect(brandKey('iPhone 13')).toBe('apple');
    expect(brandKey('Apple')).toBe('apple');
    expect(brandKey('سامسونج')).toBe('samsung');
    expect(brandKey('Redmi Note 12')).toBe('xiaomi');
    expect(brandKey('OPPO')).toBe('oppo');
    expect(brandKey('realme C55')).toBe('realme');
    expect(brandKey('Nokia')).toBe('general');
    expect(brandKey(null)).toBe('general');
  });
  it('العام = الفحص القديم بالظبط، وكل ماركة فيه بنودها الزيادة', () => {
    expect(BUILTIN_TEMPLATES.general.map((i) => i.key)).toEqual([...CHECK_ITEMS]);
    expect(templateFor('iPhone').map((i) => i.key)).toContain('face_id');
    expect(templateFor('Samsung').map((i) => i.key)).toContain('s_pen');
    expect(templateFor('Samsung').map((i) => i.key)).not.toContain('face_id');
  });
  it('قالب صاحب المحل بيكسب، وبيتنضّف (مفاتيح غلط ومكرر وبند من غير اسم بيتشالوا)', () => {
    const custom = { samsung: [{ key: 'wifi' }, { key: 'wifi' }, { key: 'c_ab12', label: '  فتحة الكارت  ' }, { key: 'c_x' }, { key: 'BAD KEY', label: 'x' }, { key: 'face_id' }] };
    const t = templateFor('Galaxy S23', custom);
    expect(t).toEqual([{ key: 'wifi' }, { key: 'c_ab12', label: 'فتحة الكارت' }, { key: 'face_id' }]);
    expect(labelsOf(t)).toEqual({ c_ab12: 'فتحة الكارت' });
    expect(normalizeTemplate('garbage')).toEqual([]);
    expect(normalizeTemplate(Array.from({ length: 60 }, (_, i) => ({ key: `c_${i}`, label: `b${i}` })))).toHaveLength(40);
  });
  it('المقارنة على بنود القالب، والبند اللي اتسجل ومش في القالب بيظهر برضه', () => {
    const keys = checkKeys([{ key: 'wifi' }, { key: 'c_1', label: 'x' }], { wifi: 'ok', c_1: 'ok' }, { c_1: 'fail', mic: 'ok' });
    expect(keys).toEqual(['wifi', 'c_1', 'mic']);
    const d = compareChecks({ wifi: 'ok', c_1: 'ok' } as never, { c_1: 'fail', mic: 'ok' } as never, keys);
    expect(d.find((r) => r.item === ('c_1' as never))?.regressed).toBe(true);
    expect(d).toHaveLength(3);
  });
});
