// بيعمل supabase/upgrade_existing.sql: ترقية مشروع Supabase شغّال لآخر نسخة، من غير ما يكسر حاجة.
// لكل ملف في supabase/migrations "بصمة" (حاجة الملف بيعملها وما بتتشالش بعده): جدول، أو عمود، أو index، أو trigger، أو policy، أو سطر مميز في دالة.
// الملف الناتج: بيشوف البصمات، ويسجّل اللي موجود، ويشغّل الناقص بس بالترتيب، كل ملف في transaction لوحده.
// الاستخدام: npm run db:setup-file (بيعمل الملفين)
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const q = (s) => `'${s.replace(/'/g, "''")}'`;

/** أسماء الحاجات اللي بتتشال في ملف (عشان البصمة ما تبقاش حاجة اتشالت بعدين) */
function dropped(text) {
  const out = new Set();
  for (const m of text.matchAll(/drop\s+(table|index|trigger|policy|function|view)\s+(?:if\s+exists\s+)?(?:public\.)?"?(\w+)"?/gi)) out.add(`${m[1].toLowerCase()}:${m[2].toLowerCase()}`);
  for (const m of text.matchAll(/alter\s+table\s+(?:only\s+)?public\.(\w+)\s+drop\s+column\s+(?:if\s+exists\s+)?(\w+)/gi)) out.add(`column:${m[1].toLowerCase()}.${m[2].toLowerCase()}`);
  return out;
}

