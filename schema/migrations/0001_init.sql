-- =============================================================================
--  0001_init.sql  --  PO Platform core schema  (Phase 1, final)
--
--  One physical PO folder = one purchase_orders row. Everything the office
--  files into that folder (line items, scans, money events, sticky notes, the
--  close-out sign-off) hangs off it, isolated per tenant and gated by export
--  control, with an append-only ledger and an append-only audit log.
--
--  Target      : PostgreSQL 16 (tested on 16.13). Needs 15+ (security_invoker
--                views). Extensions: pgcrypto, pg_trgm. Nothing Supabase-only.
--  Run as      : a superuser, e.g.
--                  PGPASSWORD=... psql -h HOST -U postgres -v ON_ERROR_STOP=1 -d DB -f 0001_init.sql
--                The script creates objects as `app_owner` (SET ROLE) and
--                returns to the superuser only to hand a few SECURITY DEFINER
--                functions to `app_security`, the one BYPASSRLS role.
--  Idempotency : roles are guarded (created if missing, never dropped);
--                everything else assumes a fresh database. Later migrations
--                are additive (expand/contract); this file is never re-run.
--
--  -----------------------------------------------------------------------------
--  SESSION-CONTEXT CONTRACT
--  -----------------------------------------------------------------------------
--  The database does not learn who is asking from the connection. The
--  application tells it, per transaction, through two transaction-local
--  settings:
--
--      BEGIN;
--      SET LOCAL app.tenant_id = '<tenant uuid>';
--      SET LOCAL app.user_id   = '<user uuid>';
--      ... statements ...
--      COMMIT;
--
--  * WHO sets them: the API layer's request middleware, after it has
--    authenticated the user with the identity provider (session / Keycloak /
--    OIDC) and resolved which tenant the request is for (on-prem: the single
--    tenant; hosted: the tenant the user picked from app.my_tenants()).
--    Never from client-controlled input.
--  * WHEN: inside every transaction, before the first statement that touches
--    schema app. SET LOCAL dies with the transaction, so a pooled connection
--    cannot carry one request's context into the next (use transaction-mode
--    pooling, or DISCARD ALL on release).
--  * WHAT the database trusts: only the two ids. The user's role in that
--    tenant, whether they are an attested US person, and therefore what they
--    may do, are looked up from tenant_memberships / users by the database.
--  * FAIL CLOSED: a missing, empty or malformed setting makes every helper
--    return NULL/false; every SELECT then returns zero rows and every write is
--    refused. A user who is not an active member of the asserted tenant gets
--    the same treatment.
--
--  SUPABASE: identity comes from the JWT instead of SET LOCAL. After this
--  migration, redefine exactly two functions (see §16 and
--  schema/supabase/0002_supabase.sql):
--      app.current_user_id()   -> auth.uid()
--      app.current_tenant_id() -> the tenant_id claim of the JWT
--  and GRANT app_user TO authenticated WITH INHERIT TRUE. No policy, trigger or
--  table changes.
--
--  -----------------------------------------------------------------------------
--  TABLE OF CONTENTS
--  -----------------------------------------------------------------------------
--    §1  Roles (guarded)                 §9  Role predicates + export-control gate
--    §2  Extensions + schema             §10 Provisioning, session bootstrap, allocator
--    §3  Enumerated types                §11 Trigger functions
--    §4  Pure ledger math                §12 Triggers
--    §5  Context helpers                 §13 Views + search
--    §6  Tables + constraints            §14 Row-Level Security policies
--    §7  Indexes                         §15 Grants
--    §8  Security-definer lookup helpers §16 Supabase notes (comment only)
--
--  -----------------------------------------------------------------------------
--  DESIGN INVARIANTS (enforced below, proven by tests/rls_tests.sql)
--  -----------------------------------------------------------------------------
--    * Every tenant-scoped row carries tenant_id NOT NULL; every child references
--      its parent with a COMPOSITE foreign key (tenant_id, parent_id) against the
--      parent's UNIQUE (tenant_id, id). FK checks bypass RLS by design, so a
--      plain (parent_id) FK would accept a parent in another tenant; the
--      composite key makes "child and parent share a tenant" declarative,
--      visible in pg_dump, and impossible to forget on the next table. Triggers
--      are used only for what an FK cannot say (party flags, folder open, ...).
--    * RLS is ENABLED and FORCED on every table in schema app, including the
--      ones the app never touches directly. Policies reference ONLY the small
--      helpers of §5/§8/§9, wrapped as (SELECT fn()) so the planner evaluates
--      them once per statement (InitPlan), not once per row.
--    * ledger_entries and audit_log are append-only at three layers: no
--      UPDATE/DELETE privilege for app_user, no UPDATE/DELETE policy, and a
--      trigger that refuses even the owner and superusers. Corrections are
--      reversal entries.
--    * Nothing a tenant can read carries a cluster-global counter: audit_log.seq
--      is drawn from a per-tenant sequence and rows are grouped per transaction
--      by transaction_timestamp(), never by the global xid, so a gap in what one
--      tenant sees never discloses another tenant's write volume.
--    * Users are global (one row per person), but an identity that exists
--      outside the current tenant is never linked or revealed by the app:
--      add_member refuses it, users cannot be INSERTed directly, and the
--      session-bootstrap helpers only run in a context-free transaction.
--    * Money is numeric(14,2), always positive; the sign is DERIVED from the
--      kind into a stored generated column, so a wrong-signed posting is
--      impossible. Balances are a view, never stored, so nothing can drift.
--    * A folder closes only when app.po_balances.ready_to_close is true or with
--      an explicit management override reason, and every transition is
--      snapshotted into append-only po_status_history (the sign-off record).
--    * Export control: rows marked cui/itar/ear, and everything hanging off such
--      a folder (lines, ledger, notes, documents, pages, jobs, history, audit
--      rows) do not exist for users whose is_us_person = false, through tables,
--      joins, views and functions. A document filed in a controlled folder
--      inherits the folder's marking; moving it out again needs a manager.
--    * A tenant has a marking ceiling (tenants.max_control_marking): the hosted
--      edition is provisioned with 'fci' and can therefore never accumulate
--      cui/itar/ear rows; only an operator can raise the ceiling.
-- =============================================================================

BEGIN;

-- =============================================================================
-- §1  ROLES  (cluster-wide; guarded so several databases can coexist on one
--             cluster; never dropped by any migration)
-- -----------------------------------------------------------------------------
--   app_owner     owns the schema and every object in it. Used for migrations
--                 and operator tasks only. NOT BYPASSRLS: with FORCE ROW LEVEL
--                 SECURITY even the owner is subject to the policies, so an
--                 ad-hoc query by the migration role without context returns
--                 nothing (it fails closed like everyone else).
--   app_user      the application's runtime role. NOLOGIN here; a deployment
--                 creates a LOGIN role and `GRANT app_user TO that_role`, or
--                 runs `ALTER ROLE app_user LOGIN PASSWORD ...` out of band.
--                 Cannot bypass RLS. Cannot UPDATE/DELETE the ledger or the
--                 audit log. Cannot create tenants.
--   app_security  the ONLY role with BYPASSRLS. It logs in nowhere and owns
--                 only the handful of SECURITY DEFINER functions that must read
--                 memberships/users to answer "who is this?" (otherwise the
--                 policies would recurse into themselves), write the append-only
--                 logs the app must not be able to forge, and provision tenants.
-- =============================================================================
DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_owner') THEN
    CREATE ROLE app_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_security') THEN
    CREATE ROLE app_security NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT BYPASSRLS;
  END IF;
END
$do$;

-- Refuse to continue if a pre-existing role has attributes that would defeat RLS.
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles
             WHERE rolname IN ('app_user', 'app_owner') AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'app_user / app_owner must be neither SUPERUSER nor BYPASSRLS';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_security' AND (rolcanlogin OR rolsuper)) THEN
    RAISE EXCEPTION 'app_security must be NOLOGIN and not SUPERUSER';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_security' AND rolbypassrls) THEN
    RAISE EXCEPTION 'app_security must have BYPASSRLS (its SECURITY DEFINER helpers would recurse otherwise)';
  END IF;
END
$do$;

-- =============================================================================
-- §2  EXTENSIONS + SCHEMA
-- -----------------------------------------------------------------------------
--   pgcrypto : digest()/hmac for the app layer (gen_random_uuid() is core in 13+).
--   pg_trgm  : fuzzy search on party names, folder titles, notes, memos.
--   Nothing else. No Supabase-only schemas (auth, storage) are referenced.
--   The trigram operator classes are resolved through the search_path at
--   creation time (public here; `extensions` on Supabase).
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA app AUTHORIZATION app_owner;
COMMENT ON SCHEMA app IS 'PO Platform core: tenants, folders (POs), documents, ledger, close-out, audit.';

-- From here on, objects are created by (and owned by) app_owner.
SET ROLE app_owner;

-- =============================================================================
-- §3  ENUMERATED TYPES
-- =============================================================================
CREATE TYPE app.member_role AS ENUM ('owner', 'admin', 'manager', 'clerk', 'viewer', 'auditor');
COMMENT ON TYPE app.member_role IS
  'owner: everything incl. tenant settings and the owner role. admin: users, memberships, attestation, '
  'checklist templates, renumbering, audit log, plus manager. manager: close/reopen/override folders, '
  'lower markings, legal holds, restore documents, delete parties, plus clerk. clerk: create/edit folders, '
  'lines, documents, notes, parties; post ledger entries; request close. viewer: read-only. '
  'auditor: read-only plus audit log.';

-- Declaration order matters: enum comparison follows it, so GREATEST() yields the
-- most restrictive marking, "lowering" is NEW < OLD and the tenant ceiling is a
-- simple >. This is a visibility lattice, not a legal ranking of ITAR vs EAR.
CREATE TYPE app.control_marking AS ENUM ('none', 'fci', 'cui', 'itar', 'ear');
COMMENT ON TYPE app.control_marking IS
  'none: public/commercial. fci: Federal Contract Information (not export-controlled). '
  'cui/itar/ear: controlled -- invisible to users who are not attested US persons.';

CREATE TYPE app.po_status AS ENUM ('open', 'pending_close', 'closed');

-- The brief left five category blanks. Proposed: the four physical kinds the office
-- files (machinery, tooling, accessories, software), freight (its own ledger side),
-- service (installation/training/repair), and other as the escape hatch.
CREATE TYPE app.line_item_category AS ENUM
  ('machinery', 'tooling', 'accessories', 'software', 'freight', 'service', 'other');

CREATE TYPE app.document_kind AS ENUM
  ('client_po', 'client_invoice', 'vendor_invoice', 'remittance', 'packing_slip', 'freight_bill',
   'commission_statement', 'quote', 'correspondence', 'ledger_page', 'folder_tab', 'other');

-- Phase 2 (vision extraction) will drive these two; Phase 1 only stores them.
CREATE TYPE app.extraction_status AS ENUM
  ('not_started', 'queued', 'processing', 'needs_review', 'verified', 'failed', 'not_applicable');
CREATE TYPE app.job_status AS ENUM ('queued', 'running', 'succeeded', 'failed', 'cancelled');

CREATE TYPE app.ledger_kind AS ENUM
  ('client_invoice', 'client_payment', 'vendor_bill', 'vendor_payment', 'freight_charge',
   'commission_earned', 'commission_received', 'credit_memo', 'adjustment', 'reversal');

-- Which "column" of the paper top sheet an entry belongs to.
CREATE TYPE app.ledger_side AS ENUM ('client', 'vendor', 'freight', 'commission');

-- accrual = something was billed/earned; cash = money actually moved.
CREATE TYPE app.ledger_flow AS ENUM ('accrual', 'cash');

CREATE TYPE app.note_kind AS ENUM ('comment', 'sticky');
CREATE TYPE app.audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- =============================================================================
-- §4  PURE LEDGER MATH  (IMMUTABLE: usable in generated columns and CHECKs)
-- -----------------------------------------------------------------------------
--  The sign of a ledger entry is a function of its kind and nothing else.
--    +1 : increases the open balance on its side (we billed / were billed / earned)
--    -1 : decreases it (money moved, or a credit)
--  A reversal carries the reversed entry's kind in reversed_kind and takes the
--  opposite sign, so a reversal of a payment is +, a reversal of an invoice is -.
-- =============================================================================
CREATE FUNCTION app.ledger_sign(k app.ledger_kind)
RETURNS smallint LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS $$
  SELECT CASE k
    WHEN 'client_invoice'      THEN  1
    WHEN 'client_payment'      THEN -1
    WHEN 'vendor_bill'         THEN  1
    WHEN 'vendor_payment'      THEN -1
    WHEN 'freight_charge'      THEN  1
    WHEN 'commission_earned'   THEN  1
    WHEN 'commission_received' THEN -1
    WHEN 'credit_memo'         THEN -1     -- a credit always reduces the balance on its side
    WHEN 'adjustment'          THEN  1     -- an adjustment always increases it (use credit_memo to reduce)
    ELSE NULL                              -- 'reversal' has no sign of its own
  END::smallint
$$;

CREATE FUNCTION app.ledger_flow_of(k app.ledger_kind)
RETURNS app.ledger_flow LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS $$
  SELECT CASE k
    WHEN 'client_payment'      THEN 'cash'
    WHEN 'vendor_payment'      THEN 'cash'
    WHEN 'commission_received' THEN 'cash'
    WHEN 'reversal'            THEN NULL   -- resolved through reversed_kind
    ELSE 'accrual'
  END::app.ledger_flow
$$;

-- Which sides a kind may post to. (For reversals, pass the reversed kind.)
CREATE FUNCTION app.ledger_side_allowed(k app.ledger_kind, s app.ledger_side)
RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS $$
  SELECT CASE k
    WHEN 'client_invoice'      THEN s = 'client'
    WHEN 'client_payment'      THEN s = 'client'
    WHEN 'vendor_bill'         THEN s = 'vendor'
    WHEN 'vendor_payment'      THEN s IN ('vendor', 'freight')   -- paying a carrier is a freight-side payment
    WHEN 'freight_charge'      THEN s = 'freight'
    WHEN 'commission_earned'   THEN s = 'commission'
    WHEN 'commission_received' THEN s = 'commission'
    WHEN 'credit_memo'         THEN true
    WHEN 'adjustment'          THEN true
    ELSE false                                                   -- bare 'reversal' never validates
  END
$$;

CREATE FUNCTION app.is_controlled(m app.control_marking)
RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS $$
  SELECT m IN ('cui', 'itar', 'ear')
$$;

-- =============================================================================
-- §5  CONTEXT HELPERS  (plain, cheap; the two that Supabase redefines)
-- -----------------------------------------------------------------------------
--  Parse the two settings of the session-context contract. Malformed or
--  missing values yield NULL, never an error, and NULL never matches a policy.
-- =============================================================================
CREATE FUNCTION app.current_tenant_id()
RETURNS uuid LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT CASE
           WHEN current_setting('app.tenant_id', true)
                ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           THEN current_setting('app.tenant_id', true)::uuid
         END
$$;
COMMENT ON FUNCTION app.current_tenant_id() IS
  'Tenant asserted by the application for this transaction (SET LOCAL app.tenant_id), or NULL. Supabase: redefine to read the JWT.';

CREATE FUNCTION app.current_user_id()
RETURNS uuid LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT CASE
           WHEN current_setting('app.user_id', true)
                ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           THEN current_setting('app.user_id', true)::uuid
         END
$$;
COMMENT ON FUNCTION app.current_user_id() IS
  'User asserted by the application for this transaction (SET LOCAL app.user_id), or NULL. Supabase: redefine to auth.uid().';

-- True only while NO request context exists at all: the login path, before the
-- API has set app.tenant_id / app.user_id. The session-bootstrap helpers
-- (app.resolve_user*) refuse to run outside it. Checks the raw settings as well
-- as the parsed ids, so a malformed-but-present value counts as "inside a
-- request" too.
CREATE FUNCTION app.is_login_context()
RETURNS boolean LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT COALESCE(current_setting('app.tenant_id', true), '') = ''
     AND COALESCE(current_setting('app.user_id', true), '') = ''
     AND app.current_tenant_id() IS NULL
     AND app.current_user_id() IS NULL
$$;
COMMENT ON FUNCTION app.is_login_context() IS
  'True when neither app.tenant_id nor app.user_id is set: the only state in which app.resolve_user / app.resolve_user_by_subject run.';

-- True only inside a SECURITY DEFINER function owned by app_security, or for a
-- superuser. Triggers use it to let provisioning/operator paths through ROLE
-- checks (never through the state machine, the append-only rules, the
-- last-owner guard or the marking ceiling).
CREATE FUNCTION app.is_privileged_context()
RETURNS boolean LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT current_user = 'app_security'
      OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = current_user AND rolsuper)
$$;

-- =============================================================================
-- §6  TABLES
-- -----------------------------------------------------------------------------
--  Convention for every tenant-scoped table:
--    tenant_id uuid NOT NULL REFERENCES app.tenants (id)
--    UNIQUE (tenant_id, id)          -- the target every child's composite FK points at
--  Children:  FOREIGN KEY (tenant_id, parent_id) REFERENCES parent (tenant_id, id)
-- =============================================================================

-- 6.1 tenants ---------------------------------------------------------------
CREATE TABLE app.tenants (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
  slug                 text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  is_active            boolean NOT NULL DEFAULT true,
  -- Same schema for both deployment profiles; the app reads this to disable
  -- hosted-only integrations (EasyPost, QuickBooks Online, hosted vision) on-prem.
  deployment_mode      text NOT NULL DEFAULT 'cloud' CHECK (deployment_mode IN ('cloud', 'onprem')),
  -- Marking ceiling: the highest control_marking any folder or document of this
  -- tenant may carry. Hosted tenants are provisioned with 'fci'; the on-prem /
  -- ITAR build with 'ear' (= everything). Enforced by trigger on purchase_orders
  -- and documents; only an operator (not the app) may change it.
  max_control_marking  app.control_marking NOT NULL DEFAULT 'fci',
  -- Retention: closed folders and their documents are kept at least this long
  -- (retain_until is stamped on purchase_orders at close). NULL = keep forever.
  retention_years      int CHECK (retention_years IS NULL OR retention_years BETWEEN 1 AND 100),
  settings             jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(settings) = 'object'),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE app.tenants IS 'One row per company using the platform. On-prem installs have exactly one.';
