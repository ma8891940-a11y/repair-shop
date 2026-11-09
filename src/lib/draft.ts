/**
 * البند 9: المسودات (حفظ تلقائي على الجهاز ده). لو الصفحة اتقفلت أو النت قطع أو حد خرج من غير حفظ،
 * المسودة بتفضل، والشاشة بتعرض "رجّعها" (ما بترجعش لوحدها عشان ما تفاجئش حد).
 * التخزين ممكن يبقى مقفول (وضع خاص مثلًا): كل حاجة في try/catch والبرنامج بيشتغل عادي من غيرها.
 */
const PREFIX = 'draft:';
/** المسودة بتعيش أسبوع بالكتير */
const MAX_AGE = 7 * 86_400_000;

export interface Draft<T> {
  value: T;
  at: number;
}

export function saveDraft<T>(key: string, value: T, now = Date.now()): void {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify({ value, at: now }));
  } catch {
    /* التخزين مقفول */
  }
}

export function loadDraft<T>(key: string, now = Date.now()): Draft<T> | null {
  try {
    const s = localStorage.getItem(PREFIX + key);
    if (!s) return null;
    const d = JSON.parse(s) as Draft<T>;
    if (!d || typeof d.at !== 'number' || now - d.at > MAX_AGE) {
      localStorage.removeItem(PREFIX + key);
      return null;
    }
    return d;
  } catch {
    return null;
  }
}

export function clearDraft(key: string): void {
  try {
    localStorage.removeItem(PREFIX + key);
  } catch {
    /* التخزين مقفول */
  }
}

/** فيه حاجة اتكتبت؟ (نص مش فاضي في أي مكان جوه القيمة). الأرقام والاختيارات الافتراضية مش بتتحسب */
export function hasContent(v: unknown): boolean {
  if (typeof v === 'string') return v.trim() !== '';
  if (Array.isArray(v)) return v.some(hasContent);
  if (v && typeof v === 'object') return Object.values(v as Record<string, unknown>).some(hasContent);
  return false;
}
