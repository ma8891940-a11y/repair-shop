/**
 * حالة حركة الخلفية على الجهاز ده، وأسباب وقوفها (للإعدادات ← المظهر).
 * كل الأسباب بتتقري من الجهاز نفسه، ومفيش حاجة بتتبعت لأي مكان.
 */

/**
 * مفتاح "الخلفية اتثبتت لوحدها عشان البطء".
 * - النسخة 2: القيم القديمة اتسجلت أحيانًا غلط وقت npm run dev.
 * - النسخة 3: قواعد الحارس اتصلّحت مرتين بعد النسخة 2 (توفير الطاقة/30 إطار ما بقاش بيتحسب بطء)، فأي تثبيت اتسجل بالقواعد القديمة بيتمسح مرة واحدة.
 *   من غير كده الجهاز اللي الحارس القديم غلط فيه كان هيفضل ثابت حتى بعد التحديث.
 */
export const BG_STILL_KEY = 'bg-still-v3';
const OLD_KEYS = ['bg-still', 'bg-still-v2'];
try {
  for (const k of OLD_KEYS) localStorage.removeItem(k);
} catch {
  /* التخزين ممكن يكون مقفول */
}

/**
 * حارس الأداء بيشتغل في النسخة النهائية بس. في npm run dev الكود بيتجمّع أول مرة وبيتحدّث وانت شغال،
 * فالبطء ده مش حقيقي. (الاختبارات بتشغّله في dev بمفتاح bg-guard-dev عشان تتأكد إنه شغال.)
 */
export function guardAllowed(): boolean {
  if (!import.meta.env.DEV) return true;
  try {
    return localStorage.getItem('bg-guard-dev') === '1';
  } catch {
    return false;
  }
}

/** اسم كارت الشاشة اللي المتصفح بيرسم بيه بيقول إن الرسم بالمعالج (تسريع الرسومات مقفول أو متعطّل) */
export function isSoftwareRenderer(renderer: string | null | undefined): boolean {
  return /swiftshader|llvmpipe|softpipe|software|basic render|microsoft basic/i.test(renderer ?? '');
}

/**
 * هل تسريع الرسومات مقفول في المتصفح؟ true = مقفول، false = شغال، null = مش عارفين.
 * بنطلب WebGL بشرط "من غير بطء كبير": المتصفح بيرفض لو هيرسم بالمعالج بس.
 */
export function detectSoftwareRendering(): boolean | null {
  try {
    const c = document.createElement('canvas');
    const strict = c.getContext('webgl', { failIfMajorPerformanceCaveat: true }) as WebGLRenderingContext | null;
    const gl = strict ?? (c.getContext('webgl') as WebGLRenderingContext | null);
    if (!gl) return strict === null ? true : null;
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    const renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : String(gl.getParameter(gl.RENDERER));
    gl.getExtension('WEBGL_lose_context')?.loseContext();
    if (!strict) return true;
    return isSoftwareRenderer(renderer);
  } catch {
    return null;
  }
}

export type MotionReason = 'reduced' | 'auto' | 'software';

/** أسباب وقوف الحركة (أو بطئها) بالترتيب: تقليل الحركة من النظام، والتثبيت التلقائي، وتسريع الرسومات */
export function motionReasons(o: { reduced: boolean; autoStill: boolean; software: boolean | null }): MotionReason[] {
  const r: MotionReason[] = [];
  if (o.reduced) r.push('reduced');
  if (o.autoStill) r.push('auto');
  if (o.software) r.push('software');
  return r;
}