COMMENT ON COLUMN app.tenants.max_control_marking IS 'Ceiling for purchase_orders.control_marking and documents.control_marking. Operator-only.';

-- 6.2 users -------------------------------------------------------------------
-- Global (a person may belong to several tenants). Authentication, passwords,
-- MFA secrets and sessions live in the identity provider / app layer, NOT here.
-- auth_subject is the portable link to that identity (Keycloak/OIDC `sub`
-- on-prem, auth.uid()::text on Supabase). No FK to auth.users on purpose.
CREATE TABLE app.users (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email                  text NOT NULL UNIQUE
                         CHECK (email = lower(email) AND email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  full_name              text NOT NULL CHECK (length(btrim(full_name)) BETWEEN 1 AND 200),
  auth_subject           text UNIQUE CHECK (auth_subject IS NULL OR length(auth_subject) BETWEEN 1 AND 255),
  is_active              boolean NOT NULL DEFAULT true,
  -- Export-control attribute. Defaults to false; may only be set by an owner/admin
  -- of a tenant the user belongs to, never by the user themself (trigger + CHECK),
  -- and the attestation is stamped by the trigger, not supplied by the client.
  is_us_person           boolean NOT NULL DEFAULT false,
  us_person_attested_by  uuid REFERENCES app.users (id),
  us_person_attested_at  timestamptz,
  us_person_basis        text,          -- e.g. 'US citizen, passport copy on file (HR-2026-014)'
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_us_person_needs_attestation
    CHECK (NOT is_us_person OR (us_person_attested_by IS NOT NULL AND us_person_attested_at IS NOT NULL)),
  CONSTRAINT users_no_self_attestation
    CHECK (us_person_attested_by IS NULL OR us_person_attested_by <> id)
);
COMMENT ON COLUMN app.users.is_us_person IS 'Gate for cui/itar/ear rows. Requires attestation by a different owner/admin.';

-- 6.3 tenant_memberships ------------------------------------------------------
CREATE TABLE app.tenant_memberships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES app.tenants (id),
  user_id     uuid NOT NULL REFERENCES app.users (id),
  role        app.member_role NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,        -- soft removal keeps the audit trail readable
  invited_by  uuid REFERENCES app.users (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_memberships_tenant_user_key UNIQUE (tenant_id, user_id),
  CONSTRAINT tenant_memberships_tenant_id_id_key UNIQUE (tenant_id, id)
);

-- 6.4 parties -----------------------------------------------------------------
-- Clients, vendors and freight carriers in one table; a party may be several.
CREATE TABLE app.parties (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES app.tenants (id),
  name           text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
  short_code     text CHECK (short_code IS NULL OR length(short_code) BETWEEN 1 AND 20),
  is_client      boolean NOT NULL DEFAULT false,
  is_vendor      boolean NOT NULL DEFAULT false,
  is_carrier     boolean NOT NULL DEFAULT false,
  email          text,
  phone          text,
  address_line1  text,
  address_line2  text,
  city           text,
  region         text,
  postal_code    text,
  country        text,
  payment_terms  text,                              -- free text: 'Net 30', '50% deposit'
  external_refs  jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(external_refs) = 'object'),
                                                    -- Phase 3: {"quickbooks_customer_id": "..", "quickbooks_vendor_id": ".."}
  notes          text,
  is_active      boolean NOT NULL DEFAULT true,     -- soft-retire; never hard-deleted once referenced (FKs RESTRICT)
  created_by     uuid REFERENCES app.users (id),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT parties_has_a_role CHECK (is_client OR is_vendor OR is_carrier),
  CONSTRAINT parties_tenant_id_id_key UNIQUE (tenant_id, id)
);

-- 6.5 po_number_counters --------------------------------------------------------
-- Gapless per-tenant allocator. Row-locked UPDATE ... RETURNING inside the PO
-- insert transaction: if the insert rolls back the number is not consumed.
-- Only app_security (via app.next_po_number) can touch it; imported numbers
-- are skipped by the allocator.
CREATE TABLE app.po_number_counters (
  tenant_id   uuid PRIMARY KEY REFERENCES app.tenants (id),
  prefix      text NOT NULL DEFAULT 'PO-' CHECK (length(prefix) <= 10),
  pad_width   int  NOT NULL DEFAULT 5 CHECK (pad_width BETWEEN 1 AND 12),
  next_value  bigint NOT NULL DEFAULT 1 CHECK (next_value > 0),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 6.6 close_checklist_templates -------------------------------------------------
-- The close-out checklist is first-class: the attestations the ledger math
-- cannot make ("no more vendor bills are coming"). Templates are per tenant
-- (owner/admin edit them); each new folder gets a copy. The seeded defaults are
-- ADVISORY (is_required = false) so the paper backlog can be closed on the
-- ledger math alone; the owner flips items to required once the office has
-- settled its close-out routine.
CREATE TABLE app.close_checklist_templates (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES app.tenants (id),
  item_key     text NOT NULL CHECK (item_key ~ '^[a-z0-9_]{2,40}$'),
  label        text NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 300),
  sort_order   int  NOT NULL DEFAULT 100,
  is_required  boolean NOT NULL DEFAULT false,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT close_checklist_templates_key UNIQUE (tenant_id, item_key)
);

-- 6.7 purchase_orders  (the physical folder) -------------------------------------
CREATE TABLE app.purchase_orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL REFERENCES app.tenants (id),
  -- Folder tab -------------------------------------------------------------
  po_number             text NOT NULL CHECK (length(btrim(po_number)) BETWEEN 1 AND 40),  -- allocated if NULL on insert
  client_order_number   text CHECK (client_order_number IS NULL OR length(client_order_number) <= 80),
  client_party_id       uuid NOT NULL,
  vendor_party_id       uuid,                        -- primary vendor; lines may override
  title                 text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 300),     -- "Project name / items purchased"
  description           text,
  -- Lifecycle ----------------------------------------------------------------
  status                app.po_status NOT NULL DEFAULT 'open',
  control_marking       app.control_marking NOT NULL DEFAULT 'none',
  opened_at             timestamptz NOT NULL DEFAULT now(),   -- may be back-dated when importing old folders
  opened_by             uuid REFERENCES app.users (id),
  close_requested_at    timestamptz,                          -- the "please close" sticky note
  close_requested_by    uuid REFERENCES app.users (id),
  closed_at             timestamptz,
  closed_by             uuid REFERENCES app.users (id),       -- management sign-off
  close_signoff_note    text,                                 -- free-text sign-off remark
  close_override_reason text,                                 -- NOT NULL <=> closed while not ready_to_close
  reopened_at           timestamptz,
  reopened_by           uuid REFERENCES app.users (id),
  reopen_reason         text,
  reopen_count          int NOT NULL DEFAULT 0 CHECK (reopen_count >= 0),
  -- Retention / legal hold -----------------------------------------------------
  legal_hold            boolean NOT NULL DEFAULT false,       -- blocks deletion of the folder and its documents
  legal_hold_reason     text,
  retain_until          date,                                 -- stamped at close from tenants.retention_years
  external_refs         jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(external_refs) = 'object'),
  created_by            uuid REFERENCES app.users (id),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT purchase_orders_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT purchase_orders_po_number_key   UNIQUE (tenant_id, po_number),
  CONSTRAINT purchase_orders_client_fkey
    FOREIGN KEY (tenant_id, client_party_id) REFERENCES app.parties (tenant_id, id),
  CONSTRAINT purchase_orders_vendor_fkey
    FOREIGN KEY (tenant_id, vendor_party_id) REFERENCES app.parties (tenant_id, id),
  CONSTRAINT purchase_orders_closed_consistent
    CHECK ((status = 'closed') = (closed_at IS NOT NULL AND closed_by IS NOT NULL)),
  CONSTRAINT purchase_orders_pending_consistent
    CHECK (status <> 'pending_close' OR close_requested_at IS NOT NULL),
  CONSTRAINT purchase_orders_override_only_when_closed
    CHECK (close_override_reason IS NULL OR status = 'closed'),
  CONSTRAINT purchase_orders_hold_needs_reason
    CHECK (NOT legal_hold OR length(btrim(coalesce(legal_hold_reason, ''))) >= 3),
  CONSTRAINT purchase_orders_retain_only_when_closed
    CHECK (retain_until IS NULL OR status = 'closed')
);
COMMENT ON TABLE app.purchase_orders IS 'One row per physical PO folder.';
COMMENT ON COLUMN app.purchase_orders.close_override_reason IS
  'Set only when management closed the folder although app.po_balances.ready_to_close was false.';
COMMENT ON COLUMN app.purchase_orders.retain_until IS
  'closed_at + tenants.retention_years, stamped by the database at close; cleared on reopen. A purge job may only touch folders past it and not on hold.';