/** جسم كل دالة في ملف: الاسم ← النص */
function functions(text) {
  const out = new Map();
  const re = /create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(/gi;
  let m;
  while ((m = re.exec(text))) {
    const from = m.index;
    const tag = /\$(\w*)\$/.exec(text.slice(from));
    if (!tag) continue;
    const open = from + tag.index + tag[0].length;
    const close = text.indexOf(tag[0], open);
    if (close < 0) continue;
    out.set(m[1].toLowerCase(), text.slice(open, close));
  }
  return out;
}

export function markers(root = process.cwd()) {
  const dir = join(root, 'supabase', 'migrations');
  const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  const texts = files.map((f) => readFileSync(join(dir, f), 'utf8'));
  const res = [];
  for (let i = 0; i < files.length; i++) {
    const t = texts[i];
    const later = texts.slice(i + 1).join('\n');
    const gone = dropped(later);
    const before = texts.slice(0, i).join('\n').toLowerCase();
    let m = null;
    // 1) جدول جديد
    for (const x of t.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)/gi)) {
      const n = x[1].toLowerCase();
      if (!gone.has(`table:${n}`) && !new RegExp(`create\\s+table\\s+(if\\s+not\\s+exists\\s+)?public\\.${n}\\b`).test(before)) {
        m = { kind: 'table', sql: `to_regclass('public.${n}') is not null`, what: `table ${n}` };
        break;
      }
    }
    // 2) عمود جديد
    if (!m)
      for (const x of t.matchAll(/alter\s+table\s+(?:only\s+)?public\.(\w+)\s+add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)/gi)) {
        const [tb, col] = [x[1].toLowerCase(), x[2].toLowerCase()];
        if (!gone.has(`column:${tb}.${col}`) && !gone.has(`table:${tb}`) && !new RegExp(`public\\.${tb}\\s+add\\s+column\\s+(if\\s+not\\s+exists\\s+)?${col}\\b`).test(before)) {
          m = { kind: 'column', sql: `exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = ${q(tb)} and column_name = ${q(col)})`, what: `column ${tb}.${col}` };
          break;
        }
      }
    // 3) index أو trigger أو policy جديد
    if (!m)
      for (const [re, kind] of [
        [/create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?(\w+)/gi, 'index'],
        [/create\s+(?:constraint\s+)?trigger\s+(\w+)\s+[\s\S]*?\son\s+public\.(\w+)/gi, 'trigger'],
        [/create\s+policy\s+"?(\w+)"?\s+on\s+(?:public|storage)\.(\w+)/gi, 'policy'],
      ]) {
        for (const x of t.matchAll(re)) {
          const n = x[1].toLowerCase();
          if (gone.has(`${kind}:${n}`) || new RegExp(`\\b${n}\\b`).test(before)) continue;
          m =
            kind === 'index'
              ? { kind, sql: `to_regclass('public.${n}') is not null`, what: `index ${n}` }
              : kind === 'trigger'
                ? { kind, sql: `exists (select 1 from pg_trigger where tgname = ${q(n)} and tgrelid = to_regclass('public.${x[2].toLowerCase()}'))`, what: `trigger ${n}` }
                : { kind, sql: `exists (select 1 from pg_policies where policyname = ${q(n)})`, what: `policy ${n}` };
          break;
        }
        if (m) break;
      }
    // 4) سطر مميز في دالة ما بتتعادش بعد كده
    if (!m) {
      const fns = functions(t);
      const laterFns = new Set([...later.matchAll(/create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(/gi)].map((x) => x[1].toLowerCase()));
      for (const [name, body] of fns) {
        if (laterFns.has(name) || gone.has(`function:${name}`)) continue;
        const line = body
          .split('\n')
          .map((l) => l.trim())
          .find((l) => l.length >= 25 && !l.startsWith('--') && !before.includes(l.toLowerCase()));
        if (line) {
          m = { kind: 'function', sql: `exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = ${q(name)} and position(${q(line)} in p.prosrc) > 0)`, what: `function ${name}` };
          break;
        }
      }
    }
    // 5) سطر مميز من الملف ده لسه موجود في آخر نسخة من الدالة (الدالة اتعادت بعد كده بس السطر فضل)
    if (!m) {
      for (const [name, body] of functions(t)) {
        if (gone.has(`function:${name}`)) continue;
        let last = body;
        for (const lt of texts.slice(i + 1)) {
          const f = functions(lt).get(name);
          if (f) last = f;
        }
        const line = body
          .split('\n')
          .map((l) => l.trim())
          .find((l) => l.length >= 25 && !l.startsWith('--') && !before.includes(l.toLowerCase()) && last.includes(l));
        if (line) {
          m = { kind: 'function', sql: `exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = ${q(name)} and position(${q(line)} in p.prosrc) > 0)`, what: `function ${name}` };
          break;
        }
      }
    }
    // 6) constraint بالاسم ما اتشالش بعد كده
    if (!m)
      for (const x of t.matchAll(/add\s+constraint\s+(\w+)/gi)) {
        const n = x[1].toLowerCase();
        if (new RegExp(`drop\\s+constraint\\s+(if\\s+exists\\s+)?${n}\\b`, 'i').test(later) || new RegExp(`\\b${n}\\b`).test(before)) continue;
        m = { kind: 'constraint', sql: `exists (select 1 from pg_constraint where conname = ${q(n)})`, what: `constraint ${n}` };
        break;
      }
    res.push({ file: files[i], marker: m, text: t });
  }
  return res;
}

