// بيبعت ملف SQL كله في رسالة واحدة (زي SQL Editor بتاع Supabase)، وبيطبع الخطأ لو حصل
// الاستخدام: node scripts/run-sql-once.mjs <connection-url> <file>
import { readFileSync } from 'node:fs';
import pg from 'pg';

const [url, file] = process.argv.slice(2);
const c = new pg.Client({ connectionString: url });
await c.connect();
try {
  await c.query(readFileSync(file, 'utf8'));
} catch (e) {
  console.error(e.message);
  process.exitCode = 1;
} finally {
  await c.end();
}
