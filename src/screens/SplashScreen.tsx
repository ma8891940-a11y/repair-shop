import { useEffect, useLayoutEffect } from 'react';
import { useAppBrand } from '../app/appBrand';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import { useStage } from '../app/stage';
import { convergeSignals } from '../ui/fx/CircuitField';
import { LOGO_RATIO } from '../ui/Logo';
import { LogoIntro } from '../ui/LogoIntro';
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
  const { calm, logoAnim } = usePrefs();
  const brand = useAppBrand();
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
      {/* اللوجو في نص الشاشة بالظبط، بالحركة اللي صاحب المحل اختارها من الإعدادات ← المظهر */}
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: w, height: h }}>
        <LogoIntro style={logoAnim} w={w} h={h} k={k} calm={calm} leaving={leaving} heroRef={hero} alt={brand.name} src={brand.custom ? brand.logo : undefined} />
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
