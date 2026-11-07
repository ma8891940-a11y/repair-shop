import { useEffect, useLayoutEffect } from 'react';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import { useStage } from '../app/stage';
import { convergeSignals } from '../ui/fx/CircuitField';
import { LOGO_RATIO } from '../ui/Logo';
import logo from '../assets/app-logo.png';
import { getSplashSpeed } from '../lib/splashTiming';

/** ارتفاع اللوجو في الافتتاحية (نفس اللي في index.html، عشان ما يحصلش أي قفزة) */
export const SPLASH_LOGO_H = 150;
const EASE = [0.22, 1, 0.36, 1] as const;

/**
 * الشاشة الافتتاحية: فوق نفس الخلفية الحية (من stage.tsx، مش خلفية خاصة بيها).
 * - اللوجو في نص الشاشة بالظبط، وحواليه تعتيم دايري ناعم عشان يبان من غير ما يتوه في الحركة.
 * - لحظة ظهوره: الإشارات بتتجمع ناحيته، وتوهج خفيف بلون الإبراز بيظهر وينطفي، وخط سكان بيعدّي على شكل اللوجو نفسه مرة واحدة.
 * - الحركة: تكبير من 0.92 لـ 1 مع ظهور تدريجي في 500 مللي ثانية. والاسم بيظهر تحته في الإنجليزي بس (العربي مكتوب في اللوجو).
 * - بعدين اللوجو بيطير لمكانه (stage.tsx). والمجموع أقل من ثانية ونص.
 * - "تقليل الحركة": الخلفية ثابتة واللوجو بيظهر ظهور بسيط من غير تكبير ولا سكان ولا تجمّع.
 * مش صفحة تعريفية.
 */
export function SplashScreen() {
  const { t, i18n } = useTranslation();
  const { calm } = usePrefs();
  const { hero, phase } = useStage();
  const h = SPLASH_LOGO_H;
  const w = Math.round(h * LOGO_RATIO);

  // اللوجو الثابت اللي في index.html بيتشال بعد ما ده يترسم مكانه بالظبط
  useLayoutEffect(() => {
    const boot = document.getElementById('boot');
    if (!boot) return;
    const r = requestAnimationFrame(() => boot.remove());
    return () => cancelAnimationFrame(r);
  }, []);
  // الإشارات بتتجمع ناحية اللوجو لحظة ظهوره
  useEffect(() => {
    if (calm) return;
    const tm = setTimeout(() => convergeSignals(window.innerWidth / 2, window.innerHeight / 2, h * 0.9), 40);
    return () => clearTimeout(tm);
  }, [calm, h]);

  const leaving = phase !== 'splash';
  // على جهاز ضعيف نفس التسلسل بيمشي أسرع (src/lib/splashTiming.ts)
  const k = getSplashSpeed();
  return (
    <motion.div className="fixed inset-0 z-[100] overflow-hidden" initial={false} exit={{ opacity: 0, transition: { duration: 0.3 * k } }} role="status" aria-label={t('app.loading')} data-testid="splash">
      {/* تعتيم دايري ناعم حوالين اللوجو: نفس لون الخلفية، فالمنطقة دي أهدى من الباقي */}
      <div
        className="absolute left-1/2 top-1/2 size-[min(560px,120vw)] -translate-x-1/2 -translate-y-1/2 rounded-full"
        style={{ background: 'radial-gradient(closest-side, var(--bg) 0%, color-mix(in srgb, var(--bg) 72%, transparent) 30%, color-mix(in srgb, var(--bg) 30%, transparent) 62%, transparent 100%)' }}
        data-testid="splash-calm"
      />
      {/* توهج بلون الإبراز بيظهر وينطفي */}
      {!calm && (
        <motion.div
          className="absolute left-1/2 top-1/2 size-[340px] -translate-x-1/2 -translate-y-1/2 rounded-full"
          style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.32), rgb(var(--accent-rgb) / 0.08) 55%, transparent)' }}
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: [0, 1, 0], scale: [0.8, 1, 1.08] }}
          transition={{ duration: 0.9 * k, times: [0, 0.4, 1], ease: 'easeInOut' }}
          data-testid="splash-glow"
        />
      )}
      {/* اللوجو: في نص الشاشة بالظبط */}
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: w, height: h }}>
        <motion.img
          ref={hero}
          src={logo}
          alt={t('app.name')}
          draggable={false}
          className="block size-full select-none"
          initial={calm ? { opacity: 0.55 } : { opacity: 0.55, scale: 0.92 }}
          animate={{ opacity: leaving ? 0 : 1, scale: 1 }}
          transition={leaving ? { duration: 0 } : { duration: calm ? 0.25 : 0.5 * k, ease: EASE }}
          data-testid="app-mark"
        />
        {/* خط السكان بيعدّي على شكل اللوجو نفسه مرة واحدة (متقصوص على حدود اللوجو) */}
        {!calm && !leaving && (
          <div className="pointer-events-none absolute inset-0 overflow-hidden" style={{ WebkitMaskImage: `url(${logo})`, maskImage: `url(${logo})`, WebkitMaskSize: '100% 100%', maskSize: '100% 100%' }} aria-hidden>
            <motion.div
              className="absolute inset-x-0 h-[38%]"
              style={{ background: 'linear-gradient(180deg, transparent, rgb(255 255 255 / 0.10) 45%, rgb(255 255 255 / 0.55) 50%, rgb(255 255 255 / 0.10) 55%, transparent)' }}
              initial={{ top: '-40%' }}
              animate={{ top: '105%' }}
              transition={{ delay: 0.35 * k, duration: 0.45 * k, ease: 'easeInOut' }}
              data-testid="splash-scan"
            />
          </div>
        )}
        {/* الاسم تحت اللوجو (في الإنجليزي بس) بمسافة محسوبة، ومن غير ما يحرّك اللوجو من النص */}
        {i18n.language !== 'ar' && (
          <motion.div
            className="absolute left-1/2 top-full mt-5 -translate-x-1/2 whitespace-nowrap text-xl font-medium tracking-[0.22em] text-fg"
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: leaving ? 0 : 1, y: 0 }}
            transition={{ delay: leaving ? 0 : 0.1 * k, duration: leaving ? 0.15 : 0.4 * k, ease: EASE }}
          >
            {t('app.name')}
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}
