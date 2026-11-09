import { useEffect } from 'react';

export interface Shortcut {
  /** مثال: "F2" أو "Ctrl+Enter" أو "Ctrl+J" */
  combo: string;
  handler: (e: KeyboardEvent) => void;
  /** يشتغل حتى لو المستخدم بيكتب في حقل */
  allowInInputs?: boolean;
  /** برا الخانات بس (زي ? اللي بيتكتب كحرف) */
  outsideInputsOnly?: boolean;
}

export function matches(e: Pick<KeyboardEvent, 'ctrlKey' | 'metaKey' | 'altKey' | 'shiftKey' | 'key' | 'code'>, combo: string): boolean {
  // "?" = Shift + الزرار اللي عليه / (بالزرار الفعلي، عشان الكيبورد العربي بيكتب "؟")
  if (combo === '?') return !e.ctrlKey && !e.metaKey && !e.altKey && (e.key === '?' || e.key === '\u061F' || (e.shiftKey && e.code === 'Slash'));
  const parts = combo.toLowerCase().split('+');
  const key = parts.pop()!;
  const ctrl = parts.includes('ctrl');
  const shift = parts.includes('shift');
  const alt = parts.includes('alt');
  if ((e.ctrlKey || e.metaKey) !== ctrl || e.shiftKey !== shift || e.altKey !== alt) return false;
  const k = e.key.toLowerCase();
  if (key === 'enter') return k === 'enter';
  if (/^f\d+$/.test(key)) return k === key;
  // الحروف والأرقام: بالزرار الفعلي (e.code) عشان تشتغل والكيبورد عربي، ومع Alt على الماك
  if (key.length === 1 && /[a-z]/.test(key)) return e.code === `Key${key.toUpperCase()}`;
  if (key.length === 1 && /\d/.test(key)) return e.code === `Digit${key}` || e.code === `Numpad${key}`;
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
        // F وCtrl وAlt ما بيكتبوش حروف، فبيشتغلوا جوه الخانات برضه (إلا لو الاختصار متعلّم إنه برا الخانات بس)
        const fn = /^f\d+$/i.test(s.combo) || /^(ctrl|alt)\+/i.test(s.combo);
        if (isTyping(e.target) && (s.outsideInputsOnly || (!s.allowInInputs && !fn))) continue;
        e.preventDefault();
        s.handler(e);
        return;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [list, enabled]);
}
