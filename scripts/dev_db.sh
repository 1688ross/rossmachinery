#!/usr/bin/env bash
# Fresh development database: migration 0001, the django schema, the po_api login role,
# and the synthetic seed. Needs a superuser connection. Never point this at real data.
set -euo pipefail
DB="${1:-rms_dev}"
export PGHOST="${PGHOST:-127.0.0.1}" PGPORT="${PGPORT:-5432}" PGUSER="${PGUSER:-postgres}" PGPASSWORD="${PGPASSWORD:-postgres}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$DB" in postgres|template0|template1) echo "refusing"; exit 2;; esac
dropdb --if-exists "$DB"; createdb "$DB"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$HERE/schema/migrations/0001_init.sql"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='po_api') THEN CREATE ROLE po_api LOGIN PASSWORD 'po_api_dev'; END IF; END \$\$;" \
     -c "GRANT app_user TO po_api;" -c "CREATE SCHEMA IF NOT EXISTS django AUTHORIZATION po_api;"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$HERE/fixtures/seed_dev.sql"
echo "== $DB ready (schema 0001 + synthetic seed)"
