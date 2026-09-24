-- =============================================================================
--  rls_tests.sql  --  self-checking test suite for migrations/0001_init.sql
--
--  Run (after the migration, on a FRESH database) as a superuser:
--     PGPASSWORD=... psql -h HOST -U postgres -v ON_ERROR_STOP=1 -d DB -f rls_tests.sql 2>&1
--  or simply tests/run_tests.sh, which creates the database, applies the
--  migration and runs this file.
--
--  The superuser is used ONLY to install the tiny `rt` assertion helpers, to
--  provision the two test tenants (tenant creation is an operator action, not
--  something the app role may do), for two clearly labelled belt-and-braces
--  sections (§18, §19) and for the bookends of the red-team regressions (§21,
--  reading true per-tenant counts). Everything else runs as the application role via
--  SET ROLE app_user, with the same SET LOCAL app.tenant_id / app.user_id
--  context the application would set.
--
--  Every check prints  NOTICE: PASS: ...  or aborts the script with FAIL: ... .
--  The suite inserts fixed ids, so it needs a fresh database each run.
-- =============================================================================
\set ON_ERROR_STOP on
\set QUIET on
SET client_min_messages = notice;

-- -----------------------------------------------------------------------------
-- §0  assertion helpers (installed by the superuser; SECURITY INVOKER, so every
--     statement they execute runs as app_user under RLS)
-- -----------------------------------------------------------------------------
DROP SCHEMA IF EXISTS rt CASCADE;
CREATE SCHEMA rt;

