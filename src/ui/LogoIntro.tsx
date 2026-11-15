import { useMemo, type Ref } from 'react';
import { motion } from 'motion/react';
import defaultLogo from '../assets/app-logo.png';
import outline from '../assets/app-logo-outline.json';

/**
 * حركة ظهور لوجو التطبيق. اللوجو نفسه (الصورة الأصلية) ما بيتغيّرش أبدًا: لا شكل ولا ألوان ولا نسب.
 * الحركة بتحصل حواليه بس:
 * - draw: حدود اللوجو (متطلّعة من شفافية الصورة نفسها) بتترسم بخط مضيء، وبعدين الصورة بتتملى بنعومة.
 * - shine: الصورة بتظهر بتكبير خفيف من 0.9 لـ 1، وبعدين لمعة ضوء بتعدّي عليها مرة واحدة (متقصوصة على شكل اللوجو).
 * - assemble: أجزاء من الصورة نفسها بتيجي من الإشارات اللي في الخلفية وتتجمع.
 * وبعد كل واحدة: نبضة توهج خفيفة واحدة. المدة كلها أقل من 1.2 ثانية (k بيسرّعها على الأجهزة الضعيفة).
 */
export type LogoAnim = 'draw' | 'shine' | 'assemble';
export const LOGO_ANIMS: LogoAnim[] = ['draw', 'shine', 'assemble'];
/** مدة الحركة نفسها (من غير الطيران)، بالثواني: الحركة 0.65 + نبضة التوهج 0.2 */
export const INTRO_S = 0.85;

const EASE = [0.22, 1, 0.36, 1] as const;
const SOFT = [0.45, 0, 0.2, 1] as const;

/** شبكة القطع في "تجميع": 4 × 3، وكل قطعة جاية من اتجاه مختلف (ثابت، عشان الحركة نفسها كل مرة) */
const COLS = 4;
const ROWS = 3;
const FROM = [
  [-1.6, -1.1], [-0.5, -1.7], [0.6, -1.6], [1.7, -1.0],
  [-1.9, 0.1], [-0.7, 0.9], [0.8, -0.8], [2.0, 0.2],
  [-1.5, 1.2], [-0.4, 1.8], [0.5, 1.7], [1.6, 1.1],
];

