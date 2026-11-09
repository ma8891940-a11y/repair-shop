#!/usr/bin/env node
// تشغيل المساعد الذكي على مشروع Supabase خطوة بخطوة بالعربي (npm run setup:assistant)
//
// 1) بيسأل عن كود المشروع  2) بيعمل تسجيل دخول لأداة Supabase  3) بينشر دالة المساعد
// 4) بيسأل عن مفتاح Gemini المجاني (مخفي وانت بتكتبه) ويحطه في أسرار Supabase
//
// المفتاح ما بيتكتبش على الشاشة، وما بيتحفظش في أي ملف في المشروع: بيتكتب في ملف مؤقت
// جوه فولدر النظام المؤقت، والأداة بتقراه، وبعدين بيتمسح على طول حتى لو حصل غلط.
// --dry-run: بيطبع الأوامر من غير ما ينفذها (للاختبار).
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const DRY = process.argv.includes('--dry-run');
const say = (s = '') => process.stdout.write(`${s}\n`);
const win = process.platform === 'win32';

// قراءة السطور من الكيبورد أو من ملف (في الاختبار)
const rl = createInterface({ input: process.stdin, terminal: false });
const lines = [];
const waiting = [];
rl.on('line', (l) => (waiting.length ? waiting.shift()(l) : lines.push(l)));
rl.on('close', () => waiting.splice(0).forEach((r) => r(null)));
const readLine = () => new Promise((r) => (lines.length ? r(lines.shift()) : waiting.push(r)));

async function ask(q) {
  process.stdout.write(q);
  const v = await readLine();
  if (v == null) throw new Error('E_INPUT_CLOSED');
  return v.trim();
}

/** المفتاح: مخفي وانت بتكتبه لو الشاشة Terminal حقيقي */
async function askSecret(q) {
  if (!process.stdin.isTTY) return ask(q);
  process.stdout.write(q);
  rl.pause();
  return new Promise((resolve) => {
    let v = '';
    process.stdin.setRawMode(true);
    process.stdin.resume();
    const onData = (buf) => {
      for (const ch of buf.toString('utf8')) {
        if (ch === '\r' || ch === '\n') {
          process.stdin.setRawMode(false);
          process.stdin.off('data', onData);
          process.stdout.write('\n');
          rl.resume();
          return resolve(v.trim());
        }
        if (ch === '\u0003') process.exit(130);
        if (ch === '\u007f' || ch === '\b') v = v.slice(0, -1);
        else v += ch;
      }
    };
    process.stdin.on('data', onData);
  });
}

/** بينفذ أمر من أوامر Supabase (والمستخدم بيشوف الأداة وبيرد عليها مباشرة) */
function run(args, label) {
  say(`\n▸ ${label}`);
  say(`  npx supabase ${args.join(' ')}`);
  if (DRY) return 0;
  const r = spawnSync(win ? 'npx.cmd' : 'npx', ['supabase', ...args], { stdio: 'inherit', shell: win });
  return r.status ?? 1;
}
/** النسخ الجديدة من الأداة بتستخدم --project-ref، وفيه نسخ بتستخدم --remote */
function runWithRef(args, ref, label) {
  if (run([...args, `--project-ref=${ref}`], label) === 0) return true;
  say('  جرّبنا بطريقة تانية (نسخة مختلفة من أداة Supabase)...');
  return run([...args, `--remote=${ref}`], label) === 0;
}

async function main() {
  say('==============================================');
  say(' تشغيل المساعد الذكي (مجاني: Gemini من Google)');
  say('==============================================');
  say('هتحتاج: إنترنت، وحساب Supabase بتاع المشروع، ومفتاح Gemini المجاني.');
  say('المفتاح: افتح https://aistudio.google.com ← Get API key ← Create API key، وانسخه.');
  say('');

  // 1) كود المشروع
  let ref = '';
  for (;;) {
    const v = (await ask('1) اكتب كود مشروع Supabase (الكلمة اللي قبل .supabase.co في رابط المشروع): ')).toLowerCase();
    const m = /^(?:https?:\/\/)?([a-z0-9]{15,30})(?:\.supabase\.co)?\/?$/.exec(v);
    if (m) {
      ref = m[1];
      break;
    }
    say('   الكود ده شكله مش صح. مثال: لو الرابط https://abcd1234efgh5678ijkl.supabase.co يبقى الكود abcd1234efgh5678ijkl');
  }

  // 2) تسجيل الدخول
  say('\n2) تسجيل الدخول: هيفتح المتصفح، ادخل بحساب Supabase ووافق.');
  if (run(['login'], 'تسجيل الدخول') !== 0) return fail('تسجيل الدخول ما نجحش. جرّب تاني، أو اتأكد إن النت شغال.');

  // 3) نشر الدالة
  say('\n3) نشر دالة المساعد على مشروعك (لو سألك "متأكد؟" اكتب y ودوس Enter).');
  if (!runWithRef(['functions', 'deploy', 'assistant', '--use-api'], ref, 'نشر الدالة')) return fail('النشر ما نجحش. اتأكد من كود المشروع وإنك داخل بنفس الحساب.');

  // 4) المفتاح
  let key = '';
  for (;;) {
    key = await askSecret('\n4) الصق مفتاح Gemini (مش هيظهر وانت بتكتبه) ودوس Enter: ');
    if (/^[A-Za-z0-9_-]{20,200}$/.test(key)) break;
    say('   المفتاح ده شكله مش صح (غالبًا بيبدأ بـ AIza ومن غير مسافات). جرّب تاني.');
  }
  const dir = mkdtempSync(join(tmpdir(), 'gawalak-'));
  const file = join(dir, 'assistant.env');
  try {
    writeFileSync(file, `GEMINI_API_KEY=${key}\nAI_PROVIDER=gemini\n`, { mode: 0o600 });
    if (!runWithRef(['secrets', 'set', '--env-file', file], ref, 'حفظ المفتاح في أسرار Supabase')) return fail('حفظ المفتاح ما نجحش. تقدر تحطه بإيدك: مشروعك ← Edge Functions ← Secrets ← GEMINI_API_KEY.');
  } finally {
    rmSync(dir, { recursive: true, force: true });
    key = '';
  }

  say('\n✔ خلاص. افتح البرنامج ← الإعدادات ← المساعد: لازم يقول "المساعد شغال على السيرفر".');
  say('  ومن نفس المكان تختار فين يشتغل ومين يستخدمه (المالية مقفولة لحد ما تفتحها بنفسك).');
  rl.close();
  return 0;
}

function fail(msg) {
  say(`\n✖ ${msg}`);
  say('  التفاصيل والخطوات اليدوية في README تحت "المساعد الذكي".');
  rl.close();
  process.exitCode = 1;
  return 1;
}

main().catch((e) => {
  fail(e?.message === 'E_INPUT_CLOSED' ? 'الإدخال اتقفل قبل ما نخلص.' : 'حصل غلط غير متوقع.');
});
