import { motion } from 'motion/react';
import { usePrefs } from '../app/prefs';

/** علامة البرنامج: دايرة معايرة بأربع علامات قياس ونقطة إبراز (تصميم أصلي). draw = تترسم بالحركة */
export function Mark({ size = 28, draw = false }: { size?: number; draw?: boolean }) {
  const { calm } = usePrefs();
  const anim = draw && !calm;
  const p = (delay: number) =>
    anim
      ? { initial: { pathLength: 0, opacity: 0 }, animate: { pathLength: 1, opacity: 1 }, transition: { duration: 0.8, delay, ease: [0.65, 0, 0.35, 1] as const } }
      : {};
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden>
      <rect x="0.5" y="0.5" width="31" height="31" rx="8" fill="var(--raised)" stroke="var(--glass-border-strong)" />
      <motion.circle cx="16" cy="16" r="8" fill="none" stroke="var(--text)" strokeWidth="1.6" {...p(0)} />
      <g stroke="var(--text)" strokeWidth="1.6" strokeLinecap="round">
        <motion.path d="M16 5.5v3" {...p(0.35)} />
        <motion.path d="M16 23.5v3" {...p(0.45)} />
        <motion.path d="M5.5 16h3" {...p(0.55)} />
        <motion.path d="M23.5 16h3" {...p(0.65)} />
      </g>
      <motion.circle
        cx="16"
        cy="16"
        r="2.4"
        fill="var(--accent)"
        style={{ filter: 'drop-shadow(0 0 3px var(--accent))' }}
        {...(anim ? { initial: { scale: 0 }, animate: { scale: 1 }, transition: { delay: 0.8, type: 'spring', stiffness: 400, damping: 15 } } : {})}
      />
    </svg>
  );
}
