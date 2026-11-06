import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildSetup } from '../../scripts/build-setup.mjs';

describe('ملف الإعداد الواحد', () => {
  it('supabase/setup_all.sql مطابق لكل الـ migrations بالترتيب (لو فشل: npm run db:setup-file)', () => {
    const root = join(__dirname, '..', '..');
    expect(readFileSync(join(root, 'supabase', 'setup_all.sql'), 'utf8')).toBe(buildSetup(root));
  });
});
