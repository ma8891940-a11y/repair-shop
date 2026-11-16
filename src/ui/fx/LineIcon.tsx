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
  // K: أيقونات التصنيفات (مرسومة بإيدينا بنفس الأسلوب)
  box: ['M12 22l20-10 20 10v22L32 54 12 44z', 'M12 22l20 10 20-10', 'M32 32v22'],
  screen: ['M22 8h20a4 4 0 0 1 4 4v40a4 4 0 0 1-4 4H22a4 4 0 0 1-4-4V12a4 4 0 0 1 4-4z', 'M22 14h20v34H22z', 'M26 22l12 12M30 20l10 10'],
  battery: ['M24 12h16v4h4v40H20V16h4z', 'M27 30l-3 8h7l-3 8', 'M24 22h16'],
  camera: ['M12 22h10l4-6h12l4 6h10v26H12z', 'M32 27a8 8 0 1 0 .01 0', 'M45 27h.01'],
  speaker: ['M14 26h10l12-10v32L24 38H14z', 'M42 24c3 2 4 5 4 8s-1 6-4 8', 'M47 18c5 4 7 9 7 14s-2 10-7 14'],
  charge: ['M24 10v12M40 10v12', 'M18 22h28v10a14 14 0 0 1-28 0z', 'M32 46v10'],
  cable: ['M20 8v10h8V8', 'M24 18v14c0 8 16 8 16 16v8', 'M36 56h8'],
  case: ['M21 8h22a5 5 0 0 1 5 5v38a5 5 0 0 1-5 5H21a5 5 0 0 1-5-5V13a5 5 0 0 1 5-5z', 'M24 14h8v8h-8z', 'M28 18h.01'],
  glass: ['M20 8h24v48H20z', 'M16 14h4M44 50h4', 'M26 18l12 12', 'M26 28l8 8'],
  earphones: ['M14 36a18 18 0 0 1 36 0', 'M14 36h6v14h-6z', 'M44 36h6v14h-6z'],
  watch: ['M24 8h16l2 10H22z', 'M22 46h20l-2 10H24z', 'M20 18h24v28H20z', 'M32 26v6l4 3'],
  powerbank: ['M18 10h28v44H18z', 'M26 22h12', 'M30 30l-4 8h8l-4 8'],
  screwdriver: ['M42 8l14 14-6 6-14-14z', 'M36 14l-22 22-4 12 12-4 22-22', 'M14 50l-6 6'],
  gamepad: ['M18 22h28c6 0 10 6 10 14s-4 12-8 12-6-6-10-6H26c-4 0-6 6-10 6s-8-4-8-12 4-14 10-14z', 'M20 31v8M16 35h8', 'M42 33h.01M46 37h.01'],
  phone_new: ['M24 8h16a4 4 0 0 1 4 4v40a4 4 0 0 1-4 4H24a4 4 0 0 1-4-4V12a4 4 0 0 1 4-4z', 'M32 22v14M25 29h14', 'M29 50h6'],
  tablet: ['M14 10h36a4 4 0 0 1 4 4v36a4 4 0 0 1-4 4H14a4 4 0 0 1-4-4V14a4 4 0 0 1 4-4z', 'M30 48h4'],
  frame: ['M18 8h28v48H18z', 'M22 12h20v40H22z', 'M18 20h-4M18 44h-4M46 20h4M46 44h4'],
  backglass: ['M20 8h24a4 4 0 0 1 4 4v40a4 4 0 0 1-4 4H20a4 4 0 0 1-4-4V12a4 4 0 0 1 4-4z', 'M22 12h10v12H22z', 'M27 16h.01'],
  flex: ['M10 20h14v8h16v-8h14', 'M10 36h14v8h16v-8h14', 'M24 28v8M40 28v8'],
  inspect: ['M28 12a16 16 0 1 0 .01 0', 'M40 40l14 14', 'M22 28l4 4 8-8'],
  cleaning: ['M20 56l4-22h16l4 22z', 'M28 34V14h8v20', 'M24 14h16', 'M44 10l2 4M50 16l-4 2M48 24l-4-1'],
  software: ['M10 14h44v32H10z', 'M24 54h16M32 46v8', 'M24 26l-6 4 6 4M40 26l6 4-6 4M35 22l-6 16'],
  transfer: ['M16 10h14v24H16z', 'M34 30h14v24H34z', 'M30 20h10l-4-4M40 20l-4 4', 'M34 44H24l4 4M24 44l4-4'],
  unlock: ['M18 30h28v24H18z', 'M24 30V20a8 8 0 0 1 16 0', 'M32 38v8'],
  brand: ['M14 18h36v28H14z', 'M22 26h20', 'M22 34h12'],
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