-- 6.8 po_line_items ---------------------------------------------------------------
CREATE TABLE app.po_line_items (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                  uuid NOT NULL REFERENCES app.tenants (id),
  po_id                      uuid NOT NULL,
  line_no                    int  NOT NULL CHECK (line_no > 0),
  category                   app.line_item_category NOT NULL,
  description                text NOT NULL CHECK (length(btrim(description)) BETWEEN 1 AND 1000),
  part_number                text,
  quantity                   numeric(12,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price                 numeric(14,4) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  extended_amount            numeric(14,2) GENERATED ALWAYS AS (round(quantity * unit_price, 2)) STORED,
  vendor_party_id            uuid,                 -- per-line override of the folder's primary vendor
  serial_number              text,
  -- Phase 3 placeholders (shipment tracking). Nullable and unused in Phase 1.
  tracking_carrier_party_id  uuid,
  tracking_number            text,
  tracking_status            text,
  shipped_at                 timestamptz,
  delivered_at               timestamptz,
  created_by                 uuid REFERENCES app.users (id),
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT po_line_items_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT po_line_items_line_no_key      UNIQUE (tenant_id, po_id, line_no),
  CONSTRAINT po_line_items_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT po_line_items_vendor_fkey
    FOREIGN KEY (tenant_id, vendor_party_id) REFERENCES app.parties (tenant_id, id),
  CONSTRAINT po_line_items_carrier_fkey
    FOREIGN KEY (tenant_id, tracking_carrier_party_id) REFERENCES app.parties (tenant_id, id)
);

-- 6.9 documents  (metadata only; bytes live in object storage) --------------------
-- po_id IS NULL is the inbox (scanned, not yet filed). A document carries its
-- own marking AND inherits its folder's on filing/refiling (trigger), so a scan
-- can never leave a controlled folder with a lower marking than the folder.
CREATE TABLE app.documents (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES app.tenants (id),
  po_id                   uuid,                     -- NULL = inbox / not yet filed (Phase 2 HITL assigns it)
  kind                    app.document_kind NOT NULL DEFAULT 'other',
  control_marking         app.control_marking NOT NULL DEFAULT 'none',
  title                   text,
  original_filename       text,
  storage_key             text NOT NULL CHECK (length(storage_key) BETWEEN 1 AND 1024),   -- opaque key in the object store
  sha256                  text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  mime_type               text NOT NULL CHECK (mime_type ~ '^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$'),
  byte_size               bigint NOT NULL CHECK (byte_size > 0),
  page_count              int CHECK (page_count IS NULL OR page_count > 0),
  document_date           date,                     -- date printed on the document
  amount_hint             numeric(14,2),            -- typed-in total, for quick matching against the ledger
  supersedes_document_id  uuid,                     -- new version (re-scan) of an earlier upload
  extraction_status       app.extraction_status NOT NULL DEFAULT 'not_started',   -- Phase 2 placeholder
  uploaded_by             uuid REFERENCES app.users (id),
  uploaded_at             timestamptz NOT NULL DEFAULT now(),
  deleted_at              timestamptz,              -- soft delete: storage cleanup is async and the hash must remain auditable
  deleted_by              uuid REFERENCES app.users (id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT documents_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT documents_storage_key_key UNIQUE (tenant_id, storage_key),
  CONSTRAINT documents_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT documents_supersedes_fkey
    FOREIGN KEY (tenant_id, supersedes_document_id) REFERENCES app.documents (tenant_id, id),
  CONSTRAINT documents_not_self_superseding CHECK (supersedes_document_id IS NULL OR supersedes_document_id <> id),
  CONSTRAINT documents_soft_delete_consistent CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- 6.10 document_pages  (Phase 2 hook: the page the HITL screen shows) --------------
-- Phase 1 may fill page_number/storage_key when a PDF is rasterised; Phase 2
-- fills ocr_text / ocr_confidence. Visible iff the document is visible.
CREATE TABLE app.document_pages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES app.tenants (id),
  document_id     uuid NOT NULL,
  page_number     int NOT NULL CHECK (page_number > 0),
  storage_key     text CHECK (storage_key IS NULL OR length(storage_key) BETWEEN 1 AND 1024),   -- rendered page image
  width_px        int CHECK (width_px IS NULL OR width_px > 0),
  height_px       int CHECK (height_px IS NULL OR height_px > 0),
  rotation_deg    smallint NOT NULL DEFAULT 0 CHECK (rotation_deg IN (0, 90, 180, 270)),
  ocr_text        text,                                          -- Phase 2
  ocr_confidence  numeric(4,3) CHECK (ocr_confidence IS NULL OR ocr_confidence BETWEEN 0 AND 1),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT document_pages_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT document_pages_page_key UNIQUE (tenant_id, document_id, page_number),
  CONSTRAINT document_pages_document_fkey
    FOREIGN KEY (tenant_id, document_id) REFERENCES app.documents (tenant_id, id) ON DELETE CASCADE
);

-- 6.11 extraction_jobs  (Phase 2 hook: one row per extraction attempt) --------------
-- result holds the schema-constrained JSON; reviewed_by/at is the human-in-the-
-- loop sign-off; applied_po_id is the folder the reviewed result was written to.
-- Visible iff the document is visible. Audited.
CREATE TABLE app.extraction_jobs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES app.tenants (id),
  document_id     uuid NOT NULL,
  status          app.job_status NOT NULL DEFAULT 'queued',
  engine          text,                                          -- e.g. 'claude-vision', 'local-vlm', 'manual'
  confidence      numeric(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
  result          jsonb CHECK (result IS NULL OR jsonb_typeof(result) = 'object'),
  error           text,
  applied_po_id   uuid,
  reviewed_by     uuid REFERENCES app.users (id),
  reviewed_at     timestamptz,
  created_by      uuid REFERENCES app.users (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  started_at      timestamptz,
  finished_at     timestamptz,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT extraction_jobs_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT extraction_jobs_document_fkey
    FOREIGN KEY (tenant_id, document_id) REFERENCES app.documents (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT extraction_jobs_applied_po_fkey
    FOREIGN KEY (tenant_id, applied_po_id) REFERENCES app.purchase_orders (tenant_id, id),
  CONSTRAINT extraction_jobs_review_consistent CHECK ((reviewed_at IS NULL) = (reviewed_by IS NULL)),
  CONSTRAINT extraction_jobs_applied_needs_review CHECK (applied_po_id IS NULL OR reviewed_at IS NOT NULL)
);

-- 6.12 ledger_entries  (THE HEART: append-only money events) ------------------------
CREATE TABLE app.ledger_entries (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL REFERENCES app.tenants (id),
  po_id                  uuid NOT NULL,             -- every money event lives in a folder
  kind                   app.ledger_kind NOT NULL,
  side                   app.ledger_side NOT NULL,
  amount                 numeric(14,2) NOT NULL CHECK (amount > 0),   -- ALWAYS positive
  reverses_entry_id      uuid,                      -- set only for kind = 'reversal'
  reversed_kind          app.ledger_kind,           -- copied from the reversed entry by trigger
  -- Derived, stored, impossible to get wrong:
  signed_amount          numeric(14,2) GENERATED ALWAYS AS (
                           amount * (CASE WHEN kind = 'reversal'::app.ledger_kind
                                          THEN -app.ledger_sign(reversed_kind)
                                          ELSE  app.ledger_sign(kind) END)) STORED,
  flow                   app.ledger_flow GENERATED ALWAYS AS (app.ledger_flow_of(COALESCE(reversed_kind, kind))) STORED,
  entry_date             date NOT NULL DEFAULT CURRENT_DATE,
  counterparty_party_id  uuid,
  reference              text CHECK (reference IS NULL OR length(reference) <= 120),   -- invoice #, check #, ACH id
  document_id            uuid,                      -- the invoice/remittance this entry was posted from (evidence)
  evidence_page          int CHECK (evidence_page IS NULL OR evidence_page > 0),   -- ... and the exact page of it
  memo                   text,
  created_by             uuid REFERENCES app.users (id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ledger_entries_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ledger_entries_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT ledger_entries_counterparty_fkey
    FOREIGN KEY (tenant_id, counterparty_party_id) REFERENCES app.parties (tenant_id, id),
  CONSTRAINT ledger_entries_document_fkey
    FOREIGN KEY (tenant_id, document_id) REFERENCES app.documents (tenant_id, id),
  CONSTRAINT ledger_entries_reverses_fkey
    FOREIGN KEY (tenant_id, reverses_entry_id) REFERENCES app.ledger_entries (tenant_id, id),
  CONSTRAINT ledger_entries_reversal_shape
    CHECK ((kind = 'reversal') = (reverses_entry_id IS NOT NULL)
       AND (kind = 'reversal') = (reversed_kind IS NOT NULL)),
  CONSTRAINT ledger_entries_no_reversal_of_reversal
    CHECK (reversed_kind IS DISTINCT FROM 'reversal'::app.ledger_kind),
  CONSTRAINT ledger_entries_no_self_reversal
    CHECK (reverses_entry_id IS NULL OR reverses_entry_id <> id),
  CONSTRAINT ledger_entries_side_matches_kind
    CHECK (app.ledger_side_allowed(COALESCE(reversed_kind, kind), side)),
  CONSTRAINT ledger_entries_memo_required
    CHECK (kind NOT IN ('adjustment', 'credit_memo', 'reversal') OR length(btrim(coalesce(memo, ''))) >= 3),
  CONSTRAINT ledger_entries_page_needs_document
    CHECK (evidence_page IS NULL OR document_id IS NOT NULL)
);
COMMENT ON TABLE app.ledger_entries IS
  'Append-only. No UPDATE/DELETE for anyone; corrections are kind=reversal entries referencing the original.';
COMMENT ON COLUMN app.ledger_entries.signed_amount IS 'amount * sign(kind); reversals take the opposite sign of the reversed kind.';

-- 6.13 po_notes  (sticky notes + the hand-written comments column) --------------------
CREATE TABLE app.po_notes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES app.tenants (id),
  po_id        uuid NOT NULL,
  kind         app.note_kind NOT NULL DEFAULT 'comment',
  body         text NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 10000),
  is_pinned    boolean NOT NULL DEFAULT false,
  resolved_at  timestamptz,
  resolved_by  uuid REFERENCES app.users (id),
  created_by   uuid REFERENCES app.users (id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT po_notes_tenant_id_id_key UNIQUE (tenant_id, id),
  CONSTRAINT po_notes_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT po_notes_resolved_consistent CHECK ((resolved_at IS NULL) = (resolved_by IS NULL))
);

-- 6.14 po_close_checklist_items ------------------------------------------------------
CREATE TABLE app.po_close_checklist_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES app.tenants (id),
  po_id         uuid NOT NULL,
  item_key      text NOT NULL CHECK (item_key ~ '^[a-z0-9_]{2,40}$'),
  label         text NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 300),
  sort_order    int  NOT NULL DEFAULT 100,
  is_required   boolean NOT NULL DEFAULT false,
  completed_at  timestamptz,
  completed_by  uuid REFERENCES app.users (id),
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT po_close_checklist_items_key UNIQUE (tenant_id, po_id, item_key),
  CONSTRAINT po_close_checklist_items_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT po_close_checklist_items_completed_consistent CHECK ((completed_at IS NULL) = (completed_by IS NULL))
);

-- 6.15 po_status_history  (append-only; the close-out sign-off record) -----------------
CREATE TABLE app.po_status_history (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES app.tenants (id),
  po_id               uuid NOT NULL,
  from_status         app.po_status,               -- NULL on creation
  to_status           app.po_status NOT NULL,
  changed_by          uuid REFERENCES app.users (id),
  changed_at          timestamptz NOT NULL DEFAULT now(),
  reason              text,                        -- override reason / reopen reason / sign-off note
  was_ready_to_close  boolean,
  balances            jsonb,                       -- snapshot of app.po_balances at the transition
  checklist           jsonb,                       -- snapshot of the checklist at the transition
  CONSTRAINT po_status_history_po_fkey
    FOREIGN KEY (tenant_id, po_id) REFERENCES app.purchase_orders (tenant_id, id) ON DELETE RESTRICT
);

-- 6.16 audit_log  (append-only, trigger-populated) --------------------------------------
CREATE TABLE app.audit_log (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq              bigint NOT NULL,                          -- per-tenant ordinal: tg_audit draws it from the tenant's OWN
                                                            -- sequence (app.audit_seq_<tenant>, see 11.2), never from a global
                                                            -- counter, so a gap in what one tenant sees never discloses
                                                            -- another tenant's write volume
  tenant_id        uuid NOT NULL REFERENCES app.tenants (id),
  table_name       text NOT NULL,
  row_id           uuid,
  action           app.audit_action NOT NULL,
  old_data         jsonb,
  new_data         jsonb,
  changed_columns  text[],
  po_id            uuid,                                     -- folder the row belongs to, if any (live gating)
  document_id      uuid,                                     -- document the row belongs to, if any (live gating)
  control_marking  app.control_marking NOT NULL DEFAULT 'none',   -- effective marking at write time
  actor_user_id    uuid,                                     -- app.current_user_id() at write time
  actor_role       app.member_role,                          -- membership role at write time (forensics without replay)
  actor_db_role    text NOT NULL,
  client_addr      inet,
  tx_started_at    timestamptz NOT NULL,                     -- transaction_timestamp(): every row of one transaction shares it.
                                                            -- Deliberately NOT the xid: pg_current_xact_id() is a cluster-global
                                                            -- counter and would leak other tenants' (and databases') write volume.
  statement_at     timestamptz NOT NULL DEFAULT statement_timestamp(),
  created_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT audit_log_tenant_id_seq_key UNIQUE (tenant_id, seq)
);
COMMENT ON TABLE app.audit_log IS 'Every INSERT/UPDATE/DELETE on business tables, written by app.tg_audit (SECURITY DEFINER). Immutable.';

-- =============================================================================
-- §7  INDEXES
-- =============================================================================
CREATE INDEX tenant_memberships_user_idx        ON app.tenant_memberships (user_id);
CREATE INDEX tenant_memberships_tenant_idx      ON app.tenant_memberships (tenant_id, is_active);

CREATE UNIQUE INDEX parties_tenant_name_uniq    ON app.parties (tenant_id, lower(name));
CREATE INDEX parties_name_trgm_idx              ON app.parties USING gin (name gin_trgm_ops);
CREATE INDEX parties_tenant_flags_idx           ON app.parties (tenant_id, is_client, is_vendor, is_carrier);

CREATE INDEX purchase_orders_tenant_status_idx  ON app.purchase_orders (tenant_id, status, opened_at DESC);
CREATE INDEX purchase_orders_client_idx         ON app.purchase_orders (tenant_id, client_party_id);
CREATE INDEX purchase_orders_vendor_idx         ON app.purchase_orders (tenant_id, vendor_party_id);
CREATE INDEX purchase_orders_client_order_idx   ON app.purchase_orders (tenant_id, client_order_number);
CREATE INDEX purchase_orders_title_trgm_idx     ON app.purchase_orders USING gin (title gin_trgm_ops);
CREATE INDEX purchase_orders_number_trgm_idx    ON app.purchase_orders USING gin (po_number gin_trgm_ops);
CREATE INDEX purchase_orders_corder_trgm_idx    ON app.purchase_orders USING gin (client_order_number gin_trgm_ops);
CREATE INDEX purchase_orders_retention_idx      ON app.purchase_orders (tenant_id, retain_until) WHERE retain_until IS NOT NULL;

CREATE INDEX po_line_items_po_idx               ON app.po_line_items (tenant_id, po_id);

CREATE INDEX documents_po_idx                   ON app.documents (tenant_id, po_id);
CREATE INDEX documents_sha256_idx               ON app.documents (tenant_id, sha256);
CREATE INDEX documents_inbox_idx                ON app.documents (tenant_id, uploaded_at DESC) WHERE po_id IS NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX documents_supersedes_uniq   ON app.documents (tenant_id, supersedes_document_id) WHERE supersedes_document_id IS NOT NULL;
CREATE INDEX documents_title_trgm_idx           ON app.documents USING gin (title gin_trgm_ops);
CREATE INDEX documents_filename_trgm_idx        ON app.documents USING gin (original_filename gin_trgm_ops);

CREATE INDEX document_pages_document_idx        ON app.document_pages (tenant_id, document_id, page_number);
CREATE INDEX document_pages_ocr_trgm_idx        ON app.document_pages USING gin (ocr_text gin_trgm_ops);

CREATE INDEX extraction_jobs_document_idx       ON app.extraction_jobs (tenant_id, document_id, created_at DESC);
CREATE INDEX extraction_jobs_status_idx         ON app.extraction_jobs (tenant_id, status) WHERE status IN ('queued', 'running');

CREATE INDEX ledger_entries_po_idx              ON app.ledger_entries (tenant_id, po_id, entry_date);
CREATE INDEX ledger_entries_date_idx            ON app.ledger_entries (tenant_id, entry_date);
CREATE INDEX ledger_entries_counterparty_idx    ON app.ledger_entries (tenant_id, counterparty_party_id);
CREATE INDEX ledger_entries_document_idx        ON app.ledger_entries (tenant_id, document_id) WHERE document_id IS NOT NULL;
CREATE UNIQUE INDEX ledger_entries_reversed_once ON app.ledger_entries (tenant_id, reverses_entry_id) WHERE reverses_entry_id IS NOT NULL;
CREATE INDEX ledger_entries_memo_trgm_idx       ON app.ledger_entries USING gin (memo gin_trgm_ops);
CREATE INDEX ledger_entries_reference_trgm_idx  ON app.ledger_entries USING gin (reference gin_trgm_ops);

CREATE INDEX po_notes_po_idx                    ON app.po_notes (tenant_id, po_id, created_at);
CREATE INDEX po_notes_body_trgm_idx             ON app.po_notes USING gin (body gin_trgm_ops);
CREATE INDEX po_close_checklist_items_po_idx    ON app.po_close_checklist_items (tenant_id, po_id);
CREATE INDEX po_status_history_po_idx           ON app.po_status_history (tenant_id, po_id, changed_at);

-- (tenant_id, seq) is covered by the UNIQUE constraint audit_log_tenant_id_seq_key
CREATE INDEX audit_log_row_idx                  ON app.audit_log (tenant_id, table_name, row_id);
CREATE INDEX audit_log_po_idx                   ON app.audit_log (tenant_id, po_id) WHERE po_id IS NOT NULL;
CREATE INDEX audit_log_document_idx             ON app.audit_log (tenant_id, document_id) WHERE document_id IS NOT NULL;

-- =============================================================================
-- §8  SECURITY-DEFINER LOOKUP HELPERS  (owned by app_security, the BYPASSRLS role)
-- -----------------------------------------------------------------------------
--  "What is my role in the current tenant?" and "am I an attested US person?"
--  must read tenant_memberships/users. If those reads went through RLS, the
--  policies on tenant_memberships would call current_member_role() which reads
--  tenant_memberships ... => infinite recursion. Hence: two tiny functions that
--  bypass RLS, owned by a role that can log in nowhere and owns nothing else of
--  consequence. They are STABLE, so policies wrap them in (SELECT ...) and the
--  planner evaluates them once per statement as an InitPlan, not once per row.
--
--  Membership is the source of truth for authorization: the app asserts only
--  WHO (user_id) and WHERE (tenant_id); the database decides WHAT they may do.
--  A user_id that is not an active member of the asserted tenant has no role,
--  and no role means no policy matches: fail closed.
-- =============================================================================
RESET ROLE;   -- superuser: needed to hand ownership to app_security

CREATE FUNCTION app.current_member_role()
RETURNS app.member_role LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
  SELECT m.role
  FROM app.tenant_memberships m
  JOIN app.users   u ON u.id = m.user_id
  JOIN app.tenants t ON t.id = m.tenant_id
  WHERE m.tenant_id = app.current_tenant_id()
    AND m.user_id   = app.current_user_id()
    AND m.is_active AND u.is_active AND t.is_active
$$;
ALTER FUNCTION app.current_member_role() OWNER TO app_security;
COMMENT ON FUNCTION app.current_member_role() IS
  'Role of the context user in the context tenant, or NULL (=> no access). Named to avoid shadowing the SQL keyword CURRENT_ROLE.';

CREATE FUNCTION app.current_user_is_us_person()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
  SELECT COALESCE(
           (SELECT u.is_us_person FROM app.users u
             WHERE u.id = app.current_user_id() AND u.is_active),
           false)
$$;
ALTER FUNCTION app.current_user_is_us_person() OWNER TO app_security;

SET ROLE app_owner;

-- =============================================================================
-- §9  ROLE PREDICATES + EXPORT-CONTROL GATE  (plain wrappers, used by policies
--      and triggers; all return false rather than NULL when there is no context)
-- =============================================================================
CREATE FUNCTION app.is_member() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT app.current_member_role() IS NOT NULL $$;

CREATE FUNCTION app.is_owner() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(app.current_member_role() = 'owner', false) $$;

-- owner, admin: manage users, memberships, attestations, checklist templates, renumbering
CREATE FUNCTION app.can_manage_users() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(app.current_member_role() IN ('owner', 'admin'), false) $$;

-- owner, admin, manager: close / reopen / override folders, lower markings, legal holds,
-- restore documents, delete parties
CREATE FUNCTION app.can_manage_lifecycle() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(app.current_member_role() IN ('owner', 'admin', 'manager'), false) $$;

-- owner, admin, manager, clerk: create/edit folders, post ledger entries, request close
CREATE FUNCTION app.can_write() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(app.current_member_role() IN ('owner', 'admin', 'manager', 'clerk'), false) $$;

-- owner, admin, manager, auditor: read the audit log
CREATE FUNCTION app.can_read_audit() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(app.current_member_role() IN ('owner', 'admin', 'manager', 'auditor'), false) $$;

-- The markings the context user may see. Non-US persons: none and fci only.
CREATE FUNCTION app.visible_markings() RETURNS app.control_marking[] LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN app.current_user_is_us_person()
              THEN ARRAY['none', 'fci', 'cui', 'itar', 'ear']::app.control_marking[]
              ELSE ARRAY['none', 'fci']::app.control_marking[] END $$;

CREATE FUNCTION app.marking_visible(m app.control_marking) RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT m = ANY (app.visible_markings()) $$;

-- Party role check used by several triggers (runs as the invoker, under RLS).
CREATE FUNCTION app.assert_party_role(p_tenant uuid, p_party uuid, p_role text)
RETURNS void LANGUAGE plpgsql STABLE AS $$
DECLARE r record; v_ok boolean;
BEGIN
  SELECT name, is_client, is_vendor, is_carrier, is_active INTO r
  FROM app.parties WHERE tenant_id = p_tenant AND id = p_party;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'party % not found in this tenant (or not visible)', p_party
      USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF NOT r.is_active THEN
    RAISE EXCEPTION 'party "%" is inactive', r.name USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  v_ok := CASE p_role
            WHEN 'client'  THEN r.is_client
            WHEN 'vendor'  THEN r.is_vendor
            WHEN 'carrier' THEN r.is_carrier
            WHEN 'freight' THEN r.is_carrier OR r.is_vendor   -- freight may be billed by a carrier or the vendor
            ELSE false END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'party "%" is not flagged as a %', r.name, p_role USING ERRCODE = 'check_violation';
  END IF;
END $$;

-- Folder lookup used by the document triggers (runs as the invoker, under RLS:
-- a folder the caller may not see is "not found").
CREATE FUNCTION app.assert_folder_open(p_tenant uuid, p_po uuid, p_purpose text)
RETURNS app.purchase_orders LANGUAGE plpgsql STABLE AS $$
DECLARE r app.purchase_orders%ROWTYPE;
BEGIN
  SELECT * INTO r FROM app.purchase_orders WHERE tenant_id = p_tenant AND id = p_po;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', p_po
      USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF r.status = 'closed' THEN
    RAISE EXCEPTION 'purchase order % is closed; reopen it before %', r.po_number, p_purpose
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  RETURN r;
END $$;

-- =============================================================================
-- §10 PROVISIONING, SESSION BOOTSTRAP, ALLOCATOR  (owned by app_security)
-- -----------------------------------------------------------------------------
--  bootstrap_tenant : creates tenant + owner user + owner membership. An
--                     OPERATOR action: EXECUTE is granted to app_owner only
--                     (superusers can always call it), never to app_user, so
--                     the application cannot mint tenants. On-prem this is the
--                     one-time install step; a hosted control plane would call
--                     it from a provisioning worker connected as app_owner.
--  add_member       : find-or-create a user by e-mail and (re)activate their
--                     membership in the CURRENT tenant. Requires owner/admin.
--                     Users are global (one row per person, e-mail unique), so
--                     the lookup may hit an identity that belongs to ANOTHER
--                     tenant: that is refused (23505), never linked, and the
--                     other tenant's row stays invisible. Linking one person to
--                     a second tenant is an operator action (README, "cross-
--                     tenant identities"); a consent-based invitation flow is
--                     the hosted edition's job. The refusal does tell an
--                     owner/admin that the e-mail is registered somewhere;
--                     nothing else is learned.
--  resolve_user*    : session bootstrap on plain Postgres. Before any context
--                     exists, the API turns the identity the IdP authenticated
--                     into a user id. They run ONLY in a context-free
--                     transaction (app.is_login_context()) and raise otherwise,
--                     so a tenant user can never use them as an e-mail/subject
--                     -> identity oracle from inside a request. In the login
--                     path the database has no caller identity to filter on:
--                     the API must pass only identities the IdP has verified.
--  my_tenants       : the context user's own memberships (needs app.user_id).
--  next_po_number   : gapless per-tenant allocator (see po_number_counters).
-- =============================================================================
RESET ROLE;

CREATE FUNCTION app.bootstrap_tenant(
  p_tenant_name          text,
  p_slug                 text,
  p_owner_email          text,
  p_owner_name           text,
  p_tenant_id            uuid  DEFAULT NULL,
  p_owner_user_id        uuid  DEFAULT NULL,
  p_deployment_mode      text  DEFAULT 'cloud',
  p_max_control_marking  app.control_marking DEFAULT NULL,   -- NULL: 'fci' for cloud, 'ear' (everything) for onprem
  p_retention_years      int   DEFAULT NULL,
  p_settings             jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_tenant   uuid := COALESCE(p_tenant_id, gen_random_uuid());
  v_user     uuid;
  v_new_user boolean;
  v_old_t    text := current_setting('app.tenant_id', true);
  v_old_u    text := current_setting('app.user_id', true);
  v_ceiling  app.control_marking := COALESCE(p_max_control_marking,
                                             CASE WHEN p_deployment_mode = 'onprem' THEN 'ear' ELSE 'fci' END::app.control_marking);
BEGIN
  SELECT id INTO v_user FROM app.users WHERE email = lower(btrim(p_owner_email));
  v_new_user := (v_user IS NULL);
  IF v_new_user THEN v_user := COALESCE(p_owner_user_id, gen_random_uuid()); END IF;

  -- Attribute everything that follows to the new owner in the new tenant.
  -- app.provisioning_tenant_id is the fallback the audit trigger uses for the
  -- global users row when no request context exists (e.g. Supabase, where
  -- app.current_tenant_id() reads the JWT and an operator has none).
  PERFORM set_config('app.tenant_id', v_tenant::text, true);
  PERFORM set_config('app.user_id',   v_user::text,   true);
  PERFORM set_config('app.provisioning_tenant_id', v_tenant::text, true);

  INSERT INTO app.tenants (id, name, slug, deployment_mode, max_control_marking, retention_years, settings)
  VALUES (v_tenant, btrim(p_tenant_name), p_slug, p_deployment_mode, v_ceiling, p_retention_years, COALESCE(p_settings, '{}'::jsonb));
  -- (AFTER INSERT trigger creates the PO counter and the default close-out checklist.)

  IF v_new_user THEN
    INSERT INTO app.users (id, email, full_name) VALUES (v_user, lower(btrim(p_owner_email)), btrim(p_owner_name));
  END IF;

  INSERT INTO app.tenant_memberships (tenant_id, user_id, role, invited_by)
  VALUES (v_tenant, v_user, 'owner', NULL);

  -- Restore the caller's context (set_config with is_local=true is transaction-scoped).
  PERFORM set_config('app.tenant_id', COALESCE(v_old_t, ''), true);
  PERFORM set_config('app.user_id',   COALESCE(v_old_u, ''), true);
  PERFORM set_config('app.provisioning_tenant_id', '', true);
  RETURN v_tenant;
END $$;
ALTER FUNCTION app.bootstrap_tenant(text, text, text, text, uuid, uuid, text, app.control_marking, int, jsonb) OWNER TO app_security;

-- p_user_id / p_auth_subject let the app pin the identity-provider id at invite
-- time (Keycloak `sub` on-prem; on Supabase invite through Auth first, then pass
-- the returned uid as BOTH p_user_id and p_auth_subject so users.id = auth.uid()).
CREATE FUNCTION app.add_member(
  p_email        text,
  p_full_name    text,
  p_role         app.member_role,
  p_user_id      uuid DEFAULT NULL,
  p_auth_subject text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_tenant uuid := app.current_tenant_id();
  v_user   uuid;
BEGIN
  IF NOT app.can_manage_users() THEN
    RAISE EXCEPTION 'only an owner or admin may add members' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_role = 'owner' AND NOT app.is_owner() THEN
    RAISE EXCEPTION 'only an owner may grant the owner role' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT id INTO v_user FROM app.users WHERE email = lower(btrim(p_email));
  -- Never attach (or reveal) an identity that exists outside this tenant.
  IF v_user IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM app.tenant_memberships m WHERE m.tenant_id = v_tenant AND m.user_id = v_user) THEN
    RAISE EXCEPTION 'e-mail % is already registered on this platform outside tenant %; linking an existing identity is an operator action (see README)',
      lower(btrim(p_email)), v_tenant USING ERRCODE = 'unique_violation';
  END IF;
  IF v_user IS NULL THEN
    v_user := COALESCE(p_user_id, gen_random_uuid());
    INSERT INTO app.users (id, email, full_name, auth_subject)
    VALUES (v_user, lower(btrim(p_email)), btrim(p_full_name), NULLIF(btrim(p_auth_subject), ''));
  ELSIF p_auth_subject IS NOT NULL THEN
    UPDATE app.users SET auth_subject = NULLIF(btrim(p_auth_subject), '') WHERE id = v_user AND auth_subject IS NULL;
  END IF;

  INSERT INTO app.tenant_memberships (tenant_id, user_id, role, invited_by)
  VALUES (v_tenant, v_user, p_role, app.current_user_id())
  ON CONFLICT (tenant_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, is_active = true, updated_at = now();
  RETURN v_user;
END $$;
ALTER FUNCTION app.add_member(text, text, app.member_role, uuid, text) OWNER TO app_security;

-- Session bootstrap (plain Postgres login path; Supabase uses auth.uid() instead).
-- Both run only in a context-free transaction: once app.tenant_id / app.user_id
-- are set (i.e. inside a request) they raise, whatever the argument, so they
-- cannot serve tenant users as an "is this e-mail / subject registered?" oracle.
CREATE FUNCTION app.resolve_user(p_email text)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NOT app.is_login_context() THEN
    RAISE EXCEPTION 'app.resolve_user is a login-path helper: call it before SET LOCAL app.tenant_id / app.user_id, never inside a request'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN (SELECT u.id FROM app.users u WHERE u.email = lower(btrim(p_email)) AND u.is_active);
END $$;
ALTER FUNCTION app.resolve_user(text) OWNER TO app_security;
COMMENT ON FUNCTION app.resolve_user(text) IS
  'Login helper: e-mail -> user id (active users only); context-free transactions only. Call after the IdP has authenticated that e-mail.';

CREATE FUNCTION app.resolve_user_by_subject(p_auth_subject text)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NOT app.is_login_context() THEN
    RAISE EXCEPTION 'app.resolve_user_by_subject is a login-path helper: call it before SET LOCAL app.tenant_id / app.user_id, never inside a request'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN (SELECT u.id FROM app.users u WHERE u.auth_subject = p_auth_subject AND u.is_active);
END $$;
ALTER FUNCTION app.resolve_user_by_subject(text) OWNER TO app_security;
COMMENT ON FUNCTION app.resolve_user_by_subject(text) IS
  'Login helper: identity-provider subject -> user id (active users only); context-free transactions only.';

CREATE FUNCTION app.my_tenants()
RETURNS TABLE (tenant_id uuid, slug text, name text, role app.member_role, deployment_mode text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT t.id, t.slug, t.name, m.role, t.deployment_mode
  FROM app.tenant_memberships m
  JOIN app.tenants t ON t.id = m.tenant_id
  JOIN app.users   u ON u.id = m.user_id
  WHERE m.user_id = app.current_user_id() AND m.is_active AND t.is_active AND u.is_active
  ORDER BY t.name
$$;
ALTER FUNCTION app.my_tenants() OWNER TO app_security;
COMMENT ON FUNCTION app.my_tenants() IS 'Tenants of the context user (needs app.user_id only). The API picks one and sets app.tenant_id.';

CREATE FUNCTION app.next_po_number(p_tenant uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_num text; i int;
BEGIN
  IF p_tenant IS NULL OR p_tenant IS DISTINCT FROM app.current_tenant_id() THEN
    RAISE EXCEPTION 'PO numbers can only be allocated for the current tenant' USING ERRCODE = 'insufficient_privilege';
  END IF;
  FOR i IN 1..10000 LOOP
    UPDATE app.po_number_counters
       SET next_value = next_value + 1, updated_at = now()
     WHERE tenant_id = p_tenant
    RETURNING prefix || lpad((next_value - 1)::text, pad_width, '0') INTO v_num;   -- row lock serialises allocators
    IF NOT FOUND THEN
      RAISE EXCEPTION 'no PO number counter for tenant %', p_tenant USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
    -- Skip numbers already taken by manually-numbered (imported) folders.
    EXIT WHEN NOT EXISTS (SELECT 1 FROM app.purchase_orders WHERE tenant_id = p_tenant AND po_number = v_num);
  END LOOP;
  RETURN v_num;
END $$;
ALTER FUNCTION app.next_po_number(uuid) OWNER TO app_security;

SET ROLE app_owner;

-- =============================================================================
-- §11 TRIGGER FUNCTIONS
-- -----------------------------------------------------------------------------
--  RLS says WHO may touch a row; triggers say WHAT a change means (state
--  machine, stamping, inheritance, immutability). The role matrix is therefore
--  enforced twice on purpose: a policy failure yields "0 rows" or 42501 without
--  detail, a trigger failure yields a precise message. Both are tested.
--
--  SQLSTATE conventions (so the app and the tests can react precisely):
--    42501 insufficient_privilege            role / attestation / append-only
--    55000 object_not_in_prerequisite_state  closed folder, not ready, bad transition, legal hold, last owner
--    23514 check_violation                   data-shape rules (reversal shape, party flags, ceiling, ...)
--    23503 foreign_key_violation             referenced row not found in this tenant / not visible
-- =============================================================================

-- 11.1 generic ------------------------------------------------------------------
CREATE FUNCTION app.tg_tenant_scoped_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id <> OLD.id THEN
    RAISE EXCEPTION '%.id is immutable', TG_TABLE_NAME USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.tenant_id <> OLD.tenant_id THEN
    RAISE EXCEPTION '%.tenant_id is immutable', TG_TABLE_NAME USING ERRCODE = 'check_violation';
  END IF;
  NEW.created_at := OLD.created_at;
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Refuses UPDATE/DELETE/TRUNCATE for everyone, including the owner and superusers.
CREATE FUNCTION app.tg_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: % is not allowed (post a reversal / a new row instead)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'insufficient_privilege';
END $$;

-- A folder's or document's marking may not exceed the tenant's ceiling.
-- Reads the tenant row by the ROW's tenant_id (under the invoker's RLS): an
-- invisible tenant yields NULL and the write is refused, i.e. fail closed.
CREATE FUNCTION app.tg_check_marking_ceiling() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ceiling app.control_marking;
BEGIN
  SELECT max_control_marking INTO v_ceiling FROM app.tenants WHERE id = NEW.tenant_id;
  IF v_ceiling IS NULL THEN
    RAISE EXCEPTION 'tenant % is not visible in this context', NEW.tenant_id USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.control_marking > v_ceiling THEN
    RAISE EXCEPTION 'control marking % exceeds this tenant''s ceiling (%): this deployment may not store it',
      NEW.control_marking, v_ceiling USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

-- 11.2 tenants ------------------------------------------------------------------
-- Every tenant owns its own audit sequence, app.audit_seq_<tenant id without
-- dashes>, so audit_log.seq is a per-tenant ordinal and never a cluster-global
-- counter. The t10_after_insert trigger creates it (before t90_audit writes the
-- tenant's first audit row) through create_audit_sequence, which is SECURITY
-- DEFINER owned by app_owner (the schema owner: the only role that may create
-- objects in app) and executable by app_security / app_owner only (§15). It
-- does no reads: app_owner is under FORCE RLS and would see nothing anyway.
CREATE FUNCTION app.audit_sequence_name(p_tenant uuid)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT 'audit_seq_' || replace(p_tenant::text, '-', '')
$$;

CREATE FUNCTION app.create_audit_sequence(p_tenant uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_name text := app.audit_sequence_name(p_tenant);
BEGIN
  IF p_tenant IS NULL THEN
    RAISE EXCEPTION 'create_audit_sequence: a tenant id is required' USING ERRCODE = 'null_value_not_allowed';
  END IF;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS app.%I AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE', v_name);
  EXECUTE format('REVOKE ALL ON SEQUENCE app.%I FROM PUBLIC', v_name);
  EXECUTE format('GRANT USAGE ON SEQUENCE app.%I TO app_security', v_name);   -- tg_audit (app_security) calls nextval
  EXECUTE format('COMMENT ON SEQUENCE app.%I IS %L', v_name,
                 'audit_log.seq allocator for tenant ' || p_tenant || ' (one per tenant: gaps never disclose other tenants'' activity)');
END $$;
COMMENT ON FUNCTION app.create_audit_sequence(uuid) IS
  'Operator/provisioning helper: creates the per-tenant audit_log.seq sequence (idempotent). Called by the tenants t10_after_insert trigger.';

CREATE FUNCTION app.tg_tenants_after_insert_setup() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM app.create_audit_sequence(NEW.id);
  RETURN NULL;
END $$;

CREATE FUNCTION app.tg_tenants_after_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO app.po_number_counters (tenant_id, prefix, pad_width)
  VALUES (NEW.id,
          COALESCE(NEW.settings ->> 'po_number_prefix', 'PO-'),
          COALESCE((NEW.settings ->> 'po_number_width')::int, 5));

  -- Default close-out checklist: the attestations the ledger math cannot make.
  -- Advisory by default (see 6.6); the owner marks items required.
  INSERT INTO app.close_checklist_templates (tenant_id, item_key, label, sort_order, is_required) VALUES
    (NEW.id, 'client_billing_final',  'Client invoicing is final: nothing further will be billed on this order',        10, false),
    (NEW.id, 'vendor_bills_complete', 'All vendor and freight bills have been received and posted',                    20, false),
    (NEW.id, 'commission_settled',    'Commission statement reconciled, or marked not applicable',                     30, false),
    (NEW.id, 'documents_attached',    'Client invoice, vendor invoices, remittances and freight bills are attached',   40, false),
    (NEW.id, 'paper_folder_archived', 'Physical folder scanned and archived',                                          50, false);
  RETURN NULL;
END $$;

CREATE FUNCTION app.tg_tenants_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_priv boolean := app.is_privileged_context();
BEGIN
  IF NEW.id <> OLD.id THEN
    RAISE EXCEPTION 'tenants.id is immutable' USING ERRCODE = 'check_violation';
  END IF;
  NEW.created_at := OLD.created_at;
  NEW.updated_at := now();
  IF NOT v_priv THEN
    IF NEW.is_active <> OLD.is_active THEN
      RAISE EXCEPTION 'tenant activation is an operator action' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NEW.max_control_marking <> OLD.max_control_marking THEN
      RAISE EXCEPTION 'the marking ceiling is an operator action (it decides where controlled data may live)'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF (NEW.name, NEW.slug, NEW.deployment_mode, NEW.settings, NEW.retention_years)
       IS DISTINCT FROM (OLD.name, OLD.slug, OLD.deployment_mode, OLD.settings, OLD.retention_years)
       AND NOT app.is_owner() THEN
      RAISE EXCEPTION 'only an owner may change tenant settings' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  -- Lowering the ceiling under existing rows would strand data: refuse (even for operators).
  IF NEW.max_control_marking < OLD.max_control_marking
     AND (EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = NEW.id AND p.control_marking > NEW.max_control_marking)
          OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = NEW.id AND d.control_marking > NEW.max_control_marking)) THEN
    RAISE EXCEPTION 'cannot lower the marking ceiling to %: rows above it exist', NEW.max_control_marking
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  RETURN NEW;
END $$;

-- 11.3 users --------------------------------------------------------------------
CREATE FUNCTION app.tg_users_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_priv boolean := app.is_privileged_context();
BEGIN
  NEW.email := lower(btrim(NEW.email));
  NEW.full_name := btrim(NEW.full_name);
  NEW.created_at := now();
  NEW.updated_at := now();
  IF NOT (v_priv OR app.can_manage_users()) THEN
    RAISE EXCEPTION 'only an owner or admin may create users' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.is_us_person THEN
    IF NOT (v_priv AND NEW.us_person_attested_by IS NOT NULL) THEN
      -- The attestation is stamped by the database from the context, never taken from the client.
      NEW.us_person_attested_by := app.current_user_id();
      NEW.us_person_attested_at := now();
    END IF;
    IF NEW.us_person_attested_by IS NULL THEN
      RAISE EXCEPTION 'US-person status must be attested by an identified owner/admin' USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSE
    NEW.us_person_attested_by := NULL;
    NEW.us_person_attested_at := NULL;
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION app.tg_users_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv   boolean := app.is_privileged_context();
  v_me     uuid    := app.current_user_id();
  v_tenant uuid    := app.current_tenant_id();
BEGIN
  IF NEW.id <> OLD.id THEN
    RAISE EXCEPTION 'users.id is immutable' USING ERRCODE = 'check_violation';
  END IF;
  NEW.email := lower(btrim(NEW.email));
  NEW.full_name := btrim(NEW.full_name);
  NEW.created_at := OLD.created_at;
  NEW.updated_at := now();

  IF NOT v_priv THEN
    IF (NEW.email <> OLD.email OR NEW.is_active <> OLD.is_active
        OR NEW.auth_subject IS DISTINCT FROM OLD.auth_subject) AND NOT app.can_manage_users() THEN
      RAISE EXCEPTION 'only an owner or admin may change e-mail, identity subject or active status' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  -- Deactivating the last active owner of the current tenant would lock it.
  IF OLD.is_active AND NOT NEW.is_active AND v_tenant IS NOT NULL
     AND EXISTS (SELECT 1 FROM app.tenant_memberships m
                  WHERE m.tenant_id = v_tenant AND m.user_id = NEW.id AND m.role = 'owner' AND m.is_active)
     AND NOT EXISTS (SELECT 1 FROM app.tenant_memberships m JOIN app.users u ON u.id = m.user_id
                      WHERE m.tenant_id = v_tenant AND m.user_id <> NEW.id AND m.role = 'owner' AND m.is_active AND u.is_active) THEN
    RAISE EXCEPTION 'cannot deactivate the last active owner of the tenant' USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;

  IF NEW.is_us_person IS DISTINCT FROM OLD.is_us_person
     OR NEW.us_person_basis IS DISTINCT FROM OLD.us_person_basis THEN
    IF v_priv AND NEW.us_person_attested_by IS NOT NULL
       AND (NEW.us_person_attested_by, NEW.us_person_attested_at)
           IS DISTINCT FROM (OLD.us_person_attested_by, OLD.us_person_attested_at) THEN
      NULL;   -- operator import supplied an explicit attester: keep it (CHECK still forbids self)
    ELSE
      IF NOT app.can_manage_users() THEN
        RAISE EXCEPTION 'only an owner or admin may change US-person status' USING ERRCODE = 'insufficient_privilege';
      END IF;
      IF v_me = NEW.id THEN
        RAISE EXCEPTION 'US-person status cannot be self-attested' USING ERRCODE = 'insufficient_privilege';
      END IF;
      NEW.us_person_attested_by := v_me;
      NEW.us_person_attested_at := now();
    END IF;
    IF NOT NEW.is_us_person THEN          -- revocation clears the attestation
      NEW.us_person_attested_by := NULL;
      NEW.us_person_attested_at := NULL;
    END IF;
  ELSE
    -- attestation columns are trigger-managed; silently keep them
    NEW.us_person_attested_by := OLD.us_person_attested_by;
    NEW.us_person_attested_at := OLD.us_person_attested_at;
  END IF;
  RETURN NEW;
END $$;

-- 11.4 tenant_memberships --------------------------------------------------------
CREATE FUNCTION app.tg_memberships_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_priv boolean := app.is_privileged_context();
BEGIN
  NEW.created_at := now();
  NEW.updated_at := now();
  IF v_priv THEN RETURN NEW; END IF;
  IF NOT app.can_manage_users() THEN
    RAISE EXCEPTION 'only an owner or admin may add members' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.role = 'owner' AND NOT app.is_owner() THEN
    RAISE EXCEPTION 'only an owner may grant the owner role' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.invited_by := app.current_user_id();
  RETURN NEW;
END $$;

CREATE FUNCTION app.tg_memberships_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_priv boolean := app.is_privileged_context();
BEGIN
  IF NEW.user_id <> OLD.user_id THEN
    RAISE EXCEPTION 'tenant_memberships.user_id is immutable' USING ERRCODE = 'check_violation';
  END IF;
  NEW.invited_by := OLD.invited_by;
  IF v_priv THEN RETURN NEW; END IF;
  IF NEW.user_id = app.current_user_id()
     AND (NEW.role <> OLD.role OR NEW.is_active <> OLD.is_active) THEN
    RAISE EXCEPTION 'you cannot change your own membership' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (NEW.role = 'owner' OR OLD.role = 'owner')
     AND (NEW.role <> OLD.role OR NEW.is_active <> OLD.is_active)
     AND NOT app.is_owner() THEN
    RAISE EXCEPTION 'only an owner may grant or revoke the owner role' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;

-- Last-owner protection: never demote, deactivate or remove the last active
-- owner of a tenant. Applies to operators too (add another owner first).
CREATE FUNCTION app.tg_memberships_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.role = 'owner' AND OLD.is_active
     AND (TG_OP = 'DELETE' OR NEW.role <> 'owner' OR NOT NEW.is_active) THEN
    IF NOT EXISTS (SELECT 1 FROM app.tenant_memberships m JOIN app.users u ON u.id = m.user_id
                    WHERE m.tenant_id = OLD.tenant_id AND m.id <> OLD.id
                      AND m.role = 'owner' AND m.is_active AND u.is_active) THEN
      RAISE EXCEPTION 'cannot remove, deactivate or demote the last active owner of a tenant'
        USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

-- 11.5 parties ------------------------------------------------------------------
CREATE FUNCTION app.tg_parties_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.name := btrim(NEW.name);
  NEW.created_by := CASE WHEN app.is_privileged_context()
                         THEN COALESCE(NEW.created_by, app.current_user_id())
                         ELSE app.current_user_id() END;
  NEW.created_at := now();
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE FUNCTION app.tg_parties_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.name := btrim(NEW.name);
  NEW.created_by := OLD.created_by;
  RETURN NEW;
END $$;

-- 11.6 purchase_orders -------------------------------------------------------------
CREATE FUNCTION app.tg_po_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_priv boolean := app.is_privileged_context();
BEGIN
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not create purchase orders', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.status <> 'open' THEN
    RAISE EXCEPTION 'a new purchase order starts open (import history through the normal lifecycle)'
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  NEW.po_number := NULLIF(btrim(COALESCE(NEW.po_number, '')), '');
  IF NEW.po_number IS NULL THEN
    NEW.po_number := app.next_po_number(NEW.tenant_id);
  END IF;
  NEW.title      := btrim(NEW.title);
  NEW.opened_at  := COALESCE(NEW.opened_at, now());          -- back-dating allowed for folder imports
  NEW.opened_by  := CASE WHEN v_priv THEN COALESCE(NEW.opened_by, app.current_user_id()) ELSE app.current_user_id() END;
  NEW.created_by := app.current_user_id();
  NEW.created_at := now();
  NEW.updated_at := now();
  -- lifecycle columns always start clean
  NEW.close_requested_at := NULL; NEW.close_requested_by := NULL;
  NEW.closed_at := NULL;          NEW.closed_by := NULL;
  NEW.close_signoff_note := NULL; NEW.close_override_reason := NULL;
  NEW.reopened_at := NULL;        NEW.reopened_by := NULL;
  NEW.reopen_reason := NULL;      NEW.reopen_count := 0;
  NEW.retain_until := NULL;
  IF NEW.legal_hold AND NOT (v_priv OR app.can_manage_lifecycle()) THEN
    RAISE EXCEPTION 'placing a legal hold requires a manager' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT NEW.legal_hold THEN NEW.legal_hold_reason := NULL; END IF;

  PERFORM app.assert_party_role(NEW.tenant_id, NEW.client_party_id, 'client');
  IF NEW.vendor_party_id IS NOT NULL THEN
    PERFORM app.assert_party_role(NEW.tenant_id, NEW.vendor_party_id, 'vendor');
  END IF;
  RETURN NEW;
END $$;

-- The state machine. open -> pending_close -> closed, with reopen; closed rows are
-- frozen (only the legal hold may move); closing requires ready_to_close or a
-- recorded management override; retain_until is stamped at close.
CREATE FUNCTION app.tg_po_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv  boolean := app.is_privileged_context();
  v_uid   uuid    := app.current_user_id();
  v_bal   record;
  v_years int;
BEGIN
  -- immutable provenance / trigger-managed columns
  NEW.created_by   := OLD.created_by;
  NEW.opened_by    := OLD.opened_by;
  NEW.retain_until := OLD.retain_until;
  NEW.updated_at   := now();

  IF NEW.po_number <> OLD.po_number AND NOT (v_priv OR app.can_manage_users()) THEN
    RAISE EXCEPTION 'only an owner or admin may renumber a purchase order' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF app.is_controlled(OLD.control_marking) AND NEW.control_marking <> OLD.control_marking
     AND NOT (v_priv OR app.can_manage_lifecycle()) THEN
    RAISE EXCEPTION 'changing a controlled marking (%) requires a manager', OLD.control_marking
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (NEW.legal_hold, NEW.legal_hold_reason) IS DISTINCT FROM (OLD.legal_hold, OLD.legal_hold_reason) THEN
    IF NOT (v_priv OR app.can_manage_lifecycle()) THEN
      RAISE EXCEPTION 'placing or lifting a legal hold requires a manager' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NOT NEW.legal_hold THEN NEW.legal_hold_reason := NULL; END IF;
  END IF;
  IF NEW.client_party_id <> OLD.client_party_id THEN
    PERFORM app.assert_party_role(NEW.tenant_id, NEW.client_party_id, 'client');
  END IF;
  IF NEW.vendor_party_id IS DISTINCT FROM OLD.vendor_party_id AND NEW.vendor_party_id IS NOT NULL THEN
    PERFORM app.assert_party_role(NEW.tenant_id, NEW.vendor_party_id, 'vendor');
  END IF;

  -------------------------------------------------------------------- closed
  IF OLD.status = 'closed' THEN
    IF NEW.status = 'closed' THEN
      IF (to_jsonb(NEW) - ARRAY['updated_at', 'legal_hold', 'legal_hold_reason'])
         <> (to_jsonb(OLD) - ARRAY['updated_at', 'legal_hold', 'legal_hold_reason']) THEN
        RAISE EXCEPTION 'purchase order % is closed and read-only; reopen it first', OLD.po_number
          USING ERRCODE = 'object_not_in_prerequisite_state';
      END IF;
      RETURN NEW;
    ELSIF NEW.status = 'open' THEN                             -- reopen
      IF NOT (v_priv OR app.can_manage_lifecycle()) THEN
        RAISE EXCEPTION 'only a manager, admin or owner may reopen a purchase order' USING ERRCODE = 'insufficient_privilege';
      END IF;
      IF NULLIF(btrim(COALESCE(NEW.reopen_reason, '')), '') IS NULL THEN
        RAISE EXCEPTION 'reopening requires reopen_reason' USING ERRCODE = 'check_violation';
      END IF;
      NEW.reopened_at := now();
      NEW.reopened_by := v_uid;
      NEW.reopen_count := OLD.reopen_count + 1;
      NEW.closed_at := NULL;             NEW.closed_by := NULL;
      NEW.close_override_reason := NULL; NEW.close_signoff_note := NULL;
      NEW.close_requested_at := NULL;    NEW.close_requested_by := NULL;
      NEW.retain_until := NULL;
      RETURN NEW;
    ELSE
      RAISE EXCEPTION 'invalid status transition closed -> %', NEW.status USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
  END IF;

  ------------------------------------------------------ open / pending_close
  IF NEW.status = OLD.status THEN
    -- ordinary edit: lifecycle columns are trigger-managed, pin them (sign-off note may be drafted)
    NEW.close_requested_at := OLD.close_requested_at; NEW.close_requested_by := OLD.close_requested_by;
    NEW.closed_at := OLD.closed_at;                   NEW.closed_by := OLD.closed_by;
    NEW.close_override_reason := OLD.close_override_reason;
    NEW.reopened_at := OLD.reopened_at;               NEW.reopened_by := OLD.reopened_by;
    NEW.reopen_reason := OLD.reopen_reason;           NEW.reopen_count := OLD.reopen_count;
    RETURN NEW;
  END IF;

  IF OLD.status = 'open' AND NEW.status = 'pending_close' THEN          -- the sticky note
    NEW.close_requested_at := now();
    NEW.close_requested_by := v_uid;
  ELSIF OLD.status = 'pending_close' AND NEW.status = 'open' THEN       -- withdraw the request
    NEW.close_requested_at := NULL;
    NEW.close_requested_by := NULL;
  ELSIF NEW.status = 'closed' THEN                                      -- management sign-off
    IF NOT (v_priv OR app.can_manage_lifecycle()) THEN
      RAISE EXCEPTION 'only a manager, admin or owner may close a purchase order' USING ERRCODE = 'insufficient_privilege';
    END IF;
    SELECT * INTO v_bal FROM app.po_balances b WHERE b.tenant_id = OLD.tenant_id AND b.po_id = OLD.id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'balances for purchase order % are not available', OLD.po_number
        USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
    IF NOT v_bal.ready_to_close THEN
      IF NULLIF(btrim(COALESCE(NEW.close_override_reason, '')), '') IS NULL THEN
        RAISE EXCEPTION 'purchase order % is not ready to close (open client %, open vendor %, open freight %, open commission %, entries %, open required checklist items %); set close_override_reason to close it anyway',
          OLD.po_number, v_bal.open_client_balance, v_bal.open_vendor_balance, v_bal.open_freight_balance,
          v_bal.open_commission_balance, v_bal.entry_count, v_bal.open_required_items
          USING ERRCODE = 'object_not_in_prerequisite_state';
      END IF;
      NEW.close_override_reason := btrim(NEW.close_override_reason);
    ELSE
      NEW.close_override_reason := NULL;    -- non-null means "closed by override", nothing else
    END IF;
    NEW.closed_at := now();
    NEW.closed_by := v_uid;
    NEW.close_requested_at := OLD.close_requested_at;  -- keep who asked for the close
    NEW.close_requested_by := OLD.close_requested_by;
    SELECT retention_years INTO v_years FROM app.tenants t WHERE t.id = OLD.tenant_id;
    NEW.retain_until := CASE WHEN v_years IS NULL THEN NULL
                             ELSE (NEW.closed_at + make_interval(years => v_years))::date END;
  ELSE
    RAISE EXCEPTION 'invalid status transition % -> %', OLD.status, NEW.status USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;

  -- reopen bookkeeping never changes on these transitions
  NEW.reopened_at := OLD.reopened_at; NEW.reopened_by := OLD.reopened_by;
  NEW.reopen_reason := OLD.reopen_reason; NEW.reopen_count := OLD.reopen_count;
  RETURN NEW;
END $$;

-- Folders are never deleted by the app (no privilege, no policy). This guard
-- protects operator paths: never a closed folder (retention), never one on hold.
CREATE FUNCTION app.tg_po_before_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.legal_hold THEN
    RAISE EXCEPTION 'purchase order % is under legal hold', OLD.po_number USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  IF OLD.status = 'closed' THEN
    RAISE EXCEPTION 'purchase order % is closed and subject to retention; it cannot be deleted', OLD.po_number
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  RETURN OLD;
END $$;

-- 11.7 po_line_items ------------------------------------------------------------------
CREATE FUNCTION app.tg_line_items_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv   boolean := app.is_privileged_context();
  v_tenant uuid; v_po uuid; v_status app.po_status;
BEGIN
  IF TG_OP = 'DELETE' THEN v_tenant := OLD.tenant_id; v_po := OLD.po_id;
  ELSE                     v_tenant := NEW.tenant_id; v_po := NEW.po_id; END IF;
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not change line items', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT status INTO v_status FROM app.purchase_orders WHERE tenant_id = v_tenant AND id = v_po;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', v_po USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF v_status = 'closed' THEN
    RAISE EXCEPTION 'purchase order is closed; reopen it before changing line items' USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.po_id <> OLD.po_id THEN
      RAISE EXCEPTION 'line items cannot move between purchase orders' USING ERRCODE = 'check_violation';
    END IF;
    NEW.created_by := OLD.created_by;
  ELSE
    NEW.created_by := app.current_user_id();
    NEW.created_at := now();
    NEW.updated_at := now();
  END IF;
  NEW.description := btrim(NEW.description);
  IF NEW.vendor_party_id IS NOT NULL THEN
    PERFORM app.assert_party_role(v_tenant, NEW.vendor_party_id, 'vendor');
  END IF;
  IF NEW.tracking_carrier_party_id IS NOT NULL THEN
    PERFORM app.assert_party_role(v_tenant, NEW.tracking_carrier_party_id, 'carrier');
  END IF;
  RETURN NEW;
END $$;

-- 11.8 documents ------------------------------------------------------------------------
-- Marking inheritance: on filing (INSERT with po_id, or UPDATE that changes
-- po_id) the document's marking becomes GREATEST(own, folder's, superseded
-- version's). Moving a document OUT of a controlled folder is treated as a
-- marking change and needs a manager. Together these close the
-- "file an unmarked scan into an ITAR folder, refile it elsewhere, non-US user
-- sees it" path.
CREATE FUNCTION app.tg_documents_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv boolean := app.is_privileged_context();
  v_prev app.documents%ROWTYPE;
  v_po   app.purchase_orders%ROWTYPE;
BEGIN
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not upload documents', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.sha256      := lower(NEW.sha256);
  NEW.uploaded_by := CASE WHEN v_priv THEN COALESCE(NEW.uploaded_by, app.current_user_id()) ELSE app.current_user_id() END;
  NEW.uploaded_at := CASE WHEN v_priv THEN COALESCE(NEW.uploaded_at, now()) ELSE now() END;
  NEW.deleted_at  := NULL;
  NEW.deleted_by  := NULL;
  NEW.created_at  := now();
  NEW.updated_at  := now();
  IF NEW.supersedes_document_id IS NOT NULL THEN
    SELECT * INTO v_prev FROM app.documents WHERE tenant_id = NEW.tenant_id AND id = NEW.supersedes_document_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'superseded document % not found in this tenant (or not visible)', NEW.supersedes_document_id
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.po_id := COALESCE(NEW.po_id, v_prev.po_id);              -- a re-scan lands in the same folder
    IF v_prev.po_id IS NOT NULL AND v_prev.po_id IS DISTINCT FROM NEW.po_id THEN
      RAISE EXCEPTION 'a new document version must stay on the same purchase order' USING ERRCODE = 'check_violation';
    END IF;
    NEW.control_marking := GREATEST(NEW.control_marking, v_prev.control_marking);
  END IF;
  IF NEW.po_id IS NOT NULL THEN
    v_po := app.assert_folder_open(NEW.tenant_id, NEW.po_id, 'filing documents');
    NEW.control_marking := GREATEST(NEW.control_marking, v_po.control_marking);
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION app.tg_documents_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv   boolean := app.is_privileged_context();
  v_old_po app.purchase_orders%ROWTYPE;
  v_new_po app.purchase_orders%ROWTYPE;
  v_hold   boolean := false;
BEGIN
  -- The file is immutable; a corrected scan is a new row with supersedes_document_id.
  IF (NEW.storage_key, NEW.sha256, NEW.byte_size, NEW.mime_type, NEW.uploaded_by, NEW.uploaded_at)
     IS DISTINCT FROM (OLD.storage_key, OLD.sha256, OLD.byte_size, OLD.mime_type, OLD.uploaded_by, OLD.uploaded_at) THEN
    RAISE EXCEPTION 'document bytes and upload provenance are immutable; upload a new version' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.supersedes_document_id IS NOT NULL AND NEW.supersedes_document_id IS DISTINCT FROM OLD.supersedes_document_id THEN
    RAISE EXCEPTION 'the supersedes link is immutable' USING ERRCODE = 'check_violation';
  END IF;

  -- The folder it is filed in (must be visible; frozen once closed).
  IF OLD.po_id IS NOT NULL THEN
    SELECT * INTO v_old_po FROM app.purchase_orders WHERE tenant_id = OLD.tenant_id AND id = OLD.po_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', OLD.po_id USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_old_po.status = 'closed' THEN
      RAISE EXCEPTION 'purchase order % is closed; its documents are frozen (reopen it first)', v_old_po.po_number
        USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
    v_hold := v_old_po.legal_hold;
  END IF;

  -- Markings: anyone who can write may raise; changing a controlled one needs a manager.
  IF app.is_controlled(OLD.control_marking) AND NEW.control_marking <> OLD.control_marking
     AND NOT (v_priv OR app.can_manage_lifecycle()) THEN
    RAISE EXCEPTION 'changing a controlled marking (%) requires a manager', OLD.control_marking USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Refiling to another folder (or back to the inbox).
  IF NEW.po_id IS DISTINCT FROM OLD.po_id THEN
    IF EXISTS (SELECT 1 FROM app.ledger_entries l WHERE l.tenant_id = OLD.tenant_id AND l.document_id = OLD.id) THEN
      RAISE EXCEPTION 'document is referenced by ledger entries and cannot be moved to another purchase order'
        USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
    IF OLD.po_id IS NOT NULL AND app.is_controlled(v_old_po.control_marking)
       AND NOT (v_priv OR app.can_manage_lifecycle()) THEN
      RAISE EXCEPTION 'moving a document out of a % folder requires a manager', v_old_po.control_marking
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NEW.po_id IS NOT NULL THEN
      v_new_po := app.assert_folder_open(NEW.tenant_id, NEW.po_id, 'filing documents');
      NEW.control_marking := GREATEST(NEW.control_marking, v_new_po.control_marking);
      v_hold := v_hold OR v_new_po.legal_hold;
    END IF;
  ELSIF OLD.po_id IS NOT NULL THEN
    -- a filed document never carries less than its folder
    NEW.control_marking := GREATEST(NEW.control_marking, v_old_po.control_marking);
  END IF;

  -- soft delete / restore
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    IF v_hold THEN
      RAISE EXCEPTION 'the purchase order is under legal hold; its documents cannot be deleted' USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
    NEW.deleted_at := now();
    NEW.deleted_by := app.current_user_id();
  ELSIF NEW.deleted_at IS NULL AND OLD.deleted_at IS NOT NULL THEN
    IF NOT (v_priv OR app.can_manage_lifecycle()) THEN
      RAISE EXCEPTION 'restoring a deleted document requires a manager' USING ERRCODE = 'insufficient_privilege';
    END IF;
    NEW.deleted_by := NULL;
  ELSE
    NEW.deleted_at := OLD.deleted_at;
    NEW.deleted_by := OLD.deleted_by;
    -- a deleted document is frozen, except that its marking may still be raised
    IF OLD.deleted_at IS NOT NULL
       AND (to_jsonb(NEW) - ARRAY['updated_at', 'control_marking']) <> (to_jsonb(OLD) - ARRAY['updated_at', 'control_marking'])
    THEN
      RAISE EXCEPTION 'document is deleted; restore it before editing' USING ERRCODE = 'object_not_in_prerequisite_state';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- 11.9 ledger_entries  (the posting rules) -----------------------------------------------
CREATE FUNCTION app.tg_ledger_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv   boolean := app.is_privileged_context();
  v_orig   app.ledger_entries%ROWTYPE;
  v_status app.po_status;
  v_doc    record;
BEGIN
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not post ledger entries', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.created_by := app.current_user_id();
  NEW.created_at := now();
  NEW.entry_date := COALESCE(NEW.entry_date, CURRENT_DATE);

  ------------------------------------------------------------------ reversals
  IF NEW.kind = 'reversal' THEN
    IF NEW.reverses_entry_id IS NULL THEN
      RAISE EXCEPTION 'a reversal must reference the entry it reverses' USING ERRCODE = 'check_violation';
    END IF;
    SELECT * INTO v_orig FROM app.ledger_entries
     WHERE tenant_id = NEW.tenant_id AND id = NEW.reverses_entry_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'ledger entry % not found in this tenant (or not visible)', NEW.reverses_entry_id
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_orig.kind = 'reversal' THEN
      RAISE EXCEPTION 'a reversal cannot be reversed; post the original entry again' USING ERRCODE = 'check_violation';
    END IF;
    IF EXISTS (SELECT 1 FROM app.ledger_entries r WHERE r.tenant_id = NEW.tenant_id AND r.reverses_entry_id = v_orig.id) THEN
      RAISE EXCEPTION 'ledger entry % has already been reversed', v_orig.id USING ERRCODE = 'unique_violation';
    END IF;
    IF NEW.po_id IS NOT NULL AND NEW.po_id <> v_orig.po_id THEN
      RAISE EXCEPTION 'a reversal must stay on the same purchase order as the original' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.amount IS NOT NULL AND NEW.amount <> v_orig.amount THEN
      RAISE EXCEPTION 'a reversal must be for the full original amount (%); use credit_memo / adjustment for partial corrections', v_orig.amount
        USING ERRCODE = 'check_violation';
    END IF;
    -- everything else is copied from the original so the pair nets to exactly zero
    NEW.po_id                 := v_orig.po_id;
    NEW.side                  := v_orig.side;
    NEW.amount                := v_orig.amount;
    NEW.counterparty_party_id := v_orig.counterparty_party_id;
    NEW.reversed_kind         := v_orig.kind;
    NEW.reference             := COALESCE(NEW.reference, v_orig.reference);
    NEW.document_id           := COALESCE(NEW.document_id, v_orig.document_id);
    NEW.evidence_page         := CASE WHEN NEW.document_id = v_orig.document_id THEN COALESCE(NEW.evidence_page, v_orig.evidence_page)
                                      ELSE NEW.evidence_page END;
  ELSE
    IF NEW.reverses_entry_id IS NOT NULL OR NEW.reversed_kind IS NOT NULL THEN
      RAISE EXCEPTION 'only kind = reversal may reference another entry' USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  ---------------------------------------------------- the folder must be open
  SELECT status INTO v_status FROM app.purchase_orders WHERE tenant_id = NEW.tenant_id AND id = NEW.po_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', NEW.po_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF v_status = 'closed' THEN
    RAISE EXCEPTION 'purchase order is closed; reopen it before posting' USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  -- Share-lock the folder so a concurrent close (which re-reads the balances) serialises after us.
  PERFORM 1 FROM app.purchase_orders WHERE tenant_id = NEW.tenant_id AND id = NEW.po_id FOR SHARE;

  IF NEW.entry_date > CURRENT_DATE + 1 THEN
    RAISE EXCEPTION 'entry_date % is in the future', NEW.entry_date USING ERRCODE = 'check_violation';
  END IF;

  ------------------------------------------------------------ counterparty
  IF NEW.kind <> 'reversal' THEN
    IF NEW.counterparty_party_id IS NULL THEN
      IF NEW.kind <> 'adjustment' THEN
        RAISE EXCEPTION 'counterparty_party_id is required for %', NEW.kind USING ERRCODE = 'check_violation';
      END IF;
    ELSE
      PERFORM app.assert_party_role(NEW.tenant_id, NEW.counterparty_party_id,
        CASE NEW.side WHEN 'client' THEN 'client' WHEN 'vendor' THEN 'vendor'
                      WHEN 'freight' THEN 'freight' WHEN 'commission' THEN 'vendor' END);
    END IF;
  END IF;

  ---------------------------------------------------------- evidence document / page
  IF NEW.document_id IS NOT NULL THEN
    SELECT po_id, page_count INTO v_doc FROM app.documents
     WHERE tenant_id = NEW.tenant_id AND id = NEW.document_id AND deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'document % not found in this tenant (or deleted / not visible)', NEW.document_id USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_doc.po_id IS DISTINCT FROM NEW.po_id THEN
      RAISE EXCEPTION 'document % is not filed under this purchase order; attach it first', NEW.document_id USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.evidence_page IS NOT NULL AND v_doc.page_count IS NOT NULL AND NEW.evidence_page > v_doc.page_count THEN
      RAISE EXCEPTION 'evidence_page % exceeds the document''s page_count %', NEW.evidence_page, v_doc.page_count
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- 11.10 po_notes --------------------------------------------------------------------------
CREATE FUNCTION app.tg_notes_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT (app.is_privileged_context() OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not add notes', COALESCE(app.current_member_role()::text, 'none') USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM 1 FROM app.purchase_orders WHERE tenant_id = NEW.tenant_id AND id = NEW.po_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', NEW.po_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  NEW.created_by  := app.current_user_id();
  NEW.created_at  := now();
  NEW.updated_at  := now();
  NEW.resolved_at := NULL;
  NEW.resolved_by := NULL;
  RETURN NEW;
END $$;

CREATE FUNCTION app.tg_notes_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.po_id <> OLD.po_id THEN
    RAISE EXCEPTION 'notes cannot move between purchase orders' USING ERRCODE = 'check_violation';
  END IF;
  NEW.created_by := OLD.created_by;
  IF NEW.resolved_at IS NOT NULL AND OLD.resolved_at IS NULL THEN
    NEW.resolved_at := now();
    NEW.resolved_by := app.current_user_id();
  ELSIF NEW.resolved_at IS NULL AND OLD.resolved_at IS NOT NULL THEN
    NEW.resolved_by := NULL;
  ELSE
    NEW.resolved_at := OLD.resolved_at;
    NEW.resolved_by := OLD.resolved_by;
  END IF;
  RETURN NEW;
END $$;

-- 11.11 po_close_checklist_items --------------------------------------------------------------
CREATE FUNCTION app.tg_checklist_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv boolean := app.is_privileged_context();
  v_tenant uuid; v_po uuid; v_status app.po_status;
BEGIN
  IF TG_OP = 'DELETE' THEN v_tenant := OLD.tenant_id; v_po := OLD.po_id;
  ELSE                     v_tenant := NEW.tenant_id; v_po := NEW.po_id; END IF;
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not change the close-out checklist', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT status INTO v_status FROM app.purchase_orders WHERE tenant_id = v_tenant AND id = v_po;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order % not found in this tenant (or not visible)', v_po USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF v_status = 'closed' THEN
    RAISE EXCEPTION 'purchase order is closed; its checklist is frozen' USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.po_id <> OLD.po_id OR NEW.item_key <> OLD.item_key THEN
      RAISE EXCEPTION 'checklist item identity is immutable' USING ERRCODE = 'check_violation';
    END IF;
    -- definition is frozen once copied from the template; only completion and the note move
    NEW.label := OLD.label; NEW.is_required := OLD.is_required; NEW.sort_order := OLD.sort_order;
    IF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
      NEW.completed_at := now();
      NEW.completed_by := app.current_user_id();
    ELSIF NEW.completed_at IS NULL AND OLD.completed_at IS NOT NULL THEN
      NEW.completed_by := NULL;
    ELSE
      NEW.completed_at := OLD.completed_at;
      NEW.completed_by := OLD.completed_by;
    END IF;
  ELSE
    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.label := btrim(NEW.label);
    IF NEW.completed_at IS NOT NULL THEN
      NEW.completed_at := now();
      NEW.completed_by := app.current_user_id();
    ELSE
      NEW.completed_by := NULL;
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- 11.12 document_pages ------------------------------------------------------------------------
CREATE FUNCTION app.tg_document_pages_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT (app.is_privileged_context() OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not change document pages', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.document_id <> OLD.document_id OR NEW.page_number <> OLD.page_number THEN
      RAISE EXCEPTION 'a page belongs to its document; identity is immutable' USING ERRCODE = 'check_violation';
    END IF;
  ELSE
    PERFORM 1 FROM app.documents WHERE tenant_id = NEW.tenant_id AND id = NEW.document_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'document % not found in this tenant (or not visible)', NEW.document_id USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.created_at := now();
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END $$;

-- 11.13 extraction_jobs -----------------------------------------------------------------------
-- Phase 1 stores jobs; Phase 2 adds the state machine. What is fixed now: the
-- document must be visible, the reviewer is stamped from the context, and a
-- result may only be "applied" to the folder the document is filed in.
CREATE FUNCTION app.tg_extraction_jobs_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_doc_po uuid;
BEGIN
  IF NOT (app.is_privileged_context() OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not change extraction jobs', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.document_id <> OLD.document_id THEN
      RAISE EXCEPTION 'extraction_jobs.document_id is immutable' USING ERRCODE = 'check_violation';
    END IF;
    NEW.created_by := OLD.created_by;
    IF NEW.reviewed_at IS NOT NULL AND OLD.reviewed_at IS NULL THEN
      NEW.reviewed_at := now();
      NEW.reviewed_by := app.current_user_id();
    ELSIF NEW.reviewed_at IS NULL AND OLD.reviewed_at IS NOT NULL THEN
      NEW.reviewed_by := NULL;
    ELSE
      NEW.reviewed_at := OLD.reviewed_at;
      NEW.reviewed_by := OLD.reviewed_by;
    END IF;
  ELSE
    NEW.created_by := app.current_user_id();
    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.reviewed_at := NULL; NEW.reviewed_by := NULL; NEW.applied_po_id := NULL;
  END IF;
  SELECT po_id INTO v_doc_po FROM app.documents WHERE tenant_id = NEW.tenant_id AND id = NEW.document_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'document % not found in this tenant (or not visible)', NEW.document_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF NEW.applied_po_id IS NOT NULL AND NEW.applied_po_id IS DISTINCT FROM v_doc_po THEN
    RAISE EXCEPTION 'an extraction can only be applied to the purchase order its document is filed under' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

-- 11.14 security-definer trigger functions (owned by app_security) ----------------------------------
RESET ROLE;

-- Audit: every INSERT/UPDATE/DELETE on business tables. Runs with BYPASSRLS so it
-- can (a) write audit_log, on which app_user has no INSERT privilege, and (b)
-- resolve the folder's/document's marking for rows that inherit it. Each row
-- also records po_id / document_id so the SELECT policy can gate it against the
-- LIVE folder/document (a later marking change hides the history too).
CREATE FUNCTION app.tg_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_row_id uuid; v_tenant uuid; v_po uuid; v_doc uuid;
  v_marking app.control_marking := 'none'; v_m app.control_marking; v_changed text[]; v_role text;
  v_seqrel regclass; v_seq bigint;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN v_old := to_jsonb(OLD); END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN v_new := to_jsonb(NEW); END IF;
  v_row_id := COALESCE(v_new ->> 'id', v_old ->> 'id')::uuid;

  IF    TG_TABLE_NAME = 'tenants' THEN v_tenant := v_row_id;
  ELSIF TG_TABLE_NAME = 'users'   THEN
    -- global row: attributed to the acting tenant, or to the tenant being provisioned
    v_tenant := COALESCE(app.current_tenant_id(),
                         CASE WHEN current_setting('app.provisioning_tenant_id', true)
                                   ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                              THEN current_setting('app.provisioning_tenant_id', true)::uuid END);
  ELSE  v_tenant := COALESCE(v_new ->> 'tenant_id', v_old ->> 'tenant_id')::uuid;
  END IF;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'audit: a change to % needs a tenant context (SET LOCAL app.tenant_id)', TG_TABLE_NAME
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF TG_TABLE_NAME = 'purchase_orders' THEN
    v_po := v_row_id;
    v_marking := GREATEST(COALESCE((v_old ->> 'control_marking')::app.control_marking, 'none'),
                          COALESCE((v_new ->> 'control_marking')::app.control_marking, 'none'));
  ELSIF TG_TABLE_NAME = 'documents' THEN
    v_doc := v_row_id;
    v_po  := COALESCE(v_new ->> 'po_id', v_old ->> 'po_id')::uuid;
    v_marking := GREATEST(COALESCE((v_old ->> 'control_marking')::app.control_marking, 'none'),
                          COALESCE((v_new ->> 'control_marking')::app.control_marking, 'none'));
    -- a move between folders is as sensitive as the more restrictive of the two
    FOR v_m IN SELECT p.control_marking FROM app.purchase_orders p
                WHERE p.id IN ((v_old ->> 'po_id')::uuid, (v_new ->> 'po_id')::uuid) LOOP
      v_marking := GREATEST(v_marking, v_m);
    END LOOP;
  ELSIF TG_TABLE_NAME IN ('document_pages', 'extraction_jobs') THEN
    v_doc := COALESCE(v_new ->> 'document_id', v_old ->> 'document_id')::uuid;
    SELECT d.po_id, d.control_marking INTO v_po, v_m FROM app.documents d WHERE d.id = v_doc;
    v_marking := COALESCE(v_m, 'none');
    IF v_po IS NOT NULL THEN
      SELECT GREATEST(v_marking, p.control_marking) INTO v_marking FROM app.purchase_orders p WHERE p.id = v_po;
    END IF;
  ELSE
    v_po := COALESCE(v_new ->> 'po_id', v_old ->> 'po_id')::uuid;
    IF v_po IS NOT NULL THEN
      SELECT p.control_marking INTO v_m FROM app.purchase_orders p WHERE p.id = v_po;
      v_marking := COALESCE(v_m, 'none');
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    SELECT array_agg(n.key ORDER BY n.key) INTO v_changed
    FROM jsonb_each(v_new) n WHERE (v_old -> n.key) IS DISTINCT FROM n.value;
  END IF;

  v_role := current_setting('role', true);                 -- SET ROLE target, if any
  IF v_role IS NULL OR v_role IN ('', 'none') THEN v_role := session_user; END IF;

  -- seq comes from the tenant's own sequence (11.2). to_regclass() rather than a
  -- bare cast: a missing sequence fails with an operator-actionable message and
  -- no subtransaction is opened per audit row.
  v_seqrel := to_regclass(format('app.%I', app.audit_sequence_name(v_tenant)));
  IF v_seqrel IS NULL THEN
    RAISE EXCEPTION 'audit: tenant % has no audit sequence; an operator must run SELECT app.create_audit_sequence(%L)', v_tenant, v_tenant
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;
  v_seq := nextval(v_seqrel);

  INSERT INTO app.audit_log
    (seq, tenant_id, table_name, row_id, action, old_data, new_data, changed_columns, po_id, document_id, control_marking,
     actor_user_id, actor_role, actor_db_role, client_addr, tx_started_at)
  VALUES
    (v_seq, v_tenant, TG_TABLE_NAME, v_row_id, TG_OP::app.audit_action, v_old, v_new, v_changed, v_po, v_doc, v_marking,
     app.current_user_id(), app.current_member_role(), v_role, inet_client_addr(), transaction_timestamp());
  RETURN NULL;
END $$;
ALTER FUNCTION app.tg_audit() OWNER TO app_security;

-- New folder: copy the tenant's checklist template and record the creation in the history.
CREATE FUNCTION app.tg_po_after_insert() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  INSERT INTO app.po_close_checklist_items (tenant_id, po_id, item_key, label, sort_order, is_required)
  SELECT NEW.tenant_id, NEW.id, t.item_key, t.label, t.sort_order, t.is_required
  FROM app.close_checklist_templates t
  WHERE t.tenant_id = NEW.tenant_id AND t.is_active;

  INSERT INTO app.po_status_history (tenant_id, po_id, from_status, to_status, changed_by, reason)
  VALUES (NEW.tenant_id, NEW.id, NULL, NEW.status, app.current_user_id(), 'created');
  RETURN NULL;
END $$;
ALTER FUNCTION app.tg_po_after_insert() OWNER TO app_security;

-- Status change: write the sign-off record with a snapshot of balances + checklist.
-- Marking raised: raise the folder's documents with it (invariant: a filed
-- document never carries less than its folder).
CREATE FUNCTION app.tg_po_after_update() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO app.po_status_history
      (tenant_id, po_id, from_status, to_status, changed_by, reason, was_ready_to_close, balances, checklist)
    SELECT NEW.tenant_id, NEW.id, OLD.status, NEW.status, app.current_user_id(),
           CASE WHEN NEW.status = 'closed' THEN COALESCE(NEW.close_override_reason, NEW.close_signoff_note)
                WHEN OLD.status = 'closed' THEN NEW.reopen_reason
                ELSE NULL END,
           b.ready_to_close,
           to_jsonb(b),
           (SELECT jsonb_agg(jsonb_build_object('item_key', c.item_key, 'label', c.label, 'is_required', c.is_required,
                                                'completed_at', c.completed_at, 'completed_by', c.completed_by)
                             ORDER BY c.sort_order)
              FROM app.po_close_checklist_items c WHERE c.tenant_id = NEW.tenant_id AND c.po_id = NEW.id)
    FROM app.po_balances b
    WHERE b.tenant_id = NEW.tenant_id AND b.po_id = NEW.id;
  END IF;
  IF NEW.control_marking > OLD.control_marking THEN
    UPDATE app.documents d
       SET control_marking = NEW.control_marking
     WHERE d.tenant_id = NEW.tenant_id AND d.po_id = NEW.id AND d.control_marking < NEW.control_marking;
  END IF;
  RETURN NULL;
END $$;
ALTER FUNCTION app.tg_po_after_update() OWNER TO app_security;

-- =============================================================================
-- §12 TRIGGERS  (names carry an ordering prefix: same-event triggers fire alphabetically;
--               t00 guards, t10 housekeeping, t20 business rules, t30 ceiling, t90 audit, t95 derived rows)
-- =============================================================================
-- tenants  (t10_after_insert creates the tenant's audit sequence before t90_audit needs it)
CREATE TRIGGER t10_before_update BEFORE UPDATE ON app.tenants FOR EACH ROW EXECUTE FUNCTION app.tg_tenants_before_update();
CREATE TRIGGER t10_after_insert  AFTER  INSERT ON app.tenants FOR EACH ROW EXECUTE FUNCTION app.tg_tenants_after_insert_setup();
CREATE TRIGGER t95_after_insert  AFTER  INSERT ON app.tenants FOR EACH ROW EXECUTE FUNCTION app.tg_tenants_after_insert();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.tenants FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- users
CREATE TRIGGER t10_before_insert BEFORE INSERT ON app.users FOR EACH ROW EXECUTE FUNCTION app.tg_users_before_insert();
CREATE TRIGGER t10_before_update BEFORE UPDATE ON app.users FOR EACH ROW EXECUTE FUNCTION app.tg_users_before_update();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.users FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- tenant_memberships
CREATE TRIGGER t10_before_insert BEFORE INSERT ON app.tenant_memberships FOR EACH ROW EXECUTE FUNCTION app.tg_memberships_before_insert();
CREATE TRIGGER t10_common        BEFORE UPDATE ON app.tenant_memberships FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.tenant_memberships FOR EACH ROW EXECUTE FUNCTION app.tg_memberships_before_update();
CREATE TRIGGER t25_last_owner    BEFORE UPDATE OR DELETE ON app.tenant_memberships FOR EACH ROW EXECUTE FUNCTION app.tg_memberships_guard();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.tenant_memberships FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- parties
CREATE TRIGGER t10_common        BEFORE UPDATE ON app.parties FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.parties FOR EACH ROW EXECUTE FUNCTION app.tg_parties_before_insert();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.parties FOR EACH ROW EXECUTE FUNCTION app.tg_parties_before_update();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.parties FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- purchase_orders
CREATE TRIGGER t10_common        BEFORE UPDATE ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_po_before_insert();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_po_before_update();
CREATE TRIGGER t20_before_delete BEFORE DELETE ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_po_before_delete();
CREATE TRIGGER t30_ceiling       BEFORE INSERT OR UPDATE OF control_marking ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_check_marking_ceiling();
CREATE TRIGGER t95_after_insert  AFTER  INSERT ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_po_after_insert();
CREATE TRIGGER t95_after_update  AFTER  UPDATE ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_po_after_update();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.purchase_orders FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- po_line_items
CREATE TRIGGER t10_common BEFORE UPDATE ON app.po_line_items FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_guard  BEFORE INSERT OR UPDATE OR DELETE ON app.po_line_items FOR EACH ROW EXECUTE FUNCTION app.tg_line_items_guard();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.po_line_items FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- documents (ceiling runs after inheritance: t30 > t20)
CREATE TRIGGER t10_common        BEFORE UPDATE ON app.documents FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.documents FOR EACH ROW EXECUTE FUNCTION app.tg_documents_before_insert();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.documents FOR EACH ROW EXECUTE FUNCTION app.tg_documents_before_update();
CREATE TRIGGER t30_ceiling       BEFORE INSERT OR UPDATE ON app.documents FOR EACH ROW EXECUTE FUNCTION app.tg_check_marking_ceiling();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.documents FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- document_pages / extraction_jobs
CREATE TRIGGER t10_common BEFORE UPDATE ON app.document_pages FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_guard  BEFORE INSERT OR UPDATE OR DELETE ON app.document_pages FOR EACH ROW EXECUTE FUNCTION app.tg_document_pages_guard();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.document_pages FOR EACH ROW EXECUTE FUNCTION app.tg_audit();
CREATE TRIGGER t10_common BEFORE UPDATE ON app.extraction_jobs FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_guard  BEFORE INSERT OR UPDATE OR DELETE ON app.extraction_jobs FOR EACH ROW EXECUTE FUNCTION app.tg_extraction_jobs_guard();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.extraction_jobs FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- ledger_entries (append-only)
CREATE TRIGGER t00_append_only   BEFORE UPDATE OR DELETE ON app.ledger_entries FOR EACH ROW EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t00_no_truncate   BEFORE TRUNCATE ON app.ledger_entries FOR EACH STATEMENT EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.ledger_entries FOR EACH ROW EXECUTE FUNCTION app.tg_ledger_before_insert();
CREATE TRIGGER t90_audit AFTER INSERT ON app.ledger_entries FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- po_notes
CREATE TRIGGER t10_common        BEFORE UPDATE ON app.po_notes FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.po_notes FOR EACH ROW EXECUTE FUNCTION app.tg_notes_before_insert();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.po_notes FOR EACH ROW EXECUTE FUNCTION app.tg_notes_before_update();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.po_notes FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- po_close_checklist_items
CREATE TRIGGER t10_common BEFORE UPDATE ON app.po_close_checklist_items FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_guard  BEFORE INSERT OR UPDATE OR DELETE ON app.po_close_checklist_items FOR EACH ROW EXECUTE FUNCTION app.tg_checklist_guard();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.po_close_checklist_items FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- close_checklist_templates
CREATE TRIGGER t10_common BEFORE UPDATE ON app.close_checklist_templates FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.close_checklist_templates FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

-- append-only logs
CREATE TRIGGER t00_append_only BEFORE UPDATE OR DELETE ON app.po_status_history FOR EACH ROW EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t00_no_truncate BEFORE TRUNCATE ON app.po_status_history FOR EACH STATEMENT EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t00_append_only BEFORE UPDATE OR DELETE ON app.audit_log FOR EACH ROW EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t00_no_truncate BEFORE TRUNCATE ON app.audit_log FOR EACH STATEMENT EXECUTE FUNCTION app.tg_append_only();

SET ROLE app_owner;

-- =============================================================================
-- §13 VIEWS + SEARCH
-- -----------------------------------------------------------------------------
--  security_invoker : the caller's RLS applies to every base table, so a
--                     controlled folder is absent from these views for non-US users.
--  security_barrier : a caller's own (possibly leaky) function in a WHERE clause
--                     cannot be pushed below the RLS-filtered scan.
-- =============================================================================

-- 13.1 po_balances: the paper top sheet, derived from the ledger alone.
--   billed_to_client      = client-side accruals (invoices + adjustments - credit memos, net of reversals)
--   received_from_client  = client-side cash
--   open_client_balance   = billed_to_client - received_from_client        (0 => client is settled)
--   ... same shape for vendor, freight and commission ...
--   gross_margin          = billed_to_client - billed_by_vendors - freight + commission
--   is_balanced           = at least one entry and every open balance is 0
--   ready_to_close        = is_balanced AND every REQUIRED checklist item is complete
CREATE VIEW app.po_balances WITH (security_invoker = true, security_barrier = true) AS
WITH led AS (
  SELECT tenant_id, po_id,
         COALESCE( SUM(signed_amount) FILTER (WHERE side = 'client'     AND flow = 'accrual'), 0) AS billed_to_client,
         COALESCE(-SUM(signed_amount) FILTER (WHERE side = 'client'     AND flow = 'cash'),    0) AS received_from_client,
         COALESCE( SUM(signed_amount) FILTER (WHERE side = 'vendor'     AND flow = 'accrual'), 0) AS billed_by_vendors,
         COALESCE(-SUM(signed_amount) FILTER (WHERE side = 'vendor'     AND flow = 'cash'),    0) AS paid_to_vendors,
         COALESCE( SUM(signed_amount) FILTER (WHERE side = 'freight'    AND flow = 'accrual'), 0) AS freight,
         COALESCE(-SUM(signed_amount) FILTER (WHERE side = 'freight'    AND flow = 'cash'),    0) AS freight_paid,
         COALESCE( SUM(signed_amount) FILTER (WHERE side = 'commission' AND flow = 'accrual'), 0) AS commission,
         COALESCE(-SUM(signed_amount) FILTER (WHERE side = 'commission' AND flow = 'cash'),    0) AS commission_received,
         COUNT(*)        AS entry_count,
         MAX(entry_date) AS last_entry_date
  FROM app.ledger_entries
  GROUP BY tenant_id, po_id
), chk AS (
  SELECT tenant_id, po_id,
         COUNT(*) FILTER (WHERE is_required AND completed_at IS NULL) AS open_required_items,
         COUNT(*) FILTER (WHERE completed_at IS NULL)                 AS open_items,
         COUNT(*)                                                     AS total_items
  FROM app.po_close_checklist_items
  GROUP BY tenant_id, po_id
), base AS (
  SELECT p.tenant_id, p.id AS po_id, p.po_number, p.status, p.control_marking, p.legal_hold, p.retain_until,
         COALESCE(l.billed_to_client,     0)::numeric(14,2) AS billed_to_client,
         COALESCE(l.received_from_client, 0)::numeric(14,2) AS received_from_client,
         COALESCE(l.billed_by_vendors,    0)::numeric(14,2) AS billed_by_vendors,
         COALESCE(l.paid_to_vendors,      0)::numeric(14,2) AS paid_to_vendors,
         COALESCE(l.freight,              0)::numeric(14,2) AS freight,
         COALESCE(l.freight_paid,         0)::numeric(14,2) AS freight_paid,
         COALESCE(l.commission,           0)::numeric(14,2) AS commission,
         COALESCE(l.commission_received,  0)::numeric(14,2) AS commission_received,
         COALESCE(l.entry_count, 0)                         AS entry_count,
         l.last_entry_date,
         COALESCE(c.open_required_items, 0)                 AS open_required_items,
         COALESCE(c.open_items, 0)                          AS open_items,
         COALESCE(c.total_items, 0)                         AS total_items
  FROM app.purchase_orders p
  LEFT JOIN led l ON l.tenant_id = p.tenant_id AND l.po_id = p.id
  LEFT JOIN chk c ON c.tenant_id = p.tenant_id AND c.po_id = p.id
), calc AS (
  SELECT base.*,
         (billed_to_client  - received_from_client)::numeric(14,2)                    AS open_client_balance,
         (billed_by_vendors - paid_to_vendors)::numeric(14,2)                         AS open_vendor_balance,
         (freight           - freight_paid)::numeric(14,2)                            AS open_freight_balance,
         (commission        - commission_received)::numeric(14,2)                     AS open_commission_balance,
         (billed_to_client - billed_by_vendors - freight + commission)::numeric(14,2) AS gross_margin,
         (open_required_items = 0)                                                    AS checklist_complete
  FROM base
), flags AS (
  SELECT calc.*,
         (entry_count > 0
          AND open_client_balance = 0 AND open_vendor_balance = 0
          AND open_freight_balance = 0 AND open_commission_balance = 0) AS is_balanced
  FROM calc
)
SELECT flags.*, (is_balanced AND checklist_complete) AS ready_to_close
FROM flags;
COMMENT ON VIEW app.po_balances IS 'Derived balances per PO (the paper top sheet). ready_to_close gates the close transition.';

-- 13.2 po_ledger: entries with their reversal status and counterparty name.
CREATE VIEW app.po_ledger WITH (security_invoker = true, security_barrier = true) AS
SELECT l.id, l.tenant_id, l.po_id, l.entry_date, l.kind, l.side, l.flow, l.amount, l.signed_amount,
       l.counterparty_party_id, cp.name AS counterparty_name, l.reference, l.document_id, l.evidence_page, l.memo,
       l.reverses_entry_id, l.reversed_kind,
       r.id IS NOT NULL   AS is_reversed,
       r.id               AS reversed_by_entry_id,
       r.created_at       AS reversed_at,
       l.created_by, l.created_at
FROM app.ledger_entries l
LEFT JOIN app.ledger_entries r  ON r.tenant_id  = l.tenant_id AND r.reverses_entry_id = l.id
LEFT JOIN app.parties        cp ON cp.tenant_id = l.tenant_id AND cp.id = l.counterparty_party_id;

-- 13.3 current_documents: not superseded, not soft-deleted (what the folder view lists).
CREATE VIEW app.current_documents WITH (security_invoker = true, security_barrier = true) AS
SELECT d.*
FROM app.documents d
WHERE d.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM app.documents n WHERE n.tenant_id = d.tenant_id AND n.supersedes_document_id = d.id);

-- 13.4 po_folder: the folder tab + top sheet in one row, for lists and the folder header.
CREATE VIEW app.po_folder WITH (security_invoker = true, security_barrier = true) AS
SELECT p.id AS po_id, p.tenant_id, p.po_number, p.client_order_number,
       c.name AS client_name, v.name AS vendor_name, p.title, p.status, p.control_marking,
       p.opened_at, p.close_requested_at, p.closed_at, p.closed_by, p.close_override_reason, p.reopen_count,
       p.legal_hold, p.retain_until,
       b.billed_to_client, b.received_from_client, b.billed_by_vendors, b.paid_to_vendors,
       b.freight, b.freight_paid, b.commission, b.commission_received, b.gross_margin,
       b.open_client_balance, b.open_vendor_balance, b.open_freight_balance, b.open_commission_balance,
       b.entry_count, b.last_entry_date, b.open_required_items, b.checklist_complete, b.is_balanced, b.ready_to_close,
       (SELECT count(*) FROM app.po_notes n
         WHERE n.tenant_id = p.tenant_id AND n.po_id = p.id AND n.kind = 'sticky' AND n.resolved_at IS NULL) AS open_stickies,
       (SELECT count(*) FROM app.current_documents d
         WHERE d.tenant_id = p.tenant_id AND d.po_id = p.id) AS document_count
FROM app.purchase_orders p
JOIN app.parties c       ON c.tenant_id = p.tenant_id AND c.id = p.client_party_id
LEFT JOIN app.parties v  ON v.tenant_id = p.tenant_id AND v.id = p.vendor_party_id
JOIN app.po_balances b   ON b.tenant_id = p.tenant_id AND b.po_id = p.id;

-- 13.5 search: fuzzy (pg_trgm word similarity: "does the query resemble a word
-- or phrase inside the text") over what people typed in, plus OCR text once
-- Phase 2 fills it. SECURITY INVOKER on purpose: it runs under the caller's
-- RLS, so it can neither leak another tenant nor a controlled folder. No fixed
-- search_path because the trigram operators live wherever the extension was
-- installed (public here, extensions on Supabase). The <% operator uses the
-- gin_trgm_ops indexes of §7.
CREATE FUNCTION app.search_purchase_orders(p_query text, p_limit int DEFAULT 25)
RETURNS TABLE (po_id uuid, po_number text, title text, score real)
LANGUAGE sql STABLE AS $$
  WITH hits AS (
    SELECT p.id AS po_id,
           greatest(word_similarity(p_query, p.title), word_similarity(p_query, p.po_number),
                    word_similarity(p_query, coalesce(p.client_order_number, ''))) AS score
    FROM app.purchase_orders p
    WHERE p_query <% p.title OR p_query <% p.po_number OR p_query <% coalesce(p.client_order_number, '')
    UNION ALL
    SELECT n.po_id, word_similarity(p_query, n.body) FROM app.po_notes n WHERE p_query <% n.body
    UNION ALL
    SELECT d.po_id, word_similarity(p_query, coalesce(d.title, '') || ' ' || coalesce(d.original_filename, ''))
    FROM app.documents d
    WHERE d.po_id IS NOT NULL AND d.deleted_at IS NULL
      AND (p_query <% coalesce(d.title, '') OR p_query <% coalesce(d.original_filename, ''))
    UNION ALL
    SELECT d.po_id, word_similarity(p_query, pg.ocr_text)
    FROM app.document_pages pg JOIN app.documents d ON d.tenant_id = pg.tenant_id AND d.id = pg.document_id
    WHERE d.po_id IS NOT NULL AND p_query <% pg.ocr_text
    UNION ALL
    SELECT l.po_id, word_similarity(p_query, coalesce(l.memo, '') || ' ' || coalesce(l.reference, ''))
    FROM app.ledger_entries l
    WHERE p_query <% coalesce(l.memo, '') OR p_query <% coalesce(l.reference, '')
  )
  SELECT p.id, p.po_number, p.title, max(h.score)::real
  FROM hits h JOIN app.purchase_orders p ON p.id = h.po_id
  GROUP BY p.id, p.po_number, p.title
  ORDER BY max(h.score) DESC, p.po_number
  LIMIT p_limit
$$;

-- =============================================================================
-- §14 ROW-LEVEL SECURITY
-- -----------------------------------------------------------------------------
--  Every table: ENABLE + FORCE. Policies are PERMISSIVE and per command, apply
--  to every role (no TO clause: app_owner is filtered like anyone else), and
--  use ONLY the helpers from §5/§8/§9, each wrapped in (SELECT ...) so it is
--  evaluated once per statement. Building blocks (spelled out in each policy):
--     T   tenant_id = (SELECT app.current_tenant_id())            row is in my tenant
--     M   (SELECT app.is_member())                                I have an active membership there
--     W/L/U (SELECT app.can_write()/can_manage_lifecycle()/can_manage_users())
--     VM  (SELECT app.visible_markings()) @> ARRAY[control_marking] marking is visible to me
--     VP  parent folder is visible to me (US person, or EXISTS on purchase_orders,
--         which itself runs under these policies => a controlled folder's children
--         vanish with it, through any join or view)
--     VD  parent document is visible to me (same pattern on documents)
--  RULE: every UPDATE policy repeats its role test in BOTH USING and WITH CHECK.
--  Permissive policies OR together; keeping the two clauses symmetric on every
--  table means a future policy can never let a row pass USING under one policy
--  and WITH CHECK under another.
--  With no context every helper is NULL/false, so nothing matches: fail closed.
-- =============================================================================

-- tenants ---------------------------------------------------------------------
ALTER TABLE app.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tenants FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.tenants FOR SELECT
  USING (id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member()));
CREATE POLICY p_update ON app.tenants FOR UPDATE
  USING      (id = (SELECT app.current_tenant_id()) AND (SELECT app.is_owner()))
  WITH CHECK (id = (SELECT app.current_tenant_id()) AND (SELECT app.is_owner()));
-- no INSERT/DELETE policy: tenants are created by app.bootstrap_tenant (operator), never deleted by the app

-- users -----------------------------------------------------------------------
-- Visible: myself, and people who share my current tenant. Editable: myself
-- (name), or anyone in my tenant if I am owner/admin (the trigger restricts what).
-- Created: only through app.add_member (app_user has no INSERT privilege, §15;
-- the INSERT policy below is belt and braces), so a direct INSERT cannot probe
-- the global e-mail key for other tenants' identities.
ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.users FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.users FOR SELECT
  USING ((SELECT app.is_member())
         AND (id = (SELECT app.current_user_id())
              OR EXISTS (SELECT 1 FROM app.tenant_memberships m
                          WHERE m.user_id = users.id AND m.tenant_id = (SELECT app.current_tenant_id()))));
CREATE POLICY p_insert ON app.users FOR INSERT
  WITH CHECK ((SELECT app.can_manage_users()));
CREATE POLICY p_update ON app.users FOR UPDATE
  USING      ((SELECT app.is_member())
              AND (id = (SELECT app.current_user_id())
                   OR ((SELECT app.can_manage_users())
                       AND EXISTS (SELECT 1 FROM app.tenant_memberships m
                                    WHERE m.user_id = users.id AND m.tenant_id = (SELECT app.current_tenant_id())))))
  WITH CHECK ((SELECT app.is_member())
              AND (id = (SELECT app.current_user_id())
                   OR ((SELECT app.can_manage_users())
                       AND EXISTS (SELECT 1 FROM app.tenant_memberships m
                                    WHERE m.user_id = users.id AND m.tenant_id = (SELECT app.current_tenant_id())))));
-- no DELETE: users are deactivated

-- tenant_memberships ------------------------------------------------------------
ALTER TABLE app.tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tenant_memberships FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.tenant_memberships FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member()));
CREATE POLICY p_insert ON app.tenant_memberships FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()));
CREATE POLICY p_update ON app.tenant_memberships FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()));
-- no DELETE: memberships are deactivated, never removed

-- parties -----------------------------------------------------------------------
ALTER TABLE app.parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.parties FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.parties FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member()));
CREATE POLICY p_insert ON app.parties FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()));
CREATE POLICY p_update ON app.parties FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()));
CREATE POLICY p_delete ON app.parties FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_lifecycle()));

