#!/usr/bin/env bash
# بيثبت إن supabase/upgrade_existing.sql بيرقّي أي قاعدة قديمة لآخر نسخة بالظبط، ومن غير ما يكسر حاجة لو اتشغّل تاني.
# لكل حالة: قاعدة فيها أول K ملفات بس ← الترقية (كل الملف في رسالة واحدة زي SQL Editor) ← نفس شكل قاعدة جديدة من setup_all.sql
# (الجداول والأعمدة، ومحتوى كل دالة، والسياسات، والتريجرات، والقيود، والـ indexes) ← الترقية تاني ما بتغيّرش حاجة.
# وبعدين نفس الحالات بالأجزاء (upgrade_part_N.sql) واحد ورا التاني، والترتيب الغلط والفجوة بيوقفوا من غير تغيير.
# على Postgres مؤقت على نفس الجهاز بس (زي test-db.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
PGBIN="$(dirname "$(command -v pg_ctl 2>/dev/null || ls /usr/lib/postgresql/*/bin/pg_ctl | tail -1)")"
DIR="$(mktemp -d)"
PORT="${PGPORT_UPGRADE:-54330}"
RUN_AS=()
if [ "$(id -u)" = "0" ]; then chown postgres "$DIR"; RUN_AS=(sudo -u postgres); command -v sudo >/dev/null || RUN_AS=(su postgres -s /bin/bash -c); fi
run() { if [ "${RUN_AS[0]:-}" = "su" ]; then "${RUN_AS[@]}" "$*"; else "${RUN_AS[@]}" "$@"; fi; }
cleanup() { run "$PGBIN/pg_ctl" -D "$DIR/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$DIR"; }
trap cleanup EXIT
run "$PGBIN/initdb" -D "$DIR/data" -U postgres --auth=trust -E UTF8 >/dev/null
run "$PGBIN/pg_ctl" -D "$DIR/data" -o "-p $PORT -k $DIR -c listen_addresses=127.0.0.1" -l "$DIR/log" start -w >/dev/null
P="postgres://postgres@127.0.0.1:$PORT"
psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database tpl"
psql -q -v ON_ERROR_STOP=1 "$P/tpl" -f tests/db/supabase-stub.sql >/dev/null 2>&1

# بصمة شكل القاعدة (من غير سجل الترقية نفسه)
FP="select string_agg(x, E'\n' order by x) from (
  select 'col ' || table_name || '.' || column_name || ' ' || data_type || ' ' || is_nullable || ' ' || coalesce(column_default, '') x from information_schema.columns where table_schema = 'public' and table_name <> 'app_migrations'
  union all select 'fn ' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ') ' || md5(p.prosrc) || ' ' || p.prosecdef from pg_proc p where p.pronamespace = 'public'::regnamespace
  union all select 'pol ' || schemaname || '.' || tablename || '.' || policyname || ' ' || cmd || ' ' || md5(coalesce(qual, '') || coalesce(with_check, '')) from pg_policies where tablename <> 'app_migrations'
  union all select 'trg ' || tgrelid::regclass || '.' || tgname || ' ' || md5(pg_get_triggerdef(oid)) from pg_trigger where not tgisinternal
  union all select 'con ' || conrelid::regclass || '.' || conname || ' ' || md5(pg_get_constraintdef(oid)) from pg_constraint where connamespace = 'public'::regnamespace and conrelid <> coalesce(to_regclass('public.app_migrations'), 0)
  union all select 'idx ' || indexname || ' ' || md5(indexdef) from pg_indexes where schemaname = 'public' and tablename <> 'app_migrations'
  union all select 'acl ' || p.proname || ' ' || coalesce(array_to_string(p.proacl, ','), '') from pg_proc p where p.pronamespace = 'public'::regnamespace
) q"

psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database ref template tpl"
psql -q -v ON_ERROR_STOP=1 "$P/ref" -f supabase/setup_all.sql >/dev/null 2>&1
REF="$(psql -At "$P/ref" -c "$FP")"
FILES=(supabase/migrations/*.sql)
N=${#FILES[@]}
UP=supabase/upgrade_existing.sql
up() { node scripts/run-sql-once.mjs "$P/$1" "$UP" 2>"$DIR/err" >/dev/null; }
fail=0
for K in ${UPGRADE_CASES:-0 1 16 28 33 39 43 47 55 $N}; do
  db="up_$K"
  psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database $db template tpl"
  for ((i = 0; i < K; i++)); do psql -q -v ON_ERROR_STOP=1 "$P/$db" -f "${FILES[$i]}" >/dev/null 2>&1; done
  # زي SQL Editor: الملف كله في رسالة واحدة
  up "$db" || { echo "K=$K: الترقية فشلت"; cat "$DIR/err"; fail=1; continue; }
  GOT="$(psql -At "$P/$db" -c "$FP")"
  if [ "$GOT" != "$REF" ]; then echo "K=$K: الشكل مختلف عن قاعدة جديدة"; diff <(echo "$REF") <(echo "$GOT") | head -20; fail=1; continue; fi
  applied="$(psql -At "$P/$db" -c "select count(*) from public.app_migrations")"
  [ "$applied" = "$N" ] || { echo "K=$K: السجل فيه $applied من $N"; fail=1; continue; }
  # مرة تانية: ولا حاجة بتتغير
  up "$db" || { echo "K=$K: التشغيل التاني فشل"; cat "$DIR/err"; fail=1; continue; }
  [ "$(psql -At "$P/$db" -c "$FP")" = "$REF" ] || { echo "K=$K: التشغيل التاني غيّر حاجة"; fail=1; continue; }
  echo "K=$K: تمام (اتطبق $((N - K)) ملف)"
done
# فجوة: ملف أحدث موجود وأقدم ناقص ← بيقف من غير ما يغيّر حاجة
psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database gap template tpl"
for ((i = 0; i < 28; i++)); do psql -q -v ON_ERROR_STOP=1 "$P/gap" -f "${FILES[$i]}" >/dev/null 2>&1; done
psql -q "$P/gap" -c "create table public.partners_probe(); create table public.branches(id uuid primary key)" >/dev/null
before="$(psql -At "$P/gap" -c "$FP")"
if up gap; then echo "gap: كان لازم يقف"; fail=1
elif grep -q E_UPGRADE_GAP "$DIR/err" && [ "$(psql -At "$P/gap" -c "$FP")" = "$before" ]; then echo "gap: وقف برسالة ومن غير تغيير"
else echo "gap: وقف بس غلط"; cat "$DIR/err"; fail=1; fi

# ============ أجزاء SQL Editor (supabase/upgrade/upgrade_part_N.sql) ============
# كل جزء بيتبعت في رسالة واحدة زي SQL Editor. الحالات: مشروع فاضي، وواقف عند ملف معيّن (PART_CASES)، وواقف عنده بسجل ترقية قديم
PARTS=(supabase/upgrade/upgrade_part_*.sql)
IFS=$'\n' PARTS=($(printf '%s\n' "${PARTS[@]}" | sort -V)); unset IFS
runpart() { node scripts/run-sql-once.mjs "$P/$1" "$2" 2>"$DIR/err" >/dev/null; }
allparts() { for f in "${PARTS[@]}"; do runpart "$1" "$f" || { echo "$2: $(basename "$f") فشل"; cat "$DIR/err"; return 1; }; done; }
for C in $(printf '%s\n' ${PART_CASES:-0 59 60 $N} log59 | awk '!seen[$0]++'); do
  K="${C#log}"
  db="part_$C"
  psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database $db template tpl"
  for ((i = 0; i < K; i++)); do psql -q -v ON_ERROR_STOP=1 "$P/$db" -f "${FILES[$i]}" >/dev/null 2>&1; done
  if [ "$C" != "$K" ]; then
    # المشروع اترقّى قبل كده بالملف الواحد: سجل الترقية فيه أول K ملفات
    psql -q -v ON_ERROR_STOP=1 "$P/$db" -c "create table public.app_migrations (version text primary key, applied_at timestamptz not null default now(), how text not null)"
    for ((i = 0; i < K; i++)); do psql -q -v ON_ERROR_STOP=1 "$P/$db" -c "insert into public.app_migrations(version, how) values ('$(basename "${FILES[$i]}")', 'applied')"; done
  fi
  allparts "$db" "parts C=$C" || { fail=1; continue; }
  GOT="$(psql -At "$P/$db" -c "$FP")"
  if [ "$GOT" != "$REF" ]; then echo "parts C=$C: الشكل مختلف عن قاعدة جديدة"; diff <(echo "$REF") <(echo "$GOT") | head -20; fail=1; continue; fi
  [ "$(psql -At "$P/$db" -c "select count(*) from public.app_migrations")" = "$N" ] || { echo "parts C=$C: السجل ناقص"; fail=1; continue; }
  # الأجزاء كلها تاني، وآخر جزء مرة تالتة: ولا حاجة بتتغير
  allparts "$db" "parts C=$C (تاني)" || { fail=1; continue; }
  runpart "$db" "${PARTS[-1]}" || { echo "parts C=$C: آخر جزء تالت مرة فشل"; cat "$DIR/err"; fail=1; continue; }
  [ "$(psql -At "$P/$db" -c "$FP")" = "$REF" ] || { echo "parts C=$C: التكرار غيّر حاجة"; fail=1; continue; }
  echo "parts C=$C: تمام (${#PARTS[@]} أجزاء، اتطبق $((N - K)) ملف، والتكرار من غير تغيير)"
done
# الترتيب: جزء قبل اللي قبله على مشروع فاضي ← بيقف من غير ما يغيّر حاجة
if [ "${#PARTS[@]}" -ge 2 ]; then
  psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database ord template tpl"
  before="$(psql -At "$P/ord" -c "$FP")"
  if runpart ord "${PARTS[-1]}"; then echo "order: كان لازم يقف"; fail=1
  elif grep -q "E_UPGRADE_ORDER.*upgrade_part_1.sql" "$DIR/err" && [ "$(psql -At "$P/ord" -c "$FP")" = "$before" ]; then echo "order: وقف برسالة (شغّل upgrade_part_1 الأول) ومن غير تغيير"
  else echo "order: وقف بس غلط"; cat "$DIR/err"; fail=1; fi
fi
# الترتيب لجزء في النص: الجزء 1 بس اتطبق، وبعدين الجزء 3 ← بيقف ويقول شغّل الجزء 2
if [ "${#PARTS[@]}" -ge 3 ]; then
  psql -q -v ON_ERROR_STOP=1 "$P/postgres" -c "create database ord2 template tpl"
  runpart ord2 "${PARTS[0]}" || { echo "order mid: الجزء 1 فشل"; cat "$DIR/err"; fail=1; }
  before="$(psql -At "$P/ord2" -c "$FP")"
  if runpart ord2 "${PARTS[2]}"; then echo "order mid: كان لازم يقف"; fail=1
  elif grep -q "E_UPGRADE_ORDER.*upgrade_part_2.sql" "$DIR/err" && [ "$(psql -At "$P/ord2" -c "$FP")" = "$before" ]; then echo "order mid: الجزء 3 بعد 1 بس وقف (شغّل upgrade_part_2 الأول) ومن غير تغيير"
  else echo "order mid: وقف بس غلط"; cat "$DIR/err"; fail=1; fi
fi
# الفجوة بالأجزاء كمان
gapfp="$(psql -At "$P/gap" -c "$FP")"
if runpart gap "${PARTS[0]}"; then echo "parts gap: كان لازم يقف"; fail=1
elif grep -q E_UPGRADE_GAP "$DIR/err" && [ "$(psql -At "$P/gap" -c "$FP")" = "$gapfp" ]; then echo "parts gap: وقف برسالة ومن غير تغيير"
else echo "parts gap: وقف بس غلط"; cat "$DIR/err"; fail=1; fi
exit $fail