/** السجل وفحص الموجود والفجوة (نفسه في الملف الواحد وفي كل جزء): بيسجّل الملفات اللي موجودة فعلًا، وأي فجوة بتوقف كل حاجة */
function checkBlock(list) {
  // ملفات من غير بصمة خاصة بيها (بتعدّل دوال بس، وآمنة لو اتعادت): بتعتبر متشغّلة لو أي ملف أحدث منها موجود
  const inferred = list.filter((x) => !x.marker).map((x) => x.file);
  const out = [
    '-- سجل الترقية (للنظام بس، من غير أي بيانات محلات)',
    'create table if not exists public.app_migrations (version text primary key, applied_at timestamptz not null default now(), how text not null);',
    'alter table public.app_migrations enable row level security;',
    'revoke all on public.app_migrations from anon, authenticated;',
    '',
    '-- 1) الملفات اللي موجودة فعلًا (من البصمة) بتتسجل، وأي فجوة بتوقف كل حاجة',
    'do $chk$',
    'declare',
    '  first_missing text;',
    '  later_present text;',
    'begin',
  ];
  for (const x of list) {
    if (!x.marker) continue;
    out.push(`  if not exists (select 1 from public.app_migrations where version = ${q(x.file)}) and (${x.marker.sql}) then`);
    out.push(`    insert into public.app_migrations(version, how) values (${q(x.file)}, 'found: ${x.marker.what.replace(/'/g, '')}');`);
    out.push('  end if;');
  }
  out.push(
    `  insert into public.app_migrations(version, how) select v, 'inferred' from unnest(array[${inferred.map(q).join(', ')}]::text[]) v`,
    `    where v < (select max(version) from public.app_migrations) on conflict (version) do nothing;`,
    `  select min(v) into first_missing from unnest(array[${list.map((x) => q(x.file)).join(', ')}]) v where v not in (select version from public.app_migrations);`,
    '  select max(version) into later_present from public.app_migrations where first_missing is not null and version > first_missing;',
    "  if later_present is not null then raise exception 'E_UPGRADE_GAP: % موجود، بس % ناقص قبله. ابعت الرسالة دي للمطوّر.', later_present, first_missing; end if;",
    'end $chk$;',
    '',
  );
  return out;
}

/** ملف واحد: بيتشغّل لو مش متسجّل بس، في transaction لوحده */
function fileBlock(x) {
  const tag = `$m${x.file.slice(0, 4)}$`;
  return [
    `-- ============================== ${x.file} ==============================`,
    'begin;',
    `do $run$ begin`,
    `  if exists (select 1 from public.app_migrations where version = ${q(x.file)}) then return; end if;`,
    `  execute ${tag}`,
    x.text.trimEnd(),
    `${tag};`,
    `  insert into public.app_migrations(version, how) values (${q(x.file)}, 'applied');`,
    `  raise notice 'applied %', ${q(x.file)};`,
    'end $run$;',
    'commit;',
    '',
  ];
}

function checked(root) {
  const list = markers(root);
  if (!list[0].marker || !list.at(-1).marker) throw new Error('first and last migrations need markers');
  for (const x of list) if (x.text.includes(`$m${x.file.slice(0, 4)}$`)) throw new Error(`tag clash in ${x.file}`);
  return list;
}

export function buildUpgrade(root = process.cwd()) {
  const list = checked(root);
  const out = [
    '-- جوالك / Gawalak: ترقية مشروع Supabase شغّال لآخر نسخة (بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك).',
    '-- شغّله في SQL Editor كله مرة واحدة. بيشوف إيه اللي موجود، وبيشغّل الناقص بس بالترتيب، كل ملف في transaction لوحده.',
    '-- آمن تشغّله أكتر من مرة: لو كله موجود، مش هيعمل حاجة. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّله تاني.',
    '-- لو لقى ملف أحدث موجود وملف أقدم منه ناقص، بيقف برسالة (E_UPGRADE_GAP) من غير ما يغيّر حاجة.',
    `-- الملفات: ${list.map((x) => x.file).join(', ')}`,
    '',
    ...checkBlock(list),
    '-- 2) الناقص بالترتيب، كل ملف في transaction لوحده',
  ];
  for (const x of list) out.push(...fileBlock(x));
  out.push("select count(*) as applied_files, max(version) as latest from public.app_migrations;", '');
  return out.join('\n');
}

/** أقصى حجم لكل جزء بالبايت: SQL Editor بتاع Supabase بيرفض الطلب الكبير (حوالي 1MB)، فبنسيب هامش كبير */
export const PART_MAX_BYTES = 300_000;
const bytes = (s) => Buffer.byteLength(s, 'utf8');

/**
 * نفس الترقية مقسومة لأجزاء مرقّمة (upgrade_part_1.sql، upgrade_part_2.sql، ...) كل جزء أصغر من الحد، عشان تشتغل من SQL Editor.
 * كل جزء: نفس فحص الموجود والفجوة (E_UPGRADE_GAP) للمشروع كله، وبعدين بيتأكد إن الأجزاء اللي قبله اتطبقت (E_UPGRADE_ORDER)،
 * وبعدين ملفاته، كل ملف بيتخطى لو متسجّل. فتشغيل جزء مرتين ما بيعملش حاجة، والأجزاء بتتقسم بالترتيب (الأقدم ما بيتغيرش).
 */
