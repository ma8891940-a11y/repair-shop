// بيجمع كل ملفات supabase/migrations بالترتيب في ملف واحد: supabase/setup_all.sql
// الاستخدام: npm run db:setup-file
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export function buildSetup(root = process.cwd()) {
  const dir = join(root, 'supabase', 'migrations');
  const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  const head = [
    '-- جوالك / Gawalak: إعداد قاعدة البيانات كاملة في خطوة واحدة.',
    '-- شغّل الملف ده مرة واحدة بس على مشروع Supabase جديد فاضي (SQL Editor ← New query ← الصق ← Run).',
    '-- الملف ده بيتولد تلقائيًا من supabase/migrations. ما تعدّلوش بإيدك: npm run db:setup-file',
    `-- الملفات: ${files.join(', ')}`,
    '',
  ].join('\n');
  const body = files.map((f) => `-- ============================== ${f} ==============================\n${readFileSync(join(dir, f), 'utf8').trimEnd()}\n`).join('\n');
  return head + '\n' + body;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  writeFileSync(join(process.cwd(), 'supabase', 'setup_all.sql'), buildSetup());
  console.log('supabase/setup_all.sql');
  // ترقية مشروع شغّال (بيشوف الموجود ويشغّل الناقص بس)
  const { buildUpgrade } = await import('./build-upgrade.mjs');
  writeFileSync(join(process.cwd(), 'supabase', 'upgrade_existing.sql'), buildUpgrade());
  console.log('supabase/upgrade_existing.sql');
  // نصوص إشعارات الجهاز (Web Push) من الترجمة
  const { buildPushTexts } = await import('./build-push-texts.mjs');
  writeFileSync(join(process.cwd(), 'supabase', 'functions', 'push', 'texts.ts'), buildPushTexts());
  console.log('supabase/functions/push/texts.ts');
}
