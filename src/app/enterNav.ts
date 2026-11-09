/**
 * البند 10: Enter بينقل للخانة اللي بعدها، وفي آخر خانة بيحفظ. وفي الكتابة الكبيرة (textarea) Enter سطر جديد وCtrl+Enter بيحفظ.
 * النطاق: أقرب فورم أو نافذة (أو أي عنصر عليه data-enter-scope). برّا النطاق Enter بيفضل زي ما هو.
 * الخانات اللي ليها Enter بتاعها (الباركود، والبحث، وجدول الجرد، ولوحة الأوامر) بتعمل preventDefault، فبنسيبها.
 * وأي خانة عليها data-enter="own" برضه بنسيبها.
 */
const SKIP_TYPES = new Set(['checkbox', 'radio', 'file', 'button', 'submit', 'reset', 'hidden', 'range', 'color']);

export function isField(el: Element): el is HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement {
  if (el instanceof HTMLInputElement) return !SKIP_TYPES.has(el.type) && !el.disabled && !el.readOnly;
  if (el instanceof HTMLSelectElement || el instanceof HTMLTextAreaElement) return !el.disabled && !(el instanceof HTMLTextAreaElement && el.readOnly);
  return false;
}

const visible = (el: Element) => (el as HTMLElement).getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden';

export function scopeOf(el: Element): HTMLElement | null {
  const s = el.closest<HTMLElement>('[data-enter-scope], form, [role="dialog"]');
  // data-enter-scope="off": شاشة فيها فورمات صغيرة كتير (زي صفحة الجهاز) — Enter بيفضل زي ما هو
  return s && s.dataset.enterScope !== 'off' ? s : null;
}

export function fieldsIn(scope: HTMLElement): HTMLElement[] {
  return [...scope.querySelectorAll<HTMLElement>('input, select, textarea')].filter((el) => isField(el) && visible(el) && el.dataset.enter !== 'skip');
}

/** زرار الحفظ في النطاق: زرار submit في الفورم، أو آخر زرار أساسي ظاهر في النافذة */
export function submitOf(scope: HTMLElement): HTMLButtonElement | null {
  const explicit = scope.querySelector<HTMLButtonElement>('[data-enter-submit]:not(:disabled)');
  if (explicit) return explicit;
  const btns = [...scope.querySelectorAll<HTMLButtonElement>('button[type="submit"]:not(:disabled), button[data-variant="primary"]:not(:disabled)')].filter(visible);
  const sub = btns.find((b) => b.type === 'submit' && b.form === (scope instanceof HTMLFormElement ? scope : b.form));
  return sub ?? btns.at(-1) ?? null;
}

function submit(scope: HTMLElement) {
  const btn = submitOf(scope);
  if (btn) return btn.click();
  if (scope instanceof HTMLFormElement) scope.requestSubmit();
}

export function onEnterKey(e: KeyboardEvent): void {
  if (e.key !== 'Enter' || e.defaultPrevented || e.isComposing || e.altKey) return;
  const el = e.target as Element | null;
  if (!el || !isField(el) || (el as HTMLElement).dataset.enter === 'own' || el.getAttribute('autocomplete') === 'one-time-code') return;
  const scope = scopeOf(el);
  if (!scope) return;
  const ctrl = e.ctrlKey || e.metaKey;
  if (el instanceof HTMLTextAreaElement) {
    // الكتابة الكبيرة: Enter سطر جديد، وCtrl+Enter بيحفظ
    if (!ctrl) return;
    e.preventDefault();
    return submit(scope);
  }
  e.preventDefault();
  if (ctrl) return submit(scope);
  const list = fieldsIn(scope);
  const i = list.indexOf(el as HTMLElement);
  const next = i >= 0 ? list[i + 1] : undefined;
  if (next) {
    next.focus();
    if (next instanceof HTMLInputElement && typeof next.select === 'function' && next.type !== 'email' && next.type !== 'number') next.select();
  } else submit(scope);
}

/** بيتركّب مرة واحدة للبرنامج كله */
export function installEnterNav(): () => void {
  document.addEventListener('keydown', onEnterKey);
  return () => document.removeEventListener('keydown', onEnterKey);
}