CREATE FUNCTION rt.pass(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('rt.passes', (COALESCE(NULLIF(current_setting('rt.passes', true), ''), '0')::int + 1)::text, false);
  RAISE NOTICE 'PASS: %', msg;
END $$;

CREATE FUNCTION rt.fail(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'FAIL: %', msg USING ERRCODE = 'RT000';
END $$;

CREATE FUNCTION rt.section(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== % ===', msg;
END $$;

CREATE FUNCTION rt.check(cond boolean, msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF cond IS TRUE THEN PERFORM rt.pass(msg); ELSE PERFORM rt.fail(msg); END IF;
END $$;

-- The statement must raise one of the listed SQLSTATEs.
CREATE FUNCTION rt.expect_error(sql text, states text[], msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE sql;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'RT000' THEN RAISE; END IF;
    IF SQLSTATE = ANY (states) THEN
      PERFORM rt.pass(msg || '  [' || SQLSTATE || ']');
      RETURN;
    END IF;
    PERFORM rt.fail(msg || ': unexpected SQLSTATE ' || SQLSTATE || ' (' || SQLERRM || ')');
  END;
  PERFORM rt.fail(msg || ': statement unexpectedly succeeded');
END $$;

-- The statement must affect exactly n rows.
CREATE FUNCTION rt.expect_rows(sql text, n bigint, msg text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE rc bigint;
BEGIN
  EXECUTE sql;
  GET DIAGNOSTICS rc = ROW_COUNT;
  PERFORM rt.check(rc = n, msg || '  [rows=' || rc || ']');
END $$;

-- The statement must affect 0 rows OR be refused with insufficient_privilege.
CREATE FUNCTION rt.expect_none_or_denied(sql text, msg text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE rc bigint;
BEGIN
  BEGIN
    EXECUTE sql;
    GET DIAGNOSTICS rc = ROW_COUNT;
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM rt.pass(msg || '  [denied 42501]');
    RETURN;
  END;
  PERFORM rt.check(rc = 0, msg || '  [rows=' || rc || ']');
END $$;

-- A "SELECT count(*) ..." query; -1 when the table is not even readable.
CREATE FUNCTION rt.count_of(sql text) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n bigint;
BEGIN
  BEGIN
    EXECUTE sql INTO n;
  EXCEPTION WHEN insufficient_privilege THEN
    RETURN -1;    -- "permission denied" is also fail-closed
  END;
  RETURN n;
END $$;

-- Fixed identifiers so every block can name things without look-ups.
CREATE FUNCTION rt.id(name text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE name
    WHEN 'ta'     THEN 'a0000000-0000-4000-8000-000000000001'   -- tenant A: Acme Aerospace Sales (on-prem, ceiling ear, retention 7y)
    WHEN 'tb'     THEN 'b0000000-0000-4000-8000-000000000002'   -- tenant B: Beta Tooling (cloud, ceiling fci)
    WHEN 'olivia' THEN '10000000-0000-4000-8000-0000000000a1'   -- A owner   (US, attested by Ann)
    WHEN 'ann'    THEN '10000000-0000-4000-8000-0000000000a2'   -- A admin   (US, attested by Olivia)
    WHEN 'mia'    THEN '10000000-0000-4000-8000-0000000000a3'   -- A manager (US)
    WHEN 'nigel'  THEN '10000000-0000-4000-8000-0000000000a4'   -- A manager (NOT a US person)
    WHEN 'carl'   THEN '10000000-0000-4000-8000-0000000000a5'   -- A clerk   (US)
    WHEN 'vera'   THEN '10000000-0000-4000-8000-0000000000a6'   -- A viewer
    WHEN 'aud'    THEN '10000000-0000-4000-8000-0000000000a7'   -- A auditor (NOT a US person)
    WHEN 'nate'   THEN '10000000-0000-4000-8000-0000000000a8'   -- A admin   (NOT a US person)
    WHEN 'bob'    THEN '10000000-0000-4000-8000-0000000000b1'   -- B owner
    WHEN 'c1'     THEN 'c0000000-0000-4000-8000-0000000000c1'   -- A client  Lockmart Aero
    WHEN 'c2'     THEN 'c0000000-0000-4000-8000-0000000000c2'   -- A vendor  Haas Automation
    WHEN 'c3'     THEN 'c0000000-0000-4000-8000-0000000000c3'   -- A carrier Fast Freight
    WHEN 'c4'     THEN 'c0000000-0000-4000-8000-0000000000c4'   -- A client+vendor Dual Co
    WHEN 'c5'     THEN 'c0000000-0000-4000-8000-0000000000c5'   -- B client
    WHEN 'c6'     THEN 'c0000000-0000-4000-8000-0000000000c6'   -- B vendor
    WHEN 'po1'    THEN 'd0000000-0000-4000-8000-0000000000d1'   -- A, none:  VF-2 vertical mill (worked example)
    WHEN 'po2'    THEN 'd0000000-0000-4000-8000-0000000000d2'   -- A, itar:  turbine blade fixture
    WHEN 'po3'    THEN 'd0000000-0000-4000-8000-0000000000d3'   -- A, none:  cancelled order (override close)
    WHEN 'po4'    THEN 'd0000000-0000-4000-8000-0000000000d4'   -- B
    WHEN 'po5'    THEN 'd0000000-0000-4000-8000-0000000000d5'   -- B, manual number
    WHEN 'po6'    THEN 'd0000000-0000-4000-8000-0000000000d6'   -- B
    WHEN 'po7'    THEN 'd0000000-0000-4000-8000-0000000000d7'   -- A, none: stays open (marking / refiling tests)
    WHEN 'f1'     THEN 'f0000000-0000-4000-8000-0000000000f1'   -- A doc: client invoice on po1 (2 pages)
    WHEN 'f2'     THEN 'f0000000-0000-4000-8000-0000000000f2'   -- A doc: itar vendor invoice on po2
    WHEN 'f3'     THEN 'f0000000-0000-4000-8000-0000000000f3'   -- A doc: unfiled scan
    WHEN 'f4'     THEN 'f0000000-0000-4000-8000-0000000000f4'   -- A doc: rescan superseding f1
    WHEN 'f5'     THEN 'f0000000-0000-4000-8000-0000000000f5'   -- A doc: unfiled, marked itar
    WHEN 'f6'     THEN 'f0000000-0000-4000-8000-0000000000f6'   -- B doc
    WHEN 'f7'     THEN 'f0000000-0000-4000-8000-0000000000f7'   -- A doc: filed as "none" into the ITAR folder (inherits itar)
    WHEN 'f8'     THEN 'f0000000-0000-4000-8000-0000000000f8'   -- A doc: on po7 (cascade test)
    WHEN 'e1'     THEN 'e0000000-0000-4000-8000-0000000000e1'   -- ledger ids for the worked example
    WHEN 'e2'     THEN 'e0000000-0000-4000-8000-0000000000e2'
    WHEN 'e3'     THEN 'e0000000-0000-4000-8000-0000000000e3'
    WHEN 'e12'    THEN 'e0000000-0000-4000-8000-000000000e12'  -- wrong payment, reversed
    WHEN 'e13'    THEN 'e0000000-0000-4000-8000-000000000e13'  -- the reversal
    WHEN 'e20'    THEN 'e0000000-0000-4000-8000-000000000e20'  -- po2 client invoice
    WHEN 'e40'    THEN 'e0000000-0000-4000-8000-000000000e40'  -- po4 (B) client invoice
    WHEN 'l1'     THEN 'a1000000-0000-4000-8000-0000000000a1'   -- line item
    WHEN 'n1'     THEN 'a2000000-0000-4000-8000-0000000000a1'   -- note
    WHEN 'j1'     THEN 'a3000000-0000-4000-8000-0000000000a1'   -- extraction job on f1
    WHEN 'j2'     THEN 'a3000000-0000-4000-8000-0000000000a2'   -- extraction job on f2 (itar)
  END::uuid
$$;

-- Set the application context exactly as the app does (transaction-local).
CREATE FUNCTION rt.ctx(tenant text, usr text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('app.tenant_id', COALESCE(rt.id(tenant)::text, tenant), true);
  PERFORM set_config('app.user_id',   COALESCE(rt.id(usr)::text,    usr),    true);
END $$;

-- True iff the statement raises exactly this SQLSTATE (used to fold several
-- probes into one assertion in §21).
CREATE FUNCTION rt.raises(sql text, state text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE sql;
  RETURN false;
EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE = 'RT000' THEN RAISE; END IF;
  RETURN SQLSTATE = state;
END $$;

GRANT USAGE ON SCHEMA rt TO app_user, app_owner;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rt TO app_user, app_owner;

-- =============================================================================
-- §1  preflight: roles, forced RLS, composite keys
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('1. preflight');
  PERFORM rt.check(EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user' AND NOT rolsuper AND NOT rolbypassrls),
                   'app_user is neither SUPERUSER nor BYPASSRLS');
  PERFORM rt.check(EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner' AND NOT rolsuper AND NOT rolbypassrls),
                   'app_owner (migration role) is neither SUPERUSER nor BYPASSRLS');
  PERFORM rt.check(EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_security' AND NOT rolsuper AND rolbypassrls AND NOT rolcanlogin),
                   'app_security is BYPASSRLS, NOLOGIN, not a superuser');
  PERFORM rt.check((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                     WHERE n.nspname = 'app' AND c.relkind = 'r' AND NOT (c.relrowsecurity AND c.relforcerowsecurity)) = 0,
                   'every table in schema app has RLS ENABLED and FORCED');
  PERFORM rt.check((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'app' AND c.relkind = 'r') = 16,
                   'schema app has the 16 expected tables');
  PERFORM rt.check((SELECT count(*) FROM pg_constraint co
                     WHERE co.contype = 'f' AND co.confrelid = 'app.purchase_orders'::regclass AND array_length(co.conkey, 1) = 2) = 7,
                   'every folder child references purchase_orders through a composite (tenant_id, po_id) FK (7 FKs)');
  PERFORM rt.check((SELECT count(*) FROM pg_constraint co
                     WHERE co.contype = 'f' AND co.confrelid = 'app.documents'::regclass AND array_length(co.conkey, 1) = 2) = 4,
                   'every document child references documents through a composite (tenant_id, document_id) FK (4 FKs)');
  PERFORM rt.check((SELECT count(*) FROM pg_constraint co JOIN pg_class c ON c.oid = co.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                     WHERE n.nspname = 'app' AND co.contype = 'f' AND array_length(co.conkey, 1) = 1
                       AND co.confrelid NOT IN ('app.tenants'::regclass, 'app.users'::regclass)) = 0,
                   'no single-column FK points anywhere but tenants or users (all others are composite)');
  PERFORM rt.check((SELECT count(*) FROM pg_views WHERE schemaname = 'app'
                      AND viewname IN ('po_balances', 'po_ledger', 'po_folder', 'current_documents')
                      AND definition IS NOT NULL) = 4
                   AND (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                         WHERE n.nspname = 'app' AND c.relkind = 'v'
                           AND c.reloptions @> ARRAY['security_invoker=true'] AND c.reloptions @> ARRAY['security_barrier=true']) = 4,
                   'all 4 views are security_invoker AND security_barrier');
  PERFORM rt.check((SELECT count(*) FROM pg_policies WHERE schemaname = 'app' AND cmd = 'UPDATE' AND qual IS DISTINCT FROM with_check) = 0,
                   'every UPDATE policy has identical USING and WITH CHECK clauses');
  PERFORM rt.check((SELECT count(*) FROM pg_policies WHERE schemaname = 'app' AND roles <> '{public}') = 0,
                   'policies apply to every role (no TO clause): app_owner is filtered like anyone else');
  PERFORM rt.check(NOT has_function_privilege('app_user',
                     'app.bootstrap_tenant(text, text, text, text, uuid, uuid, text, app.control_marking, int, jsonb)', 'EXECUTE'),
                   'app_user cannot execute app.bootstrap_tenant (tenant creation is an operator action)');
  PERFORM rt.check(NOT has_table_privilege('app_user', 'app.ledger_entries', 'UPDATE') AND NOT has_table_privilege('app_user', 'app.ledger_entries', 'DELETE')
                   AND NOT has_table_privilege('app_user', 'app.audit_log', 'INSERT') AND NOT has_table_privilege('app_user', 'app.audit_log', 'UPDATE')
                   AND NOT has_table_privilege('app_user', 'app.audit_log', 'DELETE') AND NOT has_table_privilege('app_user', 'app.purchase_orders', 'DELETE')
                   AND NOT has_table_privilege('app_user', 'app.documents', 'DELETE') AND NOT has_any_column_privilege('app_user', 'app.po_number_counters', 'SELECT'),
                   'privileges: no ledger UPDATE/DELETE, no audit INSERT/UPDATE/DELETE, no folder/document DELETE, no counters');
  PERFORM rt.check(NOT has_column_privilege('app_user', 'app.tenants', 'max_control_marking', 'UPDATE')
                   AND NOT has_column_privilege('app_user', 'app.tenants', 'is_active', 'UPDATE')
                   AND NOT has_column_privilege('app_user', 'app.users', 'us_person_attested_by', 'UPDATE')
                   AND NOT has_column_privilege('app_user', 'app.tenant_memberships', 'invited_by', 'UPDATE'),
                   'operator-only / trigger-managed columns are not UPDATE-grantable to app_user (ceiling, activation, attester)');
END $$;

-- =============================================================================
-- §2  fail closed on a virgin session (nothing was ever SET)
-- =============================================================================
SET ROLE app_user;
DO $$
BEGIN
  PERFORM rt.section('2. fail-closed on a virgin session');
  PERFORM rt.check(current_user = 'app_user', 'running as app_user');
  PERFORM rt.check(current_setting('app.tenant_id', true) IS NULL, 'app.tenant_id has never been set');
  PERFORM rt.check(app.current_tenant_id() IS NULL AND app.current_user_id() IS NULL, 'context helpers return NULL');
  PERFORM rt.check(app.current_member_role() IS NULL AND NOT app.is_member() AND NOT app.can_write() AND NOT app.current_user_is_us_person(),
                   'role helpers are NULL/false');
  PERFORM rt.check((SELECT count(*) FROM app.tenants) = 0 AND (SELECT count(*) FROM app.users) = 0, 'tenants/users invisible');
  PERFORM rt.check((SELECT count(*) FROM app.my_tenants()) = 0, 'my_tenants() is empty without a user context');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''x'', true)', rt.id('ta')),
                          ARRAY['42501'], 'INSERT without context is refused');
  PERFORM rt.expect_error('SELECT app.add_member(''x@x.test'', ''X'', ''clerk'')', ARRAY['42501'], 'add_member without context is refused');
  PERFORM rt.expect_error('SELECT app.bootstrap_tenant(''Rogue'', ''rogue'', ''r@r.test'', ''R'')', ARRAY['42501'],
                          'app_user cannot create tenants (bootstrap_tenant is not executable)');
END $$;
RESET ROLE;

-- =============================================================================
-- §3  seed: two tenants (operator action, as the superuser), then members and
--     US-person attestations as the application role
-- =============================================================================
DO $$
DECLARE v uuid;
BEGIN
  PERFORM rt.section('3. seed tenants (operator), users, memberships (app)');
  PERFORM rt.check(EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper), 'tenant provisioning runs as the operator (superuser here)');
  v := app.bootstrap_tenant('Acme Aerospace Sales', 'acme', 'owner@acme.test', 'Olivia Owner', rt.id('ta'), rt.id('olivia'),
                            p_deployment_mode => 'onprem', p_retention_years => 7);
  PERFORM rt.check(v = rt.id('ta'), 'bootstrap tenant A (on-prem, retention 7 years)');
  v := app.bootstrap_tenant('Beta Tooling', 'beta', 'boss@beta.test', 'Bob Boss', rt.id('tb'), rt.id('bob'), p_deployment_mode => 'cloud');
  PERFORM rt.check(v = rt.id('tb'), 'bootstrap tenant B (cloud)');
  PERFORM rt.check(app.current_tenant_id() IS NULL, 'bootstrap restored the (empty) caller context');
  PERFORM rt.check((SELECT max_control_marking FROM app.tenants WHERE id = rt.id('ta')) = 'ear'
                   AND (SELECT max_control_marking FROM app.tenants WHERE id = rt.id('tb')) = 'fci',
                   'marking ceilings: on-prem tenant = ear (everything), cloud tenant = fci');
END $$;

SET ROLE app_user;
DO $$
BEGIN
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.check(app.current_member_role() = 'owner', 'Olivia is owner of A');
  PERFORM app.add_member('admin@acme.test', 'Ann Admin', 'admin', rt.id('ann'));
  UPDATE app.users SET is_us_person = true, us_person_basis = 'US citizen, passport copy on file' WHERE id = rt.id('ann');
  PERFORM rt.check((SELECT is_us_person AND us_person_attested_by = rt.id('olivia') AND us_person_attested_at IS NOT NULL
                      FROM app.users WHERE id = rt.id('ann')),
                   'Olivia attests Ann as a US person; attestation stamped by the database');

  PERFORM rt.ctx('ta', 'ann');
  PERFORM app.add_member('mia@acme.test',   'Mia Manager',    'manager', rt.id('mia'));
  PERFORM app.add_member('nigel@acme.test', 'Nigel Overseas', 'manager', rt.id('nigel'));
  PERFORM app.add_member('carl@acme.test',  'Carl Clerk',     'clerk',   rt.id('carl'));
  PERFORM app.add_member('vera@acme.test',  'Vera Viewer',    'viewer',  rt.id('vera'));
  PERFORM app.add_member('aud@acme.test',   'Aud Itor',       'auditor', rt.id('aud'));
  PERFORM app.add_member('nate@acme.test',  'Nate Abroad',    'admin',   rt.id('nate'));
  UPDATE app.users SET is_us_person = true, us_person_basis = 'US citizen' WHERE id IN (rt.id('olivia'), rt.id('mia'), rt.id('carl'));
  PERFORM rt.check((SELECT count(*) FROM app.users WHERE is_us_person AND us_person_attested_by = rt.id('ann')) = 3,
                   'Ann attests Olivia, Mia and Carl');
  PERFORM rt.check((SELECT bool_and(NOT is_us_person) FROM app.users WHERE id IN (rt.id('nigel'), rt.id('aud'), rt.id('nate'))),
                   'Nigel (manager), Aud (auditor) and Nate (admin) remain non-US persons');
  PERFORM rt.check((SELECT count(*) FROM app.tenant_memberships WHERE tenant_id = rt.id('ta') AND is_active) = 8, 'tenant A has 8 active members');
  -- the close-out checklist: make one template item blocking for tenant A
  PERFORM rt.expect_rows(format('UPDATE app.close_checklist_templates SET is_required = true WHERE tenant_id = %L AND item_key = ''vendor_bills_complete''', rt.id('ta')), 1,
                         'admin marks one checklist template item as required (the rest stay advisory)');
END $$;

-- =============================================================================
-- §4  users & memberships: who may manage whom
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('4. user / membership rules');
  PERFORM rt.ctx('ta', 'ann');
  PERFORM rt.expect_error(format('UPDATE app.users SET us_person_basis = ''self'', is_us_person = true WHERE id = %L', rt.id('ann')),
                          ARRAY['42501'], 'an admin cannot re-attest their own US-person status');
  PERFORM rt.expect_error('SELECT app.add_member(''x@acme.test'', ''X'', ''owner'')', ARRAY['42501'], 'an admin cannot grant the owner role');
  PERFORM rt.expect_error(format('UPDATE app.tenant_memberships SET role = ''owner'' WHERE user_id = %L', rt.id('ann')),
                          ARRAY['42501'], 'an admin cannot change their own membership');
  PERFORM rt.expect_error(format('UPDATE app.tenant_memberships SET is_active = false WHERE user_id = %L', rt.id('olivia')),
                          ARRAY['42501'], 'an admin cannot deactivate an owner');
  PERFORM rt.check((SELECT count(*) FROM app.users) = 8, 'Ann sees the 8 users of tenant A and nobody else');
  PERFORM app.add_member('ivy@acme.test', 'Ivy Invited', 'viewer', NULL, 'keycloak|ivy-0009');
  PERFORM rt.check((SELECT auth_subject = 'keycloak|ivy-0009' AND is_active FROM app.users WHERE email = 'ivy@acme.test')
                   AND (SELECT invited_by = rt.id('ann') AND role = 'viewer' FROM app.tenant_memberships m JOIN app.users u ON u.id = m.user_id WHERE u.email = 'ivy@acme.test'),
                   'add_member pins the identity-provider subject at invite time and records who invited');
  PERFORM rt.expect_rows('UPDATE app.tenant_memberships SET is_active = false WHERE user_id = (SELECT id FROM app.users WHERE email = ''ivy@acme.test'')', 1,
                         'the invited viewer is deactivated again (keeps the member counts below stable)');
  PERFORM rt.expect_rows(format('UPDATE app.users SET auth_subject = ''keycloak|carl-0001'' WHERE id = %L', rt.id('carl')), 1,
                         'an admin sets a user''s identity subject (auth_subject)');
  PERFORM rt.expect_error(format('UPDATE app.users SET auth_subject = ''keycloak|carl-0001'' WHERE id = %L', rt.id('mia')),
                          ARRAY['23505'], 'auth_subject is unique');

  -- the non-US admin: cannot self-attest, may attest others
  PERFORM rt.ctx('ta', 'nate');
  PERFORM rt.check(app.current_member_role() = 'admin' AND NOT app.current_user_is_us_person(), 'Nate is an admin but not a US person');
  PERFORM rt.expect_error(format('UPDATE app.users SET is_us_person = true WHERE id = %L', rt.id('nate')),
                          ARRAY['42501'], 'a non-US admin cannot attest THEMSELVES (self-attestation refused)');
  PERFORM rt.expect_error(format('UPDATE app.users SET is_us_person = true, us_person_basis = ''me'' WHERE id = %L', rt.id('nate')),
                          ARRAY['42501'], '... not even with a basis text');
  PERFORM rt.check(NOT app.current_user_is_us_person() AND (SELECT NOT is_us_person FROM app.users WHERE id = rt.id('nate')), '... and he remains a non-US person');
  PERFORM rt.expect_rows(format('UPDATE app.users SET is_us_person = true, us_person_basis = ''green card on file'' WHERE id = %L', rt.id('vera')), 1,
                         'a non-US admin may attest ANOTHER user (Vera)');
  PERFORM rt.check((SELECT us_person_attested_by = rt.id('nate') FROM app.users WHERE id = rt.id('vera')), 'attester stamped as Nate');
  PERFORM rt.expect_rows(format('UPDATE app.users SET is_us_person = false WHERE id = %L', rt.id('vera')), 1, 'revocation works ...');
  PERFORM rt.check((SELECT us_person_attested_by IS NULL AND us_person_attested_at IS NULL FROM app.users WHERE id = rt.id('vera')),
                   '... and clears the attestation columns');

  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.expect_error('SELECT app.add_member(''x@acme.test'', ''X'', ''clerk'')', ARRAY['42501'], 'a clerk cannot add members');
  PERFORM rt.expect_error('INSERT INTO app.users (email, full_name) VALUES (''y@acme.test'', ''Y'')', ARRAY['42501'], 'a clerk cannot insert users');
  PERFORM rt.expect_error(format('UPDATE app.users SET is_us_person = false WHERE id = %L', rt.id('carl')),
                          ARRAY['42501'], 'a clerk cannot change their own US-person flag');
  PERFORM rt.expect_error(format('UPDATE app.users SET auth_subject = ''keycloak|carl-evil'' WHERE id = %L', rt.id('carl')),
                          ARRAY['42501'], 'a clerk cannot change their own identity subject');
  PERFORM rt.expect_rows(format('UPDATE app.users SET full_name = ''Hacked'' WHERE id = %L', rt.id('nigel')), 0,
                         'a clerk cannot update another user (row invisible for UPDATE)');
  PERFORM rt.expect_rows(format('UPDATE app.users SET full_name = ''Carl P. Clerk'' WHERE id = %L', rt.id('carl')), 1,
                         'a clerk may edit their own name');
  PERFORM rt.expect_rows(format('UPDATE app.tenant_memberships SET role = ''owner'' WHERE user_id = %L', rt.id('carl')), 0,
                         'a clerk cannot touch memberships (0 rows)');

  -- last-owner protection
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.expect_error(format('UPDATE app.users SET is_active = false WHERE id = %L', rt.id('olivia')),
                          ARRAY['55000'], 'the only owner cannot deactivate their own user row (last-owner guard)');
  PERFORM rt.expect_error(format('UPDATE app.tenant_memberships SET role = ''admin'' WHERE user_id = %L', rt.id('olivia')),
                          ARRAY['42501', '55000'], 'the only owner cannot demote themselves');
  PERFORM app.add_member('ozzy@acme.test', 'Ozzy Second-Owner', 'owner');
  PERFORM rt.expect_rows(format('UPDATE app.tenant_memberships SET role = ''viewer'' WHERE user_id = (SELECT id FROM app.users WHERE email = ''ozzy@acme.test'')'), 1,
                         'with two owners, demoting one of them is fine');
  PERFORM rt.expect_rows('UPDATE app.tenant_memberships SET is_active = false WHERE user_id = (SELECT id FROM app.users WHERE email = ''ozzy@acme.test'')', 1,
                         'the demoted member is deactivated again (Olivia stays the only owner)');

  PERFORM rt.ctx('tb', 'bob');
  PERFORM rt.check((SELECT count(*) FROM app.users) = 1 AND (SELECT count(*) FROM app.tenant_memberships) = 1,
                   'Bob (tenant B) sees only himself');
  PERFORM rt.check((SELECT count(*) FROM app.tenants) = 1 AND (SELECT slug FROM app.tenants) = 'beta', 'Bob sees only tenant B');
  PERFORM rt.expect_error(format('UPDATE app.tenants SET max_control_marking = ''itar'' WHERE id = %L', rt.id('tb')),
                          ARRAY['42501'], 'the owner cannot raise the tenant''s marking ceiling (operator-only column)');
  PERFORM rt.expect_error(format('UPDATE app.tenants SET is_active = false WHERE id = %L', rt.id('tb')),
                          ARRAY['42501'], 'nor deactivate the tenant');
END $$;

-- =============================================================================
-- §5  session bootstrap (plain-Postgres login path)
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('5. session bootstrap: resolve_user / my_tenants');
  PERFORM set_config('app.tenant_id', '', true); PERFORM set_config('app.user_id', '', true);
  PERFORM rt.check(app.resolve_user('OWNER@acme.test') = rt.id('olivia'), 'resolve_user maps the authenticated e-mail to a user id (case-insensitive)');
  PERFORM rt.check(app.resolve_user('nobody@acme.test') IS NULL, 'unknown e-mail resolves to NULL');
  PERFORM rt.check(app.resolve_user_by_subject('keycloak|carl-0001') = rt.id('carl'), 'resolve_user_by_subject maps the IdP subject');
  PERFORM set_config('app.user_id', rt.id('olivia')::text, true);
  PERFORM rt.check((SELECT count(*) FROM app.my_tenants()) = 1
                   AND (SELECT slug = 'acme' AND role = 'owner' AND deployment_mode = 'onprem' FROM app.my_tenants()),
                   'my_tenants() lists exactly the caller''s tenants (Olivia: acme/owner/onprem)');
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 0 AND (SELECT count(*) FROM app.tenants) = 0,
                   'a user context without a tenant context still sees nothing');
  PERFORM set_config('app.user_id', rt.id('bob')::text, true);
  PERFORM rt.check((SELECT string_agg(slug, ',') FROM app.my_tenants()) = 'beta', 'Bob sees only beta');
END $$;

-- =============================================================================
-- §6  parties
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('6. parties');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.parties (id, tenant_id, name, is_client)            VALUES (rt.id('c1'), rt.id('ta'), 'Lockmart Aero', true);
  INSERT INTO app.parties (id, tenant_id, name, is_vendor)            VALUES (rt.id('c2'), rt.id('ta'), 'Haas Automation', true);
  INSERT INTO app.parties (id, tenant_id, name, is_carrier)           VALUES (rt.id('c3'), rt.id('ta'), 'Fast Freight', true);
  INSERT INTO app.parties (id, tenant_id, name, is_client, is_vendor) VALUES (rt.id('c4'), rt.id('ta'), 'Dual Co', true, true);
  PERFORM rt.check((SELECT count(*) FROM app.parties) = 4, 'clerk created 4 parties in A (one is both client and vendor)');
  PERFORM rt.check((SELECT created_by = rt.id('carl') FROM app.parties WHERE id = rt.id('c1')), 'created_by stamped from context');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''LOCKMART AERO'', true)', rt.id('ta')),
                          ARRAY['23505'], 'party names are unique per tenant, case-insensitively');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name) VALUES (%L, ''Nobody'')', rt.id('ta')),
                          ARRAY['23514'], 'a party must be a client, vendor or carrier');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''Sneaky'', true)', rt.id('tb')),
                          ARRAY['42501'], 'a clerk of A cannot create a party in B');
  PERFORM rt.expect_rows(format('DELETE FROM app.parties WHERE id = %L', rt.id('c4')), 0, 'a clerk cannot delete parties (0 rows)');

  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''V'', true)', rt.id('ta')),
                          ARRAY['42501'], 'a viewer cannot create parties');
  PERFORM rt.check((SELECT count(*) FROM app.parties) = 4, 'a viewer can read parties');

  PERFORM rt.ctx('tb', 'bob');
  INSERT INTO app.parties (id, tenant_id, name, is_client) VALUES (rt.id('c5'), rt.id('tb'), 'Beta Client', true);
  INSERT INTO app.parties (id, tenant_id, name, is_vendor) VALUES (rt.id('c6'), rt.id('tb'), 'Beta Vendor', true);
  PERFORM rt.check((SELECT count(*) FROM app.parties) = 2, 'Bob sees only B''s 2 parties');
