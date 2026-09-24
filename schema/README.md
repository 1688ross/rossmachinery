# PO Platform schema (Phase 1)

The database for the Ross Machinery Sales PO platform: one physical PO folder is one
`purchase_orders` row, and everything the office files into that folder (line items,
scans, money events, sticky notes, the close-out sign-off) hangs off it, isolated per
tenant, gated by export control, with an append-only ledger and an append-only audit log.

| path | what |
|---|---|
| `migrations/0001_init.sql` | the whole Phase 1 schema: roles, enums, tables, triggers, views, RLS policies, grants (one transaction, ~2 800 lines, 16 sections) |
| `tests/rls_tests.sql` | self-checking suite, 418 assertions (incl. one regression per red-team round-1 break), runs as the application role; every check prints `PASS:` or aborts |
| `tests/run_tests.sh` | CI gate: fresh database, apply migration, run suite, non-zero exit on failure |
| `supabase/0002_supabase.sql` | the Supabase adaptation (two functions + one grant); not applied by `run_tests.sh` |
| `tests/supabase_stub_check.sh` | proves `0002_supabase.sql` parses and behaves against a stub `auth` schema on plain Postgres |

Tested on PostgreSQL 16.13 (plain). Needs 15+ (`security_invoker` views). Extensions: `pgcrypto`, `pg_trgm` only.
Supabase itself has not been exercised; see [Supabase adaptation](#supabase-adaptation).

## 1. Apply and test

```bash
# fresh database + migration + 418 checks; exits non-zero on any failure
PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=... tests/run_tests.sh po_schema_test

# apply to a real database (as a superuser; the script SET ROLEs to app_owner itself)
psql -v ON_ERROR_STOP=1 -d po_platform -f migrations/0001_init.sql
```

`0001_init.sql` runs inside one transaction: either the whole schema exists or nothing does.
It is migration 0001; it is never re-run. Later migrations are additive (expand/contract).

The migration needs a **superuser** because it (a) creates `app_security` with `BYPASSRLS`
and (b) hands a few `SECURITY DEFINER` functions to that role. Roles are cluster-wide and
created with guards (`IF NOT EXISTS`), never dropped, so several databases can share one
cluster; the guard refuses to continue if `app_user`/`app_owner` turn out to be `SUPERUSER`
or `BYPASSRLS`, or if `app_security` can log in.

After the migration, an **operator** (not the application) provisions the tenant and its
first owner, and creates the login role the application connects with:

```sql
-- as postgres, or as a role that is a member of app_owner
SELECT app.bootstrap_tenant('Ross Machinery Sales', 'rms', 'owner@rossmachinery.example', 'Ross',
                            p_deployment_mode => 'onprem',      -- ceiling defaults to 'ear' (= any marking)
                            p_retention_years => 7);
CREATE ROLE po_api LOGIN PASSWORD '...';
GRANT app_user TO po_api;                 -- the API connects as po_api and inherits app_user's privileges
```

The owner then adds everybody else from inside the application (`app.add_member`, see the
[roles matrix](#4-roles-matrix)) and a second admin attests who is a US person. Two humans
are needed before anyone can see controlled rows; that is intended.

`tests/rls_tests.sql` inserts fixed ids, so it needs a fresh database every run;
`run_tests.sh` drops and re-creates the one you name (default `po_schema_test`). Keep it as
the CI gate for every change under `migrations/`.

## 2. Session-context contract

The database never learns who is asking from the connection. The application tells it,
per transaction:

```sql
BEGIN;
SET LOCAL app.tenant_id = '<tenant uuid>';
SET LOCAL app.user_id   = '<user uuid>';
-- ... statements ...
COMMIT;
```

* **Who sets them:** the API layer's request middleware, after it has authenticated the
  user with the identity provider (session / Keycloak / OIDC) and resolved which tenant the
  request is for (on-prem: the single tenant; hosted: the one the user picked from
  `app.my_tenants()`). Never from client-controlled input.
* **When:** inside every transaction, before the first statement that touches schema `app`.
  `SET LOCAL` dies with the transaction, so a pooled connection cannot carry one request's
  context into the next. Use transaction-mode pooling (PgBouncer `pool_mode = transaction`)
  or `DISCARD ALL` on release.
* **What the database trusts:** only the two ids. The user's role in that tenant, whether
  they are an attested US person, and therefore what they may do, are looked up from
  `tenant_memberships` / `users` by the database (`app.current_member_role()`,
  `app.current_user_is_us_person()`), not asserted by the app.
* **Fail closed:** a missing, empty or malformed setting makes `app.current_tenant_id()` /
  `app.current_user_id()` return `NULL`; every helper is then `NULL`/`false`, every `SELECT`
  returns zero rows and every write is refused (`42501`). A user who is not an *active*
  member of the asserted tenant, an inactive user, or an inactive tenant gets the same
  treatment. Malicious strings (`'DROP TABLE app.users; --'`) parse to `NULL`, not to an error.
* **Login path (plain Postgres):** before any context exists the API calls
  `app.resolve_user(email)` or `app.resolve_user_by_subject(idp_subject)` to get the user
  id, `SET LOCAL app.user_id`, then `app.my_tenants()` to list that user's tenants and
  `SET LOCAL app.tenant_id` for the chosen one. The two `resolve_*` helpers are `SECURITY
  DEFINER` and run **only in a context-free transaction** (`app.is_login_context()`): once
  `app.tenant_id` or `app.user_id` is set they raise `42501` whatever the argument, so nobody
  acting as a tenant user can turn an e-mail or IdP subject into somebody's identity from
  inside a request (tested, §21). In the login path itself the database has no caller to
  filter on: the API must pass only identities the IdP has verified, the same trust it is
  already given for `SET LOCAL`. `app.my_tenants()` returns only the context user's own
  memberships. See [cross-tenant identities](#6-cross-tenant-identities-users-are-global).

Policies reference **only** the helper functions in `§5`, `§8` and `§9` of the migration,
each wrapped as `(SELECT fn())` so the planner evaluates it once per statement as an
`InitPlan` (verified with `EXPLAIN`: three InitPlans plus one hashed sub-plan over the
visible folders for child tables). On Supabase the two context functions are redefined and
nothing else changes.

## 3. Roles and grants (database roles)

| role | attributes | purpose |
|---|---|---|
| `app_owner` | `NOLOGIN NOINHERIT NOBYPASSRLS` | owns schema `app` and every object; used for migrations and operator tasks only. `FORCE ROW LEVEL SECURITY` applies to it: without a context it sees zero rows (tested, §19). Owns one `SECURITY DEFINER` function, `app.create_audit_sequence` (DDL only: creates a tenant's audit sequence; executable by `app_security`/`app_owner`). |
| `app_user` | `NOLOGIN NOINHERIT NOBYPASSRLS` | the application's runtime role. A deployment creates a `LOGIN` role and `GRANT app_user TO it`. Cannot bypass RLS, cannot weaken the schema (tested, §20). |
| `app_security` | `NOLOGIN BYPASSRLS` | the only role that bypasses RLS. Logs in nowhere; owns exactly the `SECURITY DEFINER` functions that must read `tenant_memberships`/`users` without recursing into their own policies, write the append-only logs the app must not forge, and provision tenants. |

Table privileges of `app_user` (everything else is denied):

| table | SELECT | INSERT | UPDATE | DELETE | note |
|---|:-:|:-:|:-:|:-:|---|
| `tenants` | yes | | columns `name, slug, deployment_mode, settings, retention_years` | | created by `app.bootstrap_tenant` (operator); `is_active`, `max_control_marking` are operator-only |
| `users` | yes | **no** | columns `email, full_name, auth_subject, is_active, is_us_person, us_person_basis` | | created only through `app.add_member`; attestation columns are trigger-managed and not even grantable |
| `tenant_memberships` | yes | yes | columns `role, is_active` | | deactivated, never deleted |
| `parties` | yes | yes | yes | yes | |
| `purchase_orders` | yes | yes | yes | | never deleted by the app (closed with an override reason instead) |
| `po_line_items` | yes | yes | yes | yes | |
| `documents` | yes | yes | yes | | soft-deleted (`deleted_at`) |
| `document_pages`, `extraction_jobs` | yes | yes | yes | yes | Phase 2 hooks |
| `ledger_entries` | yes | yes | **no** | **no** | append-only; corrections are `reversal` rows |
| `po_notes`, `po_close_checklist_items`, `close_checklist_templates` | yes | yes | yes | yes | |
| `po_status_history`, `audit_log` | yes | **no** | **no** | **no** | written by `app_security` triggers only |
| `po_number_counters` | **no** | **no** | **no** | **no** | reachable only through `app.next_po_number()` |
| views `po_balances`, `po_ledger`, `po_folder`, `current_documents` | yes | | | | `security_invoker` + `security_barrier` |
| sequences `audit_seq_<tenant>` | **no** | | | | one per tenant, owned by `app_owner`; only `app_security` (the audit trigger) has `USAGE` |

`ledger_entries`, `po_status_history` and `audit_log` are append-only at **three** layers:
no privilege, no `UPDATE`/`DELETE` policy, and a `BEFORE UPDATE OR DELETE OR TRUNCATE`
trigger that refuses even the owner and superusers (tested, §18).

`app.bootstrap_tenant` and `app.create_audit_sequence` are executable by `app_owner` and
`app_security` only (and superusers); the application cannot mint tenants or sequences.
`app.add_member` is executable by `app_user`, checks the caller's membership role itself and
refuses (`23505`) to link an identity that already exists outside the caller's tenant
([cross-tenant identities](#6-cross-tenant-identities-users-are-global)).

## 4. Roles matrix

`tenant_memberships.role` is the source of truth. The matrix is enforced **twice on
purpose**: in RLS (a failure yields "0 rows" or `42501` without detail) and in the `BEFORE`
triggers (a failure yields a precise message). The test suite covers both paths.

| may ... | owner | admin | manager | clerk | viewer | auditor | test |
|---|:-:|:-:|:-:|:-:|:-:|:-:|---|
| read folders, lines, documents, pages, jobs, ledger, notes, parties, history | x | x | x | x | x | x | §6-§13 |
| read `audit_log` | x | x | x | | | x | §17 |
| create/edit parties; create/edit open folders, lines, documents, notes; post ledger entries; request close (`pending_close`) and withdraw it; tick checklist items; create pages / extraction jobs | x | x | x | x | | | §6-§12 |
| raise a marking (none/fci -> cui/itar/ear) | x | x | x | x (US only) | | | §13 |
| close a folder (needs `ready_to_close` or a recorded `close_override_reason`); reopen (needs `reopen_reason`) | x | x | x | | | | §12 |
| lower or change a controlled marking; move a document out of a controlled folder; restore a soft-deleted document; place/lift a legal hold; delete parties, checklist items, extraction jobs; edit/delete other people's notes | x | x | x | | | | §9b, §12, §13 |
| add members (`app.add_member`), deactivate users, change e-mail / `auth_subject`, attest US persons (never oneself), edit checklist templates, renumber a folder | x | x | | | | | §4 |
| grant or revoke the `owner` role; change tenant name/slug/settings/retention | x | | | | | | §4, §11 |
| change `tenants.is_active` or `tenants.max_control_marking`; create tenants | operator only (superuser / `app_owner` running `bootstrap_tenant`) | | | | | | §4, §18 |

Additional rules: nobody may change their own membership; the last active owner of a
tenant cannot be demoted, deactivated or removed, not even by an operator (§4, §18); a user
may always edit their own `full_name`; authors may edit and delete their own notes.

## 5. Export-control gating

* `control_marking` enum `none < fci < cui < itar < ear` on `purchase_orders` and `documents`.
  The order is a visibility lattice (`GREATEST()` = most restrictive), not a legal ranking.
* `users.is_us_person` is the gate. It can only be set to `true` by an owner/admin **of the
  same tenant, for somebody else**; the attester and time are stamped by the trigger and a
  `CHECK` forbids self-attestation. Revoking clears the attestation.
* For a user with `is_us_person = false`, rows marked `cui`, `itar` or `ear` **do not exist**:
  * `purchase_orders`, `documents`: their own marking is checked (`visible_markings()`).
  * Everything hanging off a folder (`po_line_items`, `ledger_entries`, `po_notes`,
    `po_close_checklist_items`, `po_status_history`) is visible only if the folder is, through
    an `EXISTS` on `purchase_orders` that itself runs under RLS. Pages and extraction jobs
    inherit visibility from their document the same way. Views are `security_invoker`, so
    joins and views cannot widen visibility (§13).
  * `audit_log` rows record the effective marking at write time **and** the folder / document
    they belong to, and are gated against the live folder and document. A non-US admin or
    auditor reads the audit log but sees no controlled row, title, memo or amount (§13).
  * Trigram search (`app.search_purchase_orders`) is `SECURITY INVOKER`, so it cannot leak either.
* Non-US persons cannot *create* controlled rows (`WITH CHECK`) or raise a folder into a
  marking they may not see.
* Documents inherit: on filing or refiling, `documents.control_marking` becomes
  `GREATEST(own, folder's, superseded version's)`; raising a folder's marking raises its
  documents; lowering never cascades. Moving a document **out** of a controlled folder is
  treated as a marking change and needs a manager, and the document keeps its marking
  after the move (so "file an unmarked scan into the ITAR folder, refile it elsewhere" cannot
  declassify anything, §9b). The audit rows of such a move carry the controlled marking.
* `fci` is contract-sensitive but not export-controlled: visible to everyone in the tenant.
* `tenants.max_control_marking` is the deployment ceiling. The hosted profile is provisioned
  with `fci` and therefore **cannot** store `cui/itar/ear` rows (trigger on folders and
  documents, §7); the on-prem profile gets `ear` (= everything). Only an operator can change
  it, and it cannot be lowered under existing rows (§18).

Known limit: a non-US person can infer that a controlled folder exists from a gap in the
PO numbering. If that matters, allocate a separate number series for controlled folders
(one line in `tg_po_before_insert`).

## 6. Cross-tenant identities (users are global)

`app.users` has one row per person (`email` and `auth_subject` are globally unique) so that
one person can belong to several tenants in the hosted edition. That makes the e-mail key a
global fact, and the schema guarantees that a tenant learns nothing about identities that
live outside it (tested, §21):

* `app.add_member(email, ...)` finds-or-creates by e-mail, but if the e-mail belongs to an
  existing user **with no membership in the caller's tenant** it refuses with `23505` and
  changes nothing: the other tenant's row is never attached and never becomes visible (no
  name, no id). Re-adding or re-activating someone who already belongs to the tenant works
  as before.
* `app_user` has **no `INSERT` on `users`**; `app.add_member` is the only way the app creates
  a person, so there is no direct-`INSERT` unique-key probe and no way to plant an orphan
  `users` row (with a chosen `auth_subject`) that another tenant might later link to.
* `app.resolve_user` / `app.resolve_user_by_subject` run only in a context-free transaction
  (the login path, [§2](#2-session-context-contract)); inside a request they raise before
  looking anything up.
* The `users` `SELECT` policy shows only yourself and the members of your current tenant.

What remains, and is documented rather than hidden: an **owner/admin** who tries to add an
e-mail that is registered elsewhere learns from the refusal that it *exists somewhere* on
the platform (the same is true of changing a user's e-mail into a taken one: `23505`), and
nothing else. Closing that last bit needs the consent-based invitation flow (invite by
opaque token, the invitee accepts after logging in) that belongs to the hosted edition; it
is moot for the single-tenant on-prem launch, where only one tenant exists.

Linking one person to a second tenant is therefore an **operator** action, done without a
request context so the audit row is attributed to the target tenant:

```sql
-- as postgres (or a member of app_owner), no SET LOCAL context
INSERT INTO app.tenant_memberships (tenant_id, user_id, role)
VALUES ('<tenant uuid>', app.resolve_user('person@other-tenant.example'), 'viewer');
```

`app.bootstrap_tenant` deliberately still reuses an existing identity for the new tenant's
owner (an operator provisioning a second company for the same person).

## 7. Audit log

`app.audit_log` is written only by `app.tg_audit` (`SECURITY DEFINER`, `app_security`), is
append-only at three layers (§3) and is gated like the rows it describes (§5). Two columns
are shaped by tenant isolation rather than convenience:

* **`seq` is a per-tenant ordinal, not a global identity.** Every tenant owns a sequence,
  `app.audit_seq_<tenant id without dashes>`, created by the `tenants` `t10_after_insert`
  trigger through `app.create_audit_sequence` (idempotent; `SECURITY DEFINER` owned by
  `app_owner`, the only role that may create objects in `app`; executable by
  `app_security`/`app_owner` only). `tg_audit` draws `seq` from it, and
  `UNIQUE (tenant_id, seq)` documents the contract. A tenant therefore sees `1..n` over its
  own `n` rows; a gap in *its* numbering can only come from its own rolled-back
  allocation or from a controlled row the reader may not see (the same known limit as the
  PO numbering gap in §5), never from another tenant's activity. `app_user` cannot read or
  advance the sequences. If a tenant ever lacks its sequence (it cannot happen through
  `bootstrap_tenant`), every audited write in that tenant fails closed with a message naming
  `SELECT app.create_audit_sequence('<tenant>')`.
* **`tx_started_at` groups the rows of one transaction** (`transaction_timestamp()`,
  server-assigned, not settable by the app). The transaction id was deliberately dropped:
  `pg_current_xact_id()` is a cluster-global counter and its gaps would have disclosed the
  write volume of every other tenant, and of every other database on the cluster. Rows of
  one transaction also share `statement_at` per statement; `created_at` (`clock_timestamp()`)
  orders rows within a statement.

Other columns: the full row before and after (`old_data`, `new_data`, `changed_columns`), the
folder/document the row belongs to and the effective marking at write time (for live gating),
the acting user, their membership role at the time, the database role and client address.

## 8. Retention and legal hold

`tenants.retention_years` (NULL = keep forever) is stamped into
`purchase_orders.retain_until` when a folder closes (`closed_at + retention`, both set by
the database, never by the client) and cleared on reopen. `legal_hold` (manager+, reason
required) is the only thing that may change on a closed folder; it blocks soft-deleting the
folder's documents and, together with `status = 'closed'`, blocks deleting the folder even
for an operator. Documents are never hard-deleted by the app; a purge job (Phase 2+) may
only touch rows past `retain_until` and not on hold.

## 9. Tenant isolation: composite foreign keys

Every tenant-scoped table has `tenant_id uuid NOT NULL REFERENCES app.tenants` and a
`UNIQUE (tenant_id, id)`; every child references its parent with
`FOREIGN KEY (tenant_id, parent_id) REFERENCES parent (tenant_id, id)`. The migration has no
single-column FK that points anywhere but `tenants` or `users` (asserted in §1).

Why composite keys and not triggers: **foreign-key checks bypass row-level security by
design**, so a plain `(po_id)` FK would happily accept a parent in another tenant even under
perfect RLS. The composite key makes "child and parent share a tenant" a declarative
invariant enforced by the constraint system for every code path including `SECURITY
DEFINER` functions and superusers (§18 proves it with RLS bypassed), needs no trigger
ordering, shows up in `pg_dump`, and is impossible to forget on the next table. Triggers are
reserved for what an FK cannot say: the party must be flagged as a client/vendor/carrier,
the folder must be open, the document must be filed under the same folder, the page must
exist.

## 10. The balances view, with a worked example

`app.po_balances` is the paper top sheet, derived from `ledger_entries` alone; nothing is
stored, so nothing can drift. Each entry has a positive `amount`, a `kind`, a `side` (which
column of the top sheet) and two **stored generated columns**: `signed_amount = amount x
sign(kind)` and `flow` (accrual or cash). A `reversal` copies the reversed entry and takes
the opposite sign.

| kind | side | sign | flow | meaning |
|---|---|:-:|---|---|
| `client_invoice` | client | +1 | accrual | we billed the client |
| `client_payment` | client | -1 | cash | the client paid |
| `vendor_bill` | vendor | +1 | accrual | the vendor billed us |
| `vendor_payment` | vendor or freight | -1 | cash | we paid the vendor / carrier |
| `freight_charge` | freight | +1 | accrual | a carrier or vendor billed freight |
| `commission_earned` | commission | +1 | accrual | commission due to us |
| `commission_received` | commission | -1 | cash | commission received |
| `credit_memo` | any | -1 | accrual | reduces the billed amount on its side (memo required) |
| `adjustment` | any | +1 | accrual | increases the billed amount on its side (memo required) |
| `reversal` | copied | flipped | copied | full-amount undo of one entry, once, never of a reversal (memo required) |

Per folder:

```
billed_to_client     = sum(signed_amount) where side = client     and flow = accrual
received_from_client = -sum(signed_amount) where side = client    and flow = cash
billed_by_vendors    = ... vendor / accrual          paid_to_vendors     = ... vendor / cash
freight              = ... freight / accrual         freight_paid        = ... freight / cash
commission           = ... commission / accrual      commission_received = ... commission / cash
open_client_balance     = billed_to_client - received_from_client      (and likewise for vendor, freight, commission)
gross_margin            = billed_to_client - billed_by_vendors - freight + commission
is_balanced             = entry_count > 0 and all four open balances = 0
checklist_complete      = no REQUIRED close-out checklist item is open
ready_to_close          = is_balanced and checklist_complete
```

Worked example (the suite's PO-00001, §10): invoice 100 000 to the client; payments 60 000
and 39 500 (keyed wrong), reversal of the 39 500, corrected payment 39 000; vendor bill
80 000 paid in full, a 10 adjustment and a 10 credit memo on it; freight 2 500 charged and
paid; commission 5 000 earned and received; a 1 000 goodwill credit memo to the client.

| bucket | value |
|---|---:|
| billed_to_client | 100 000 - 1 000 = **99 000** |
| received_from_client | 60 000 + 39 500 - 39 500 + 39 000 = **99 000** |
| billed_by_vendors / paid_to_vendors | 80 000 + 10 - 10 = 80 000 / 80 000 |
| freight / freight_paid | 2 500 / 2 500 |
| commission / commission_received | 5 000 / 5 000 |
| open balances | 0 / 0 / 0 / 0 |
| gross_margin | 99 000 - 80 000 - 2 500 + 5 000 = **21 500** |
| is_balanced | true (14 entries) |
| ready_to_close | false until the one required checklist item is ticked, then true |

`app.po_folder` joins the folder tab (client, vendor, title) to these figures plus open
sticky notes and current document count; `app.po_ledger` lists entries with their reversal
status and counterparty name.

## 11. Close-out lifecycle

`open -> pending_close` (any writer: the "please close" sticky note, stamps who/when) ->
`closed` (manager+; requires `ready_to_close`, or a non-empty `close_override_reason` which is
stored and shows up in the history with `was_ready_to_close = false`) -> `open` again
(manager+, `reopen_reason` required, increments `reopen_count`). Every transition is written
to append-only `po_status_history` with the actor, the reason and a JSONB snapshot of the
balances and the checklist: that is the management sign-off record. A closed folder is
frozen: header, lines, checklist, documents and ledger refuse changes; notes may still be
added; only the legal hold may move.

The close-out checklist (`close_checklist_templates` -> `po_close_checklist_items` copied at
folder creation) holds the attestations the ledger cannot make ("no more vendor bills are
coming"). The seeded items are **advisory** (`is_required = false`) so the backlog of paper
folders can be closed on the ledger math alone; an owner/admin flips the items the office
wants to be blocking (the suite does this for one item).

## 12. Supabase adaptation

Nothing in `0001_init.sql` references `auth.*`, `storage.*` or any Supabase-only object.
`supabase/0002_supabase.sql` (run after 0001, as the project's `postgres` role) does exactly
three things:

1. `CREATE OR REPLACE` the two context functions: `app.current_user_id()` returns `auth.uid()`,
   `app.current_tenant_id()` reads a `tenant_id` claim from `request.jwt.claims` (malformed or
   missing -> `NULL` -> zero rows, exactly like the on-prem path).
2. `GRANT app_user TO authenticated WITH INHERIT TRUE` (Supabase's `authenticated` is
   `NOINHERIT`; on PG15 use `ALTER ROLE authenticated INHERIT` or copy the grants).
3. Nothing else. There is deliberately **no trigger on `auth.users`**: a self-signed-up auth
   user has no tenant, and the audit log refuses to record a `users` row without one. The
   hosted edition is invite-first: the server invites through Supabase Auth
   (`auth.admin.inviteUserByEmail`), receives the new uid, and under the inviting
   owner/admin's JWT calls `app.add_member(email, name, role, uid, uid::text)` so that
   `app.users.id = auth.uid()` and `users.auth_subject = uid`. An auth user without an
   `app.users` row or membership is authenticated but sees nothing. If the invited e-mail
   already belongs to an `app.users` row from another tenant, `add_member` refuses (`23505`,
   [§6](#6-cross-tenant-identities-users-are-global)); the hosted edition's invitation flow,
   or an operator link, is needed for that case.

Prerequisites the migration cannot solve by itself, in the runbook order:

* `app_security` is created `WITH BYPASSRLS`. That needs a superuser on PostgreSQL 15, or a
  creator that itself has `BYPASSRLS` on 16+. Supabase's `postgres` is not a superuser; run
  the migration from the dashboard SQL editor and check the §1 guard passes, or ask support
  to create the role.
* `ALTER FUNCTION ... OWNER TO app_security` and `SET ROLE app_owner` need the running role to
  be a member of those roles. PG16 grants the creator `ADMIN OPTION` automatically; on PG15
  run `GRANT app_owner, app_security TO postgres` first.
* Storage: `documents.storage_key` is the object path inside a bucket; write bucket policies
  that mirror `app.documents` RLS (tenant and marking in the path or object metadata).
* Tenant provisioning (`app.bootstrap_tenant`) runs from the SQL editor with no JWT; the audit
  trigger then attributes the new owner's `users` row through `app.provisioning_tenant_id`,
  which only that function sets.

Status: **untested on Supabase.** `tests/supabase_stub_check.sh` applies 0001 + 0002 against
a stub `auth` schema on plain Postgres 16 and proves the JWT-driven context flows through the
unchanged policies (no JWT -> zero rows; owner claim -> owner; invite-first `add_member` ->
clerk sees the tenant; self-signed-up stranger -> nothing; malformed claim -> nothing). Real Supabase validation is a Phase 4 task, not needed for
the on-prem first customer.

## 13. Checklist: adding a new tenant-scoped table

1. Columns: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `tenant_id uuid NOT NULL
   REFERENCES app.tenants (id)`, `created_at/updated_at timestamptz`, money as `numeric`,
   never `float`; `UNIQUE (tenant_id, id)` if anything will ever reference it.
2. Parent links are **composite**: `FOREIGN KEY (tenant_id, parent_id) REFERENCES
   parent (tenant_id, id)`. Never a single-column FK to a tenant-scoped table (§1 of the suite
   fails otherwise).
3. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY; ALTER TABLE ... FORCE ROW LEVEL SECURITY;`
   (the suite asserts every table in `app` is enabled + forced).
4. Policies per command, using only the helpers, each wrapped as `(SELECT ...)`: tenant
   match `T`, membership `M` or role `W/L/U`, and the parent-visibility clause `VP`/`VD`
   (`current_user_is_us_person() OR EXISTS (parent under RLS)`) if the row belongs to a folder or
   document. Every `UPDATE` policy repeats its role test in **both** `USING` and `WITH CHECK`
   (asserted in §1). No `TO` clause.
5. Triggers: `t10_common` (`tg_tenant_scoped_before_update`: id/tenant immutable, timestamps),
   a `t20_` guard for role / parent-open / stamping rules, `t90_audit` (`tg_audit`). If the
   row inherits a folder's or document's marking, extend `tg_audit` so the audit row records
   `po_id` / `document_id` and the effective marking.
6. Grants: exactly the commands the policies allow, to `app_user`; column-level `UPDATE` for
   tables with trigger-managed columns; `SELECT` (and whatever the SECURITY DEFINER functions
   need) to `app_security`.
7. Tests: add the table to the isolation loop (§14), the INSERT-with-foreign-tenant list
   (§14b), the fail-closed table list (§15), and one export-control assertion if it hangs off
   a folder or document (§13). Bump the table count in §1.

## 14. Design decisions and trade-offs

* **Candidate 0's ledger is the core** (stored derived sign, reversal discipline, balances as
  a view, sign-off history). Grafted from the other candidates: document marking inheritance
  and the "moving out needs a manager" rule, the last-owner guard, the tenant marking
  ceiling, `evidence_page` + `document_pages` + `extraction_jobs`, session bootstrap
  functions, trigram search, `users.auth_subject`, `audit_log.actor_role`, retention and
  legal hold, `security_barrier` views, and symmetric `UPDATE` policies.
* **Trimmed to Phase 1:** the QuickBooks-style period lock (`books_closed_through`) and
  `reconciliation_matches` were removed; they belong with the accounting integration in
  Phase 3 and are one `ALTER TABLE` plus one check each. `parties.external_refs` /
  `purchase_orders.external_refs` stay as the integration hooks.
* **Checklist defaults are advisory** (see §11). Alternative: make it per-tenant optional. Owner decision.
* **Adjustment is always +, credit memo always -.** Keeps "sign derived from kind" strictly true.
* **Reversals are all-or-nothing;** partial corrections are credit memos / adjustments.
* **Users are global, attestation is global.** A hosted multi-tenant edition might want
  per-membership attestation; that is a one-column move to `tenant_memberships` later. The
  global e-mail key is contained by §6: the app never links or reveals an identity from
  another tenant, and cannot create `users` rows except through `add_member`.
* **No cluster-global counter is readable by a tenant.** `audit_log.seq` comes from a
  per-tenant sequence and transactions are grouped by `tx_started_at`, not by the xid (§7).
  Cost: one sequence per tenant and a trigger-time `nextval`; benefit: the audit trail of one
  tenant carries no information about the others.
* **The database trusts the app's assertion of *who* and *where*** (inherent to SET LOCAL and
  to JWTs alike), never its claim about role or US-person status. Per-user database roles could
  be layered on later without touching a policy.
* **`app_user` cannot `INSERT` into `users` at all**; `app.add_member` is the only path (a direct
  `INSERT ... RETURNING` would also fail RLS's SELECT check, the new user not being a member
  yet). This is what makes the unique-key oracle on the global e-mail column unreachable
  outside `add_member`'s own, documented, refusal.
* **`app_owner` can, being the owner, disable triggers.** It is the migration role and must not
  be used at runtime; candidate 2's event-trigger "schema lock" was left out because it needs
  a superuser bootstrap and makes every migration start with an unlock.
* **Cost of the parent-visibility `EXISTS`:** planned as a hashed sub-plan over the tenant's
  visible folders (thousands of rows), evaluated once per statement, and skipped entirely for
  US persons. Escape hatches if a ledger of hundreds of thousands of rows ever makes it show:
  denormalise `control_marking` onto the child tables (kept in step by the same cascade that
  raises documents today), or cache the visible-folder set per transaction in a temp table.
* **Audit rows are gated live, not only by the marking stored at write time**, so raising a
  folder later also hides its earlier history. Earlier history of a document that was later
  marked while still in the inbox stays readable (it was uncontrolled when written); mark
  scans on intake if that matters.

Hardening history (each item has a regression assertion in `tests/rls_tests.sql` §21):

* **Red-team round 1, RT-1** (low): `resolve_user` / `resolve_user_by_subject` resolved any
  e-mail or IdP subject from any context, and `add_member` linked and revealed an identity
  from another tenant (the earlier README claimed both helpers "return only the caller's own
  rows", which was false). Fixed as described in §6; no business data ever crossed tenants.
* **Red-team round 1, RT-2** (low): `audit_log.seq` was one cluster-global identity, so the
  gaps in a tenant's visible range disclosed other tenants' write volume (`txid` had the same
  property). Fixed as described in §7.

## 15. Open questions for the owner

1. Freight: is it billed through to the client (then it belongs on the client invoice amount
   and nets out) or absorbed? Today it is its own side with its own open balance and blocks
   `ready_to_close` until paid.
2. Is commission tracked per folder? If a commission statement covers several POs, the office
   must allocate it per folder for `open_commission_balance` to reach zero.
3. Which close-out checklist items should be blocking for the backlog of paper folders, and
   which for new folders? (Today: all advisory until an admin flips them.)
4. Retention period for closed folders (7 years is a placeholder), and who may place a legal hold.
5. Should controlled folders use a separate PO number series so that non-US staff cannot infer
   their existence from numbering gaps?
6. Who attests US-person status in the office, and on what evidence (`us_person_basis`)? The
   schema needs two humans (an owner and an admin) before anyone sees ITAR rows.
7. Does the office ever hold documents that are ITAR while the folder is not (a controlled
   drawing in an otherwise commercial order)? The schema allows it; the UI should make it visible.
8. (Hosted edition only.) When a person already on the platform is invited into a second
   company, should that be an operator link (today, §6) or a self-service invitation the
   invitee accepts after logging in? The latter also removes the last e-mail-exists hint.

## 16. Phase 2 and 3 hooks already in place

* Phase 2 (ingestion / HITL): `documents.po_id IS NULL` is the inbox; `documents.extraction_status`,
  `document_pages` (page image key, rotation, `ocr_text` with a trigram index) and
  `extraction_jobs` (status, engine, confidence, `result` JSONB, `reviewed_by/at`,
  `applied_po_id` which must be the document's folder) are the tables; `ledger_entries.document_id`
  + `evidence_page` and the search function already point at pages. On-prem, gate the
  pipeline on `documents.control_marking` and `tenants.deployment_mode` so controlled scans
  never leave the box.
* Phase 3 (integrations): `po_line_items.tracking_*` / `shipped_at` / `delivered_at` are the
  shipment placeholders; `parties.external_refs` and `purchase_orders.external_refs` hold
  QuickBooks ids; add `reconciliation_matches` and the period lock then. Quoting (owner ask)
  is a `quotes` table shaped like `purchase_orders` with a `quote_id` on conversion.
