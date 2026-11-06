import { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { motion } from 'motion/react';
import { usePrefs } from './prefs';
import { CircuitField } from '../ui/fx/CircuitField';
import logoSrc from '../assets/app-logo.png';

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
export const HANDOFF_S = 0.45;

export function StageProvider({ phase, children }: { phase: SplashPhase; children: ReactNode }) {
  const [mode, setMode] = useState<BgMode>('live');
  const { rich } = usePrefs();
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
        >
          <CircuitField density={1.1} still={mode === 'still'} glowFollow={mode === 'live' && rich && phase === 'done'} />
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
          transition={{ duration: HANDOFF_S, ease: [0.4, 0, 0.2, 1] }}
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
