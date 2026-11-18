// U6: القوايم الجاهزة (أنواع القطع والإكسسوارات والجودة) ليها اسم إنجليزي لكل بند، عشان الإنجليزي ما يظهرش فيه عربي
import { describe, expect, it } from 'vitest';
import lists from '../data/itemLists.json';

describe('القوايم الجاهزة بالإنجليزي', () => {
  it('كل بند ليه اسم إنجليزي من غير حروف عربي، ومن غير تكرار', () => {
    const en = lists.en as Record<string, string>;
    const all = [...lists.part_types, ...lists.accessory_types, ...lists.qualities];
    for (const v of all) {
      expect(en[v], v).toBeTruthy();
      expect(en[v], v).not.toMatch(/[؀-ۿ]/);
    }
    const names = all.map((v) => en[v].toLowerCase());
    expect(new Set(names).size).toBe(names.length);
  });
});