-- po_number_counters: no policies => nobody but app.next_po_number (BYPASSRLS) ----
ALTER TABLE app.po_number_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_number_counters FORCE  ROW LEVEL SECURITY;

-- close_checklist_templates ---------------------------------------------------------
ALTER TABLE app.close_checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.close_checklist_templates FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.close_checklist_templates FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member()));
CREATE POLICY p_insert ON app.close_checklist_templates FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()));
CREATE POLICY p_update ON app.close_checklist_templates FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()));
CREATE POLICY p_delete ON app.close_checklist_templates FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_users()));

-- purchase_orders -------------------------------------------------------------------
-- Clerks may edit open/pending folders and may not produce a closed one;
-- managers and above may do anything the state machine allows.
ALTER TABLE app.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.purchase_orders FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.purchase_orders FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND (SELECT app.visible_markings()) @> ARRAY[control_marking]);
CREATE POLICY p_insert ON app.purchase_orders FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]);
CREATE POLICY p_update ON app.purchase_orders FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
              AND ((SELECT app.can_manage_lifecycle()) OR ((SELECT app.can_write()) AND status <> 'closed')))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
              AND ((SELECT app.can_manage_lifecycle()) OR ((SELECT app.can_write()) AND status <> 'closed')));
-- no DELETE policy (and no privilege): a folder created by mistake is closed with an override reason