END $$;

-- =============================================================================
-- §7  purchase orders: creation, numbering, lifecycle defaults, ceiling
-- =============================================================================
DO $$
DECLARE v_num text;
BEGIN
  PERFORM rt.section('7. purchase orders');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title)
  VALUES (rt.id('po1'), rt.id('ta'), 'LM-77812', rt.id('c1'), rt.id('c2'), 'Haas VF-2 vertical mill + tooling package')
  RETURNING po_number INTO v_num;
  PERFORM rt.check(v_num = 'PO-00001', 'first folder in A is PO-00001 (INSERT ... RETURNING works)');
  INSERT INTO app.purchase_orders (id, tenant_id, client_party_id, title)
  VALUES (rt.id('po3'), rt.id('ta'), rt.id('c1'), 'Fixture set (cancelled)');
  PERFORM rt.check((SELECT po_number FROM app.purchase_orders WHERE id = rt.id('po3')) = 'PO-00002', 'second folder is PO-00002');
  PERFORM rt.check((SELECT status = 'open' AND opened_by = rt.id('carl') AND created_by = rt.id('carl') AND closed_at IS NULL
                      AND NOT legal_hold AND retain_until IS NULL
                      FROM app.purchase_orders WHERE id = rt.id('po1')), 'new folder is open, opened_by/created_by stamped, no hold, no retention date');
  PERFORM rt.check((SELECT count(*) FROM app.po_close_checklist_items WHERE po_id = rt.id('po1')) = 5
                   AND (SELECT count(*) FROM app.po_close_checklist_items WHERE po_id = rt.id('po1') AND is_required) = 1,
                   'close-out checklist seeded from the tenant template (5 items, 1 required)');
  PERFORM rt.check((SELECT count(*) FROM app.po_status_history WHERE po_id = rt.id('po1') AND from_status IS NULL AND to_status = 'open') = 1,
                   'creation recorded in po_status_history');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''bad'')', rt.id('ta'), rt.id('c2')),
                          ARRAY['23514'], 'client_party must be flagged as a client');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, vendor_party_id, title) VALUES (%L, %L, %L, ''bad'')', rt.id('ta'), rt.id('c1'), rt.id('c3')),
                          ARRAY['23514'], 'vendor_party must be flagged as a vendor');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title, status) VALUES (%L, %L, ''bad'', ''closed'')', rt.id('ta'), rt.id('c1')),
                          ARRAY['55000'], 'a folder cannot be born closed');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''bad'')', rt.id('ta'), rt.id('c5')),
                          ARRAY['23503'], 'a folder cannot reference a party of another tenant');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title, legal_hold, legal_hold_reason) VALUES (%L, %L, ''bad'', true, ''litigation'')', rt.id('ta'), rt.id('c1')),
                          ARRAY['42501'], 'a clerk cannot create a folder under legal hold');
  PERFORM rt.expect_none_or_denied(format('DELETE FROM app.purchase_orders WHERE id = %L', rt.id('po3')), 'nobody can DELETE a folder');
  INSERT INTO app.purchase_orders (id, tenant_id, client_party_id, title) VALUES (rt.id('po7'), rt.id('ta'), rt.id('c4'), 'Spindle rebuild (stays open)');

  -- itar folder by a US manager
  PERFORM rt.ctx('ta', 'mia');
  INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title, control_marking)
  VALUES (rt.id('po2'), rt.id('ta'), 'LM-90001', rt.id('c1'), rt.id('c2'), 'Turbine blade inspection fixture', 'itar');
  PERFORM rt.check((SELECT po_number FROM app.purchase_orders WHERE id = rt.id('po2')) = 'PO-00004', 'ITAR folder is PO-00004');

  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''v'')', rt.id('ta'), rt.id('c1')),
                          ARRAY['42501'], 'a viewer cannot create folders');

  -- tenant B: independent numbering, manual numbers are skipped by the allocator, ceiling fci
  PERFORM rt.ctx('tb', 'bob');
  INSERT INTO app.purchase_orders (id, tenant_id, client_party_id, vendor_party_id, title) VALUES (rt.id('po4'), rt.id('tb'), rt.id('c5'), rt.id('c6'), 'Beta job 1');
  INSERT INTO app.purchase_orders (id, tenant_id, client_party_id, title, po_number) VALUES (rt.id('po5'), rt.id('tb'), rt.id('c5'), 'Imported folder', 'PO-00002');
  INSERT INTO app.purchase_orders (id, tenant_id, client_party_id, title) VALUES (rt.id('po6'), rt.id('tb'), rt.id('c5'), 'Beta job 3');
  PERFORM rt.check((SELECT string_agg(po_number, ',' ORDER BY po_number) FROM app.purchase_orders) = 'PO-00001,PO-00002,PO-00003',
                   'tenant B numbers independently; allocator skipped the manually imported PO-00002');
  PERFORM rt.expect_error(format('SELECT app.next_po_number(%L)', rt.id('ta')), ARRAY['42501'], 'cannot allocate numbers for another tenant');
  PERFORM rt.expect_error('SELECT * FROM app.po_number_counters', ARRAY['42501'], 'app_user has no access to the counters table');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title, control_marking) VALUES (%L, %L, ''x'', ''cui'')', rt.id('tb'), rt.id('c5')),
                          ARRAY['23514'], 'cloud tenant (ceiling fci) refuses a CUI folder');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title, control_marking) VALUES (%L, %L, ''x'', ''itar'')', rt.id('tb'), rt.id('c5')),
                          ARRAY['23514'], '... and an ITAR folder');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET control_marking = ''ear'' WHERE id = %L', rt.id('po4')),
                          ARRAY['23514'], '... and raising an existing folder above the ceiling');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET control_marking = ''fci'' WHERE id = %L', rt.id('po4')), 1, 'fci is within the ceiling');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, storage_key, sha256, mime_type, byte_size, control_marking) VALUES (%L, ''b/k'', %L, ''application/pdf'', 1, ''itar'')', rt.id('tb'), repeat('7', 64)),
                          ARRAY['23514'], 'cloud tenant refuses an ITAR document too');
END $$;

-- =============================================================================
-- §8  line items
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('8. line items');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.po_line_items (id, tenant_id, po_id, line_no, category, description, quantity, unit_price)
  VALUES (rt.id('l1'), rt.id('ta'), rt.id('po1'), 1, 'machinery', 'Haas VF-2 vertical machining center', 1, 85000);
  INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price, vendor_party_id)
  VALUES (rt.id('ta'), rt.id('po1'), 2, 'tooling', 'CAT40 tool holders', 10, 250.5, rt.id('c4'));
  INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price)
  VALUES (rt.id('ta'), rt.id('po1'), 3, 'freight', 'Crating and freight', 1, 2500);
  PERFORM rt.check((SELECT sum(extended_amount) FROM app.po_line_items WHERE po_id = rt.id('po1')) = 90005.00
                   AND (SELECT extended_amount FROM app.po_line_items WHERE po_id = rt.id('po1') AND line_no = 2) = 2505.00,
                   'extended_amount is generated (85,000 + 2,505 + 2,500 = 90,005.00)');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description) VALUES (%L, %L, 1, ''other'', ''dup'')', rt.id('ta'), rt.id('po1')),
                          ARRAY['23505'], 'line numbers are unique within a folder');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, vendor_party_id) VALUES (%L, %L, 9, ''other'', ''x'', %L)', rt.id('ta'), rt.id('po1'), rt.id('c3')),
                          ARRAY['23514'], 'per-line vendor override must be a vendor');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity) VALUES (%L, %L, 9, ''other'', ''x'', 0)', rt.id('ta'), rt.id('po1')),
                          ARRAY['23514'], 'quantity must be positive');
  PERFORM rt.expect_error(format('UPDATE app.po_line_items SET po_id = %L WHERE id = %L', rt.id('po3'), rt.id('l1')),
                          ARRAY['23514'], 'line items cannot move between folders');
  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description) VALUES (%L, %L, 9, ''other'', ''v'')', rt.id('ta'), rt.id('po1')),
                          ARRAY['42501'], 'a viewer cannot add line items');
END $$;

