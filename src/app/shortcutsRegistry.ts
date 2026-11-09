/**
 * كل اختصارات البرنامج في مكان واحد: القايمة الجانبية وشاشة "الاختصارات" وأي tooltip بياخدوا من هنا،
 * فما ينفعش اختصار يتكتب في مكان ويشتغل غيره.
 *
 * ليه الاختيارات دي:
 * - Alt + رقم للتنقل بين الشاشات: شغال على اللابتوب من غير Fn (زراير F في أغلب اللابتوبات بتعمل صوت وإضاءة)،
 *   ومش محجوز في Chrome ولا Edge على ويندوز (Ctrl + رقم محجوز للتبويبات)، وشغال وانت بتكتب في خانة.
 * - F1–F4 فضلوا كاختصار تاني لكيبورد الكمبيوتر. F5 اتشال من الافتراضي (تحديث الصفحة).
 * - Ctrl+K لوحة الأوامر (البرامج المعروفة بتستخدمه، والمتصفح بيسيبه للصفحة).
 * - Alt+T للوضع الداكن وAlt+L للغة: Ctrl+J كان بيفتح التنزيلات، وCtrl+L كان بيروح لشريط العنوان.
 * - ? (برا الخانات) شاشة الاختصارات.
 */
export type ShortcutAction =
  | 'nav.dashboard' | 'nav.intake' | 'nav.devices' | 'nav.customers' | 'nav.finance' | 'nav.inventory'
  | 'palette' | 'theme' | 'lang' | 'help' | 'diag';

export interface ShortcutDef {
  id: ShortcutAction;
  /** الاختصار الأساسي، والاختيار التاني (لو موجود) */
  combos: string[];
  /** يشتغل وانت بتكتب في خانة */
  inInputs: boolean;
  /** صاحب المحل يقدر يغيّره */
  editable: boolean;
}

export const SHORTCUTS: ShortcutDef[] = [
  { id: 'nav.dashboard', combos: ['Alt+1', 'F1'], inInputs: true, editable: true },
  { id: 'nav.intake', combos: ['Alt+2', 'F2'], inInputs: true, editable: true },
  { id: 'nav.devices', combos: ['Alt+3', 'F3'], inInputs: true, editable: true },
  { id: 'nav.customers', combos: ['Alt+4', 'F4'], inInputs: true, editable: true },
  { id: 'nav.finance', combos: ['Alt+5'], inInputs: true, editable: true },
  { id: 'nav.inventory', combos: ['Alt+6'], inInputs: true, editable: true },
  { id: 'palette', combos: ['Ctrl+K'], inInputs: true, editable: true },
  { id: 'theme', combos: ['Alt+T'], inInputs: true, editable: true },
  { id: 'lang', combos: ['Alt+L'], inInputs: true, editable: true },
  { id: 'help', combos: ['?'], inInputs: false, editable: false },
  { id: 'diag', combos: ['Ctrl+Alt+Shift+M'], inInputs: true, editable: false },
];

/**
 * محجوزة للمتصفح (Chrome/Edge) أو الويندوز، أو بتكتب حروف: ما ينفعش تتختار.
 * (Alt+Shift بيغيّر لغة الكيبورد في الويندوز، وCtrl+Alt = AltGr في بعض الكيبوردات)
 */
const RESERVED = new Set([
  'ctrl+n', 'ctrl+t', 'ctrl+w', 'ctrl+tab', 'ctrl+shift+n', 'ctrl+shift+t', 'ctrl+shift+w', 'ctrl+shift+tab', 'ctrl+shift+q',
  'ctrl+shift+d', 'ctrl+shift+b', 'ctrl+shift+i', 'ctrl+shift+j', 'ctrl+shift+c', 'ctrl+shift+delete', 'ctrl+shift+o', 'ctrl+shift+m',
  'ctrl+j', 'ctrl+l', 'ctrl+d', 'ctrl+h', 'ctrl+p', 'ctrl+s', 'ctrl+o', 'ctrl+u', 'ctrl+f', 'ctrl+g', 'ctrl+r', 'ctrl+e', 'ctrl+a', 'ctrl+c', 'ctrl+v', 'ctrl+x', 'ctrl+z', 'ctrl+y',
  'ctrl+1', 'ctrl+2', 'ctrl+3', 'ctrl+4', 'ctrl+5', 'ctrl+6', 'ctrl+7', 'ctrl+8', 'ctrl+9', 'ctrl+0', 'ctrl+=', 'ctrl+-',
  'alt+f', 'alt+e', 'alt+d', 'alt+home', 'alt+left', 'alt+right', 'alt+f4', 'alt+tab', 'alt+space', 'alt+enter',
  'f5', 'f6', 'f7', 'f10', 'f11', 'f12', 'ctrl+f5', 'shift+f5', 'ctrl+f4', 'escape', 'tab', 'enter',
]);

export function normCombo(c: string): string {
  return c.trim().toLowerCase().replace(/\s+/g, '');
}

/** ليه الاختصار ده ما ينفعش (أو null لو ينفع) */
export function comboProblem(combo: string, taken: string[] = []): 'reserved' | 'alt-shift' | 'altgr' | 'plain' | 'taken' | null {
  const c = normCombo(combo);
  const parts = c.split('+');
  const mods = parts.slice(0, -1);
  const key = parts.at(-1) ?? '';
  if (RESERVED.has(c)) return 'reserved';
  if (mods.includes('alt') && mods.includes('shift') && !mods.includes('ctrl')) return 'alt-shift';
  if (mods.includes('ctrl') && mods.includes('alt') && !mods.includes('shift')) return 'altgr';
  // حرف أو رقم لوحده بيتكتب في الخانات
  if (!mods.length && !/^f([1-9]|1[0-2])$/.test(key)) return 'plain';
  if (taken.map(normCombo).includes(c)) return 'taken';
  return null;
}

/** الاختصار من زرار اتداس (للشاشة اللي بتسجّل اختصار جديد) */
export function comboFromEvent(e: Pick<KeyboardEvent, 'ctrlKey' | 'metaKey' | 'altKey' | 'shiftKey' | 'key' | 'code'>): string | null {
  if (['Control', 'Alt', 'Shift', 'Meta'].includes(e.key)) return null;
  let key: string;
  if (/^Key[A-Z]$/.test(e.code)) key = e.code.slice(3);
  else if (/^Digit\d$/.test(e.code)) key = e.code.slice(5);
  else if (/^F\d{1,2}$/.test(e.key)) key = e.key;
  else return null;
  const mods = [e.ctrlKey || e.metaKey ? 'Ctrl' : '', e.altKey ? 'Alt' : '', e.shiftKey ? 'Shift' : ''].filter(Boolean);
  return [...mods, key].join('+');
}

/** الاختصارات الفعلية بعد تعديلات صاحب المحل (shops.extras.shortcuts) */
export function effectiveShortcuts(overrides: unknown): ShortcutDef[] {
  const o = overrides && typeof overrides === 'object' ? (overrides as Record<string, unknown>) : {};
  return SHORTCUTS.map((s) => {
    const v = o[s.id];
    if (!s.editable || typeof v !== 'string' || comboProblem(v) !== null) return s;
    return { ...s, combos: [v] };
  });
}
