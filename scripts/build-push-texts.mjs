// نصوص الإشعارات على الجهاز (Web Push) للـ Edge Function: بتتاخد من src/i18n عشان تفضل نفس كلام الجرس بالظبط.
// بيتولد مع npm run db:setup-file، وفيه اختبار بيفشل لو مش محدّث (src/lib/pushText.test.ts).
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export function buildPushTexts(root = process.cwd()) {
  const out = {};
  for (const l of ['ar', 'en']) {
    const d = JSON.parse(readFileSync(join(root, 'src', 'i18n', `${l}.json`), 'utf8'));
    const p = d.push;
    out[l] = { kinds: d.notify.kinds, titles: p.titles, summary: p.summary, test: p.test, open: p.open, read: p.read };
  }
  return [
    '// الملف ده بيتولد تلقائيًا من src/i18n (notify.kinds و push). ما تعدّلوش بإيدك: npm run db:setup-file',
    `export const TEXTS = ${JSON.stringify(out, null, 2)} as const;`,
    '',
  ].join('\n');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  writeFileSync(join(process.cwd(), 'supabase', 'functions', 'push', 'texts.ts'), buildPushTexts());
  console.log('supabase/functions/push/texts.ts');
}
