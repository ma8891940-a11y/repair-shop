import { Moon, Sun } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useTheme } from '../app/theme';
import { Tip } from './Tooltip';

export function ThemeToggle() {
  const { theme, toggle } = useTheme();
  const label = theme === 'dark' ? 'الوضع الفاتح' : 'الوضع الداكن';
  return (
    <Tip label={label} shortcut="Ctrl+J">
      <button
        type="button"
        onClick={toggle}
        aria-label={label}
        className="relative grid size-9 place-items-center overflow-hidden rounded-md text-fg-2 transition-colors hover:bg-raised hover:text-fg"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.span
            key={theme}
            initial={{ y: 10, opacity: 0, rotate: -30 }}
            animate={{ y: 0, opacity: 1, rotate: 0 }}
            exit={{ y: -10, opacity: 0, rotate: 30 }}
            transition={{ duration: 0.18 }}
          >
            {theme === 'dark' ? <Sun className="size-4" /> : <Moon className="size-4" />}
          </motion.span>
        </AnimatePresence>
      </button>
    </Tip>
  );
}
