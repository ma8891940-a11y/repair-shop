/**
 * حارس الأداء للمؤثرات الكاملة:
 * - بيقيس الإطارات في الثانية على نوافذ صغيرة (نص ثانية).
 * - ما بيقيسش في أول ثانيتين بعد فتح أي شاشة (التحميل ما يقفلش المؤثرات بالغلط).
 * - لو الأداء فضل تحت 50 إطار لمدة 3 ثواني متواصلة، بيرجّع true مرة واحدة (اقفل المؤثرات).
 * - "تحت 50" لازم يكون بطء حقيقي: تقطيع أو شغل تقيل في كل إطار. لو المتصفح أو الشاشة مقفولين على عدد أقل
 *   (توفير الطاقة، أو شاشة 30 أو 48 هرتز) والجهاز فاضي، ده مش بطء.
 * - أي فجوة كبيرة بين إطارين (التبويب اتخفى مثلًا) مش بتتحسب بطء، وبتبدأ فترة سماح جديدة.
 */
export interface FpsGuardOptions {
  threshold?: number;
  sustainMs?: number;
  graceMs?: number;
  windowMs?: number;
  /** فجوة أكبر من كده بين إطارين = توقف (مش بطء) */
  pauseGapMs?: number;
  /**
   * تكلفة الإطار (مللي ثانية) اللي فوقها يبقى الجهاز مشغول فعلًا. الإطارات القليلة لوحدها مش دليل:
   * المتصفح أو الشاشة ممكن يكونوا مقفولين على 30 أو 48 إطار عشان توفير الطاقة والجهاز فاضي.
   */
  busyMs?: number;
  /**
   * نسبة الإطارات الطويلة (أطول من 1.7 مرة من الإطار العادي) اللي فوقها يبقى فيه تقطيع حقيقي.
   * (إطار طويل هنا وهناك من ضغط لحظي مش تقطيع)
   */
  jitter?: number;
}

/** آخر قراءة للحارس (للتشخيص والاختبار) */
export interface GuardReading {
  fps: number;
  /** متوسط تكلفة الإطار بالمللي ثانية */
  work: number;
  /** نسبة الإطارات الطويلة */
  jitter: number;
  /** الإطارات قليلة بس الجهاز فاضي والإطارات منتظمة = المتصفح أو الشاشة مقفولين على عدد أقل (مش بطء) */
  capped: boolean;
  slow: boolean;
}

export class FpsGuard {
  readonly threshold: number;
  readonly sustainMs: number;
  readonly graceMs: number;
  readonly windowMs: number;
  readonly pauseGapMs: number;
  readonly busyMs: number;
  readonly jitter: number;
  private gaps: number[] = [];
  private work = 0;
  /** آخر قراءة كاملة */
  last_: GuardReading | null = null;
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
    this.busyMs = o.busyMs ?? 10;
    this.jitter = o.jitter ?? 0.25;
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
    this.gaps = [];
    this.work = 0;
  }

  /**
   * بتتنادى مع كل إطار. workMs = تكلفة الإطار اللي فات (من أوله لحد ما الرسم يخلص).
   * بترجّع true مرة واحدة لما لازم المؤثرات تتقفل.
   */
  frame(now: number, workMs = 0): boolean {
    if (this.tripped) return false;
    if (this.last !== null && now - this.last > this.pauseGapMs) {
      // توقف: نبدأ من الأول بفترة سماح
      this.start(now);
    }
    const prev = this.last;
    this.last = now;
    if (now < this.graceUntil) return false;
    if (this.windowStart === null) {
      this.windowStart = now;
      this.frames = 0;
      this.gaps = [];
      this.work = 0;
      return false;
    }
    this.frames++;
    if (prev !== null) this.gaps.push(now - prev);
    this.work += workMs;
    const span = now - this.windowStart;
    if (span < this.windowMs) return false;
    const fps = (this.frames * 1000) / span;
    // الإطار العادي = الربع الأقل من المسافات (ثابت حتى لو فيه إطارات طويلة)، والطويل أكتر منه بـ 1.7 مرة
    const sorted = [...this.gaps].sort((a, b) => a - b);
    const base = sorted.length ? sorted[Math.floor((sorted.length - 1) / 4)] : 0;
    const jitter = sorted.length && base > 0 ? sorted.filter((g) => g > base * 1.7).length / sorted.length : 0;
    const work = this.work / this.frames;
    const low = fps < this.threshold;
    // إطارات قليلة لوحدها مش بطء: لازم يكون فيه تقطيع (إطارات مش منتظمة) أو شغل تقيل في كل إطار
    const slow = low && (jitter > this.jitter || work > this.busyMs);
    this.lastFps = fps;
    this.last_ = { fps, work, jitter, capped: low && !slow, slow };
    const windowBegan = this.windowStart;
    this.windowStart = now;
    this.frames = 0;
    this.gaps = [];
    this.work = 0;
    if (slow) {
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

/**
 * حارس الخلفية الحية (الافتتاحية والدخول): تحت 50 إطار لمدة 2 ثانية متواصلة = الخلفية تثبت وتتحفظ للجهاز.
 * فترة السماح 0.8 ثانية بس (تحميل الكود)، عشان الافتتاحية نفسها قصيرة.
 */
export const BG_GUARD: FpsGuardOptions = { threshold: 50, sustainMs: 2000, graceMs: 800 };

/**
 * بيقيس تكلفة كل إطار: من أول الإطار لحد ما كل شغله ورسمه يخلص.
 * رسالة بتتبعت في أول الإطار، وبتوصل بس بعد ما الإطار كله يخلص.
 */
export function createFrameCost() {
  let start = 0;
  let lastCost = 0;
  let ch: MessageChannel | null = null;
  try {
    ch = new MessageChannel();
    ch.port1.onmessage = () => {
      lastCost = performance.now() - start;
    };
  } catch {
    ch = null;
  }
  return {
    /** في أول كل إطار (جوه requestAnimationFrame) */
    mark(frameStart: number) {
      start = Math.min(frameStart, performance.now());
      ch?.port2.postMessage(0);
    },
    /** تكلفة آخر إطار خلص */
    get last() {
      return lastCost;
    },
    close() {
      ch?.port1.close();
    },
  };
}
