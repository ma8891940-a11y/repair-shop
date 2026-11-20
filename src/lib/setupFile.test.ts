import { describe, expect, it } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildSetup } from '../../scripts/build-setup.mjs';
// @ts-expect-error سكريبت JS من غير أنواع
import { buildUpgrade, buildUpgradeParts, markers, PART_MAX_BYTES } from '../../scripts/build-upgrade.mjs';

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
  it('أجزاء الترقية (supabase/upgrade/upgrade_part_N.sql) مطابقة، وكل جزء أصغر من حد SQL Editor، وبتغطي كل الملفات بالترتيب مرة واحدة', () => {
    const parts = buildUpgradeParts(root) as { name: string; files: string[]; sql: string }[];
    const onDisk = readdirSync(join(root, 'supabase', 'upgrade')).filter((f) => /^upgrade_part_\d+\.sql$/.test(f)).sort();
    expect(onDisk).toEqual(parts.map((p) => p.name).sort());
    for (const p of parts) {
      expect(readFileSync(join(root, 'supabase', 'upgrade', p.name), 'utf8')).toBe(p.sql);
      expect(Buffer.byteLength(p.sql, 'utf8')).toBeLessThanOrEqual(PART_MAX_BYTES);
      // نفس فحوصات الأمان في كل جزء
      expect(p.sql).toContain('E_UPGRADE_GAP');
      expect(p.sql).toContain('E_UPGRADE_ORDER');
    }
    const migrations = readdirSync(join(root, 'supabase', 'migrations')).filter((f) => f.endsWith('.sql')).sort();
    expect(parts.flatMap((p) => p.files)).toEqual(migrations);
  });
});
