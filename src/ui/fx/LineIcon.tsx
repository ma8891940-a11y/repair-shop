import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { usePrefs } from '../../app/prefs';
import { cn } from '../cn';

/** أيقونات خطية مرسومة بإيدينا (64×64). كل أيقونة مجموعة خطوط بتترسم واحد ورا التاني. */
export const LINE_ICONS = {
  phone: [
    'M25 8h14a5 5 0 0 1 5 5v38a5 5 0 0 1-5 5H25a5 5 0 0 1-5-5V13a5 5 0 0 1 5-5z',
    'M29 13.5h6',
    'M20 45h24',
    'M32 49.2a1.6 1.6 0 1 0 .01 0',
  ],
  tool: [
    'M44.5 9.5a9 9 0 0 0-10.9 11.6L12 42.7a4 4 0 0 0 5.7 5.7l21.6-21.6a9 9 0 0 0 11.6-10.9l-5.6 5.6-5.2-1.4-1.4-5.2z',
    'M16.5 44.5h.01',
  ],
  receipt: [
    'M18 8h28v48l-4.7-3-4.6 3-4.7-3-4.6 3-4.7-3L18 56z',
    'M24 19h16',
    'M24 27h16',
    'M24 35h9',
    'M35 44h5',
  ],
  chip: [
    'M21 21h22v22H21z',
    'M27 27h10v10H27z',
    'M26 14v7M32 14v7M38 14v7M26 43v7M32 43v7M38 43v7',
    'M14 26h7M14 32h7M14 38h7M43 26h7M43 32h7M43 38h7',
  ],
  scan: [
    'M10 22V14a4 4 0 0 1 4-4h8',
    'M42 10h8a4 4 0 0 1 4 4v8',
    'M54 42v8a4 4 0 0 1-4 4h-8',
    'M22 54h-8a4 4 0 0 1-4-4v-8',
    'M10 32h44',
  ],
  shield: ['M32 8l18 7v14c0 12-8 21-18 27-10-6-18-15-18-27V15z', 'M24 32l6 6 11-12'],
  store: ['M10 26l4-14h36l4 14', 'M10 26c0 4 3 7 7 7s7-3 7-7c0 4 3 7 8 7s8-3 8-7c0 4 3 7 7 7s7-3 7-7', 'M14 33v21h36V33', 'M27 54V42h10v12'],
  mail: ['M10 16h44v32H10z', 'M10 18l22 16 22-16'],
  globe: ['M32 10a22 22 0 1 0 .01 0', 'M10 32h44', 'M32 10c-7 7-7 37 0 44c7-7 7-37 0-44'],
  wallet: ['M12 18h36a4 4 0 0 1 4 4v24a4 4 0 0 1-4 4H12a4 4 0 0 1-4-4V22a4 4 0 0 1 4-4z', 'M8 26h44', 'M40 38h6'],
  palette: ['M32 10a22 22 0 1 0 0 44c3 0 4-2 4-4s-2-3-2-5 2-4 5-4h5c5 0 10-4 10-9 0-12-10-22-22-22z', 'M22 28h.01M28 20h.01M38 20h.01'],
} as const;

export type LineIconName = keyof typeof LINE_ICONS;

export function LineIcon({ name, size = 64, className, draw = true, duration = 0.9 }: { name: LineIconName; size?: number; className?: string; draw?: boolean; duration?: number }) {
  const { calm } = usePrefs();
  const paths = LINE_ICONS[name];
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" className={cn('text-accent', className)} aria-hidden>
      {paths.map((d, i) => (
        <motion.path
          key={`${name}-${i}`}
          d={d}
          stroke="currentColor"
          strokeWidth={1.6}
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={draw && !calm ? { pathLength: 0, opacity: 0 } : false}
          animate={{ pathLength: 1, opacity: 1 }}
          exit={calm ? undefined : { pathLength: 0, opacity: 0, transition: { duration: duration * 0.5 } }}
          transition={{ duration, delay: i * 0.12, ease: [0.65, 0, 0.35, 1] }}
        />
      ))}
    </svg>
  );
}

/** أيقونة بتترسم، وبعدها تتمسح وتترسم اللي بعدها (موبايل ← مفك ← إيصال ← شريحة) */
export function MorphIcon({ names = ['phone', 'tool', 'receipt', 'chip'], size = 96, interval = 2600, className }: { names?: LineIconName[]; size?: number; interval?: number; className?: string }) {
  const { calm } = usePrefs();
  const [i, setI] = useState(0);
  useEffect(() => {
    if (calm || names.length < 2) return;
    const t = setInterval(() => setI((x) => (x + 1) % names.length), interval);
    return () => clearInterval(t);
  }, [calm, names.length, interval]);
  return (
    <div className={cn('relative grid place-items-center', className)} style={{ width: size, height: size }}>
      <div className="absolute inset-0 rounded-full opacity-60 blur-2xl" style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.28), transparent)' }} />
      <AnimatePresence mode="wait">
        <LineIcon key={names[i]} name={names[i]} size={size} className="relative drop-shadow-[0_0_10px_rgb(var(--accent-rgb)/0.55)]" />
      </AnimatePresence>
    </div>
  );
}
