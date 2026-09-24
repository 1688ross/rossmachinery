#!/usr/bin/env bash
# =============================================================================
#  supabase_stub_check.sh -- proves that supabase/0002_supabase.sql parses and
#  behaves on plain PostgreSQL with a STUB of Supabase's auth schema.
#
#  This is NOT a Supabase test. It only checks that the two redefined context
#  functions drive the unchanged policies correctly when identity comes from
#  request.jwt.claims, and that the invite-first member flow works. Run the real
#  thing on a Supabase project before relying on it.
#
#  Usage:  tests/supabase_stub_check.sh [dbname]   (default: po_schema_supabase_stub)
#  Env:    PGHOST PGPORT PGUSER PGPASSWORD (local defaults)
# =============================================================================
set -euo pipefail
DB="${1:-po_schema_supabase_stub}"
export PGHOST="${PGHOST:-127.0.0.1}" PGPORT="${PGPORT:-5432}" PGUSER="${PGUSER:-postgres}" PGPASSWORD="${PGPASSWORD:-postgres}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dropdb --if-exists "$DB"
createdb "$DB"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$HERE/../migrations/0001_init.sql"

# --- stub of what Supabase provides -------------------------------------------
psql -v ON_ERROR_STOP=1 -q -d "$DB" <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT NOBYPASSRLS;   -- Supabase's PostgREST role is NOINHERIT
  END IF;
END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text UNIQUE NOT NULL, raw_user_meta_data jsonb DEFAULT '{}'::jsonb);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid
$$;
GRANT USAGE ON SCHEMA auth TO PUBLIC;
GRANT EXECUTE ON FUNCTION auth.uid() TO PUBLIC;
SQL

psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$HERE/../supabase/0002_supabase.sql"

# --- behaviour ------------------------------------------------------------------
psql -v ON_ERROR_STOP=1 -q -d "$DB" <<'SQL'
SET client_min_messages = notice;
-- a tenant, provisioned by the operator; its owner signs up through auth.users with the same uuid
SELECT app.bootstrap_tenant('Acme', 'acme', 'owner@acme.test', 'Olivia', 'a0000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-0000000000a1', 'cloud');
-- the owner's auth identity uses the same uuid as app.users.id
INSERT INTO auth.users (id, email) VALUES ('10000000-0000-4000-8000-0000000000a1', 'owner@acme.test');
-- a stranger signs up on their own: authenticated, but no app.users row and no membership
INSERT INTO auth.users (id, email) VALUES ('10000000-0000-4000-8000-0000000000b1', 'stranger@else.test');
-- invite-first: Carl was invited through Supabase Auth (uid known), then added under the owner's JWT below
INSERT INTO auth.users (id, email) VALUES ('10000000-0000-4000-8000-0000000000a5', 'carl@acme.test');
SET ROLE authenticated;
DO $$
DECLARE n bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', '', true);
  IF (SELECT count(*) FROM app.tenants) <> 0 THEN RAISE EXCEPTION 'FAIL: anon saw tenants'; END IF;
  RAISE NOTICE 'PASS: no JWT -> zero rows';
  PERFORM set_config('request.jwt.claims', '{"sub": "10000000-0000-4000-8000-0000000000a1", "tenant_id": "a0000000-0000-4000-8000-000000000001"}', true);
  IF app.current_user_id() <> '10000000-0000-4000-8000-0000000000a1' OR app.current_tenant_id() <> 'a0000000-0000-4000-8000-000000000001' THEN
    RAISE EXCEPTION 'FAIL: JWT claims not read';
  END IF;
  IF app.current_member_role() <> 'owner' OR (SELECT count(*) FROM app.tenants) <> 1 THEN RAISE EXCEPTION 'FAIL: owner via JWT sees nothing'; END IF;
  INSERT INTO app.parties (tenant_id, name, is_client) VALUES ('a0000000-0000-4000-8000-000000000001', 'JWT Client', true);
  RAISE NOTICE 'PASS: JWT sub + tenant_id claim -> owner context works through the unchanged policies (authenticated inherits app_user)';
  PERFORM app.add_member('carl@acme.test', 'Carl Clerk', 'clerk', '10000000-0000-4000-8000-0000000000a5', '10000000-0000-4000-8000-0000000000a5');
  IF (SELECT auth_subject FROM app.users WHERE id = '10000000-0000-4000-8000-0000000000a5') <> '10000000-0000-4000-8000-0000000000a5' THEN
    RAISE EXCEPTION 'FAIL: invite-first add_member did not pin users.id / auth_subject to the auth uid';
  END IF;
  PERFORM set_config('request.jwt.claims', '{"sub": "10000000-0000-4000-8000-0000000000a5", "tenant_id": "a0000000-0000-4000-8000-000000000001"}', true);
  IF app.current_member_role() <> 'clerk' OR (SELECT count(*) FROM app.parties) <> 1 THEN RAISE EXCEPTION 'FAIL: invited clerk cannot see the tenant'; END IF;
  RAISE NOTICE 'PASS: invite-first flow: add_member(email, name, role, uid, uid) -> users.id = auth.uid(), clerk sees the tenant';
  PERFORM set_config('request.jwt.claims', '{"sub": "10000000-0000-4000-8000-0000000000b1", "tenant_id": "a0000000-0000-4000-8000-000000000001"}', true);
  IF app.current_member_role() IS NOT NULL OR (SELECT count(*) FROM app.parties) <> 0 THEN RAISE EXCEPTION 'FAIL: non-member saw rows'; END IF;
  RAISE NOTICE 'PASS: a signed-in user without a membership sees nothing';
  PERFORM set_config('request.jwt.claims', '{"sub": "10000000-0000-4000-8000-0000000000a1", "tenant_id": "not-a-uuid"}', true);
  IF app.current_tenant_id() IS NOT NULL OR (SELECT count(*) FROM app.parties) <> 0 THEN RAISE EXCEPTION 'FAIL: malformed tenant claim'; END IF;
  RAISE NOTICE 'PASS: malformed tenant_id claim -> zero rows, no error';
  RAISE NOTICE 'SUPABASE STUB CHECK PASSED';
END $$;
RESET ROLE;
SQL
echo "== OK: supabase/0002_supabase.sql behaves against the stub auth schema in $DB"