export function LogoIntro({ style, w, h, k = 1, calm = false, leaving = false, heroRef, alt, testids = true, src }: {
  style: LogoAnim;
  w: number;
  h: number;
  /** معامل السرعة (1 = زي التصميم) */
  k?: number;
  /** "تقليل الحركة": ظهور بسيط من غير حركة */
  calm?: boolean;
  /** الافتتاحية خلصت واللوجو بيطير لمكانه: الصورة هنا بتستخبى (اللي بيطير نسخة تانية) */
  leaving?: boolean;
  heroRef?: Ref<HTMLImageElement>;
  alt: string;
  testids?: boolean;
  /** U4: لوجو المحل بدل لوجو التطبيق (نفس الحركة؛ "الرسم" بيرسم إطار حواليه بدل حدود اللوجو الأصلي) */
  src?: string;
}) {
  const logo = src || defaultLogo;
  const custom = !!src && src !== defaultLogo;
  const tid = (s: string) => (testids ? s : undefined);
  const s = (n: number) => n * k;
  const pieces = useMemo(() => Array.from({ length: COLS * ROWS }, (_, i) => ({ i, c: i % COLS, r: Math.floor(i / COLS) })), []);

  // تقليل الحركة: الصورة بتظهر بس
  if (calm) {
    return (
      <div className="relative" style={{ width: w, height: h }}>
        <motion.img ref={heroRef} src={logo} alt={alt} draggable={false} className="block size-full select-none object-contain" initial={{ opacity: 0.55 }} animate={{ opacity: leaving ? 0 : 1 }} transition={{ duration: leaving ? 0 : 0.25 }} data-testid={tid('app-mark')} />
      </div>
    );
  }

  const imgAnim =
    style === 'shine'
      ? { initial: { opacity: 0.55, scale: 0.9 }, animate: { opacity: leaving ? 0 : 1, scale: 1 }, transition: leaving ? { duration: 0 } : { duration: s(0.5), ease: EASE } }
      : style === 'draw'
        ? { initial: { opacity: 0 }, animate: { opacity: leaving ? 0 : 1 }, transition: leaving ? { duration: 0 } : { delay: s(0.35), duration: s(0.35), ease: SOFT } }
        : // assemble: الصورة الكاملة بتظهر لما القطع توصل (من غير أي فرق في الشكل)
          { initial: { opacity: 0 }, animate: { opacity: leaving ? 0 : 1 }, transition: leaving ? { duration: 0 } : { delay: s(0.62), duration: 0.01 } };

  return (
    <div className="relative" style={{ width: w, height: h }} data-testid={tid(`logo-intro-${style}`)}>
      {/* نبضة توهج واحدة بعد الحركة (هالة ورا اللوجو، مش على اللوجو نفسه) */}
      <motion.div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-1/2 size-[200%] -translate-x-1/2 -translate-y-1/2 rounded-full"
        style={{ background: 'radial-gradient(closest-side, rgb(var(--accent-rgb) / 0.30), rgb(var(--accent-rgb) / 0.07) 55%, transparent)' }}
        initial={{ opacity: 0, scale: 0.85 }}
        animate={leaving ? { opacity: 0 } : { opacity: [0, 0, 1, 0], scale: [0.85, 0.85, 1, 1.06] }}
        transition={leaving ? { duration: 0.15 } : { duration: s(INTRO_S), times: [0, 0.74, 0.86, 1], ease: 'easeInOut' }}
        data-testid={tid('splash-glow')}
      />

      <motion.img ref={heroRef} src={logo} alt={alt} draggable={false} className="relative block size-full select-none object-contain" {...imgAnim} data-testid={tid('app-mark')} />

      {style === 'draw' && !leaving && (
        <svg className="pointer-events-none absolute inset-0 size-full overflow-visible" viewBox={custom ? '0 0 100 100' : `0 0 ${outline.w} ${outline.h}`} preserveAspectRatio={custom ? 'none' : undefined} aria-hidden data-testid={tid('splash-outline')}>
          <motion.path
            d={custom ? 'M50 1 H91 Q99 1 99 9 V91 Q99 99 91 99 H9 Q1 99 1 91 V9 Q1 1 9 1 Z' : outline.d}
            fill="none"
            stroke="rgb(var(--accent-rgb))"
            strokeWidth={custom ? 1.2 : outline.w / 160}
            strokeLinejoin="round"
            style={{ filter: 'drop-shadow(0 0 6px rgb(var(--accent-rgb) / 0.9))' }}
            initial={{ pathLength: 0, opacity: 1 }}
            animate={{ pathLength: 1, opacity: [1, 1, 0] }}
            transition={{ pathLength: { duration: s(0.5), ease: SOFT }, opacity: { duration: s(0.8), times: [0, 0.7, 1] } }}
          />
        </svg>
      )}

      {style === 'shine' && !leaving && (
        // لمعة ضوء بتعدّي مرة واحدة، متقصوصة على شكل اللوجو نفسه
        <div className="pointer-events-none absolute inset-0 overflow-hidden" style={{ WebkitMaskImage: `url(${logo})`, maskImage: `url(${logo})`, WebkitMaskSize: '100% 100%', maskSize: '100% 100%' }} aria-hidden>
          <motion.div
            className="absolute -inset-y-1/4 w-[38%]"
            style={{ background: 'linear-gradient(100deg, transparent, rgb(255 255 255 / 0.12) 40%, rgb(255 255 255 / 0.6) 50%, rgb(255 255 255 / 0.12) 60%, transparent)' }}
            initial={{ left: '-45%' }}
            animate={{ left: '110%' }}
            transition={{ delay: s(0.3), duration: s(0.42), ease: 'easeInOut' }}
            data-testid={tid('splash-sheen')}
          />
        </div>
      )}

      {style === 'assemble' && !leaving && (
        <div className="pointer-events-none absolute inset-0" aria-hidden data-testid={tid('splash-pieces')}>
          {pieces.map(({ i, c, r }) => (
            <motion.div
              key={i}
              className="absolute"
              style={{
                left: `${(c * 100) / COLS}%`,
                top: `${(r * 100) / ROWS}%`,
                width: `${100 / COLS}%`,
                height: `${100 / ROWS}%`,
                backgroundImage: `url(${logo})`,
                backgroundSize: `${COLS * 100}% ${ROWS * 100}%`,
                backgroundPosition: `${(c * 100) / (COLS - 1)}% ${(r * 100) / (ROWS - 1)}%`,
              }}
              initial={{ x: FROM[i][0] * w * 0.55, y: FROM[i][1] * h * 0.55, opacity: 0, scale: 0.6 }}
              animate={{ x: 0, y: 0, opacity: [0, 1, 1, 0], scale: 1 }}
              transition={{ duration: s(0.56), delay: s((i % 4) * 0.02), ease: EASE, opacity: { duration: s(0.7), times: [0, 0.3, 0.97, 1] } }}
            />
          ))}
        </div>
      )}
    </div>
  );
}
