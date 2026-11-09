import { beforeEach, describe, expect, it } from 'vitest';
import { clearDraft, hasContent, loadDraft, saveDraft } from './draft';

// البند 9: المسودات على الجهاز
const store = new Map<string, string>();
beforeEach(() => {
  store.clear();
  (globalThis as { localStorage?: unknown }).localStorage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  };
});

describe('المسودات', () => {
  it('بتتحفظ وترجع وتتمسح، والقديمة (أكتر من أسبوع) بتتشال', () => {
    saveDraft('intake:u1', { phone: '010' }, 1000);
    expect(loadDraft('intake:u1', 2000)).toEqual({ value: { phone: '010' }, at: 1000 });
    clearDraft('intake:u1');
    expect(loadDraft('intake:u1')).toBeNull();
    saveDraft('x', 1, 0);
    expect(loadDraft('x', 8 * 86_400_000)).toBeNull();
    expect(store.size).toBe(0);
  });
  it('من غير تخزين (وضع خاص): ما بيوقعش', () => {
    (globalThis as { localStorage?: unknown }).localStorage = {
      getItem: () => {
        throw new Error('blocked');
      },
      setItem: () => {
        throw new Error('blocked');
      },
      removeItem: () => {
        throw new Error('blocked');
      },
    };
    expect(() => saveDraft('a', 1)).not.toThrow();
    expect(loadDraft('a')).toBeNull();
    expect(() => clearDraft('a')).not.toThrow();
  });
  it('فيه حاجة اتكتبت؟', () => {
    expect(hasContent({ phone: '', name: '  ', accessories: [], check: {} })).toBe(false);
    expect(hasContent({ phone: '0', name: '' })).toBe(true);
    expect(hasContent({ accessories: ['شاحن'] })).toBe(true);
    expect(hasContent({ check: { screen: 'ok' } })).toBe(true);
    expect(hasContent({ n: 5, b: true })).toBe(false);
  });
});