-- =============================================================================
-- §9  documents: versions, soft delete, immutability, marking inheritance,
--     refiling, pages, extraction jobs
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('9. documents');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, page_count, original_filename, title)
  VALUES (rt.id('f1'), rt.id('ta'), rt.id('po1'), 'client_invoice', 'acme/2026/inv-1001.pdf', repeat('a', 64), 'application/pdf', 123456, 2, 'INV-1001.pdf', 'Invoice 1001 to Lockmart');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size)
  VALUES (rt.id('f3'), rt.id('ta'), NULL, 'other', 'acme/inbox/scan-0001.pdf', repeat('c', 64), 'application/pdf', 999);
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, supersedes_document_id)
  VALUES (rt.id('f4'), rt.id('ta'), rt.id('po1'), 'client_invoice', 'acme/2026/inv-1001-rescan.pdf', repeat('d', 64), 'application/pdf', 130000, rt.id('f1'));
  PERFORM rt.check((SELECT uploaded_by = rt.id('carl') AND uploaded_at IS NOT NULL AND extraction_status = 'not_started' FROM app.documents WHERE id = rt.id('f1')),
                   'upload provenance stamped; extraction_status placeholder defaults to not_started');
  PERFORM rt.check((SELECT count(*) FROM app.current_documents WHERE po_id = rt.id('po1')) = 1
                   AND (SELECT id FROM app.current_documents WHERE po_id = rt.id('po1')) = rt.id('f4'),
                   'current_documents hides the superseded scan (only the rescan is current)');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, po_id, storage_key, sha256, mime_type, byte_size, supersedes_document_id) VALUES (%L, %L, ''k2'', %L, ''application/pdf'', 1, %L)',
                                 rt.id('ta'), rt.id('po1'), repeat('e', 64), rt.id('f1')),
                          ARRAY['23505'], 'a document can be superseded only once');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, po_id, storage_key, sha256, mime_type, byte_size, supersedes_document_id) VALUES (%L, %L, ''k3'', %L, ''application/pdf'', 1, %L)',
                                 rt.id('ta'), rt.id('po3'), repeat('e', 64), rt.id('f4')),
                          ARRAY['23514'], 'a new version must stay on the same folder');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, storage_key, sha256, mime_type, byte_size) VALUES (%L, ''k4'', ''nothex'', ''application/pdf'', 1)', rt.id('ta')),
                          ARRAY['23514'], 'sha256 must be 64 hex chars');
  PERFORM rt.expect_error(format('UPDATE app.documents SET sha256 = %L WHERE id = %L', repeat('f', 64), rt.id('f1')),
                          ARRAY['23514'], 'document bytes (sha256/size/key) are immutable');
  -- pages
  INSERT INTO app.document_pages (tenant_id, document_id, page_number, storage_key) VALUES (rt.id('ta'), rt.id('f1'), 1, 'acme/2026/inv-1001/p1.png');
  INSERT INTO app.document_pages (tenant_id, document_id, page_number, storage_key) VALUES (rt.id('ta'), rt.id('f1'), 2, 'acme/2026/inv-1001/p2.png');
  PERFORM rt.expect_error(format('INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (%L, %L, 2)', rt.id('ta'), rt.id('f1')),
                          ARRAY['23505'], 'page numbers are unique per document');
  PERFORM rt.expect_error(format('UPDATE app.document_pages SET document_id = %L WHERE document_id = %L AND page_number = 1', rt.id('f3'), rt.id('f1')),
                          ARRAY['23514'], 'a page cannot move to another document');
  PERFORM rt.expect_rows(format('UPDATE app.document_pages SET rotation_deg = 90, ocr_text = ''INVOICE 1001 Lockmart Aero'' WHERE document_id = %L AND page_number = 1', rt.id('f1')), 1,
                         'page rotation and OCR text can be filled in');
  -- soft delete / restore
  PERFORM rt.expect_rows(format('UPDATE app.documents SET deleted_at = now() WHERE id = %L', rt.id('f3')), 1, 'clerk soft-deletes the unfiled scan');
  PERFORM rt.check((SELECT deleted_by = rt.id('carl') FROM app.documents WHERE id = rt.id('f3')), 'deleted_by stamped from context');
  PERFORM rt.expect_error(format('UPDATE app.documents SET title = ''x'' WHERE id = %L', rt.id('f3')),
                          ARRAY['55000'], 'a deleted document is frozen');
  PERFORM rt.expect_error(format('UPDATE app.documents SET deleted_at = NULL WHERE id = %L', rt.id('f3')),
                          ARRAY['42501'], 'a clerk cannot restore a deleted document');
  PERFORM rt.expect_none_or_denied(format('DELETE FROM app.documents WHERE id = %L', rt.id('f3')), 'documents cannot be hard-deleted');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET deleted_at = NULL WHERE id = %L', rt.id('f3')), 1, 'a manager restores it');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, control_marking, page_count)
  VALUES (rt.id('f2'), rt.id('ta'), rt.id('po2'), 'vendor_invoice', 'acme/2026/haas-77.pdf', repeat('b', 64), 'application/pdf', 5000, 'itar', 1);
  INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (rt.id('ta'), rt.id('f2'), 1);
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, control_marking)
  VALUES (rt.id('f5'), rt.id('ta'), NULL, 'correspondence', 'acme/inbox/drawing.pdf', repeat('9', 64), 'application/pdf', 5000, 'itar');
  PERFORM rt.check((SELECT count(*) FROM app.documents) = 5, 'Mia (US) sees all 5 documents of A');

  -- marking inheritance and the declassify-by-move path
  PERFORM rt.section('9b. marking inheritance on filing / refiling');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, control_marking, title)
  VALUES (rt.id('f7'), rt.id('ta'), rt.id('po2'), 'packing_slip', 'acme/2026/slip-9.pdf', repeat('7', 64), 'application/pdf', 100, 'none', 'Packing slip 9');
  PERFORM rt.check((SELECT control_marking = 'itar' FROM app.documents WHERE id = rt.id('f7')),
                   'a document filed as "none" into an ITAR folder inherits itar');
  PERFORM rt.expect_error(format('UPDATE app.documents SET po_id = %L WHERE id = %L', rt.id('po7'), rt.id('f7')),
                          ARRAY['42501'], 'a clerk cannot move a document out of a controlled folder');
  PERFORM rt.expect_error(format('UPDATE app.documents SET po_id = NULL WHERE id = %L', rt.id('f7')),
                          ARRAY['42501'], '... nor back to the inbox');
  PERFORM rt.expect_error(format('UPDATE app.documents SET control_marking = ''none'' WHERE id = %L', rt.id('f7')),
                          ARRAY['42501'], '... nor lower its marking');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check((SELECT count(*) FROM app.documents WHERE id = rt.id('f7')) = 0, 'the non-US manager does not see it');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET po_id = %L WHERE id = %L', rt.id('po7'), rt.id('f7')), 1, 'a manager moves it to an uncontrolled folder ...');
  PERFORM rt.check((SELECT control_marking = 'itar' FROM app.documents WHERE id = rt.id('f7')), '... and it KEEPS its itar marking (no declassify-by-move)');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check((SELECT count(*) FROM app.documents WHERE id = rt.id('f7')) = 0, 'still invisible to the non-US manager after the move');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET control_marking = ''none'' WHERE id = %L', rt.id('f7')), 1, 'a manager explicitly lowers it (a recorded decision) ...');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check((SELECT count(*) FROM app.documents WHERE id = rt.id('f7')) = 1, '... and only then does the non-US manager see it');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET po_id = NULL WHERE id = %L', rt.id('f7')), 1, 'back to the inbox for later tests');

  -- raising a folder raises its documents
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, title)
  VALUES (rt.id('f8'), rt.id('ta'), rt.id('po7'), 'quote', 'acme/2026/quote-3.pdf', repeat('8', 64), 'application/pdf', 100, 'Spindle quote');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET control_marking = ''cui'' WHERE id = %L', rt.id('po7')), 1, 'manager raises an open folder none -> cui');
  PERFORM rt.check((SELECT control_marking = 'cui' FROM app.documents WHERE id = rt.id('f8')), 'its filed document was raised with it');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders WHERE id = rt.id('po7')) = 0 AND (SELECT count(*) FROM app.documents WHERE id = rt.id('f8')) = 0,
                   'both vanished for the non-US manager');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET control_marking = ''none'' WHERE id = %L', rt.id('po7')), 1, 'manager lowers the folder again ...');
  PERFORM rt.check((SELECT control_marking = 'cui' FROM app.documents WHERE id = rt.id('f8')), '... the document stays cui (lowering never cascades)');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET control_marking = ''none'' WHERE id = %L', rt.id('f8')), 1, 'manager lowers the document explicitly');

  -- extraction jobs (Phase 2 placeholder rows)
  PERFORM rt.section('9c. extraction jobs');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.extraction_jobs (id, tenant_id, document_id, engine) VALUES (rt.id('j1'), rt.id('ta'), rt.id('f1'), 'claude-vision');
  PERFORM rt.check((SELECT status = 'queued' AND created_by = rt.id('carl') FROM app.extraction_jobs WHERE id = rt.id('j1')), 'job created queued, created_by stamped');
  PERFORM rt.expect_rows(format('UPDATE app.extraction_jobs SET status = ''succeeded'', confidence = 0.91, result = ''{"po_number": "PO-00001"}'', finished_at = now() WHERE id = %L', rt.id('j1')), 1,
                         'job result recorded');
  PERFORM rt.expect_error(format('UPDATE app.extraction_jobs SET reviewed_at = now(), applied_po_id = %L WHERE id = %L', rt.id('po3'), rt.id('j1')),
                          ARRAY['23514'], 'a result cannot be applied to a folder its document is not filed under');
  PERFORM rt.expect_rows(format('UPDATE app.extraction_jobs SET reviewed_at = now(), applied_po_id = %L WHERE id = %L', rt.id('po1'), rt.id('j1')), 1,
                         'human-in-the-loop sign-off applied to the right folder');
  PERFORM rt.check((SELECT reviewed_by = rt.id('carl') FROM app.extraction_jobs WHERE id = rt.id('j1')), 'reviewed_by stamped from context');
  PERFORM rt.expect_error(format('UPDATE app.extraction_jobs SET document_id = %L WHERE id = %L', rt.id('f3'), rt.id('j1')),
                          ARRAY['23514'], 'a job cannot move to another document');
  PERFORM rt.ctx('ta', 'mia');
  INSERT INTO app.extraction_jobs (id, tenant_id, document_id, engine) VALUES (rt.id('j2'), rt.id('ta'), rt.id('f2'), 'local-vlm');
  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.extraction_jobs (tenant_id, document_id) VALUES (%L, %L)', rt.id('ta'), rt.id('f1')),
                          ARRAY['42501'], 'a viewer cannot create jobs');
  PERFORM rt.check((SELECT count(*) FROM app.extraction_jobs) = 1 AND (SELECT count(*) FROM app.document_pages) = 2,
                   'a (non-US) viewer reads jobs and pages, minus the ones hanging off the ITAR document');

  PERFORM rt.ctx('tb', 'bob');
  INSERT INTO app.documents (id, tenant_id, po_id, kind, storage_key, sha256, mime_type, byte_size, page_count)
  VALUES (rt.id('f6'), rt.id('tb'), rt.id('po4'), 'client_invoice', 'beta/inv.pdf', repeat('6', 64), 'application/pdf', 10, 1);
  INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (rt.id('tb'), rt.id('f6'), 1);
  INSERT INTO app.extraction_jobs (tenant_id, document_id) VALUES (rt.id('tb'), rt.id('f6'));
  INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, unit_price) VALUES (rt.id('tb'), rt.id('po4'), 1, 'service', 'calibration', 300);
  PERFORM rt.check((SELECT count(*) FROM app.documents) = 1 AND (SELECT count(*) FROM app.document_pages) = 1 AND (SELECT count(*) FROM app.extraction_jobs) = 1,
                   'Bob sees only B''s document, page and job');
END $$;

-- =============================================================================
-- §10 THE LEDGER: worked example, derived balances, reversal flow, posting rules
-- =============================================================================
DO $$
DECLARE b app.po_balances%ROWTYPE;
BEGIN
  PERFORM rt.section('10. ledger worked example on PO-00001');
  PERFORM rt.ctx('ta', 'carl');
  -- the folder's paper top sheet, as money events
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, document_id, evidence_page, entry_date)
  VALUES (rt.id('e1'), rt.id('ta'), rt.id('po1'), 'client_invoice', 'client', 100000, rt.id('c1'), 'INV-1001', rt.id('f1'), 1, CURRENT_DATE - 20);
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date)
  VALUES (rt.id('e2'), rt.id('ta'), rt.id('po1'), 'client_payment', 'client', 60000, rt.id('c1'), 'CHK 5501', CURRENT_DATE - 15);
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date)
  VALUES (rt.id('e3'), rt.id('ta'), rt.id('po1'), 'vendor_bill', 'vendor', 80000, rt.id('c2'), 'H-77', CURRENT_DATE - 18);
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'vendor_payment', 'vendor', 80000, rt.id('c2'), 'ACH 9');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'freight_charge', 'freight', 2500, rt.id('c3'), 'FF-12');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'vendor_payment', 'freight', 2500, rt.id('c3'), 'CHK 5510');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'commission_earned', 'commission', 5000, rt.id('c2'), 'Q3 statement');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'commission_received', 'commission', 5000, rt.id('c2'), 'ACH 41');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, memo)
  VALUES (rt.id('ta'), rt.id('po1'), 'credit_memo', 'client', 1000, rt.id('c1'), 'goodwill credit for late delivery');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, memo)
  VALUES (rt.id('ta'), rt.id('po1'), 'adjustment', 'vendor', 10, rt.id('c2'), 'rounding on H-77');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, memo)
  VALUES (rt.id('ta'), rt.id('po1'), 'credit_memo', 'vendor', 10, rt.id('c2'), 'rounding on H-77 reversed by vendor');
  -- a mistaken payment, its reversal, and the corrected payment
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('e12'), rt.id('ta'), rt.id('po1'), 'client_payment', 'client', 39500, rt.id('c1'), 'CHK 5602');
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, reverses_entry_id, memo)
  VALUES (rt.id('e13'), rt.id('ta'), rt.id('po1'), 'reversal', rt.id('e12'), 'keyed 39,500 instead of 39,000');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('ta'), rt.id('po1'), 'client_payment', 'client', 39000, rt.id('c1'), 'CHK 5602');

  PERFORM rt.check((SELECT side = 'client' AND amount = 39500 AND signed_amount = 39500 AND flow = 'cash' AND reversed_kind = 'client_payment'
                      AND counterparty_party_id = rt.id('c1') AND reference = 'CHK 5602'
                      FROM app.ledger_entries WHERE id = rt.id('e13')),
                   'reversal copied side/amount/counterparty/reference from the original and flipped the sign');
  PERFORM rt.check((SELECT is_reversed AND reversed_by_entry_id = rt.id('e13') FROM app.po_ledger WHERE id = rt.id('e12')),
                   'po_ledger view shows the original as reversed');
  PERFORM rt.check((SELECT sum(signed_amount) FROM app.ledger_entries WHERE id IN (rt.id('e12'), rt.id('e13'))) = 0,
                   'original + reversal net to exactly 0');
  PERFORM rt.check((SELECT document_id = rt.id('f1') AND evidence_page = 1 FROM app.ledger_entries WHERE id = rt.id('e1')),
                   'the invoice entry cites document f1, page 1 as evidence');

  SELECT * INTO b FROM app.po_balances WHERE po_id = rt.id('po1');
  RAISE NOTICE '      PO-00001: billed_to_client=% received=% billed_by_vendors=% paid=% freight=%/% commission=%/% margin=% entries=%',
    b.billed_to_client, b.received_from_client, b.billed_by_vendors, b.paid_to_vendors, b.freight, b.freight_paid,
    b.commission, b.commission_received, b.gross_margin, b.entry_count;
  PERFORM rt.check(b.billed_to_client = 99000.00,     'billed_to_client = 100,000 - 1,000 credit = 99,000');
  PERFORM rt.check(b.received_from_client = 99000.00, 'received_from_client = 60,000 + 39,500 - 39,500 + 39,000 = 99,000');
  PERFORM rt.check(b.open_client_balance = 0,         'open_client_balance = 0');
  PERFORM rt.check(b.billed_by_vendors = 80000.00 AND b.paid_to_vendors = 80000.00 AND b.open_vendor_balance = 0,
                   'vendor side: 80,000 + 10 adj - 10 credit billed, 80,000 paid, open 0');
  PERFORM rt.check(b.freight = 2500.00 AND b.freight_paid = 2500.00 AND b.open_freight_balance = 0, 'freight 2,500 charged and paid');
  PERFORM rt.check(b.commission = 5000.00 AND b.commission_received = 5000.00 AND b.open_commission_balance = 0, 'commission 5,000 earned and received');
  PERFORM rt.check(b.gross_margin = 21500.00, 'gross_margin = 99,000 - 80,000 - 2,500 + 5,000 = 21,500');
  PERFORM rt.check(b.entry_count = 14 AND b.is_balanced AND NOT b.checklist_complete AND NOT b.ready_to_close AND b.open_required_items = 1,
                   '14 entries, is_balanced = true, but ready_to_close = false until the 1 required checklist item is done');

  -- posting rules
  PERFORM rt.section('10b. posting rules');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', -5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['23514'], 'amount must be positive');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''vendor'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c2')),
                          ARRAY['23514'], 'a client_invoice cannot post to the vendor side');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''adjustment'', ''vendor'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c2')),
                          ARRAY['23514'], 'adjustments and credit memos require a memo');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''vendor_bill'', ''vendor'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['23514'], 'a vendor_bill counterparty must be a vendor');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount) VALUES (%L, %L, ''client_payment'', ''client'', 5)', rt.id('ta'), rt.id('po1')),
                          ARRAY['23514'], 'payments/invoices require a counterparty');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c5')),
                          ARRAY['23503'], 'counterparty of another tenant is not found');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, document_id) VALUES (%L, %L, ''client_invoice'', ''client'', 5, %L, %L)', rt.id('ta'), rt.id('po3'), rt.id('c1'), rt.id('f1')),
                          ARRAY['23514'], 'a linked document must be filed under the same folder');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, document_id, evidence_page) VALUES (%L, %L, ''client_invoice'', ''client'', 5, %L, %L, 3)', rt.id('ta'), rt.id('po1'), rt.id('c1'), rt.id('f1')),
                          ARRAY['23514'], 'evidence_page beyond the document''s page_count is refused');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, evidence_page) VALUES (%L, %L, ''client_invoice'', ''client'', 5, %L, 1)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['23514'], 'evidence_page without a document is refused');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id, memo) VALUES (%L, %L, ''reversal'', %L, ''again'')', rt.id('ta'), rt.id('po1'), rt.id('e12')),
                          ARRAY['23505'], 'an entry can be reversed only once');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id, memo) VALUES (%L, %L, ''reversal'', %L, ''undo undo'')', rt.id('ta'), rt.id('po1'), rt.id('e13')),
                          ARRAY['23514'], 'a reversal cannot be reversed');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id, amount, memo) VALUES (%L, %L, ''reversal'', %L, 1, ''partial'')', rt.id('ta'), rt.id('po1'), rt.id('e2')),
                          ARRAY['23514'], 'a reversal must be for the full original amount');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id) VALUES (%L, %L, ''reversal'', %L)', rt.id('ta'), rt.id('po1'), rt.id('e2')),
                          ARRAY['23514'], 'a reversal requires a memo (the reason)');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id, memo) VALUES (%L, %L, ''reversal'', %L, ''wrong folder'')', rt.id('ta'), rt.id('po3'), rt.id('e2')),
                          ARRAY['23514'], 'a reversal must stay on the same folder');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reverses_entry_id) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1'), rt.id('e2')),
                          ARRAY['23514'], 'only kind = reversal may reference another entry');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, entry_date) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L, CURRENT_DATE + 10)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['23514'], 'entry_date cannot be in the future');
  PERFORM rt.expect_error(format('UPDATE app.ledger_entries SET amount = 1 WHERE id = %L', rt.id('e1')), ARRAY['42501'], 'ledger UPDATE is refused for app_user');
  PERFORM rt.expect_error(format('DELETE FROM app.ledger_entries WHERE id = %L', rt.id('e1')), ARRAY['42501'], 'ledger DELETE is refused for app_user');
  PERFORM rt.expect_error(format('UPDATE app.documents SET po_id = %L WHERE id = %L', rt.id('po3'), rt.id('f1')),
                          ARRAY['55000'], 'a document referenced by ledger entries cannot be refiled');
  -- Dual Co can be a counterparty on either side
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference) VALUES (rt.id('ta'), rt.id('po3'), 'vendor_bill', 'vendor', 100, rt.id('c4'), 'DC-1');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, reverses_entry_id, memo)
    SELECT rt.id('ta'), rt.id('po3'), 'reversal', id, 'order cancelled, bill withdrawn' FROM app.ledger_entries WHERE po_id = rt.id('po3') AND kind = 'vendor_bill';
  PERFORM rt.check((SELECT open_vendor_balance = 0 AND entry_count = 2 AND is_balanced FROM app.po_balances WHERE po_id = rt.id('po3')),
                   'a party flagged client+vendor works as a vendor counterparty; PO-00002 nets to zero');

  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['42501'], 'a viewer cannot post');
  PERFORM rt.ctx('ta', 'aud');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['42501'], 'an auditor cannot post');
  PERFORM rt.check((SELECT count(*) FROM app.ledger_entries) = 16, 'an auditor can read every (uncontrolled) entry of the tenant');

  -- ITAR folder gets a couple of entries (by a US manager); tenant B gets one
  PERFORM rt.ctx('ta', 'mia');
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, document_id)
  VALUES (rt.id('e20'), rt.id('ta'), rt.id('po2'), 'client_invoice', 'client', 250000, rt.id('c1'), 'INV-1002', NULL);
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, document_id, evidence_page, memo)
  VALUES (rt.id('ta'), rt.id('po2'), 'vendor_bill', 'vendor', 200000, rt.id('c2'), 'H-91', rt.id('f2'), 1, 'controlled fixture bill');
  PERFORM rt.ctx('tb', 'bob');
  INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, counterparty_party_id, reference)
  VALUES (rt.id('e40'), rt.id('tb'), rt.id('po4'), 'client_invoice', 'client', 500, rt.id('c5'), 'B-1');
  PERFORM rt.check((SELECT open_client_balance FROM app.po_balances WHERE po_id = rt.id('po4')) = 500, 'tenant B balances are computed independently');
