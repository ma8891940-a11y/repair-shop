import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { animate, motion, useMotionValue, useTransform } from 'motion/react';
import { usePrefs } from '../app/prefs';
import { cn } from './cn';

/** رقم بيعدّ لحد قيمته، ولما يتغير بعد كده بينبض نبضة خفيفة */
export function CountUp({ value, format = (n) => String(n), className }: { value: number; format?: (n: number) => string; className?: string }) {
  const { calm, rich } = usePrefs();
  const mv = useMotionValue(calm ? value : 0);
  const text = useTransform(mv, (v) => format(Math.round(v)));
  const prev = useRef<number | null>(null);
  const [pulse, setPulse] = useState(0);

  useEffect(() => {
    const changed = prev.current !== null && prev.current !== value;
    prev.current = value;
    if (changed) setPulse((p) => p + 1);
    if (calm) {
      mv.set(value);
      return;
    }
    const c = animate(mv, value, { duration: changed ? 0.45 : 0.9, ease: [0.2, 0.8, 0.2, 1] });
    return () => c.stop();
  }, [value, calm, mv]);

  return (
    <span className={cn('relative inline-block', className)}>
      <motion.span aria-label={format(value)}>{text}</motion.span>
      {pulse > 0 && rich && (
        <motion.span
          key={pulse}
          className="pointer-events-none absolute -inset-x-2 -inset-y-1 rounded-md"
          style={{ boxShadow: '0 0 0 1px rgb(var(--accent-rgb) / 0.6), 0 0 22px rgb(var(--accent-rgb) / 0.45)' }}
          initial={{ opacity: 0.9, scale: 0.9 }}
          animate={{ opacity: 0, scale: 1.25 }}
          transition={{ duration: 0.9, ease: 'easeOut' }}
          aria-hidden
        />
      )}
    </span>
  );
}

/** خط صغير لآخر أيام (sparkline) بيترسم من الشمال لليمين */
export function Sparkline({ data, color = 'var(--accent)', className, height = 32 }: { data: number[]; color?: string; className?: string; height?: number }) {
  const { calm } = usePrefs();
  const w = 120;
  const h = height;
  const { line, area } = useMemo(() => {
    if (data.length < 2) return { line: '', area: '' };
    const max = Math.max(1, ...data);
    const step = w / (data.length - 1);
    const pts = data.map((v, i) => [i * step, h - 3 - (v / max) * (h - 6)] as const);
    const line = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
    return { line, area: `${line} L${w} ${h} L0 ${h} Z` };
  }, [data, h]);
  const gid = useMemo(() => `sg-${Math.random().toString(36).slice(2, 8)}`, []);
  if (!line) return null;
  return (
    // إحداثيات SVG مش بتتقلب مع RTL: الأقدم دايمًا على الشمال
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" className={cn('h-8 w-full overflow-visible', className)}  aria-hidden>
      <defs>
        <linearGradient id={gid} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="0.28" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <motion.path d={area} fill={`url(#${gid})`} initial={calm ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.6, delay: 0.3 }} />
      <motion.path
        d={line}
        fill="none"
        stroke={color}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
        initial={calm ? false : { pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 0.9, ease: [0.65, 0, 0.35, 1] }}
        style={{ filter: `drop-shadow(0 0 4px ${color})` }}
      />
    </svg>
  );
}

export interface RingSegment {
  key: string;
  value: number;
  color: string;
  label: string;
}

/** حلقة متحركة لتوزيع الحالات. الأجزاء بتترسم بالترتيب، والجزء اللي عليه الماوس بيتوهج */
export function Ring({ segments, size = 180, thickness = 14, center, label }: { segments: RingSegment[]; size?: number; thickness?: number; center?: (active: RingSegment | null) => ReactNode; label: string }) {
  const { calm } = usePrefs();
  const [active, setActive] = useState<string | null>(null);
  const total = segments.reduce((s, x) => s + x.value, 0);
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  const gap = total > 0 && segments.filter((s) => s.value > 0).length > 1 ? 3 : 0;
  let offset = 0;
  const shown = segments.filter((s) => s.value > 0);
  const act = shown.find((s) => s.key === active) ?? null;
  return (
    <div className="relative grid place-items-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90" role="img" aria-label={label}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--line)" strokeWidth={thickness} opacity={0.6} />
        {shown.map((s, i) => {
          const len = (s.value / total) * c;
          const dash = Math.max(0, len - gap);
          const seg = (
            <motion.circle
              key={s.key}
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke={s.color}
              strokeWidth={active === s.key ? thickness + 3 : thickness}
              strokeLinecap="butt"
              strokeDasharray={`${dash} ${c - dash}`}
              strokeDashoffset={-offset}
              initial={calm ? false : { strokeDasharray: `0 ${c}` }}
              animate={{ strokeDasharray: `${dash} ${c - dash}` }}
              transition={{ duration: 0.7, delay: 0.08 * i, ease: [0.2, 0.8, 0.2, 1] }}
              style={{ filter: active === s.key ? `drop-shadow(0 0 6px ${s.color})` : undefined, cursor: 'pointer', transition: 'stroke-width 150ms' }}
              onPointerEnter={() => setActive(s.key)}
              onPointerLeave={() => setActive(null)}
            />
          );
          offset += len;
          return seg;
        })}
      </svg>
      <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">{center?.(act)}</div>
    </div>
  );
}
