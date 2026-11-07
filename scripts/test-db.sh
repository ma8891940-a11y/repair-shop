#!/usr/bin/env bash
# بيشغّل Postgres مؤقت على الجهاز، يطبّق ملفات قاعدة البيانات، ويشغّل اختبارات الأمان.
# محتاج PostgreSQL 16 متثبّت. ما بيلمسش أي قاعدة بيانات حقيقية.
set -euo pipefail
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
DIR="$(mktemp -d)"
PORT="${PGPORT_TEST:-54329}"
RUN_AS=()
if [ "$(id -u)" = "0" ]; then chown postgres "$DIR"; RUN_AS=(sudo -u postgres); command -v sudo >/dev/null || RUN_AS=(su postgres -s /bin/bash -c); fi
run() { if [ "${RUN_AS[0]:-}" = "su" ]; then "${RUN_AS[@]}" "$*"; else "${RUN_AS[@]}" "$@"; fi; }
cleanup() { run "$PGBIN/pg_ctl" -D "$DIR/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$DIR"; }
trap cleanup EXIT
run "$PGBIN/initdb" -D "$DIR/data" -U postgres --auth=trust -E UTF8 >/dev/null
run "$PGBIN/pg_ctl" -D "$DIR/data" -o "-p $PORT -k $DIR -c listen_addresses=127.0.0.1" -l "$DIR/log" start -w >/dev/null
URL="postgres://postgres@127.0.0.1:$PORT/postgres"
psql -q -v ON_ERROR_STOP=1 "$URL" -f tests/db/supabase-stub.sql >/dev/null
# بنطبّق ملف الإعداد الواحد (نفس اللي صاحب المشروع بيشغّله على Supabase)
psql -q -v ON_ERROR_STOP=1 "$URL" -f supabase/setup_all.sql >/dev/null
# الملفات بالتتابع: كلها على نفس قاعدة البيانات، وبعضها بيقفل جداول لحظة (كسر التوازن عن قصد)
TEST_DATABASE_URL="$URL" npx vitest run tests/db --no-file-parallelism ${DB_TEST_FILTER:-}
