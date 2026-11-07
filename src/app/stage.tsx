import { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { motion } from 'motion/react';
import { usePrefs } from './prefs';
import { CircuitField } from '../ui/fx/CircuitField';
import { BG_GUARD, FpsGuard } from '../lib/fpsGuard';
import { BG_STILL_KEY, guardAllowed } from './motionStatus';
import logoSrc from '../assets/app-logo.png';
import { getHandoffMs } from '../lib/splashTiming';

/**
 * "المسرح": خلفية واحدة للبرنامج كله، ما بتتشالش وترجع بين الشاشات، والانتقال المشترك للوجو بعد الافتتاحية.
 * - live: الافتتاحية والدخول والتسجيل وصفحة التتبع (إشارات وسكان).
 * - still: جوه البرنامج (نفس الخطوط بالظبط، ثابتة وأهدى) عشان الأداء.
 * - off: صفحات الطباعة.
 * حالة الافتتاحية: splash = ظاهرة، handoff = خلصت واللوجو بيطير لمكانه، done.
 */
type BgMode = 'live' | 'still' | 'off';
export type SplashPhase = 'splash' | 'handoff' | 'done';

interface Stage {
  setBg: (m: BgMode) => void;
  phase: SplashPhase;
  /** لوجو الافتتاحية (نقطة البداية) */
  hero: (el: HTMLElement | null) => void;
  /** مكان اللوجو النهائي (الشريط الجانبي أو الدخول). ممكن أكتر من واحد، والظاهر منهم هو اللي بيستلم */
  target: (el: HTMLElement | null) => void;
}
const Ctx = createContext<Stage | null>(null);

/** مدة الانتقال المشترك بالثواني */
// مدة طيران اللوجو في src/lib/splashTiming.ts (getHandoffMs)

/**
 * شرط أمان: لو الأداء في الافتتاحية أو الدخول (الخلفية الحية) نزل تحت 50 إطار لمدة 2 ثانية متواصلة،
 * الخلفية بتثبت لوحدها بنعومة (الخطوط بتفضل، والإشارات والسكان بينطفوا)، وده بيتحفظ للجهاز ده بس.
 * ما بيشتغلش:
 * - في npm run dev (التجميع الأول والتحديث وانت شغال بيبطّأ من غير ما يكون الجهاز بطيء).
 * - وقت تحميل الصفحة: بيبدأ بعد ما الصفحة تخلص تحميل بثانية، وبعدها 0.8 ثانية سماح.
 * - والتبويب في الخلفية: بيقف، ولما يرجع بيبدأ من الأول.
 * مستقل عن "المؤثرات الكاملة": دي للزجاج والتأثيرات التقيلة بس.
 */
function readBgStill() {
  try {
    return localStorage.getItem(BG_STILL_KEY) === '1';
  } catch {
    return false;
  }
}
export function setBgStillSaved(v: boolean) {
  try {
    if (v) localStorage.setItem(BG_STILL_KEY, '1');
    else localStorage.removeItem(BG_STILL_KEY);
  } catch {
    /* التخزين ممكن يكون مقفول */
  }
  window.dispatchEvent(new CustomEvent('bg-still', { detail: v }));
}
/** هل الخلفية اتثبتت لوحدها على الجهاز ده (عشان الإعدادات تعرض "رجّع الحركة") */
export function useBgStillSaved() {
  const [v, setV] = useState(readBgStill);
  useEffect(() => {
    const on = (e: Event) => setV(Boolean((e as CustomEvent<boolean>).detail));
    window.addEventListener('bg-still', on);
    return () => window.removeEventListener('bg-still', on);
  }, []);
  return v;
}

export function StageProvider({ phase, children }: { phase: SplashPhase; children: ReactNode }) {
  const [mode, setMode] = useState<BgMode>('live');
  const { rich, calm } = usePrefs();
  const autoStill = useBgStillSaved();
  // حارس الأداء للخلفية الحية (الافتتاحية والدخول والتسجيل)
  useEffect(() => {
    if (mode !== 'live' || calm || autoStill || !guardAllowed()) return;
    const guard = new FpsGuard(BG_GUARD);
    let raf = 0;
    let wait = 0;
    let stopped = false;
    const tick = (now: number) => {
      if (stopped) return;
      if (guard.frame(now)) {
        setBgStillSaved(true);
        return;
      }
      raf = requestAnimationFrame(tick);
    };
    // بيبدأ بعد ما الصفحة تخلص تحميل بثانية، والتبويب ظاهر
    const begin = () => {
      cancelAnimationFrame(raf);
      clearTimeout(wait);
      if (document.hidden) return;
      wait = window.setTimeout(() => {
        guard.start(performance.now());
        raf = requestAnimationFrame(tick);
      }, 1000);
    };
    const onLoad = () => begin();
    const onVis = () => {
      cancelAnimationFrame(raf);
      clearTimeout(wait);
      if (!document.hidden) begin();
    };
    if (document.readyState === 'complete') begin();
    else window.addEventListener('load', onLoad, { once: true });
    document.addEventListener('visibilitychange', onVis);
    return () => {
      stopped = true;
      cancelAnimationFrame(raf);
      clearTimeout(wait);
      window.removeEventListener('load', onLoad);
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [mode, calm, autoStill]);
  const heroEl = useRef<HTMLElement | null>(null);
  const targets = useRef(new Set<HTMLElement>());
  const [fly, setFly] = useState<{ from: DOMRect; to: DOMRect } | null>(null);

  const hero = useCallback((el: HTMLElement | null) => {
    if (el) heroEl.current = el;
  }, []);
  const target = useCallback((el: HTMLElement | null) => {
    if (el) targets.current.add(el);
    // العناصر اللي اتشالت بتتنضف وقت القياس
  }, []);

  // لحظة نهاية الافتتاحية: بنقيس البداية (لوجو الافتتاحية) والنهاية (المكان الظاهر)، واللوجو بيطير بينهم
  useLayoutEffect(() => {
    if (phase === 'handoff') {
      const from = heroEl.current?.getBoundingClientRect();
      const to = [...targets.current].filter((el) => el.isConnected && el.getClientRects().length > 0).map((el) => el.getBoundingClientRect()).find((r) => r.width > 0);
      setFly(from && to ? { from, to } : null);
    } else if (phase === 'done') {
      setFly(null);
    }
  }, [phase]);

  const value = useMemo(() => ({ setBg: setMode, phase, hero, target }), [phase, hero, target]);
  return (
    <Ctx.Provider value={value}>
      {mode !== 'off' && (
        // الخطوط بتظهر بنعومة أول ما الكود يحمّل (فوق نفس لون الخلفية اللي كان ظاهر من index.html)
        <motion.div
          className="fixed inset-0 z-0 print:hidden"
          initial={{ opacity: 0 }}
          animate={{ opacity: mode === 'still' ? 0.6 : 1 }}
          transition={{ duration: 0.5 }}
          aria-hidden
          data-testid="stage-bg"
          data-mode={mode}
          data-auto-still={autoStill ? '' : undefined}
        >
          <CircuitField density={1.1} still={mode === 'still' || autoStill} glowFollow={mode === 'live' && rich && !autoStill && phase === 'done'} />
        </motion.div>
      )}
      {children}
      {fly && (
        <motion.img
          src={logoSrc}
          alt=""
          aria-hidden
          className="pointer-events-none fixed z-[110] select-none"
          style={{ left: fly.from.left, top: fly.from.top, width: fly.from.width, height: fly.from.height, transformOrigin: '0 0' }}
          initial={{ x: 0, y: 0, scale: 1 }}
          animate={{ x: fly.to.left - fly.from.left, y: fly.to.top - fly.from.top, scale: fly.to.height / fly.from.height }}
          transition={{ duration: getHandoffMs() / 1000, ease: [0.4, 0, 0.2, 1] }}
          data-testid="logo-flight"
        />
      )}
    </Ctx.Provider>
  );
}

/** الشاشة بتحدد شكل الخلفية طول ما هي مفتوحة، ولما تتقفل بترجع live */
export function useBackground(mode: BgMode) {
  const ctx = useContext(Ctx);
  const setBg = ctx?.setBg;
  useEffect(() => {
    if (!setBg) return;
    setBg(mode);
    return () => setBg('live');
  }, [setBg, mode]);
}

export function useStage() {
  return useContext(Ctx) ?? { phase: 'done' as SplashPhase, hero: () => undefined, target: () => undefined, setBg: () => undefined };
}
