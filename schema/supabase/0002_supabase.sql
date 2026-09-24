-- =============================================================================
--  0002_supabase.sql  --  Supabase adaptation of the PO Platform schema
--
--  STATUS: written for review, NOT applied by tests/run_tests.sh and NOT
--  validated against a real Supabase project. It has only been checked to
--  parse and execute against plain PostgreSQL 16 with a stub `auth` schema
--  (tests/supabase_stub_check.sh does that). Run it on a Supabase project
--  only after reading schema/README.md, "Supabase adaptation".
--
--  Run AFTER migrations/0001_init.sql, as the project's `postgres` role.
--
--  What it does
--    1. Redefines the two context functions to read the JWT instead of the
--       SET LOCAL settings. Nothing else in the schema changes: every policy,
--       trigger and view keeps working because they only ever call these two.
--    2. Gives PostgREST's `authenticated` role app_user's privileges.
--       `authenticated` is NOINHERIT on Supabase, so the grant must be
--       WITH INHERIT TRUE (PG16 syntax; on PG15 make authenticated INHERIT or
--       copy the grants).
--    3. Nothing else. There is deliberately NO trigger on auth.users: a
--       self-signed-up auth user has no tenant, and the audit log refuses to
--       record a users row without one (fail closed). The hosted edition is
--       invite-first:
--         a. the server invites through Supabase Auth
--            (auth.admin.inviteUserByEmail) and receives the new auth uid;
--         b. under the inviting owner/admin's JWT it calls
--            app.add_member(email, name, role, <uid>, <uid>::text)
--            so that app.users.id = auth.uid() and users.auth_subject = uid.
--       An auth user without an app.users row (or without a membership) is
--       authenticated but sees nothing.
--
--  Prerequisites the migration itself cannot solve (see README):
--    * 0001_init.sql creates app_security WITH BYPASSRLS and hands it the
--      SECURITY DEFINER helpers. Creating a BYPASSRLS role needs a superuser
--      on PostgreSQL 15 (Supabase's `postgres` is not one) or a creator that
--      itself has BYPASSRLS on 16+. If the CREATE ROLE step is refused, ask
--      Supabase support to create the role, or run the migration through the
--      dashboard SQL editor (which executes as `postgres`) and check that the
--      guard block in §1 of 0001_init.sql passes.
--    * `ALTER FUNCTION ... OWNER TO app_security` and `SET ROLE app_owner`
--      require the running role to be a member of those roles: on PG16 the
--      creator of a role gets ADMIN OPTION on it automatically; on PG15 run
--      `GRANT app_owner, app_security TO postgres` first.
--    * Storage: documents.storage_key is the object path inside a bucket;
--      write the bucket's storage policies to mirror app.documents RLS
--      (tenant_id and control_marking in the path or in object metadata).
-- =============================================================================
BEGIN;

-- 1. identity from the JWT -----------------------------------------------------
-- auth.uid() returns NULL for anonymous requests, so anon sees nothing.
CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS uuid LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT auth.uid()
$$;

-- The tenant comes from a custom JWT claim `tenant_id` (set by an auth hook or
-- by the app when it mints the session for the chosen tenant). Malformed or
-- missing claim => NULL => zero rows, exactly like the on-prem SET LOCAL path.
CREATE OR REPLACE FUNCTION app.current_tenant_id()
RETURNS uuid LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT CASE
           WHEN NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'tenant_id'
                ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           THEN (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'tenant_id')::uuid
         END
$$;

-- 2. PostgREST role gets the application role's privileges ----------------------
GRANT app_user TO authenticated WITH INHERIT TRUE;
-- (anon gets nothing: with auth.uid() NULL every policy is false anyway.)

-- 3. (no auth.users trigger; see the header: invite-first, users.id = auth.uid())

COMMIT;