END $$;

-- =============================================================================
-- §11 notes (sticky notes), tenant settings
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('11. notes and tenant settings');
  PERFORM rt.ctx('ta', 'carl');
  INSERT INTO app.po_notes (id, tenant_id, po_id, kind, body) VALUES (rt.id('n1'), rt.id('ta'), rt.id('po1'), 'sticky', 'Ready to close? Waiting on Haas commission statement.');
  PERFORM rt.check((SELECT created_by = rt.id('carl') FROM app.po_notes WHERE id = rt.id('n1')), 'clerk leaves a sticky note');
  PERFORM rt.check((SELECT open_stickies = 1 AND document_count = 1 FROM app.po_folder WHERE po_id = rt.id('po1')), 'po_folder shows 1 open sticky and 1 current document');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET name = ''Renamed'' WHERE id = %L', rt.id('ta')), 0, 'a clerk cannot rename the tenant (0 rows)');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.expect_rows(format('UPDATE app.po_notes SET resolved_at = now() WHERE id = %L', rt.id('n1')), 1, 'a manager resolves the sticky');
  PERFORM rt.check((SELECT resolved_by = rt.id('nigel') FROM app.po_notes WHERE id = rt.id('n1')), 'resolved_by stamped');
  PERFORM rt.expect_rows(format('UPDATE app.po_notes SET body = ''edited by a manager'' WHERE id = %L', rt.id('n1')), 1, 'a manager may edit another author''s note');
  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_error(format('INSERT INTO app.po_notes (tenant_id, po_id, body) VALUES (%L, %L, ''v'')', rt.id('ta'), rt.id('po1')), ARRAY['42501'], 'a viewer cannot add notes');
  PERFORM rt.expect_rows(format('DELETE FROM app.po_notes WHERE id = %L', rt.id('n1')), 0, 'a viewer cannot delete notes (0 rows)');
  PERFORM rt.check((SELECT count(*) FROM app.po_notes) = 1, 'a viewer can read notes');
  PERFORM rt.ctx('ta', 'ann');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET name = ''Renamed'' WHERE id = %L', rt.id('ta')), 0, 'an admin cannot rename the tenant (owner only; 0 rows)');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET retention_years = 1 WHERE id = %L', rt.id('ta')), 0, 'an admin cannot change retention (owner only; 0 rows)');
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET name = ''Acme Aerospace Sales, Inc.'', retention_years = 7 WHERE id = %L', rt.id('ta')), 1, 'the owner may rename the tenant and set retention');
  PERFORM rt.ctx('tb', 'bob');
  INSERT INTO app.po_notes (tenant_id, po_id, body) VALUES (rt.id('tb'), rt.id('po4'), 'beta note');
END $$;

-- =============================================================================
-- §12 close / reopen: the checklist, the sign-off, the override, retention, legal hold
-- =============================================================================
DO $$
DECLARE h record;
BEGIN
  PERFORM rt.section('12. close-out lifecycle');
  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''closed'' WHERE id = %L', rt.id('po1')), ARRAY['42501'], 'a clerk cannot close a folder');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''pending_close'' WHERE id = %L', rt.id('po1')), 1, 'a clerk requests close (open -> pending_close)');
  PERFORM rt.check((SELECT close_requested_by = rt.id('carl') AND close_requested_at IS NOT NULL FROM app.purchase_orders WHERE id = rt.id('po1')), 'request stamped');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET closed_at = now(), closed_by = %L WHERE id = %L', rt.id('carl'), rt.id('po1')), 1,
                         'lifecycle columns cannot be set by hand (statement runs ...)');
  PERFORM rt.check((SELECT closed_at IS NULL AND closed_by IS NULL AND status = 'pending_close' FROM app.purchase_orders WHERE id = rt.id('po1')), '... but the trigger pins them');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET legal_hold = true, legal_hold_reason = ''audit'' WHERE id = %L', rt.id('po1')),
                          ARRAY['42501'], 'a clerk cannot place a legal hold');
  PERFORM rt.expect_rows(format('UPDATE app.po_close_checklist_items SET is_required = false, label = ''x'' WHERE po_id = %L AND is_required', rt.id('po1')), 1,
                         'a clerk tries to un-require the checklist item (statement runs ...)');
  PERFORM rt.check((SELECT count(*) FROM app.po_close_checklist_items WHERE po_id = rt.id('po1') AND is_required AND label <> 'x') = 1, '... but the definition is pinned');

  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET title = ''v'' WHERE id = %L', rt.id('po1')), 0, 'a viewer cannot edit a folder (0 rows)');

  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''closed'' WHERE id = %L', rt.id('po1')), ARRAY['55000'],
                          'manager cannot close while a required checklist item is open (balanced but not ready)');
  UPDATE app.po_close_checklist_items SET completed_at = now(), note = 'verified' WHERE po_id = rt.id('po1') AND is_required;
  PERFORM rt.check((SELECT count(*) FROM app.po_close_checklist_items WHERE po_id = rt.id('po1') AND completed_by = rt.id('mia')) = 1, 'manager completes the required item (completed_by stamped)');
  PERFORM rt.check((SELECT ready_to_close FROM app.po_balances WHERE po_id = rt.id('po1')), 'ready_to_close is now true');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''closed'', close_signoff_note = ''Reviewed with Dad; all paid.'' WHERE id = %L', rt.id('po1')), 1, 'manager closes PO-00001');
  PERFORM rt.check((SELECT status = 'closed' AND closed_by = rt.id('mia') AND closed_at IS NOT NULL AND close_override_reason IS NULL
                      AND close_requested_by = rt.id('carl') FROM app.purchase_orders WHERE id = rt.id('po1')),
                   'closed_by/closed_at stamped, no override, requester preserved');
  PERFORM rt.check((SELECT retain_until = (closed_at + interval '7 years')::date FROM app.purchase_orders WHERE id = rt.id('po1')),
                   'retain_until stamped from the database-set closed_at + tenant retention (7 years)');
  SELECT * INTO h FROM app.po_status_history WHERE po_id = rt.id('po1') AND to_status = 'closed' ORDER BY changed_at DESC LIMIT 1;
  PERFORM rt.check(h.from_status = 'pending_close' AND h.changed_by = rt.id('mia') AND h.was_ready_to_close
                   AND (h.balances ->> 'open_client_balance')::numeric = 0 AND (h.balances ->> 'gross_margin')::numeric = 21500
                   AND jsonb_array_length(h.checklist) = 5 AND h.reason = 'Reviewed with Dad; all paid.',
                   'sign-off record holds who/when/why plus a balances and checklist snapshot');

  -- a closed folder is frozen
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L)', rt.id('ta'), rt.id('po1'), rt.id('c1')),
                          ARRAY['55000'], 'no posting to a closed folder');
  PERFORM rt.expect_error(format('UPDATE app.po_line_items SET quantity = 2 WHERE id = %L', rt.id('l1')), ARRAY['55000'], 'line items of a closed folder are frozen');
  PERFORM rt.expect_error(format('UPDATE app.po_close_checklist_items SET completed_at = NULL WHERE po_id = %L', rt.id('po1')), ARRAY['55000'], 'checklist of a closed folder is frozen');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET title = ''edited'' WHERE id = %L', rt.id('po1')), ARRAY['55000'], 'header of a closed folder is read-only');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, po_id, storage_key, sha256, mime_type, byte_size) VALUES (%L, %L, ''late'', %L, ''application/pdf'', 1)', rt.id('ta'), rt.id('po1'), repeat('5', 64)),
                          ARRAY['55000'], 'no filing documents into a closed folder');
  PERFORM rt.expect_error(format('UPDATE app.documents SET title = ''late edit'' WHERE id = %L', rt.id('f1')), ARRAY['55000'], 'documents of a closed folder are frozen');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''pending_close'' WHERE id = %L', rt.id('po1')), ARRAY['55000'], 'closed -> pending_close is not a transition');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''open'' WHERE id = %L', rt.id('po1')), ARRAY['23514'], 'reopen requires a reason');
  INSERT INTO app.po_notes (tenant_id, po_id, body) VALUES (rt.id('ta'), rt.id('po1'), 'Filed in cabinet 3.');
  PERFORM rt.pass('notes may still be added to a closed folder');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET legal_hold = true, legal_hold_reason = ''DCMA audit 2026'' WHERE id = %L', rt.id('po1')), 1,
                         'a manager may place a legal hold on a closed folder (the only change a closed folder accepts)');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET legal_hold = false WHERE id = %L', rt.id('po1')), 1, '... and lift it again');
  PERFORM rt.check((SELECT legal_hold_reason IS NULL FROM app.purchase_orders WHERE id = rt.id('po1')), 'lifting the hold clears the reason');

  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''open'', reopen_reason = ''x'' WHERE id = %L', rt.id('po1')), 0, 'a clerk cannot reopen (closed rows are invisible to clerk UPDATEs)');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET title = ''x'' WHERE id = %L', rt.id('po1')), 0, 'a clerk cannot edit a closed folder (0 rows)');

  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''open'', reopen_reason = ''Late freight credit from Fast Freight'' WHERE id = %L', rt.id('po1')), 1, 'manager reopens with a reason');
  PERFORM rt.check((SELECT status = 'open' AND closed_at IS NULL AND closed_by IS NULL AND reopen_count = 1 AND reopened_by = rt.id('mia') AND retain_until IS NULL
                      FROM app.purchase_orders WHERE id = rt.id('po1')),
                   'reopened: closed_* and retain_until cleared, reopen_count = 1');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, memo) VALUES (rt.id('ta'), rt.id('po1'), 'credit_memo', 'freight', 100, rt.id('c3'), 'late freight credit');
  PERFORM rt.check((SELECT NOT is_balanced AND open_freight_balance = -100 FROM app.po_balances WHERE po_id = rt.id('po1')), 'after the credit the folder is out of balance again');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''closed'' WHERE id = %L', rt.id('po1')), ARRAY['55000'], 'cannot close an unbalanced folder without an override');
  INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, memo) VALUES (rt.id('ta'), rt.id('po1'), 'adjustment', 'freight', 100, rt.id('c3'), 'credit refunded to client via invoice adj');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''closed'' WHERE id = %L', rt.id('po1')), 1, 'balanced again: manager closes directly (open -> closed)');
  PERFORM rt.check((SELECT count(*) FROM app.po_status_history WHERE po_id = rt.id('po1')) = 5, 'history: created, pending, closed, reopened, closed');
  PERFORM rt.check((SELECT retain_until IS NOT NULL FROM app.purchase_orders WHERE id = rt.id('po1')), 'retain_until stamped again on the second close');

  -- override close of the cancelled folder (no required items open there? the required item is open -> override needed)
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET status = ''closed'' WHERE id = %L', rt.id('po3')), ARRAY['55000'], 'PO-00002 (required checklist item open) cannot close silently');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET status = ''closed'', close_override_reason = ''Order cancelled by client before invoicing'' WHERE id = %L', rt.id('po3')), 1,
                         'management override closes it with a recorded reason');
  PERFORM rt.check((SELECT close_override_reason IS NOT NULL FROM app.purchase_orders WHERE id = rt.id('po3'))
                   AND (SELECT NOT was_ready_to_close AND reason LIKE 'Order cancelled%' FROM app.po_status_history WHERE po_id = rt.id('po3') AND to_status = 'closed'),
                   'override reason stored on the folder and in the sign-off record with was_ready_to_close = false');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET legal_hold = true, legal_hold_reason = ''Client dispute'' WHERE id = %L', rt.id('po3')), 1, 'legal hold placed on the cancelled folder');

  -- legal hold on an open folder blocks document deletion
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET legal_hold = true, legal_hold_reason = ''Warranty claim'' WHERE id = %L', rt.id('po7')), 1, 'legal hold placed on an open folder');
  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.expect_error(format('UPDATE app.documents SET deleted_at = now() WHERE id = %L', rt.id('f8')), ARRAY['55000'], 'documents of a folder under legal hold cannot be soft-deleted');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET legal_hold = false WHERE id = %L', rt.id('po7')), ARRAY['42501'], 'a clerk cannot lift the hold');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET legal_hold = false WHERE id = %L', rt.id('po7')), 1, 'a manager lifts it');
