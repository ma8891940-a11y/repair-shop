import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import { CircuitField } from '../ui/fx/CircuitField';
import { AppLogo } from '../ui/Logo';

/** الشاشة الافتتاحية: الشعار بيترسم فوق الخلفية الحية، وخط تحميل رفيع. مش صفحة تعريفية. */
export function SplashScreen({ duration }: { duration: number }) {
  const { t, i18n } = useTranslation();
  const { calm } = usePrefs();
  return (
    <motion.div
      className="fixed inset-0 z-[100] grid place-items-center overflow-hidden bg-bg"
      style={{ background: 'var(--page-gradient)' }}
      initial={{ opacity: 1 }}
      exit={{ opacity: 0, transition: { duration: 0.22 } }}
      role="status"
      aria-label={t('app.loading')}
    >
      <CircuitField density={1.4} />
      <div className="relative flex flex-col items-center">
        <motion.div initial={calm ? false : { scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ duration: 0.4 }} className="relative">
          <div className="absolute inset-0 -m-6 rounded-full opacity-70 blur-2xl" style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.35), transparent)' }} />
          <AppLogo height={150} intro />
        </motion.div>
        <motion.div initial={calm ? false : { opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.45, duration: 0.3 }} className="mt-5 text-center">
          {/* الاسم العربي مكتوب في اللوجو نفسه، فبيظهر كنص في الإنجليزي بس */}
          {i18n.language !== 'ar' && <div className="text-glow text-2xl font-semibold tracking-tight text-fg">{t('app.name')}</div>}
          <div className="mt-1 text-sm text-fg-3">{t('app.tagline')}</div>
        </motion.div>
        <div className="mt-8 h-[2px] w-40 overflow-hidden rounded-full bg-line">
          <motion.div
            className="h-full rounded-full bg-accent shadow-[0_0_8px_var(--accent)]"
            style={{ transformOrigin: 'var(--start-origin)' }}
            initial={{ scaleX: 0 }}
            animate={{ scaleX: 1 }}
            transition={{ duration: duration / 1000, ease: [0.4, 0, 0.2, 1] }}
          />
        </div>
        <div className="readout-label mt-3">{t('splash.booting')}</div>
      </div>
    </motion.div>
  );
}
