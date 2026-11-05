import { animate, useMotionValue, useReducedMotion, useTransform, motion } from 'motion/react';
import { useEffect } from 'react';

/** رقم بيتحرك بنعومة لما قيمته تتغير (زي عداد جهاز قياس). بيتلغي مع "تقليل الحركة". */
export function AnimatedNumber({ value, format = (n) => String(n), className }: { value: number; format?: (n: number) => string; className?: string }) {
  const reduce = useReducedMotion();
  const mv = useMotionValue(reduce ? value : 0);
  const text = useTransform(mv, (v) => format(Math.round(v)));

  useEffect(() => {
    if (reduce) {
      mv.set(value);
      return;
    }
    const controls = animate(mv, value, { duration: 0.6, ease: [0.2, 0.8, 0.2, 1] });
    return () => controls.stop();
  }, [value, reduce, mv]);

  return (
    <motion.span className={className} aria-label={format(value)}>
      {text}
    </motion.span>
  );
}
