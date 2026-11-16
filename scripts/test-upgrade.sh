#!/usr/bin/env bash
# بيثبت إن supabase/upgrade_existing.sql بيرقّي أي قاعدة قديمة لآخر نسخة بالظبط، ومن غير ما يكسر حاجة لو اتشغّل تاني.
# لكل حالة: قاعدة فيها أول K ملفات بس ← الترقية (كل الملف في رسالة واحدة زي SQL Editor) ← نفس شكل قاعدة جديدة من setup_all.sql
# (الجداول والأعمدة، ومحتوى كل دالة، والسياسات، والتريجرات، والقيود، والـ indexes) ← الترقية تاني ما بتغيّرش حاجة.
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
exit $fail
