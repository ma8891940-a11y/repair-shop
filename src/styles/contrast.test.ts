import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

// تباين WCAG AA: كل لون نص على كل خلفية في الوضعين >= 4.5، ومحسوب من tokens.css نفسه
const css = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8');

function block(selector: string) {
  const i = css.indexOf(selector);
  expect(i, selector).toBeGreaterThanOrEqual(0);
  const body = css.slice(css.indexOf('{', i) + 1, css.indexOf('\n}', i));
  const vars: Record<string, string> = {};
  for (const m of body.matchAll(/--([\w-]+):\s*(#[0-9a-fA-F]{6})\s*;/g)) vars[m[1]] = m[2];
  return vars;
}
function lum(hex: string) {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
export function contrast(a: string, b: string) {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

const TEXTS = ['text', 'text-2', 'text-3', 'accent', 'danger', 'warn', 'ok'];
const BGS = ['bg', 'bg-2', 'surface', 'raised', 'overlay', 'sunken'];

describe('التباين (WCAG AA)', () => {
  it('حساب التباين نفسه صح (أبيض على أسود = 21)', () => {
    expect(contrast('#ffffff', '#000000')).toBeCloseTo(21, 5);
    expect(contrast('#777777', '#ffffff')).toBeCloseTo(4.48, 2);
  });
  for (const [theme, sel] of [
    ['الداكن', "[data-theme='dark']"],
    ['الفاتح', "[data-theme='light']"],
  ] as const) {
    it(`الوضع ${theme}: كل نص على كل خلفية >= 4.5، والنص على لون الإبراز كمان`, () => {
      const v = { ...block(":root,\n[data-theme='dark']"), ...(theme === 'الفاتح' ? block(sel) : {}) };
      const bad: string[] = [];
      for (const t of TEXTS)
        for (const b of BGS) {
          if (!v[t] || !v[b]) continue;
          const r = contrast(v[t], v[b]);
          if (r < 4.5) bad.push(`${t} على ${b}: ${r.toFixed(2)}`);
        }
      expect(v['on-accent'] && v.accent, 'on-accent').toBeTruthy();
      const onAccent = contrast(v['on-accent'], v.accent);
      if (onAccent < 4.5) bad.push(`on-accent على accent: ${onAccent.toFixed(2)}`);
      expect(bad).toEqual([]);
    });
  }
});
