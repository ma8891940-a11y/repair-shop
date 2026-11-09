import { describe, expect, it } from 'vitest';
import { isDiagShortcut } from './diagShortcut';

const k = (o: Partial<KeyboardEvent>) => ({ ctrlKey: false, metaKey: false, altKey: false, shiftKey: false, code: '', ...o });

describe('اختصار شاشة التشخيص', () => {
  it('Ctrl+Alt+Shift+M (وبالكيبورد العربي: نفس الزرار الفعلي)', () => {
    expect(isDiagShortcut(k({ ctrlKey: true, altKey: true, shiftKey: true, code: 'KeyM' }))).toBe(true);
    expect(isDiagShortcut(k({ metaKey: true, altKey: true, shiftKey: true, code: 'KeyM' }))).toBe(true);
  });
  it('مش بيتفتح بالاختصار القديم المحجوز في Chrome ولا بأي جزء من الاختصار', () => {
    expect(isDiagShortcut(k({ ctrlKey: true, shiftKey: true, code: 'KeyD' }))).toBe(false);
    expect(isDiagShortcut(k({ ctrlKey: true, shiftKey: true, code: 'KeyM' }))).toBe(false);
    expect(isDiagShortcut(k({ ctrlKey: true, altKey: true, code: 'KeyM' }))).toBe(false);
  });
});
