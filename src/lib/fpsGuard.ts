/**
 * حارس الأداء للمؤثرات الكاملة:
 * - بيقيس الإطارات في الثانية على نوافذ صغيرة (نص ثانية).
 * - ما بيقيسش في أول ثانيتين بعد فتح أي شاشة (التحميل ما يقفلش المؤثرات بالغلط).
 * - لو الأداء فضل تحت 50 إطار لمدة 3 ثواني متواصلة، بيرجّع true مرة واحدة (اقفل المؤثرات).
 * - أي فجوة كبيرة بين إطارين (التبويب اتخفى مثلًا) مش بتتحسب بطء، وبتبدأ فترة سماح جديدة.
 */
export interface FpsGuardOptions {
  threshold?: number;
  sustainMs?: number;
  graceMs?: number;
  windowMs?: number;
  /** فجوة أكبر من كده بين إطارين = توقف (مش بطء) */
  pauseGapMs?: number;
}

export class FpsGuard {
  readonly threshold: number;
  readonly sustainMs: number;
  readonly graceMs: number;
  readonly windowMs: number;
  readonly pauseGapMs: number;
  private graceUntil = 0;
  private windowStart: number | null = null;
  private frames = 0;
  private lowSince: number | null = null;
  private last: number | null = null;
  private tripped = false;
  /** آخر قراءة (للعرض والاختبار) */
  lastFps: number | null = null;

  constructor(o: FpsGuardOptions = {}) {
    this.threshold = o.threshold ?? 50;
    this.sustainMs = o.sustainMs ?? 3000;
    this.graceMs = o.graceMs ?? 2000;
    this.windowMs = o.windowMs ?? 500;
    this.pauseGapMs = o.pauseGapMs ?? 1000;
  }

  /** بداية جديدة: فتح شاشة، أو تشغيل المؤثرات */
  start(now: number) {
    this.graceUntil = now + this.graceMs;
    this.windowStart = null;
    this.frames = 0;
    this.lowSince = null;
    this.last = null;
    this.tripped = false;
    this.lastFps = null;
  }

  /** بتتنادى مع كل إطار. بترجّع true مرة واحدة لما لازم المؤثرات تتقفل */
  frame(now: number): boolean {
    if (this.tripped) return false;
    if (this.last !== null && now - this.last > this.pauseGapMs) {
      // توقف: نبدأ من الأول بفترة سماح
      this.start(now);
    }
    this.last = now;
    if (now < this.graceUntil) return false;
    if (this.windowStart === null) {
      this.windowStart = now;
      this.frames = 0;
      return false;
    }
    this.frames++;
    const span = now - this.windowStart;
    if (span < this.windowMs) return false;
    const fps = (this.frames * 1000) / span;
    this.lastFps = fps;
    const windowBegan = this.windowStart;
    this.windowStart = now;
    this.frames = 0;
    if (fps < this.threshold) {
      if (this.lowSince === null) this.lowSince = windowBegan;
      if (now - this.lowSince >= this.sustainMs) {
        this.tripped = true;
        return true;
      }
    } else {
      this.lowSince = null;
    }
    return false;
  }
}
