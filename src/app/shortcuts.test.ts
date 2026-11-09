import { describe, expect, it } from 'vitest';
import { matches } from './shortcuts';
import { comboFromEvent, comboProblem, effectiveShortcuts, SHORTCUTS } from './shortcutsRegistry';

const ev = (o: Partial<KeyboardEvent>) => ({ ctrlKey: false, metaKey: false, altKey: false, shiftKey: false, key: '', code: '', ...o }) as KeyboardEvent;

describe('الاختصارات', () => {
  it('Alt + رقم بالزرار الفعلي (والكيبورد عربي)، وF، وCtrl+K، و؟', () => {
    expect(matches(ev({ altKey: true, key: '٢', code: 'Digit2' }), 'Alt+2')).toBe(true);
    expect(matches(ev({ altKey: true, key: '2', code: 'Numpad2' }), 'Alt+2')).toBe(true);
    expect(matches(ev({ key: '2', code: 'Digit2' }), 'Alt+2')).toBe(false);
    expect(matches(ev({ key: 'F2', code: 'F2' }), 'F2')).toBe(true);
    expect(matches(ev({ ctrlKey: true, key: 'ن', code: 'KeyK' }), 'Ctrl+K')).toBe(true);
    expect(matches(ev({ shiftKey: true, key: '؟', code: 'Slash' }), '?')).toBe(true);
    expect(matches(ev({ shiftKey: true, key: '?', code: 'Slash' }), '?')).toBe(true);
    expect(matches(ev({ ctrlKey: true, shiftKey: true, key: '?', code: 'Slash' }), '?')).toBe(false);
    expect(matches(ev({ altKey: true, key: 't', code: 'KeyT' }), 'Alt+T')).toBe(true);
  });
  it('مفيش اختصار افتراضي محجوز للمتصفح أو الويندوز، ومفيش اتنين بنفس الزرار', () => {
    const all = SHORTCUTS.flatMap((s) => s.combos);
    for (const c of all) if (c !== '?' && !/^f\d$/i.test(c)) expect(comboProblem(c), c).toBeNull();
    expect(new Set(all.map((c) => c.toLowerCase())).size).toBe(all.length);
    // الاختصارات اللي كانت بتتاخد من المتصفح
    for (const c of ['Ctrl+J', 'Ctrl+L', 'Ctrl+Shift+D', 'F5', 'Ctrl+T', 'Ctrl+N', 'Ctrl+1']) expect(comboProblem(c), c).toBe('reserved');
    expect(comboProblem('Alt+Shift+1')).toBe('alt-shift');
    expect(comboProblem('Ctrl+Alt+1')).toBe('altgr');
    expect(comboProblem('K')).toBe('plain');
    expect(comboProblem('Alt+9', ['Alt+9'])).toBe('taken');
  });
  it('تسجيل اختصار جديد من الكيبورد، وتعديلات صاحب المحل (والغلط بيترفض)', () => {
    expect(comboFromEvent(ev({ altKey: true, key: '٧', code: 'Digit7' }))).toBe('Alt+7');
    expect(comboFromEvent(ev({ ctrlKey: true, shiftKey: true, key: 'ي', code: 'KeyD' }))).toBe('Ctrl+Shift+D');
    expect(comboFromEvent(ev({ key: 'Alt', code: 'AltLeft', altKey: true }))).toBeNull();
    const eff = effectiveShortcuts({ 'nav.intake': 'Alt+9', 'nav.devices': 'Ctrl+J', help: 'Alt+H' });
    expect(eff.find((s) => s.id === 'nav.intake')!.combos).toEqual(['Alt+9']);
    expect(eff.find((s) => s.id === 'nav.devices')!.combos).toEqual(['Alt+3', 'F3']);
    expect(eff.find((s) => s.id === 'help')!.combos).toEqual(['?']);
  });
});
