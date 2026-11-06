import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import ar from './ar.json';
import en from './en.json';

function keys(o: Record<string, unknown>, prefix = ''): string[] {
  return Object.entries(o).flatMap(([k, v]) => (v && typeof v === 'object' ? keys(v as Record<string, unknown>, `${prefix}${k}.`) : [`${prefix}${k}`]));
}

/** الجمع في العربي ليه صيغ زيادة (zero/two/few/many). بنقارن الكلمة الأساسية بس */
const base = (k: string) => k.replace(/_(zero|one|two|few|many|other)$/, '');

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? walk(p) : /\.(ts|tsx)$/.test(f) && !/\.test\.ts$/.test(f) ? [p] : [];
  });
}

/** بيشيل التعليقات عشان التعليقات بالعربي مسموحة */
function stripComments(src: string): string {
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:'"`])\/\/.*$/gm, '$1').replace(/\{\s*\/\*[\s\S]*?\*\/\s*\}/g, '');
}

describe('الترجمة', () => {
  it('نفس المفاتيح في العربي والإنجليزي', () => {
    const a = new Set(keys(ar).map(base));
    const e = new Set(keys(en).map(base));
    expect([...a].filter((k) => !e.has(k))).toEqual([]);
    expect([...e].filter((k) => !a.has(k))).toEqual([]);
  });

  it('مفيش نص عربي مكتوب مباشرة في الكود (كله في ملفات الترجمة)', () => {
    const root = join(__dirname, '..');
    const offenders: string[] = [];
    for (const file of walk(root)) {
      const lines = stripComments(readFileSync(file, 'utf8')).split('\n');
      lines.forEach((line, i) => {
        if (/[؀-ۿ]/.test(line) && !/i18n-allow/.test(line)) offenders.push(`${file.replace(root, 'src')}:${i + 1}: ${line.trim().slice(0, 80)}`);
      });
    }
    expect(offenders).toEqual([]);
  });

  it('مفيش نص إنجليزي ظاهر في JSX', () => {
    const root = join(__dirname, '..');
    const offenders: string[] = [];
    for (const file of walk(root).filter((f) => f.endsWith('.tsx'))) {
      const src = stripComments(readFileSync(file, 'utf8'));
      // نص بين > و < فيه كلمتين إنجليزي أو أكتر
      for (const m of src.matchAll(/>\s*([A-Za-z][A-Za-z ,.'!?-]{6,})\s*</g)) {
        if (!/^[A-Z][a-z]+$/.test(m[1].trim())) offenders.push(`${file.replace(root, 'src')}: ${m[1].trim()}`);
      }
    }
    expect(offenders).toEqual([]);
  });
});

describe('كل مفتاح نص مستخدم في الكود موجود في اللغتين', () => {
  const has = (d: unknown, k: string): boolean => {
    let cur = d as Record<string, unknown>;
    for (const p of k.split('.')) {
      if (!cur || typeof cur !== 'object') return false;
      if (p in cur) {
        cur = cur[p] as Record<string, unknown>;
        continue;
      }
      return Object.keys(cur).some((x) => x.startsWith(`${p}_`)); // صيغ الجمع
    }
    return true;
  };
  it('مفيش مفتاح ناقص', () => {
    const missing: string[] = [];
    for (const f of walk(join(__dirname, '..'))) {
      for (const m of readFileSync(f, 'utf8').matchAll(/\bt\(\s*'([a-zA-Z][\w.]+)'/g)) {
        if (!m[1].includes('.')) continue;
        if (!has(ar, m[1])) missing.push(`ar: ${m[1]}`);
        if (!has(en, m[1])) missing.push(`en: ${m[1]}`);
      }
    }
    expect(missing).toEqual([]);
  });
});
