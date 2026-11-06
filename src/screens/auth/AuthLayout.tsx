import type { ReactNode } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../../app/prefs';
import { LineIcon, MorphIcon, type LineIconName } from '../../ui/fx/LineIcon';
import { AppLogo } from '../../ui/Logo';
import { LangToggle, ThemeToggle } from '../../ui/ThemeToggle';

/**
 * شاشة مقسومة: الفورم في ناحية، ولوح جانبي بخلفية حية وأيقونة بتترسم في الناحية التانية.
 * الخلفية فيها توهج بيتبع الماوس.
 */
export function AuthLayout({
  children,
  asideIcon,
  asideKey,
  asideTitle,
  asideText,
  top,
}: {
  children: ReactNode;
  /** أيقونة واحدة، أو مجموعة بتتحول بين بعضها */
  asideIcon: LineIconName | LineIconName[];
  asideKey?: string;
  asideTitle: ReactNode;
  asideText?: ReactNode;
  top?: ReactNode;
}) {
  const { t } = useTranslation();
  const { calm } = usePrefs();
  return (
    <div className="relative min-h-dvh overflow-hidden">
      <div className="relative z-10 flex min-h-dvh flex-col">
        <header className="flex items-center justify-between px-5 py-4">
          <div className="flex items-center gap-2.5">
            <AppLogo height={36} shared />
            <div>
              <div className="text-sm font-semibold text-fg">{t('app.name')}</div>
              <div className="readout-label">{t('app.tagline')}</div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <LangToggle />
            <ThemeToggle />
          </div>
        </header>

        <div className="mx-auto grid w-full max-w-6xl flex-1 items-center gap-8 px-4 pb-10 lg:grid-cols-[minmax(0,460px)_minmax(0,1fr)] lg:gap-14">
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.26, ease: [0.2, 0.8, 0.2, 1] }} className="w-full">
            {top}
            {children}
          </motion.div>

          {/* اللوح الجانبي */}
          <div className="relative hidden h-[520px] lg:block" aria-hidden>
            <div className="glass absolute inset-0 overflow-hidden rounded-2xl">
              <div className="absolute inset-0 opacity-70" style={{ background: 'radial-gradient(500px 300px at 50% 40%, rgb(var(--accent-rgb) / 0.14), transparent 70%)' }} />
              {/* حلقات سكان */}
              <div className="absolute left-1/2 top-[42%] -translate-x-1/2 -translate-y-1/2">
                {[300, 220, 150].map((s, i) => (
                  <motion.div
                    key={s}
                    className="absolute left-1/2 top-1/2 rounded-full border border-[rgb(var(--accent-rgb)/0.14)]"
                    style={{ width: s, height: s, marginLeft: -s / 2, marginTop: -s / 2 }}
                    animate={calm ? { rotate: 0 } : { rotate: i % 2 ? -360 : 360 }}
                    transition={calm ? { duration: 0 } : { duration: 40 + i * 12, repeat: Infinity, ease: 'linear' }}
                  >
                    <span className="absolute -top-1 left-1/2 size-2 -translate-x-1/2 rounded-full bg-accent shadow-[0_0_10px_var(--accent)]" />
                  </motion.div>
                ))}
                <div className="absolute left-0 top-0 -translate-x-1/2 -translate-y-1/2">
                  <AnimatePresence mode="wait">
                    <motion.div key={asideKey ?? 'icon'} initial={{ opacity: 0, scale: 0.92 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.25 }}>
                      {Array.isArray(asideIcon) ? <MorphIcon names={asideIcon} size={112} /> : <BigIcon name={asideIcon} />}
                    </motion.div>
                  </AnimatePresence>
                </div>
              </div>
              <div className="absolute inset-x-0 bottom-0 p-8">
                <AnimatePresence mode="wait">
                  <motion.div key={asideKey ?? 'text'} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.22 }}>
                    <div className="text-xl font-semibold text-fg">{asideTitle}</div>
                    {asideText && <p className="mt-2 max-w-md text-sm text-fg-2">{asideText}</p>}
                  </motion.div>
                </AnimatePresence>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function BigIcon({ name }: { name: LineIconName }) {
  return (
    <div className="relative grid size-[112px] place-items-center">
      <div className="absolute inset-0 rounded-full opacity-60 blur-2xl" style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.3), transparent)' }} />
      <LineIcon name={name} size={112} className="relative drop-shadow-[0_0_10px_rgb(var(--accent-rgb)/0.55)]" />
    </div>
  );
}