END $$;

-- =============================================================================
-- §13 export control: a non-US person cannot see controlled rows anywhere
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('13. export-control gating (Nigel is a non-US manager)');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check(app.current_member_role() = 'manager' AND NOT app.current_user_is_us_person(), 'Nigel is a manager but not a US person');
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 3 AND (SELECT count(*) FROM app.purchase_orders WHERE id = rt.id('po2')) = 0, 'the ITAR folder does not exist for him (3 of 4 folders)');
  PERFORM rt.check((SELECT count(*) FROM app.po_balances) = 3 AND (SELECT count(*) FROM app.po_folder) = 3, '... nor in the balances / folder views');
  PERFORM rt.check((SELECT count(*) FROM app.ledger_entries WHERE po_id = rt.id('po2')) = 0
                   AND (SELECT count(*) FROM app.ledger_entries l JOIN app.purchase_orders p ON p.id = l.po_id WHERE p.control_marking = 'itar') = 0
                   AND (SELECT count(*) FROM app.po_ledger WHERE po_id = rt.id('po2')) = 0,
                   '... nor its ledger entries, through a join or the ledger view');
  PERFORM rt.check((SELECT count(*) FROM app.po_close_checklist_items WHERE po_id = rt.id('po2')) = 0
                   AND (SELECT count(*) FROM app.po_status_history WHERE po_id = rt.id('po2')) = 0,
                   '... nor its checklist or history');
  PERFORM rt.check((SELECT count(*) FROM app.documents) = 5 AND (SELECT count(*) FROM app.documents WHERE control_marking <> 'none') = 0
                   AND (SELECT count(*) FROM app.documents WHERE po_id = rt.id('po2')) = 0,
                   'controlled documents (filed or unfiled) are invisible; the 5 unmarked ones are visible');
  PERFORM rt.check((SELECT count(*) FROM app.document_pages WHERE document_id = rt.id('f2')) = 0 AND (SELECT count(*) FROM app.document_pages) = 2
                   AND (SELECT count(*) FROM app.extraction_jobs WHERE document_id = rt.id('f2')) = 0 AND (SELECT count(*) FROM app.extraction_jobs) = 1
                   AND (SELECT count(*) FROM app.current_documents WHERE control_marking <> 'none') = 0,
                   '... nor the pages / extraction jobs of controlled documents');
  PERFORM rt.check((SELECT count(*) FROM app.search_purchase_orders('Turbine blade')) = 0
                   AND (SELECT count(*) FROM app.search_purchase_orders('VF-2')) = 1,
                   'trigram search cannot reach the ITAR folder but finds the uncontrolled one');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE po_id = rt.id('po2') OR control_marking <> 'none'
                                                          OR document_id IN (rt.id('f2'), rt.id('f5'))
                                                          OR old_data ->> 'po_id' = rt.id('po2')::text OR new_data ->> 'po_id' = rt.id('po2')::text
                                                          OR new_data ->> 'title' = 'Turbine blade inspection fixture') = 0
                   AND (SELECT count(*) FROM app.audit_log) > 0,
                   'audit rows of controlled folders/documents (incl. the refiling of f7) are invisible, the rest is readable (he is a manager)');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE row_id = rt.id('f7')
                                                          AND (old_data ->> 'po_id' = rt.id('po2')::text OR new_data ->> 'po_id' = rt.id('po2')::text
                                                               OR old_data ->> 'control_marking' = 'itar' OR new_data ->> 'control_marking' = 'itar')) = 0
                   AND (SELECT count(*) FROM app.audit_log WHERE row_id = rt.id('f7')) > 0,
                   'no audit row of the moved document leaks the ITAR folder''s id or its former marking (its uncontrolled history is readable)');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title, control_marking) VALUES (%L, %L, ''x'', ''itar'')', rt.id('ta'), rt.id('c1')),
                          ARRAY['42501'], 'he cannot create a controlled folder');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, storage_key, sha256, mime_type, byte_size, control_marking) VALUES (%L, ''k9'', %L, ''application/pdf'', 1, ''cui'')', rt.id('ta'), repeat('1', 64)),
                          ARRAY['42501'], 'he cannot create a controlled document');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, po_id, storage_key, sha256, mime_type, byte_size) VALUES (%L, %L, ''k10'', %L, ''application/pdf'', 1)', rt.id('ta'), rt.id('po2'), repeat('2', 64)),
                          ARRAY['23503', '42501'], 'he cannot file into the ITAR folder (it is not found)');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_payment'', ''client'', 5, %L)', rt.id('ta'), rt.id('po2'), rt.id('c1')),
                          ARRAY['23503', '42501'], 'he cannot post to the ITAR folder (it is not found)');
  PERFORM rt.expect_error(format('INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (%L, %L, 2)', rt.id('ta'), rt.id('f2')),
                          ARRAY['23503', '42501'], 'he cannot add a page to a controlled document');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET title = ''x'' WHERE id = %L', rt.id('po2')), 0, 'he cannot update it (0 rows)');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET control_marking = ''none'' WHERE id = %L', rt.id('po2')), 0, 'he cannot declassify it (0 rows)');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET control_marking = ''itar'' WHERE id = %L', rt.id('po7')),
                          ARRAY['42501'], 'he cannot raise a folder into a marking he may not see');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET description = ''reviewed by Nigel'' WHERE id = %L', rt.id('po3')),
                          ARRAY['55000'], 'he can reach the unmarked (closed) PO-00002, where the read-only rule applies as for any manager ...');
  PERFORM rt.expect_rows(format('UPDATE app.parties SET phone = ''+1 555 0100'' WHERE id = %L', rt.id('c1')), 1, '... but he can do ordinary work on unmarked data');

  -- the same wall for a non-US admin and a non-US auditor, who both may read the audit log
  PERFORM rt.ctx('ta', 'nate');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log) > 0
                   AND (SELECT count(*) FROM app.audit_log WHERE po_id = rt.id('po2') OR control_marking <> 'none' OR document_id IN (rt.id('f2'), rt.id('f5'))
                                                              OR new_data ->> 'title' = 'Turbine blade inspection fixture' OR new_data ->> 'memo' = 'controlled fixture bill') = 0
                   AND (SELECT count(*) FROM app.purchase_orders WHERE id = rt.id('po2')) = 0,
                   'a non-US ADMIN reads the audit log but sees no controlled row, title, memo or amount in it');
  PERFORM rt.ctx('ta', 'aud');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log) > 0
                   AND (SELECT count(*) FROM app.audit_log WHERE po_id = rt.id('po2') OR control_marking <> 'none' OR document_id IN (rt.id('f2'), rt.id('f5'))
                                                              OR new_data ->> 'title' = 'Turbine blade inspection fixture') = 0
                   AND (SELECT count(*) FROM app.ledger_entries WHERE po_id = rt.id('po2')) = 0,
                   'a non-US AUDITOR reads the audit log but sees no controlled row in it');

  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 4 AND (SELECT count(*) FROM app.documents) = 7
                   AND (SELECT count(*) FROM app.ledger_entries WHERE po_id = rt.id('po2')) = 2
                   AND (SELECT count(*) FROM app.search_purchase_orders('Turbine blade')) = 1,
                   'Mia (US) sees all 4 folders, all 7 documents, the ITAR ledger, and finds the ITAR folder by search');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE po_id = rt.id('po2')) > 0
                   AND (SELECT count(*) FROM app.audit_log WHERE row_id = rt.id('f7') AND control_marking = 'itar') >= 3,
                   'Mia sees the ITAR audit rows; the refiling of f7 was audited under the itar marking');
  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET control_marking = ''none'' WHERE id = %L', rt.id('po2')), ARRAY['42501'], 'a (US) clerk cannot lower a controlled marking');
  PERFORM rt.expect_error(format('UPDATE app.purchase_orders SET control_marking = ''cui'' WHERE id = %L', rt.id('po2')), ARRAY['42501'], '... nor change it sideways (itar -> cui)');
  PERFORM rt.expect_rows(format('UPDATE app.purchase_orders SET control_marking = ''cui'' WHERE id = %L', rt.id('po1')), 0, '(closed folder: no edits at all, 0 rows for a clerk)');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET control_marking = ''cui'' WHERE id = %L', rt.id('f3')), 1, 'a clerk may raise a marking (none -> cui)');
  PERFORM rt.expect_error(format('UPDATE app.documents SET control_marking = ''none'' WHERE id = %L', rt.id('f3')), ARRAY['42501'], '... but not lower it back');
  PERFORM rt.ctx('ta', 'nigel');
  PERFORM rt.check((SELECT count(*) FROM app.documents) = 4, 'the newly marked document just vanished for Nigel');
  PERFORM rt.ctx('ta', 'mia');
  PERFORM rt.expect_rows(format('UPDATE app.documents SET control_marking = ''none'' WHERE id = %L', rt.id('f3')), 1, 'a manager may lower it');
END $$;

-- =============================================================================
-- §14 tenant isolation, on every tenant-scoped table
-- =============================================================================
DO $$
DECLARE
  t text;
  tables text[] := ARRAY['tenant_memberships', 'parties', 'purchase_orders', 'po_line_items', 'documents', 'document_pages',
                         'extraction_jobs', 'ledger_entries', 'po_notes', 'po_close_checklist_items', 'close_checklist_templates',
                         'po_status_history', 'po_number_counters', 'audit_log'];
  n bigint; n_b bigint;
BEGIN
  PERFORM rt.section('14. tenant isolation (Olivia, owner of A, against tenant B rows)');
  FOREACH t IN ARRAY tables LOOP
    PERFORM rt.ctx('tb', 'bob');
    n_b := rt.count_of(format('SELECT count(*) FROM app.%I WHERE tenant_id = %L', t, rt.id('tb')));
    PERFORM rt.ctx('ta', 'olivia');
    n := rt.count_of(format('SELECT count(*) FROM app.%I WHERE tenant_id = %L', t, rt.id('tb')));
    PERFORM rt.check(n IN (0, -1) AND (n_b > 0 OR n_b = -1),
                     format('%-26s SELECT: B owner sees %s B rows, A owner sees %s', t, n_b, n));
    PERFORM rt.expect_none_or_denied(format('UPDATE app.%I SET tenant_id = tenant_id WHERE tenant_id = %L', t, rt.id('tb')),
                                     format('%-26s UPDATE of B rows from A', t));
    PERFORM rt.expect_none_or_denied(format('DELETE FROM app.%I WHERE tenant_id = %L', t, rt.id('tb')),
                                     format('%-26s DELETE of B rows from A', t));
  END LOOP;
  PERFORM rt.check((SELECT count(*) FROM app.tenants) = 1 AND (SELECT count(*) FROM app.users WHERE id = rt.id('bob')) = 0,
                   'tenants / users: A''s owner sees neither tenant B nor Bob');
  PERFORM rt.check((SELECT count(*) FROM app.search_purchase_orders('Beta job')) = 0, 'search: A''s owner cannot find B''s folders');

  PERFORM rt.section('14b. INSERT with another tenant''s id');
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''X'', true)', rt.id('tb')), ARRAY['42501'], 'parties');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''X'')', rt.id('tb'), rt.id('c5')), ARRAY['42501', '23503'], 'purchase_orders');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description) VALUES (%L, %L, 1, ''other'', ''X'')', rt.id('tb'), rt.id('po4')), ARRAY['42501', '23503'], 'po_line_items');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, storage_key, sha256, mime_type, byte_size) VALUES (%L, ''kx'', %L, ''application/pdf'', 1)', rt.id('tb'), repeat('2', 64)), ARRAY['42501'], 'documents');
  PERFORM rt.expect_error(format('INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (%L, %L, 9)', rt.id('tb'), rt.id('f6')), ARRAY['42501', '23503'], 'document_pages');
  PERFORM rt.expect_error(format('INSERT INTO app.extraction_jobs (tenant_id, document_id) VALUES (%L, %L)', rt.id('tb'), rt.id('f6')), ARRAY['42501', '23503'], 'extraction_jobs');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', 1, %L)', rt.id('tb'), rt.id('po4'), rt.id('c5')), ARRAY['42501', '23503'], 'ledger_entries');
  PERFORM rt.expect_error(format('INSERT INTO app.po_notes (tenant_id, po_id, body) VALUES (%L, %L, ''X'')', rt.id('tb'), rt.id('po4')), ARRAY['42501', '23503'], 'po_notes');
  PERFORM rt.expect_error(format('INSERT INTO app.po_close_checklist_items (tenant_id, po_id, item_key, label) VALUES (%L, %L, ''x_item'', ''X'')', rt.id('tb'), rt.id('po4')), ARRAY['42501', '23503'], 'po_close_checklist_items');
  PERFORM rt.expect_error(format('INSERT INTO app.close_checklist_templates (tenant_id, item_key, label) VALUES (%L, ''x_item'', ''X'')', rt.id('tb')), ARRAY['42501'], 'close_checklist_templates');
  PERFORM rt.expect_error(format('INSERT INTO app.tenant_memberships (tenant_id, user_id, role) VALUES (%L, %L, ''clerk'')', rt.id('tb'), rt.id('olivia')), ARRAY['42501'], 'tenant_memberships');
  PERFORM rt.expect_error(format('INSERT INTO app.po_status_history (tenant_id, po_id, to_status) VALUES (%L, %L, ''open'')', rt.id('tb'), rt.id('po4')), ARRAY['42501'], 'po_status_history (no INSERT privilege at all)');
  PERFORM rt.expect_error(format('INSERT INTO app.po_number_counters (tenant_id) VALUES (%L)', rt.id('tb')), ARRAY['42501'], 'po_number_counters (no privilege at all)');
  PERFORM rt.expect_error(format('INSERT INTO app.audit_log (tenant_id, table_name, action, actor_db_role, seq, tx_started_at) VALUES (%L, ''x'', ''INSERT'', ''x'', 1, now())', rt.id('tb')), ARRAY['42501'], 'audit_log (no INSERT privilege at all)');
  PERFORM rt.expect_error('INSERT INTO app.tenants (name, slug) VALUES (''Evil'', ''evil'')', ARRAY['42501'], 'tenants (no INSERT privilege at all)');

  PERFORM rt.section('14c. cross-tenant children and mismatched contexts');
  PERFORM rt.ctx('tb', 'bob');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description) VALUES (%L, %L, 1, ''other'', ''X'')', rt.id('tb'), rt.id('po1')), ARRAY['23503'], 'B cannot hang a line item on A''s folder');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', 1, %L)', rt.id('tb'), rt.id('po1'), rt.id('c5')), ARRAY['23503'], 'B cannot post to A''s folder');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', 1, %L)', rt.id('tb'), rt.id('po4'), rt.id('c1')), ARRAY['23503'], 'B cannot use A''s party as a counterparty');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, document_id) VALUES (%L, %L, ''client_invoice'', ''client'', 1, %L, %L)', rt.id('tb'), rt.id('po4'), rt.id('c5'), rt.id('f1')), ARRAY['23503'], 'B cannot cite A''s document as evidence');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, po_id, storage_key, sha256, mime_type, byte_size) VALUES (%L, %L, ''ky'', %L, ''application/pdf'', 1)', rt.id('tb'), rt.id('po1'), repeat('3', 64)), ARRAY['23503'], 'B cannot file a document into A''s folder');
  PERFORM rt.expect_error(format('INSERT INTO app.documents (tenant_id, storage_key, sha256, mime_type, byte_size, supersedes_document_id) VALUES (%L, ''kz'', %L, ''application/pdf'', 1, %L)', rt.id('tb'), repeat('4', 64), rt.id('f1')), ARRAY['23503'], 'B cannot supersede A''s document');
  PERFORM rt.expect_error(format('INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (%L, %L, 7)', rt.id('tb'), rt.id('f1')), ARRAY['23503'], 'B cannot add a page to A''s document');
  PERFORM rt.expect_error(format('INSERT INTO app.extraction_jobs (tenant_id, document_id) VALUES (%L, %L)', rt.id('tb'), rt.id('f1')), ARRAY['23503'], 'B cannot queue a job on A''s document');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''X'')', rt.id('tb'), rt.id('c1')), ARRAY['23503'], 'B cannot use A''s client party');
  PERFORM rt.ctx('ta', 'bob');      -- Bob asserts tenant A: he is not a member there
  PERFORM rt.check(app.current_member_role() IS NULL AND (SELECT count(*) FROM app.purchase_orders) = 0 AND (SELECT count(*) FROM app.parties) = 0,
                   'a non-member with a valid tenant id sees nothing');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''X'', true)', rt.id('ta')), ARRAY['42501'], 'and cannot write');
  PERFORM rt.ctx('tb', 'olivia');   -- Olivia asserts tenant B
  PERFORM rt.check(app.current_member_role() IS NULL AND (SELECT count(*) FROM app.purchase_orders) = 0, 'the other way round: also nothing');
