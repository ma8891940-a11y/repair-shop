import { useEffect } from 'react';

export interface Shortcut {
  /** مثال: "F2" أو "Ctrl+Enter" أو "Ctrl+J" */
  combo: string;
  handler: (e: KeyboardEvent) => void;
  /** يشتغل حتى لو المستخدم بيكتب في حقل */
  allowInInputs?: boolean;
}

export function matches(e: KeyboardEvent, combo: string): boolean {
  const parts = combo.toLowerCase().split('+');
  const key = parts.pop()!;
  const ctrl = parts.includes('ctrl');
  const shift = parts.includes('shift');
  const alt = parts.includes('alt');
  if ((e.ctrlKey || e.metaKey) !== ctrl || e.shiftKey !== shift || e.altKey !== alt) return false;
  const k = e.key.toLowerCase();
  if (key === 'enter') return k === 'enter';
  if (/^f\d+$/.test(key)) return k === key;
  // الحروف: نقارن بالـ code عشان تشتغل حتى لو الكيبورد عربي
  if (key.length === 1 && /[a-z]/.test(key)) return e.code === `Key${key.toUpperCase()}`;
  if (key === '/') return e.code === 'Slash' || k === '/';
  return k === key;
}

function isTyping(el: EventTarget | null): boolean {
  if (!(el instanceof HTMLElement)) return false;
  return el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName);
}

export function useShortcuts(list: Shortcut[], enabled = true) {
  useEffect(() => {
    if (!enabled) return;
    const onKey = (e: KeyboardEvent) => {
      for (const s of list) {
        if (!matches(e, s.combo)) continue;
        const fn = /^f\d+$/i.test(s.combo) || s.combo.toLowerCase().startsWith('ctrl');
        if (isTyping(e.target) && !s.allowInInputs && !fn) continue;
        e.preventDefault();
        s.handler(e);
        return;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [list, enabled]);
}
