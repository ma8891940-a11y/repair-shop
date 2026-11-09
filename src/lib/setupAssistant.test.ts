import { describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// npm run setup:assistant: بالعربي خطوة بخطوة، والمفتاح ما بيظهرش ولا بيفضل في أي ملف
const script = fileURLToPath(new URL('../../scripts/setup-assistant.mjs', import.meta.url));
const KEY = 'AIzaSyTESTKEY_1234567890abcdef';
const run = (input: string) => spawnSync(process.execPath, [script, '--dry-run'], { input, encoding: 'utf8' });

describe('سكريبت تشغيل المساعد', () => {
  it('بيمشي بالخطوات بالترتيب: الدخول، والنشر، والمفتاح في الأسرار، ومن غير ما يطبع المفتاح', () => {
    const r = run(`https://abcd1234efgh5678ijkl.supabase.co\n${KEY}\n`);
    expect(r.status).toBe(0);
    const out = r.stdout;
    const order = ['npx supabase login', 'functions deploy assistant', 'secrets set --env-file'].map((s) => out.indexOf(s));
    expect(order.every((i) => i >= 0)).toBe(true);
    expect([...order].sort((a, b) => a - b)).toEqual(order);
    expect(out).toContain('--project-ref=abcd1234efgh5678ijkl');
    expect(out).not.toContain(KEY);
    // الملف المؤقت اتمسح
    const tmp = /--env-file (\S+)/.exec(out)![1];
    expect(existsSync(tmp)).toBe(false);
  });
  it('كود مشروع أو مفتاح غلط بيتقال السبب بالعربي ويسأل تاني', () => {
    const r = run(`كود غلط\nabcd1234efgh5678ijkl\nمفتاح بمسافات\n${KEY}\n`);
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('الكود ده شكله مش صح');
    expect(r.stdout).toContain('المفتاح ده شكله مش صح');
  });
  it('لو الإدخال خلص قبل المفتاح: بيقف بغلط واضح', () => {
    const r = run('abcd1234efgh5678ijkl\n');
    expect(r.status).toBe(1);
    expect(r.stdout).toContain('الإدخال اتقفل');
  });
});
