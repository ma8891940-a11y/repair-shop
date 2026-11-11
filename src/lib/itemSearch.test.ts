import { describe, expect, it } from 'vitest';
import { byCode, composeItemName, matches, normalize, searchItems } from './itemSearch';

const items = [
  { id: 'a', name: 'شاشة iPhone 13 Pro - OLED - أسود', item_type: 'شاشة', brand: 'Apple', model: 'iPhone 13 Pro', quality: 'OLED', color: 'أسود', barcode: '2000000000017' },
  { id: 'b', name: 'بطارية Samsung A52', item_type: 'بطارية', brand: 'Samsung', model: 'A52', quality: 'أصلي' },
  { id: 'c', name: 'جراب سيليكون', item_type: 'جراب', brand: null, model: null },
  { id: 'd', name: 'شاشة Oppo A78 - Incell', item_type: 'شاشة', brand: 'Oppo', model: 'A78', quality: 'Incell' },
];
const ids = (q: string) => searchItems(items, q).map((i) => i.id);

describe('البحث عن الصنف بالكتابة', () => {
  it('"شاشه 13 برو" بتجيب "شاشة iPhone 13 Pro" (ه/ة، وبرو = pro)', () => {
    expect(ids('شاشه 13 برو')).toEqual(['a']);
    expect(ids('ايفون 13')).toEqual(['a']);
    expect(ids('iphone 13 pro')).toEqual(['a']);
  });
  it('النوع بالإنجليزي بيلاقي الاسم العربي (والعكس)', () => {
    expect(ids('screen 13 pro')).toEqual(['a']);
    expect(ids('battery a52')).toEqual(['b']);
    expect(ids('case')).toEqual(['c']);
    expect(ids('بطاريه سامسونج')).toEqual(['b']);
  });
  it('جزء من الكلمة، وبالنوع والماركة والموديل والجودة', () => {
    expect(ids('شاش')).toEqual(['a', 'd']);
    expect(ids('سامسونج')).toEqual(['b']);
    expect(ids('a5')).toEqual(['b']);
    expect(ids('اوبو')).toEqual(['d']);
    expect(ids('incell')).toEqual(['d']);
    expect(ids('اوليد')).toEqual(['a']);
    expect(ids('أصلى')).toEqual(['b']); // ى = ي، وأ = ا
  });
  it('الباركود بالظبط بييجي الأول، وبيتلقى بالكود (والأرقام العربي)', () => {
    expect(ids('2000000000017')[0]).toBe('a');
    expect(byCode(items, '٢٠٠٠٠٠٠٠٠٠٠١٧')?.id).toBe('a');
    expect(byCode(items, '123')).toBeUndefined();
  });
  it('كلمة مش موجودة: مفيش نتايج', () => {
    expect(ids('شاحن')).toEqual([]);
    expect(matches(items[2], '')).toBe(true);
    expect(normalize('  إيفون   ١٣ ')).toBe('ايفون 13');
  });
  it('الاسم بيتكوّن من الخانات: النوع + الموديل (أو الماركة) - الجودة - اللون', () => {
    expect(composeItemName({ item_type: 'شاشة', brand: 'Apple', model: 'iPhone 13 Pro', quality: 'OLED', color: 'أسود' })).toBe('شاشة iPhone 13 Pro - OLED - أسود');
    expect(composeItemName({ item_type: 'جراب', brand: 'Samsung' })).toBe('جراب Samsung');
    expect(composeItemName({ item_type: 'كابل', quality: 'أصلي' })).toBe('كابل - أصلي');
    expect(composeItemName({})).toBe('');
  });
});