END $$;

-- =============================================================================
-- §15 fail closed with reset, empty, malformed, malicious and half contexts
-- =============================================================================
DO $$
DECLARE t text; total bigint := 0; n bigint;
  tables text[] := ARRAY['tenants', 'users', 'tenant_memberships', 'parties', 'purchase_orders', 'po_line_items', 'documents',
                         'document_pages', 'extraction_jobs', 'ledger_entries', 'po_notes', 'po_close_checklist_items',
                         'close_checklist_templates', 'po_status_history', 'po_number_counters', 'audit_log',
                         'po_balances', 'po_ledger', 'po_folder', 'current_documents'];
BEGIN
  PERFORM rt.section('15. fail-closed after activity');
  PERFORM set_config('app.tenant_id', '', true); PERFORM set_config('app.user_id', '', true);
  FOREACH t IN ARRAY tables LOOP
    n := rt.count_of(format('SELECT count(*) FROM app.%I', t));
    IF n > 0 THEN PERFORM rt.fail(format('empty context: %s returned %s rows', t, n)); END IF;
    total := total + GREATEST(n, 0);
  END LOOP;
  PERFORM rt.check(total = 0, 'empty context: every table and view (16 + 4) returns zero rows');
  PERFORM rt.check((SELECT count(*) FROM app.search_purchase_orders('VF-2')) = 0 AND (SELECT count(*) FROM app.my_tenants()) = 0, 'empty context: search and my_tenants return nothing');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''X'', true)', rt.id('ta')), ARRAY['42501'], 'empty context: INSERT refused');
  PERFORM rt.expect_none_or_denied(format('UPDATE app.purchase_orders SET title = ''x'' WHERE tenant_id = %L', rt.id('ta')), 'empty context: UPDATE touches nothing');
  PERFORM rt.expect_none_or_denied(format('DELETE FROM app.parties WHERE tenant_id = %L', rt.id('ta')), 'empty context: DELETE touches nothing');

  PERFORM set_config('app.tenant_id', 'not-a-uuid', true); PERFORM set_config('app.user_id', '12345', true);
  PERFORM rt.check(app.current_tenant_id() IS NULL AND app.current_user_id() IS NULL, 'malformed context parses to NULL instead of erroring');
  total := 0;
  FOREACH t IN ARRAY tables LOOP total := total + GREATEST(rt.count_of(format('SELECT count(*) FROM app.%I', t)), 0); END LOOP;
  PERFORM rt.check(total = 0, 'malformed context: every table and view returns zero rows');
  PERFORM rt.expect_error(format('INSERT INTO app.parties (tenant_id, name, is_client) VALUES (%L, ''X'', true)', rt.id('ta')), ARRAY['42501'], 'malformed context: INSERT refused');

  PERFORM set_config('app.tenant_id', rt.id('ta')::text || ''' OR 1=1 --', true); PERFORM set_config('app.user_id', 'DROP TABLE app.users; --', true);
  PERFORM rt.check(app.current_tenant_id() IS NULL AND app.current_user_id() IS NULL AND app.current_member_role() IS NULL, 'malicious context strings parse to NULL, no error');
  total := 0;
  FOREACH t IN ARRAY tables LOOP total := total + GREATEST(rt.count_of(format('SELECT count(*) FROM app.%I', t)), 0); END LOOP;
  PERFORM rt.check(total = 0, 'malicious context: every table and view returns zero rows');

  PERFORM set_config('app.tenant_id', rt.id('ta')::text, true); PERFORM set_config('app.user_id', '', true);
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 0 AND (SELECT count(*) FROM app.tenants) = 0, 'tenant without user: nothing');
  PERFORM set_config('app.tenant_id', '', true); PERFORM set_config('app.user_id', rt.id('olivia')::text, true);
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 0 AND (SELECT count(*) FROM app.users) = 0, 'user without tenant: nothing (not even yourself)');
  PERFORM set_config('app.tenant_id', rt.id('ta')::text, true); PERFORM set_config('app.user_id', gen_random_uuid()::text, true);
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 0, 'unknown user id: nothing');
  PERFORM set_config('app.tenant_id', rt.id('ta')::text, true); PERFORM set_config('app.user_id', (SELECT id FROM app.users WHERE email = 'ozzy@acme.test')::text, true);
  PERFORM rt.check(app.current_member_role() IS NULL AND (SELECT count(*) FROM app.purchase_orders) = 0, 'deactivated membership: nothing');
END $$;

-- The literal pattern the application uses, at top level:
BEGIN;
SET LOCAL app.tenant_id = 'a0000000-0000-4000-8000-000000000001';
SET LOCAL app.user_id   = '10000000-0000-4000-8000-0000000000a7';   -- Aud, auditor, not a US person
DO $$
BEGIN
  PERFORM rt.section('16. SET LOCAL contract');
  PERFORM rt.check(app.current_member_role() = 'auditor' AND (SELECT count(*) FROM app.po_folder) = 3,
                   'SET LOCAL context works exactly like set_config(..., true) (auditor is not a US person: 3 of 4 folders)');
END $$;
COMMIT;
DO $$
BEGIN
  PERFORM rt.check(app.current_tenant_id() IS NULL AND (SELECT count(*) FROM app.po_folder) = 0, 'and it is gone after COMMIT');
END $$;

-- =============================================================================
-- §17 audit log: who may read it, what it holds, that it cannot change
-- =============================================================================
DO $$
BEGIN
  PERFORM rt.section('17. audit log');
  PERFORM rt.ctx('ta', 'aud');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log) > 50, 'auditor reads the tenant audit log');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE table_name = 'ledger_entries' AND action = 'INSERT' AND new_data ->> 'kind' = 'reversal' AND po_id = rt.id('po1')
                                                          AND actor_user_id = rt.id('carl') AND actor_role = 'clerk') = 1,
                   'the reversal was audited with its full row, the actor and the actor''s membership role');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE table_name = 'purchase_orders' AND action = 'UPDATE' AND row_id = rt.id('po1')
                                                          AND 'status' = ANY (changed_columns) AND new_data ->> 'status' = 'closed'
                                                          AND actor_user_id = rt.id('mia') AND actor_role = 'manager') = 2,
                   'both closes of PO-00001 are audited with before/after, changed_columns and the actor');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE table_name = 'documents' AND action = 'UPDATE' AND old_data ->> 'deleted_at' IS NULL AND new_data ->> 'deleted_at' IS NOT NULL) = 1,
                   'the soft delete is audited');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE table_name = 'extraction_jobs' AND 'reviewed_by' = ANY (changed_columns)) = 1
                   AND (SELECT count(*) FROM app.audit_log WHERE table_name = 'document_pages' AND document_id = rt.id('f1')) >= 3,
                   'extraction jobs and document pages are audited (pages carry their document id)');
  PERFORM rt.check((SELECT bool_and(tx_started_at IS NOT NULL AND tx_started_at <= statement_at AND statement_at <= created_at) FROM app.audit_log)
                   AND (SELECT count(*) FROM app.audit_log WHERE actor_db_role = 'app_user' AND actor_role IS NULL) = 0
                   AND (SELECT count(DISTINCT tx_started_at) FROM app.audit_log WHERE table_name = 'ledger_entries' AND po_id = rt.id('po1') AND actor_user_id = rt.id('carl')) = 1,
                   'every row carries the db role, transaction start and statement timestamp; app_user rows always carry the membership role; one transaction = one tx_started_at');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE tenant_id <> rt.id('ta')) = 0, 'no rows of other tenants');
  PERFORM rt.expect_error(format('UPDATE app.audit_log SET new_data = NULL WHERE tenant_id = %L', rt.id('ta')), ARRAY['42501'], 'audit_log UPDATE refused');
  PERFORM rt.expect_error(format('DELETE FROM app.audit_log WHERE tenant_id = %L', rt.id('ta')), ARRAY['42501'], 'audit_log DELETE refused');
  PERFORM rt.expect_error(format('INSERT INTO app.audit_log (tenant_id, table_name, action, actor_db_role, seq, tx_started_at) VALUES (%L, ''x'', ''INSERT'', ''x'', 1, now())', rt.id('ta')), ARRAY['42501'], 'audit_log cannot be forged by the app');
  PERFORM rt.expect_error(format('UPDATE app.po_status_history SET reason = ''x'' WHERE tenant_id = %L', rt.id('ta')), ARRAY['42501'], 'po_status_history is append-only too');
  PERFORM rt.ctx('ta', 'vera');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log) = 0, 'a viewer sees no audit rows');
  PERFORM rt.ctx('ta', 'carl');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log) = 0, 'a clerk sees no audit rows');
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.check((SELECT count(*) FROM app.audit_log WHERE table_name = 'users' AND action = 'UPDATE' AND new_data ->> 'is_us_person' = 'true') >= 2,
                   'the owner can see the US-person attestations in the audit trail');
END $$;

-- =============================================================================
-- §18 belt and braces, as the SUPERUSER (labelled): the append-only trigger,
--     the composite FKs, the delete guards, the last-owner guard and the
--     ceiling hold even when RLS and privileges are bypassed
-- =============================================================================
RESET ROLE;
DO $$
BEGIN
  PERFORM rt.section('18. superuser belt-and-braces');
  PERFORM rt.check(EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper), 'running as a superuser now');
  PERFORM rt.expect_error(format('UPDATE app.ledger_entries SET amount = 1 WHERE id = %L', rt.id('e1')), ARRAY['42501'], 'ledger UPDATE refused even for the superuser (trigger)');
  PERFORM rt.expect_error(format('DELETE FROM app.ledger_entries WHERE id = %L', rt.id('e1')), ARRAY['42501'], 'ledger DELETE refused even for the superuser');
  PERFORM rt.expect_error('TRUNCATE app.ledger_entries', ARRAY['42501', '0A000'], 'ledger TRUNCATE refused (FK references, then the trigger)');
  PERFORM rt.expect_error('TRUNCATE app.audit_log', ARRAY['42501'], 'audit_log TRUNCATE refused even for the superuser (trigger)');
  PERFORM rt.expect_error('UPDATE app.audit_log SET new_data = NULL', ARRAY['42501'], 'audit_log UPDATE refused even for the superuser');
  PERFORM rt.expect_error('DELETE FROM app.audit_log', ARRAY['42501'], 'audit_log DELETE refused even for the superuser');
  PERFORM rt.ctx('tb', 'bob');
  PERFORM rt.expect_error(format('INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description) VALUES (%L, %L, 77, ''other'', ''X'')', rt.id('tb'), rt.id('po3')),
                          ARRAY['23503'], 'composite FK (tenant_id, po_id) rejects a cross-tenant line item even with RLS bypassed');
  PERFORM rt.expect_error(format('INSERT INTO app.document_pages (tenant_id, document_id, page_number) VALUES (%L, %L, 77)', rt.id('tb'), rt.id('f1')),
                          ARRAY['23503'], 'composite FK (tenant_id, document_id) rejects a cross-tenant page even with RLS bypassed');
  PERFORM rt.expect_error(format('INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id) VALUES (%L, %L, ''client_invoice'', ''client'', 1, %L)', rt.id('tb'), rt.id('po4'), rt.id('c1')),
                          ARRAY['23503'], 'composite FK (tenant_id, counterparty_party_id) rejects a cross-tenant counterparty even with RLS bypassed');
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.expect_error(format('DELETE FROM app.purchase_orders WHERE id = %L', rt.id('po1')), ARRAY['55000'], 'a closed folder cannot be deleted even by the superuser (retention)');
  PERFORM rt.expect_error(format('DELETE FROM app.purchase_orders WHERE id = %L', rt.id('po3')), ARRAY['55000'], 'a folder under legal hold cannot be deleted even by the superuser');
  PERFORM rt.expect_error(format('UPDATE app.tenant_memberships SET is_active = false WHERE user_id = %L', rt.id('olivia')), ARRAY['55000'], 'the last owner cannot be deactivated even by the superuser');
  PERFORM rt.expect_error(format('DELETE FROM app.tenant_memberships WHERE user_id = %L', rt.id('olivia')), ARRAY['55000'], '... nor deleted');
  PERFORM rt.expect_error(format('UPDATE app.tenants SET max_control_marking = ''fci'' WHERE id = %L', rt.id('ta')), ARRAY['55000'], 'the ceiling cannot be lowered under existing ITAR rows');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET max_control_marking = ''itar'' WHERE id = %L', rt.id('tb')), 1, 'an operator may raise a ceiling ...');
  PERFORM rt.expect_rows(format('UPDATE app.tenants SET max_control_marking = ''fci'' WHERE id = %L', rt.id('tb')), 1, '... and lower it again while nothing is above it');
  PERFORM set_config('app.tenant_id', '', true); PERFORM set_config('app.user_id', '', true);
  PERFORM rt.expect_error(format('UPDATE app.users SET full_name = ''DBA edit'' WHERE id = %L', rt.id('carl')), ARRAY['42501'],
                          'even a DBA must set a tenant context before touching users (the audit trigger insists)');
  PERFORM rt.expect_error(format('INSERT INTO app.purchase_orders (tenant_id, client_party_id, title) VALUES (%L, %L, ''dba'')', rt.id('ta'), rt.id('c1')), ARRAY['42501'],
                          'even a DBA cannot allocate a PO number without a tenant context');
END $$;

-- =============================================================================
-- §19 the migration/owner role is filtered like everyone else (FORCE RLS)
-- =============================================================================
SET ROLE app_owner;
DO $$
DECLARE n bigint;
BEGIN
  PERFORM rt.section('19. app_owner (migration role) fails closed');
  PERFORM rt.check(current_user = 'app_owner', 'running as app_owner');
  PERFORM set_config('app.tenant_id', '', true); PERFORM set_config('app.user_id', '', true);
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 0 AND (SELECT count(*) FROM app.ledger_entries) = 0 AND (SELECT count(*) FROM app.po_balances) = 0,
                   'without context the owner of the tables sees zero rows (no "permission denied", no data)');
  PERFORM rt.expect_none_or_denied('UPDATE app.ledger_entries SET memo = ''owner edit''', 'without context the owner cannot touch the ledger');
  PERFORM rt.ctx('ta', 'olivia');
  PERFORM rt.check((SELECT count(*) FROM app.purchase_orders) = 4, 'with a valid context the owner role is subject to the same policies (sees tenant A as Olivia)');
  PERFORM rt.expect_none_or_denied('UPDATE app.ledger_entries SET memo = ''owner edit''', 'no UPDATE policy on ledger_entries: 0 rows even for the table owner');
  PERFORM rt.expect_none_or_denied('DELETE FROM app.audit_log', 'no DELETE policy on audit_log: 0 rows even for the table owner');
  PERFORM rt.expect_error(format('UPDATE app.tenants SET max_control_marking = ''cui'' WHERE id = %L', rt.id('ta')), ARRAY['42501'],
                          'app_owner is not a privileged context: even with an owner context it cannot change the ceiling (operator action)');
  PERFORM rt.expect_none_or_denied(format('UPDATE app.tenants SET name = ''x'' WHERE id = %L', rt.id('tb')), 'and it cannot reach tenant B from a tenant-A context');
