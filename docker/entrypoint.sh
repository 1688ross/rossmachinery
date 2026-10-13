#!/usr/bin/env bash
# Boot: wait for Postgres, set the database up once (schema, roles, Django tables, optional
# sample data), then serve. Safe to run every start: every step is idempotent.
set -euo pipefail
cd "${RMS_APP_DIR:-/app}"

ADMIN_USER="${RMS_DB_ADMIN_USER:-postgres}"
ADMIN_PASSWORD="${RMS_DB_ADMIN_PASSWORD:?set RMS_DB_ADMIN_PASSWORD}"
APP_USER="${PGUSER:-po_api}"
APP_PASSWORD="${PGPASSWORD:?set PGPASSWORD, the password of the app role}"
DB="${PGDATABASE:-rms}"
HOST="${PGHOST:-db}"; PORT="${PGPORT:-5432}"

admin() { PGPASSWORD="$ADMIN_PASSWORD" psql -v ON_ERROR_STOP=1 -q -h "$HOST" -p "$PORT" -U "$ADMIN_USER" "$@"; }

echo "== waiting for postgres at $HOST:$PORT"
for i in $(seq 1 60); do
  PGPASSWORD="$ADMIN_PASSWORD" pg_isready -h "$HOST" -p "$PORT" -U "$ADMIN_USER" >/dev/null 2>&1 && break
  sleep 1
done

case "${RMS_REQUIRE_2FA:-1}" in 0|false|no|off|FALSE|NO|OFF|False|No|Off)
  if [ "${RMS_SEED_DEMO:-0}" != "1" ] && [ "${RMS_ALLOW_NO_2FA:-0}" != "1" ]; then
    echo "!! Refusing to start: the second factor is off (RMS_REQUIRE_2FA=${RMS_REQUIRE_2FA}) on a box that is not a demo (RMS_SEED_DEMO is not 1)."
    echo "!! Set RMS_REQUIRE_2FA=1 for a real install. For a throwaway box, set RMS_ALLOW_NO_2FA=1 as well."
    exit 3
  fi;;
esac

echo "== database $DB"
admin -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB'" | grep -q 1 || admin -d postgres -c "CREATE DATABASE \"$DB\""
admin -d "$DB" -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"

apply() {  # apply one schema migration file once
  local f="$1" name; name="$(basename "$f")"
  if admin -d "$DB" -tAc "SELECT 1 FROM public.schema_migrations WHERE name = '$name'" | grep -q 1; then return; fi
  echo "== applying $name"
  admin -d "$DB" -f "$f"
  admin -d "$DB" -c "INSERT INTO public.schema_migrations (name) VALUES ('$name')"
}
seed() {   # load a synthetic fixture once
  local f="$1" name; name="seed:$(basename "$f")"
  if admin -d "$DB" -tAc "SELECT 1 FROM public.schema_migrations WHERE name = '$name'" | grep -q 1; then return; fi
  echo "== loading sample data $(basename "$f")"
  admin -d "$DB" -f "$f"
  admin -d "$DB" -c "INSERT INTO public.schema_migrations (name) VALUES ('$name')"
}

apply schema/migrations/0001_init.sql
admin -d "$DB" -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$APP_USER') THEN CREATE ROLE \"$APP_USER\" LOGIN; END IF; END \$\$;" \
                -c "ALTER ROLE \"$APP_USER\" WITH LOGIN PASSWORD '$APP_PASSWORD';" \
                -c "GRANT app_user TO \"$APP_USER\";" \
                -c "CREATE SCHEMA IF NOT EXISTS django AUTHORIZATION \"$APP_USER\";"
if [ "${RMS_SEED_DEMO:-0}" = "1" ]; then seed fixtures/seed_dev.sql; fi
apply schema/migrations/0002_fulfillment_and_sources.sql
if [ "${RMS_SEED_DEMO:-0}" = "1" ]; then seed fixtures/seed_dev_0002.sql; fi
apply schema/migrations/0003_acks_and_previews.sql

echo "== django tables"
python manage.py migrate --noinput
if [ "${RMS_SEED_DEMO:-0}" = "1" ]; then RMS_SEED_DEMO=1 python manage.py seed_dev_users; fi
python manage.py collectstatic --noinput >/dev/null

echo "== serving on :${RMS_BIND_PORT:-8000} (profile ${PO_PROFILE:-sovereign}, second factor ${RMS_REQUIRE_2FA:-1})"
exec gunicorn rms.wsgi:application --bind 0.0.0.0:${RMS_BIND_PORT:-8000} --workers "${RMS_WORKERS:-2}" --timeout 120 --access-logfile -
