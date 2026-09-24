#!/usr/bin/env bash
# =============================================================================
#  run_tests.sh -- create a fresh database, apply the migration, run the RLS
#  test suite. Exits non-zero on any failure. Intended as the CI gate for
#  every change to schema/migrations.
#
#  Usage:  tests/run_tests.sh [dbname]          (default: po_schema_test)
#  Env:    PGHOST (127.0.0.1)  PGPORT (5432)  PGUSER (postgres)  PGPASSWORD (postgres)
#
#  The connecting user must be a superuser (or able to create the database,
#  create roles with BYPASSRLS, and SET ROLE to app_owner/app_security).
#  The database named here is DROPPED and re-created on every run; never point
#  it at a database you care about.
# =============================================================================
set -euo pipefail

DB="${1:-po_schema_test}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../migrations/0001_init.sql"
SUITE="$HERE/rls_tests.sql"
LOG="${RLS_TEST_LOG:-$(mktemp -t rls_tests.XXXXXX.log)}"

case "$DB" in
  postgres|template0|template1) echo "refusing to drop system database '$DB'" >&2; exit 2 ;;
esac

echo "== target: $PGUSER@$PGHOST:$PGPORT/$DB"
echo "== server: $(psql -d postgres -Atc 'select version()')"

echo "== recreating database $DB"
dropdb --if-exists "$DB"
createdb "$DB"

echo "== applying $MIGRATION"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$MIGRATION"

echo "== running $SUITE (log: $LOG)"
set +e
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$SUITE" >"$LOG" 2>&1
rc=$?
set -e

passes=$(grep -c 'PASS:' "$LOG" || true)
if [ "$rc" -ne 0 ] || ! grep -q 'ALL RLS TESTS PASSED' "$LOG"; then
  echo "== FAILED after $passes passing checks (psql exit $rc). Last lines:"
  tail -n 25 "$LOG"
  exit 1
fi

echo "== $(grep 'ALL RLS TESTS PASSED' "$LOG" | sed 's/.*NOTICE:  //')"
echo "== OK ($passes checks, database $DB left in place for inspection)"