-- po_line_items ---------------------------------------------------------------------
ALTER TABLE app.po_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_line_items FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.po_line_items FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_line_items.tenant_id AND p.id = po_line_items.po_id)));
CREATE POLICY p_insert ON app.po_line_items FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_line_items.tenant_id AND p.id = po_line_items.po_id)));
CREATE POLICY p_update ON app.po_line_items FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_line_items.tenant_id AND p.id = po_line_items.po_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_line_items.tenant_id AND p.id = po_line_items.po_id)));
CREATE POLICY p_delete ON app.po_line_items FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_line_items.tenant_id AND p.id = po_line_items.po_id)));

-- documents ------------------------------------------------------------------------------
-- Own marking must be visible AND (unfiled, or the folder is visible).
ALTER TABLE app.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.documents FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.documents FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
         AND (po_id IS NULL OR (SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = documents.tenant_id AND p.id = documents.po_id)));
CREATE POLICY p_insert ON app.documents FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
              AND (po_id IS NULL OR (SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = documents.tenant_id AND p.id = documents.po_id)));
CREATE POLICY p_update ON app.documents FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
              AND (po_id IS NULL OR (SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = documents.tenant_id AND p.id = documents.po_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
              AND (po_id IS NULL OR (SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = documents.tenant_id AND p.id = documents.po_id)));
-- no DELETE policy: documents are soft-deleted (deleted_at)

-- document_pages / extraction_jobs  (visible iff the document is) --------------------------
ALTER TABLE app.document_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.document_pages FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.document_pages FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = document_pages.tenant_id AND d.id = document_pages.document_id)));
CREATE POLICY p_insert ON app.document_pages FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = document_pages.tenant_id AND d.id = document_pages.document_id)));
CREATE POLICY p_update ON app.document_pages FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = document_pages.tenant_id AND d.id = document_pages.document_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = document_pages.tenant_id AND d.id = document_pages.document_id)));
CREATE POLICY p_delete ON app.document_pages FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = document_pages.tenant_id AND d.id = document_pages.document_id)));