export function buildUpgradeParts(root = process.cwd(), max = PART_MAX_BYTES) {
  const list = checked(root);
  const check = checkBlock(list).join('\n');
  // حجم الإطار الثابت لكل جزء (الرأس والفحص والترتيب والنهاية) تقريبيًا، وبعدين الملفات بالترتيب لحد الحد
  const frame = bytes(check) + 8_000 + list.length * 40;
  const groups = [];
  let cur = [];
  let size = frame;
  for (const x of list) {
    const b = bytes(fileBlock(x).join('\n'));
    if (frame + b > max) throw new Error(`${x.file} أكبر من حد الجزء`);
    if (cur.length && size + b > max) {
      groups.push(cur);
      cur = [];
      size = frame;
    }
    cur.push(x);
    size += b;
  }
  if (cur.length) groups.push(cur);
  const n = groups.length;
  const partOf = list.map((x) => groups.findIndex((g) => g.includes(x)) + 1);
  const name = (k) => `upgrade_part_${k}.sql`;
  return groups.map((g, i) => {
    const k = i + 1;
    const first = g[0].file;
    const last = g.at(-1).file;
    const out = [
      `-- جوالك / Gawalak: ترقية مشروع Supabase لآخر نسخة، الجزء ${k} من ${n} (الملفات ${first} لـ ${last}).`,
      '-- بيتولد تلقائيًا: npm run db:setup-file. ما تعدّلوش بإيدك.',
      `-- شغّل الأجزاء بالترتيب في SQL Editor (كل جزء لوحده: New query ← الصق ← Run): ${groups.map((_, j) => name(j + 1)).join(' ثم ')}.`,
      '-- آمن تشغّل أي جزء أكتر من مرة: اللي اتطبق قبل كده بيتخطى. ولو ملف فشل، اللي قبله بيفضل، وصلّح السبب وشغّل نفس الجزء تاني.',
      '-- لو لقى ملف أحدث موجود وأقدم منه ناقص بيقف (E_UPGRADE_GAP). ولو جزء قبله لسه ما اتطبقش بيقف (E_UPGRADE_ORDER). الاتنين من غير تغيير.',
      `-- ملفات الجزء ده: ${g.map((x) => x.file).join(', ')}`,
      '',
      check,
      '-- 2) الأجزاء اللي قبل الجزء ده لازم تكون اتطبقت',
      'do $ord$',
      'declare',
      `  files text[] := array[${list.map((x) => q(x.file)).join(', ')}];`,
      `  parts int[] := array[${partOf.join(', ')}];`,
      '  miss text;',
      'begin',
      `  select min(v) into miss from unnest(files) v where v < ${q(first)} and v not in (select version from public.app_migrations);`,
      `  if miss is not null then raise exception 'E_UPGRADE_ORDER: الملف % لسه ما اتطبقش. شغّل upgrade_part_%.sql الأول، وبعدين الجزء ده (${k}).', miss, parts[array_position(files, miss)]; end if;`,
      'end $ord$;',
      '',
      `-- 3) ملفات الجزء ${k} بالترتيب، كل ملف في transaction لوحده`,
    ];
    for (const x of g) out.push(...fileBlock(x));
    out.push(
      `select ${k} as part, ${n} as parts, count(*) as applied_files, max(version) as latest,`,
      `  case when ${q(last)} in (select version from public.app_migrations) then`,
      `    ${k === n ? "'خلص: المشروع على آخر نسخة'" : `'الجزء ${k} خلص. اللي بعده: ${name(k + 1)}'`}`,
      `  else 'فيه ملف ما اتطبقش' end as status`,
      'from public.app_migrations;',
      '',
    );
    return { name: name(k), files: g.map((x) => x.file), sql: out.join('\n') };
  });
}
