/**
 * U4: لون الإبراز اللي صاحب المحل بيختاره، بتباين مضمون في الوضعين (WCAG AA):
 * - الوضع الداكن: اللون لازم يبان على الخلفية الداكنة (3:1 على الأقل للحاجات والحدود، و4.5:1 للكلام الملون).
 * - الوضع الفاتح: نفس الشرط على الخلفية الفاتحة.
 * لو اللون اللي اتختار مش كفاية، بيتفتّح أو بيتغمّق شوية لحد ما يعدّي، من غير ما يتغير "لونه" نفسه (hue).
 */
export type Rgb = [number, number, number];

export function hexToRgb(hex: string): Rgb | null {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
export const rgbToHex = ([r, g, b]: Rgb) => `#${[r, g, b].map((x) => Math.round(x).toString(16).padStart(2, '0')).join('')}`;

function lum([r, g, b]: Rgb): number {
  const f = (c: number) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
export function contrast(a: Rgb, b: Rgb): number {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

/** خلط اللون بالأبيض (t > 0) أو الأسود (t < 0) */
function mix(c: Rgb, t: number): Rgb {
  const to = t > 0 ? 255 : 0;
  const k = Math.abs(t);
  return c.map((v) => v + (to - v) * k) as Rgb;
}

/** أقرب درجة من نفس اللون تعدّي التباين المطلوب على الخلفية */
export function fitContrast(c: Rgb, bg: Rgb, min: number): Rgb {
  if (contrast(c, bg) >= min) return c;
  const lighter = lum(bg) < 0.5;
  for (let i = 1; i <= 40; i++) {
    const x = mix(c, (lighter ? 1 : -1) * (i / 40));
    if (contrast(x, bg) >= min) return x.map(Math.round) as Rgb;
  }
  return lighter ? [255, 255, 255] : [0, 0, 0];
}

// خلفيات الوضعين من tokens.css (الأساسية)
export const BG_DARK: Rgb = [11, 15, 18];
export const BG_LIGHT: Rgb = [238, 243, 249];

export interface AccentVars {
  dark: Record<string, string>;
  light: Record<string, string>;
}

/** متغيرات اللون للوضعين (نفس أسماء tokens.css)، أو null لو اللون مش صالح */
export function accentVars(hex: string): AccentVars | null {
  const base = hexToRgb(hex);
  if (!base) return null;
  const build = (bg: Rgb, dark: boolean) => {
    const a = fitContrast(base, bg, 4.5);
    const hover = dark ? mix(a, 0.2) : mix(a, -0.15);
    // الكلام فوق زرار ملون: أبيض أو أسود، الأوضح
    const on: Rgb = contrast([255, 255, 255], a) >= contrast([0, 0, 0], a) ? [255, 255, 255] : [12, 16, 20];
    const rgb = a.map(Math.round).join(' ');
    return {
      '--accent': rgbToHex(a),
      '--accent-hover': rgbToHex(hover),
      '--accent-rgb': rgb,
      '--accent-soft': `rgb(${rgb} / ${dark ? 0.12 : 0.09})`,
      '--accent-glow': `rgb(${rgb} / ${dark ? 0.42 : 0.28})`,
      '--on-accent': rgbToHex(on),
    };
  };
  return { dark: build(BG_DARK, true), light: build(BG_LIGHT, false) };
}

/** CSS بيتحط في <style> فوق tokens.css */
export function accentCss(v: AccentVars): string {
  const block = (o: Record<string, string>) => Object.entries(o).map(([k, x]) => `${k}: ${x};`).join(' ');
  return `[data-theme='dark'] { ${block(v.dark)} } [data-theme='light'] { ${block(v.light)} }`;
}