END $$;
RESET ROLE;

-- =============================================================================
-- §20 the application role cannot weaken the schema
-- =============================================================================
SET ROLE app_user;
DO $$
BEGIN
  PERFORM rt.section('20. app_user cannot weaken the schema');
  PERFORM rt.expect_error('ALTER TABLE app.ledger_entries DISABLE TRIGGER t00_append_only', ARRAY['42501'], 'cannot disable the append-only trigger');
  PERFORM rt.expect_error('DROP TRIGGER t90_audit ON app.purchase_orders', ARRAY['42501'], 'cannot drop the audit trigger');
  PERFORM rt.expect_error('CREATE OR REPLACE FUNCTION app.tg_audit() RETURNS trigger LANGUAGE plpgsql AS ''BEGIN RETURN NULL; END''', ARRAY['42501'], 'cannot replace the audit function');
  PERFORM rt.expect_error('CREATE OR REPLACE FUNCTION app.current_member_role() RETURNS app.member_role LANGUAGE sql AS ''SELECT ''''owner''''::app.member_role''', ARRAY['42501'], 'cannot redefine who-am-I');
  PERFORM rt.expect_error('CREATE OR REPLACE FUNCTION app.current_user_is_us_person() RETURNS boolean LANGUAGE sql AS ''SELECT true''', ARRAY['42501'], 'cannot redefine the US-person gate');
  PERFORM rt.expect_error('ALTER FUNCTION app.current_member_role() OWNER TO app_user', ARRAY['42501'], 'cannot take ownership of a helper');
  PERFORM rt.expect_error('ALTER TABLE app.purchase_orders DISABLE ROW LEVEL SECURITY', ARRAY['42501'], 'cannot disable RLS');
  PERFORM rt.expect_error('ALTER TABLE app.purchase_orders NO FORCE ROW LEVEL SECURITY', ARRAY['42501'], 'cannot un-force RLS');
  PERFORM rt.expect_error('CREATE POLICY p_evil ON app.purchase_orders FOR SELECT USING (true)', ARRAY['42501'], 'cannot add a policy');
  PERFORM rt.expect_error('DROP POLICY p_select ON app.purchase_orders', ARRAY['42501'], 'cannot drop a policy');
  PERFORM rt.expect_error('CREATE TABLE app.evil (id int)', ARRAY['42501'], 'cannot create objects in schema app');
  -- (SET ROLE is checked against the SESSION user, a superuser in this harness, so
  --  membership is asserted from the catalog instead of attempted.)
  PERFORM rt.check(NOT pg_has_role('app_user', 'app_security', 'MEMBER') AND NOT pg_has_role('app_user', 'app_owner', 'MEMBER'),
                   'app_user is not a member of app_security or app_owner (cannot SET ROLE to them)');
  PERFORM rt.expect_error('ALTER ROLE app_user BYPASSRLS', ARRAY['42501'], 'cannot grant itself BYPASSRLS');
  PERFORM rt.expect_error('GRANT app_security TO app_user', ARRAY['42501'], 'cannot grant itself membership in app_security');
END $$;

-- =============================================================================
-- §21 red-team round 1 regressions: ONE assertion per break, replaying the red
--     team's own probes as app_user. The superuser bookends only read the true
--     per-tenant row counts and sequence positions the assertions compare against.
--       RT-1  resolve_user / resolve_user_by_subject / add_member / INSERT users
--             as a cross-tenant identity oracle (global users table)
--       RT-2  audit_log.seq (and the xid) as a cluster-global counter that
--             leaked other tenants' write volume through the gaps
-- =============================================================================
RESET ROLE;
DO $$
BEGIN
  PERFORM rt.section('21. red-team round 1 regressions');
  PERFORM set_config('rt.audit_rows_a', (SELECT count(*) FROM app.audit_log WHERE tenant_id = rt.id('ta'))::text, false);
  PERFORM set_config('rt.audit_rows_b', (SELECT count(*) FROM app.audit_log WHERE tenant_id = rt.id('tb'))::text, false);
  PERFORM set_config('rt.audit_seq_a',  (SELECT last_value FROM pg_sequences WHERE schemaname = 'app' AND sequencename = app.audit_sequence_name(rt.id('ta')))::text, false);
  PERFORM set_config('rt.audit_seq_b',  (SELECT last_value FROM pg_sequences WHERE schemaname = 'app' AND sequencename = app.audit_sequence_name(rt.id('tb')))::text, false);
END $$;

SET ROLE app_user;
DO $$
DECLARE
  ok  boolean;
  n_a bigint := current_setting('rt.audit_rows_a')::bigint;     -- true row counts, read with RLS bypassed above
  n_b bigint := current_setting('rt.audit_rows_b')::bigint;
  seq_a text := 'app.' || app.audit_sequence_name(rt.id('ta'));
BEGIN
  -- RT-1 ----------------------------------------------------------------------
  PERFORM rt.ctx('ta', 'carl');                                    -- a clerk, inside a tenant-A request
  ok := rt.raises('SELECT app.resolve_user(''boss@beta.test'')', '42501')              -- B's owner: not resolved
    AND rt.raises('SELECT app.resolve_user(''owner@acme.test'')', '42501')             -- own tenant: the same refusal
    AND rt.raises('SELECT app.resolve_user(''nobody@nowhere.test'')', '42501')         -- unknown: the same refusal (no oracle at all)
    AND rt.raises('SELECT app.resolve_user_by_subject(''keycloak|carl-0001'')', '42501')
    AND (SELECT count(*) FROM app.my_tenants()) = 1;                                   -- my_tenants() still answers, with own rows only
  PERFORM rt.ctx('ta', 'olivia');                                  -- A's owner tries to attach B's owner by e-mail
  ok := ok
    AND rt.raises('SELECT app.add_member(''boss@beta.test'', ''ignored'', ''viewer'')', '23505')
    AND (SELECT count(*) FROM app.tenant_memberships WHERE user_id = rt.id('bob')) = 0          -- not attached
    AND (SELECT count(*) FROM app.users WHERE id = rt.id('bob') OR email = 'boss@beta.test') = 0 -- not visible (no name, no row)
    AND rt.raises('INSERT INTO app.users (email, full_name) VALUES (''boss@beta.test'', ''probe'')', '42501')       -- taken e-mail
    AND rt.raises('INSERT INTO app.users (email, full_name) VALUES (''brand-new@nowhere.test'', ''probe'')', '42501') -- free e-mail: same answer
    AND app.add_member('carl@acme.test', 'Carl Clerk', 'clerk') = rt.id('carl');       -- an existing member of THIS tenant still works (+1 audit row in A)
  PERFORM rt.check(ok, 'RT-1 no cross-tenant identity oracle: resolve_user* refuse inside a request (foreign, own and unknown identities alike), '
                       'add_member neither links nor reveals an identity from another tenant, users cannot be INSERTed directly (taken and free e-mail both 42501)');

  -- RT-2 ----------------------------------------------------------------------
  PERFORM rt.ctx('ta', 'olivia');                                  -- US owner: sees every tenant-A row
  ok := (SELECT count(*) = n_a + 1 AND min(seq) = 1 AND max(seq) = n_a + 1 FROM app.audit_log);   -- seq = 1..n over exactly n rows
  PERFORM rt.ctx('ta', 'aud');                                     -- the red team's vantage point: non-US auditor of A
  ok := ok AND (SELECT max(seq) <= n_a + 1 AND count(*) < n_a + 1 FROM app.audit_log);            -- the only gap is A's own hidden ITAR rows
  PERFORM rt.ctx('tb', 'bob');
  ok := ok AND (SELECT count(*) = n_b AND min(seq) = 1 AND max(seq) = n_b FROM app.audit_log);    -- B's own ordinal starts at 1 too
  INSERT INTO app.parties (tenant_id, name, is_vendor) VALUES (rt.id('tb'), 'Seq Probe Vendor', true);   -- one audit row in B
  ok := ok AND (SELECT max(seq) = n_b + 1 FROM app.audit_log)
        AND NOT has_sequence_privilege('app_user', seq_a, 'USAGE') AND NOT has_sequence_privilege('app_user', seq_a, 'SELECT')
        AND rt.raises(format('SELECT nextval(%L)', seq_a), '42501')                      -- the app cannot advance or read a sequence
        AND rt.raises(format('SELECT last_value FROM %s', seq_a), '42501')
        AND rt.raises(format('SELECT app.create_audit_sequence(%L)', rt.id('tb')), '42501');   -- nor create one
  PERFORM set_config('rt.rt2_partial', ok::text, false);
END $$;

RESET ROLE;
DO $$
BEGIN
  -- Each tenant's sequence moved by exactly its own writes: A by the one RT-1 membership update, B by the one probe row.
  PERFORM rt.check(current_setting('rt.rt2_partial')::boolean
                   AND (SELECT last_value FROM pg_sequences WHERE schemaname = 'app' AND sequencename = app.audit_sequence_name(rt.id('ta'))) = current_setting('rt.audit_seq_a')::bigint + 1
                   AND (SELECT last_value FROM pg_sequences WHERE schemaname = 'app' AND sequencename = app.audit_sequence_name(rt.id('tb'))) = current_setting('rt.audit_seq_b')::bigint + 1
                   AND (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'app' AND c.relkind = 'S' AND pg_get_userbyid(c.relowner) = 'app_owner') = 2
                   AND (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'audit_log' AND column_name IN ('txid', 'tx_token')) = 0,
                   'RT-2 audit_log.seq is a per-tenant ordinal (each tenant sees 1..n over its own n rows, a tenant''s write moves only its own sequence, '
                   'the app cannot read or advance the sequences) and no cluster-global counter (identity, xid) is exposed');
END $$;
SET ROLE app_user;

-- =============================================================================
-- §22 summary
-- =============================================================================
DO $$
DECLARE b app.po_balances%ROWTYPE;
BEGIN
  PERFORM rt.section('22. summary');
  PERFORM rt.ctx('ta', 'olivia');
  FOR b IN SELECT * FROM app.po_balances ORDER BY po_number LOOP
    RAISE NOTICE '      % [%] status=% billed=% received=% vendors=%/% freight=%/% commission=%/% margin=% balanced=% ready=% hold=% retain_until=%',
      b.po_number, b.control_marking, b.status, b.billed_to_client, b.received_from_client, b.billed_by_vendors, b.paid_to_vendors,
      b.freight, b.freight_paid, b.commission, b.commission_received, b.gross_margin, b.is_balanced, b.ready_to_close, b.legal_hold, b.retain_until;
  END LOOP;
  RAISE NOTICE '';
  RAISE NOTICE 'ALL RLS TESTS PASSED: % checks', current_setting('rt.passes');
END $$;
RESET ROLE;
