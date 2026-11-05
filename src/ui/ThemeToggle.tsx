import { Languages, Moon, Sun } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import { Tip } from './Tooltip';
import { cn } from './cn';

const iconBtn = 'relative grid size-9 place-items-center overflow-hidden rounded-md text-fg-2 transition-colors hover:bg-raised/70 hover:text-fg';

export function ThemeToggle({ className }: { className?: string }) {
  const { theme, toggleTheme } = usePrefs();
  const { t } = useTranslation();
  const label = theme === 'dark' ? t('prefs.lightMode') : t('prefs.darkMode');
  return (
    <Tip label={label} shortcut="Ctrl+J">
      <button type="button" onClick={toggleTheme} aria-label={label} className={cn(iconBtn, className)}>
        <AnimatePresence mode="wait" initial={false}>
          <motion.span key={theme} initial={{ y: 10, opacity: 0, rotate: -40 }} animate={{ y: 0, opacity: 1, rotate: 0 }} exit={{ y: -10, opacity: 0, rotate: 40 }} transition={{ duration: 0.18 }}>
            {theme === 'dark' ? <Sun className="size-4" /> : <Moon className="size-4" />}
          </motion.span>
        </AnimatePresence>
      </button>
    </Tip>
  );
}

/** زرار اللغة: عربي ⇄ English، وبيقلب الاتجاه */
export function LangToggle({ className }: { className?: string }) {
  const { lang, toggleLang } = usePrefs();
  const { t } = useTranslation();
  return (
    <Tip label={t('prefs.language')} shortcut="Ctrl+L">
      <button type="button" onClick={toggleLang} aria-label={t('prefs.switchTo')} className={cn('flex h-9 items-center gap-1.5 rounded-md px-2.5 text-xs font-semibold text-fg-2 transition-colors hover:bg-raised/70 hover:text-fg', className)}>
        <Languages className="size-4" aria-hidden />
        <span lang={lang === 'ar' ? 'en' : 'ar'}>{t('prefs.otherLangShort')}</span>
      </button>
    </Tip>
  );
}
