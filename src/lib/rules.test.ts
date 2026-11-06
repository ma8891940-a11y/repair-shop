import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? walk(p) : /\.(ts|tsx)$/.test(f) && !/\.test\.ts$/.test(f) ? [p] : [];
  });
}

describe('قواعد ثابتة في الكود', () => {
  // التعليقات مش كود (فيه تعليقات بتحذّر من service_role مثلًا)
  const strip = (src: string) => src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:'"`])\/\/.*$/gm, '$1');
  const files = walk(join(__dirname, '..')).map((p) => ({ p, s: strip(readFileSync(p, 'utf8')) }));

  it('كل إضافة صف بتبعت id متولد من التطبيق (عشان الشغل بدون نت)', () => {
    const bad: string[] = [];
    for (const { p, s } of files) {
      for (const m of s.matchAll(/\.insert\(\s*\{([^}]*)/g)) {
        if (!/(^|[\s,{])id\s*[:,]/.test(m[1])) bad.push(`${p}: ${m[0].slice(0, 80)}`);
      }
    }
    expect(bad).toEqual([]);
  });

  it('مفيش service_role ولا حذف فعلي في كود الواجهة', () => {
    for (const { p, s } of files) {
      expect(s, p).not.toMatch(/service_role/i);
      expect(s, p).not.toMatch(/\.delete\(\)/);
    }
  });
});