ALTER TABLE app.extraction_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.extraction_jobs FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.extraction_jobs FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = extraction_jobs.tenant_id AND d.id = extraction_jobs.document_id)));
CREATE POLICY p_insert ON app.extraction_jobs FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = extraction_jobs.tenant_id AND d.id = extraction_jobs.document_id)));
CREATE POLICY p_update ON app.extraction_jobs FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = extraction_jobs.tenant_id AND d.id = extraction_jobs.document_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = extraction_jobs.tenant_id AND d.id = extraction_jobs.document_id)));
CREATE POLICY p_delete ON app.extraction_jobs FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_lifecycle())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = extraction_jobs.tenant_id AND d.id = extraction_jobs.document_id)));

-- ledger_entries  (SELECT + INSERT only; no UPDATE/DELETE policy exists) -------------------
ALTER TABLE app.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ledger_entries FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.ledger_entries FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = ledger_entries.tenant_id AND p.id = ledger_entries.po_id)));
CREATE POLICY p_insert ON app.ledger_entries FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = ledger_entries.tenant_id AND p.id = ledger_entries.po_id)));

-- po_notes -----------------------------------------------------------------------------------
-- Authors edit/delete their own notes; managers and above any note.
ALTER TABLE app.po_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_notes FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.po_notes FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_notes.tenant_id AND p.id = po_notes.po_id)));
CREATE POLICY p_insert ON app.po_notes FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_notes.tenant_id AND p.id = po_notes.po_id)));
CREATE POLICY p_update ON app.po_notes FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id())
              AND (((SELECT app.can_write()) AND created_by = (SELECT app.current_user_id())) OR (SELECT app.can_manage_lifecycle()))
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_notes.tenant_id AND p.id = po_notes.po_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id())
              AND (((SELECT app.can_write()) AND created_by = (SELECT app.current_user_id())) OR (SELECT app.can_manage_lifecycle()))
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_notes.tenant_id AND p.id = po_notes.po_id)));
CREATE POLICY p_delete ON app.po_notes FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id())
         AND (((SELECT app.can_write()) AND created_by = (SELECT app.current_user_id())) OR (SELECT app.can_manage_lifecycle()))
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_notes.tenant_id AND p.id = po_notes.po_id)));

