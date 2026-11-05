import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { X } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toneIcon } from './Feedback';
import { cn } from './cn';

type Tone = 'info' | 'ok' | 'warn' | 'danger';
interface Toast {
  id: number;
  tone: Tone;
  title: ReactNode;
  description?: ReactNode;
}

const Ctx = createContext<(t: Omit<Toast, 'id'>) => void>(() => {});

/** تنبيهات بتنزلق من فوق، وبتختفي لوحدها بعد 4 ثواني. مقروءة لقارئ الشاشة. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  const [items, setItems] = useState<Toast[]>([]);
  const seq = useRef(0);
  const dismiss = useCallback((id: number) => setItems((cur) => cur.filter((x) => x.id !== id)), []);
  const push = useCallback(
    (toast: Omit<Toast, 'id'>) => {
      const id = ++seq.current;
      setItems((cur) => [...cur.slice(-3), { ...toast, id }]);
      setTimeout(() => dismiss(id), 4200);
    },
    [dismiss],
  );
  return (
    <Ctx.Provider value={push}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 top-3 z-[60] flex flex-col items-center gap-2 px-3 sm:items-end sm:pe-5" aria-live="polite">
        <AnimatePresence initial={false}>
          {items.map((x) => (
            <motion.div
              key={x.id}
              layout
              initial={{ opacity: 0, y: -16, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, scale: 0.96, transition: { duration: 0.15 } }}
              transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}
              className={cn('glass-strong pointer-events-auto flex w-full max-w-sm items-start gap-2.5 rounded-lg px-3.5 py-3 text-sm')}
              role={x.tone === 'danger' ? 'alert' : 'status'}
            >
              <span className="mt-0.5 shrink-0">{toneIcon[x.tone]}</span>
              <div className="min-w-0 flex-1">
                <div className="font-semibold text-fg">{x.title}</div>
                {x.description && <div className="mt-0.5 text-fg-2">{x.description}</div>}
              </div>
              <button type="button" onClick={() => dismiss(x.id)} className="rounded-sm p-0.5 text-fg-3 hover:text-fg" aria-label={t('common.close')}>
                <X className="size-3.5" />
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </Ctx.Provider>
  );
}

export const useToast = () => useContext(Ctx);
