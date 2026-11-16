import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildSetup } from '../../scripts/build-setup.mjs';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildUpgrade, markers } from '../../scripts/build-upgrade.mjs';

describe('ملف الإعداد الواحد', () => {
  const root = join(__dirname, '..', '..');
  it('supabase/setup_all.sql مطابق لكل الـ migrations بالترتيب (لو فشل: npm run db:setup-file)', () => {
    expect(readFileSync(join(root, 'supabase', 'setup_all.sql'), 'utf8')).toBe(buildSetup(root));
  });
  it('supabase/upgrade_existing.sql مطابق لكل الـ migrations، وكل ملف ليه بصمة (ما عدا ملف واحد بيعدّل دالة بس)', () => {
    expect(readFileSync(join(root, 'supabase', 'upgrade_existing.sql'), 'utf8')).toBe(buildUpgrade(root));
    const none = (markers(root) as { file: string; marker: unknown }[]).filter((x) => !x.marker).map((x) => x.file);
    expect(none).toEqual(['0022_security_review.sql']);
  });
});