-- po_close_checklist_items --------------------------------------------------------------------
ALTER TABLE app.po_close_checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_close_checklist_items FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.po_close_checklist_items FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_close_checklist_items.tenant_id AND p.id = po_close_checklist_items.po_id)));
CREATE POLICY p_insert ON app.po_close_checklist_items FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_close_checklist_items.tenant_id AND p.id = po_close_checklist_items.po_id)));
CREATE POLICY p_update ON app.po_close_checklist_items FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_close_checklist_items.tenant_id AND p.id = po_close_checklist_items.po_id)))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
              AND ((SELECT app.current_user_is_us_person())
                   OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_close_checklist_items.tenant_id AND p.id = po_close_checklist_items.po_id)));
CREATE POLICY p_delete ON app.po_close_checklist_items FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_lifecycle())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_close_checklist_items.tenant_id AND p.id = po_close_checklist_items.po_id)));

-- po_status_history  (read-only for the app; written by app.tg_po_after_* as app_security) ------
ALTER TABLE app.po_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_status_history FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.po_status_history FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
         AND ((SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_status_history.tenant_id AND p.id = po_status_history.po_id)));

-- audit_log  (owner/admin/manager/auditor; controlled rows gated like their folder AND document) --
ALTER TABLE app.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.audit_log FORCE  ROW LEVEL SECURITY;
CREATE POLICY p_select ON app.audit_log FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_read_audit())
         AND (SELECT app.visible_markings()) @> ARRAY[control_marking]
         AND (po_id IS NULL OR (SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = audit_log.tenant_id AND p.id = audit_log.po_id))
         AND (document_id IS NULL OR (SELECT app.current_user_is_us_person())
              OR EXISTS (SELECT 1 FROM app.documents d WHERE d.tenant_id = audit_log.tenant_id AND d.id = audit_log.document_id)));

-- =============================================================================
-- §15 GRANTS
-- -----------------------------------------------------------------------------
--  app_user gets exactly what the application needs; note in particular:
--    * no INSERT/UPDATE/DELETE on tenants (bootstrap function, owner-only UPDATE
--      on a few columns), no INSERT on users (app.add_member only), no DELETE on
--      purchase_orders / documents / users / memberships,
--    * ledger_entries: SELECT + INSERT only,
--    * audit_log / po_status_history: SELECT only,
--    * po_number_counters: nothing,
--    * app.bootstrap_tenant: NOT executable by app_user (operator action),
--    * column-level UPDATE on tenants / users / memberships so trigger-managed
--      and operator-only columns cannot even be named in an UPDATE.
--  app_owner gets EXECUTE on the helpers so that an owner-role query without
--  context fails closed with zero rows instead of "permission denied".
-- =============================================================================
RESET ROLE;

REVOKE ALL ON SCHEMA app FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO app_user, app_security;

-- functions ----------------------------------------------------------------------
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA app FROM PUBLIC;
-- pure math used by CHECKs / generated columns: evaluated as the writing user
GRANT EXECUTE ON FUNCTION
  app.ledger_sign(app.ledger_kind), app.ledger_flow_of(app.ledger_kind),
  app.ledger_side_allowed(app.ledger_kind, app.ledger_side), app.is_controlled(app.control_marking)
TO PUBLIC;
-- context / predicates / lookups / session bootstrap / allocator
GRANT EXECUTE ON FUNCTION
  app.current_tenant_id(), app.current_user_id(), app.is_privileged_context(), app.is_login_context(),
  app.audit_sequence_name(uuid), app.current_member_role(), app.current_user_is_us_person(),
  app.is_member(), app.is_owner(), app.can_manage_users(), app.can_manage_lifecycle(),
  app.can_write(), app.can_read_audit(), app.visible_markings(), app.marking_visible(app.control_marking),
  app.assert_party_role(uuid, uuid, text), app.assert_folder_open(uuid, uuid, text), app.next_po_number(uuid),
  app.add_member(text, text, app.member_role, uuid, text),
  app.resolve_user(text), app.resolve_user_by_subject(text), app.my_tenants(),
  app.search_purchase_orders(text, int)
TO app_user, app_security, app_owner;
-- tenant provisioning (and the per-tenant audit sequence it creates) is an operator action
GRANT EXECUTE ON FUNCTION
  app.bootstrap_tenant(text, text, text, text, uuid, uuid, text, app.control_marking, int, jsonb),
  app.create_audit_sequence(uuid)
TO app_owner, app_security;

-- tables: app_user --------------------------------------------------------------------
GRANT SELECT ON app.tenants TO app_user;
GRANT UPDATE (name, slug, deployment_mode, settings, retention_years) ON app.tenants TO app_user;

GRANT SELECT ON app.users TO app_user;            -- no INSERT: users are created through app.add_member only
GRANT UPDATE (email, full_name, auth_subject, is_active, is_us_person, us_person_basis) ON app.users TO app_user;

GRANT SELECT, INSERT ON app.tenant_memberships TO app_user;
GRANT UPDATE (role, is_active) ON app.tenant_memberships TO app_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON app.parties                  TO app_user;
GRANT SELECT, INSERT, UPDATE         ON app.purchase_orders          TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.po_line_items            TO app_user;
GRANT SELECT, INSERT, UPDATE         ON app.documents                TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.document_pages           TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.extraction_jobs          TO app_user;
GRANT SELECT, INSERT                 ON app.ledger_entries           TO app_user;   -- append-only
GRANT SELECT, INSERT, UPDATE, DELETE ON app.po_notes                 TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.po_close_checklist_items TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.close_checklist_templates TO app_user;
GRANT SELECT                         ON app.po_status_history        TO app_user;
GRANT SELECT                         ON app.audit_log                TO app_user;   -- append-only, trigger-written
GRANT SELECT ON app.po_balances, app.po_ledger, app.current_documents, app.po_folder TO app_user;

-- tables: app_security (only what its SECURITY DEFINER functions touch) ----------------
GRANT SELECT ON app.tenants, app.users, app.tenant_memberships, app.purchase_orders, app.documents,
                app.po_number_counters, app.ledger_entries, app.po_close_checklist_items,
                app.close_checklist_templates, app.po_balances
TO app_security;
GRANT INSERT ON app.tenants, app.users, app.tenant_memberships, app.po_number_counters,
                app.close_checklist_templates, app.po_close_checklist_items,
                app.po_status_history, app.audit_log
TO app_security;
GRANT UPDATE ON app.tenant_memberships, app.po_number_counters TO app_security;
GRANT UPDATE (control_marking, updated_at) ON app.documents TO app_security;   -- marking cascade in tg_po_after_update

-- Objects created later by app_owner / app_security default to no access for PUBLIC.
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner    IN SCHEMA app REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner    IN SCHEMA app REVOKE ALL ON SEQUENCES FROM PUBLIC;   -- the per-tenant audit sequences
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner    IN SCHEMA app REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_security IN SCHEMA app REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- =============================================================================
-- §16 SUPABASE  (not executed here; schema/supabase/0002_supabase.sql holds it)
-- -----------------------------------------------------------------------------
--   -- identity comes from the JWT instead of SET LOCAL:
--   CREATE OR REPLACE FUNCTION app.current_user_id() RETURNS uuid
--     LANGUAGE sql STABLE AS $$ SELECT auth.uid() $$;
--   CREATE OR REPLACE FUNCTION app.current_tenant_id() RETURNS uuid
--     LANGUAGE sql STABLE AS $$
--       SELECT CASE WHEN current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id'
--                        ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
--                   THEN (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id')::uuid END $$;
--   -- PostgREST executes as `authenticated` (NOINHERIT): give it app_user's privileges:
--   GRANT app_user TO authenticated WITH INHERIT TRUE;
--   -- keep app.users in step with auth.users (trigger on auth.users -> app.users, users.auth_subject = auth uid)
--   -- storage: documents.storage_key = '<bucket>/<object path>'; bucket policies mirror app.documents RLS
--  Nothing in the policies or triggers changes. On-prem keeps the SET LOCAL model.
-- =============================================================================

COMMIT;
