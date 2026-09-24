# 06. Phase 1 plan: the digital folder on the office server

Date: 2026-09-24. Audience: Ross first, then the office staff and the outside accountant at Ross Machinery Sales.

This is the working document for Phase 1. It starts Monday 2026-09-28. The work is broken into small tasks that can each be started, finished and checked on their own. Where a task waits on an office answer, the plan names the question and the default if the answer is late.

**Calibration.** One developer (Ross), full time, five days a week, with AI assistance for scaffolding, tests, forms and boilerplate. Eight weeks is 40 working days; the 58 tasks add up to about 53 days if every medium task lands in one day and about 68 at the middle of each size band. So eight weeks is the target, not a promise: ten to eleven weeks is the honest range at the middle estimate, about double that at two or three days a week. The week-3 milestone (staff entering real folders) is protected by putting everything it needs first and letting everything after it slip instead.

Terms used more than once, explained here only:

| Term | Meaning here |
|---|---|
| Sovereign profile | The on-prem configuration: one Linux server in the office, no internet, outbound traffic blocked. |
| Tenant | One customer company. Phase 1 has one: Ross Machinery Sales. |
| RLS | Row-level security: rules inside PostgreSQL that hide rows a login may not see. |
| Marking | The control label on every folder and document: `none`, `fci`, `cui`, `itar`, `ear`, plus `proprietary` after migration 0002. |
| TOTP | The six-digit authenticator-app code required at every login. |
| CI | The automatic checks on every repository change; a red check blocks the change. |
| Adapter | Code with a fixed interface and swappable implementations (storage, secrets, AI, mail), each with an offline version. |
| Egress | Outbound network traffic from the server; blocked in the sovereign profile. |
| Canary | A nightly job that tries one outbound connection and records that it failed. |
| Unmanaged model | A Django model that describes an existing table and never creates or alters it. |

## 1. Goal and definition of done

By the end of Phase 1, Ross Machinery Sales runs a single-tenant digital folder on the office server, in the sovereign profile, and the office manager uses it instead of sticky notes for every open Project Order folder. Each folder is one record: tab fields, parties, line items, a typed append-only ledger that computes the four top-sheet balances, documents marked at intake, notes, the close-out checklist, and the open / pending_close / closed history with Manager-only close and reopen. The pile (every open folder and what it waits on) is the home screen. Search, five CSV reports, the audit viewer, user and role admin with US-person attestation, encrypted backups with a tested restore, TLS on the LAN, proven egress blocking, a runbook and the cutover of the open folders complete it. No AI extraction, QuickBooks connector, shipment tracking, control plane or white-label UI.

Phase 1 is done when every line is true:

- [ ] Migrations 0001 and 0002 are applied on the office server through the migration runner, never by hand.
- [ ] The RLS suite (418 checks today, more after 0002) runs in CI on a fresh PostgreSQL 16 database on every change as a required merge gate.
- [ ] A second red-team round has run against the final schema and the context middleware; every break has a regression test, no medium or higher finding is open, and its script replays green in CI.
- [ ] The unmanaged Django models agree with the SQL schema, checked in CI on every change.
- [ ] Every screen works with egress disabled: CI has no route out, and the nightly canary on the office server records "egress blocked: OK".
- [ ] Every account, Ross's included, logs in with a password and a TOTP code.
- [ ] A nightly encrypted backup exists on the NAS and an off-site USB drive, and a restore drill has been performed and logged (date, who, duration).
- [ ] The office manager has closed at least one real folder end to end on the office server without the developer at the keyboard.
- [ ] The open folders are in with opening balances, each paper folder carries a printed cover sheet, and the bookkeeper has reviewed the variance list.
- [ ] The five reports open and export to CSV under the user's own RLS context; the audit viewer shows who did what and when.
- [ ] The standing rule on real data (section 2) was followed throughout, and the repository history has been checked for it.
- [ ] The runbook and the handoff document exist, and Ross and the office manager have signed the definition-of-done review.

## 2. Ground rules

**The standing rule on real data** (04, section 10; binds everyone, including AI coding assistants):

1. Never put a real PO, invoice, drawing, ledger sheet or anything carrying a CUI or ITAR legend into any AI coding session, cloud or local.
2. Never commit real documents or real data to the repository: no scans, exports, database dumps or log files.
3. Develop and test with synthetic fixtures: made-up companies, PO numbers, amounts and generated PDFs. The fixture set is the only data CI ever sees.
4. Real-document testing happens only on the office server, in the sovereign profile, with the extractor off; a bug that only reproduces with a real document is reproduced on-site.

**SQL migrations are the source of truth for the database.** RLS, triggers and policies cannot be expressed in Django migrations, so `schema/migrations` defines the database; Django models are unmanaged mirrors, and a CI check fails the build if the two disagree. Nobody runs `makemigrations` to change a table.

**The sovereign profile is the CI default.** `PO_PROFILE=sovereign` in development and CI, with no route out. A feature that cannot run with egress disabled is not merged.

**Every external capability sits behind a named adapter with an offline implementation in the same image.** Phase 1 ships only those. A lint rule fails the build if `anthropic`, `boto3`, `httpx` or `requests` is imported outside `adapters/` and `integrations/`.

**No company-specific hard-coding.** Name, logo, colours, PO prefix and checklist come from `branding/`, the `tenants` row and the templates, never from code.

**Markings gate everything.** A document cannot be viewed, filed, downloaded or linked until a person has set its marking. Controlled markings (`cui`, `itar`, `ear`) are visible only to attested US persons. There is no AI in Phase 1, and when it arrives the marking decides whether it may run. `classified` is a hard stop at intake: the file is refused, nothing is stored.

**The repository is `1688ross/rossmachinery`, private.** It holds code, docs, synthetic fixtures and the schema, never real documents, dumps, logs or secrets; guards enforce this (B5).

## 3. Sequencing and the decision gates

Discovery runs in week 1 alongside the scaffold: nothing in workstream B, C1 to C4 or D1 depends on an office answer, so week 1 builds the repository, compose file, CI and login while Ross takes the questions to the office. Answers land in the decision log (A3). On its gate date each gate is marked resolved or defaulted; after that we build under the default, and a late answer that contradicts it becomes a change request with its own task.

Question numbers refer to `05-discovery-questions.md`.

| Gate | Questions | Gates | Default if unanswered by the gate date | Gate date |
|---|---|---|---|---|
| G1 Folder shape and numbering | Q1, Q3 | E2, E4, I2, C5 | A folder is one client order and may hold one or more vendor orders: the primary vendor sits on the folder, a line may name another. The system allocates the next PO number from the highest on paper; a typed number is accepted if unused. | Fri Oct 2 (week 1) |
| G2 Deal type and commission | Q5, Q6 | C5, E5, G1 | Both models exist. 0002 adds `deal_type` (resale, commission, mixed) per folder, nullable, with a pile reminder. Commission is typed per folder; its arrival is a `commission_received` entry. | Fri Oct 16 (week 3) |
| G3 Payment shape | Q7, Q8 | C5, E5 | Several invoices and payments per side per folder. A payment spanning folders is one entry per folder sharing the check reference. No payments header unless the bookkeeper asks. | Fri Oct 16 (week 3) |
| G4 Close rules and "balanced" | Q13, Q14 | E6, E7, E8 | Ready when all four open balances are zero and every required checklist item is ticked; the five seeded items stay advisory until the owner flips them. Owner, admin and manager close; the office manager proposes; reopen needs a reason. Bank reconciliation stays in the accounting package. | Fri Oct 16 (week 3) |
| G5 Invoices, quotes, accounting | Q15, Q16, Q18 | C5, G3 | Invoices and quotes are produced outside and recorded here (number, date, amounts, PDF); 0002 adds the four quote fields. Some QuickBooks edition is in use; Phase 1 exports CSV only. | Fri Oct 16 (week 3) |
| G6 Markings and which rules apply | Q29 to Q32 | A4, C5, F4, H1, H4 | Nothing is formally classified; no facility clearance. DFARS 7012 applies. Unmarked means controlled. The tenant ceiling is `ear` (every marking allowed). 0002 adds `proprietary` for NDA-covered material such as Sikorsky's: visible to every member, never to AI. | Fri Oct 2 (week 1) |
| G7 People and roles | Q25 to Q27 | D4, E10, I4 | Three to six users, all US persons. The owner is the named system owner; Ross administers. The outside bookkeeper gets `viewer` (see the note below). | Fri Oct 2 (week 1) |
| G8 Server and network | Q35 to Q38 | H1, H2, H3, D1 | No suitable server exists: a small Linux host is ordered on the gate date. Local accounts with TOTP; office network only; no VPN; egress none. | Fri Oct 2 (week 1) |
| G9 Volumes and backlog | Q22, Q23 | E8, I1 | 20 to 40 new folders a month, 60 to 120 open. Start forward: open folders are entered, the closed archive stays on paper. | Fri Oct 2 (week 1) |
| G10 Backups and scanner | Q39 to Q41 | H4, F3 | No reliable backup exists today: nightly encrypted local backup plus rotating off-site USB. The copier scans to a network share; if not, browser upload alone until it is replaced. | Fri Oct 23 (week 4) |
| G11 Second administrator and retention | Q42, Q44 | H6, I4 | Ross is the sole administrator, with a sealed break-glass credential in the safe. Closed folders are kept forever (`retention_years` empty); soft delete only. | Fri Nov 6 (week 6) |

Note on G7: `viewer` and `auditor` both read documents; no 0001 role sees numbers but not attachments. If the bookkeeper must not see documents, or is not a US person, that is a 0002 policy change and must be known by the G7 date.

## 4. Workstreams and tasks

Sizes: S is up to half a day, M is one to two days, L is three days; anything larger was split. "Done when" is what Ross checks before ticking the task.

### A. Discovery and decisions

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| A1 | Office discovery session | S | none | all | The ten "ask first" questions have an answer or a written "don't know"; the checklist in 05 is ticked; no real page leaves the office. |
| A2 | Ross's look-and-see checks and the brand system | S | none | G8, G10 | Server, login method, VPN, backup, copier and email facts are written down; the brand system files are in the repository under `branding/`. |
| A3 | Decision log | S | A1, A2 | none | `docs/07-discovery-answers.md` lists every question with its answer or default, dated; each gate is marked resolved or defaulted. |
| A4 | Classification triage | S | A1 | G6 | Written confirmation that nothing is formally classified and no facility clearance exists; whether DFARS 7012 appears in the Sikorsky and prime terms is recorded; the meaning of `proprietary` is written for C5. |
| A5 | Money, close, quote and invoice decisions | S | A1 | G2 to G5 | Deal type values, commission handling, payment shape, close rules and "invoices and quotes are recorded, not produced" are confirmed or defaulted; the 0002 column list is final. |

### B. Repository, tooling and CI

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| B1 | Create the Django project in `1688ross/rossmachinery` | M | none | none | The private repository holds the Django LTS project (apps: accounts, tenancy, folders, ledger, documents, reports, ops), the `docs` and `schema` trees, `PO_PROFILE=sovereign` as default; `manage.py check` passes. |
| B2 | Sovereign compose file | M | B1 | none | `docker compose` starts Caddy, web, worker, PostgreSQL 16 and the backup sidecar on an internal network with no route out; web answers over HTTPS on the LAN name. |
| B3 | CI pipeline | M | B1, B2, C2 | none | Every push runs lint, unit tests, the RLS suite on a fresh PostgreSQL 16 and the model-agreement check on a network that denies egress; a red job blocks merge. |
| B4 | Synthetic fixtures | M | B1 | none | A loader creates made-up parties, folders, line items, ledger entries and generated PDFs with no real names, numbers or logos; CI and the dev database see only this set. |
| B5 | Repository guards | S | B1 | none | Pre-commit and CI refuse PDFs, images, dumps and secrets outside `fixtures/`; the import lint fails the build on `anthropic`, `boto3`, `httpx` or `requests` outside `adapters/` and `integrations/`. |
| B6 | Adapter skeletons with offline implementations | M | B1 | none | The seven adapters (`BlobStore`, `KeyProvider`, `SecretsProvider`, `Mailer`, `Extractor`, `OutboundHttp`, `Telemetry`) exist with offline implementations; the app refuses to boot if any adapter has a remote endpoint under `EGRESS_MODE=none`. |

### C. Database

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| C1 | Apply 0001 and document the operator bootstrap | S | B2 | none | `0001_init.sql` applies to the dev database; `tests/run_tests.sh` passes 418 checks locally; the bootstrap steps (`app.bootstrap_tenant`, the `po_api` login role granted `app_user`) are written down. |
| C2 | RLS suite as a CI gate | S | C1 | none | `run_tests.sh` runs in CI on a fresh database for every change under `schema/`; the job is required for merge. |
| C3 | Unmanaged Django models and the agreement check | L | C1 | none | Each of the 16 tables and 4 views has an unmanaged model; a command compares model fields with the live schema (name, type, null, default) and fails CI on any difference; `makemigrations --check` reports nothing. |
| C4 | SQL migration runner | S | C1 | none | `po migrate` applies files under `schema/migrations` in order, records each in a `schema_migrations` table, refuses to re-run 0001, and takes a backup first on the office server. |
| C5 | Migration 0002 | L | A3, A4, A5, C3 | G1, G2, G3, G5, G6 | Expand-only: `deal_type`, `quote_number`, `quote_date`, `quoted_client_total`, `quoted_vendor_cost`, `shelf_location`, a `filed` status, a `proprietary` marking, and the payments header if A5 asked for it; the suite gains assertions for each and passes; models and the agreement check are updated; week-3 data survives untouched. |
| C6 | Second red-team round | M | C5, D2, F4 | none | Round 1's script replays green; new attacks target the 0002 columns, `filed`, `proprietary`, the intake quarantine and the context middleware; every break has a regression test; no medium or higher finding is open. |

### D. Application skeleton

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| D1 | Login with mandatory TOTP | M | B1 | G8 | Local accounts only; every user enrols an authenticator app at first login; printed recovery codes; admin-issued resets; lockout; idle lock; login banner; no email in the flow. |
| D2 | Tenant-context middleware | M | C1, D1 | none | Each request runs in one transaction that sets `app.tenant_id` and `app.user_id` from the server-side session before any statement touches schema `app`; the login path calls `app.resolve_user` only in a context-free transaction; a test proves client input never sets either value. |
| D3 | Runtime role proof | S | D2, B2 | none | An integration test shows web and worker connect as `po_api`, cannot bypass RLS, and see zero rows with no context or a wrong tenant id; connections are released with `DISCARD ALL`. |
| D4 | Roles and permissions layer | M | D2 | G7 | `authz.can(user, action, object)` mirrors the README roles matrix; navigation and buttons follow it; a table-driven test covers every row for all six roles. |
| D5 | Theme from the Ross brand system | M | B1, A2 | none | Colours, type and logo come from `branding/` as CSS custom properties; no font, script or image loads from outside the box; HTMX is vendored; the layout works at phone width. |
| D6 | PostgreSQL-backed worker | M | D2 | none | A jobs table polled with `SKIP LOCKED` runs intake, backup verification, the canary and CSV exports under the same runtime role; a failed job shows on the health page. |

### E. Screens

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| E1 | Parties | S | D4 | none | List, create, edit and retire clients, vendors and carriers with the three flags; every other screen picks a party from this list, never types a name. |
| E2 | Folder create and header | M | E1 | G1 | The tab fields (PO number allocated or typed, client order number, client, primary vendor, title, marking) save to `purchase_orders`; a duplicate PO number is refused with a plain message. |
| E3 | Folder view | L | E2, E4, E5 | none | One page shows the tab, the top sheet from `po_balances`, line items, ledger, documents, notes, checklist and status history; a printable cover sheet (PO number, balances) prints from it. |
| E4 | Line items | S | E2 | none | Add, edit and remove lines with category, quantity, unit price and an optional vendor override. |
| E5 | Ledger entry form | M | E2 | G2, G3 | Laid out like the top sheet: kind, side, amount, date, counterparty, reference, evidence document and page; memo required where the schema requires it; a reversal action; posting to a closed folder is refused. |
| E6 | Notes and close-out checklist | M | E3 | G4 | Sticky notes and comments on the folder; a "please close" shortcut sets `pending_close`; checklist items tick with who and when; an owner or admin edits the templates and required flags. |
| E7 | Close and reopen | M | E6, D4 | G4 | Close is offered only to owner, admin and manager; it succeeds when `ready_to_close` is true or an override reason is typed; reopen needs a reason; the history panel shows every transition with its balance snapshot. |
| E8 | The pile (home screen) | M | E3 | G9 | Home lists open and pending folders with what each waits on (client, vendor, freight and commission balances, required checklist items, unmarked scans, deal type not set), sortable by age and amount. |
| E9 | Search box | S | E3 | none | One box over PO number, client order number, title and party names via `app.search_purchase_orders`; filters by status, party, year and balanced. |
| E10 | User and role admin | M | D4 | G7 | Owner and admin add members through `app.add_member`, set roles, deactivate, reset TOTP, and attest US-person status for somebody else with a basis; the schema's refusals appear as plain messages. |
| E11 | Audit log viewer | S | D4 | none | Owner, admin and auditor filter `audit_log` by folder, user, table and date, see before and after values, and export the filtered rows to CSV. |

### F. Documents and intake

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| F1 | Storage adapter | M | B6 | none | `FileSystemBlobStore` writes each file under an opaque key on the encrypted volume with envelope encryption; the master key comes from `KeyProvider` (an owner-held key file at launch); with the wrong key, nothing opens. |
| F2 | Upload path and quarantine | M | F1, D6 | G6 | A browser upload lands in the quarantine (hash, size and type checks, a `classified` choice that refuses the file); a duplicate by SHA-256 against the quarantine and `documents` is reported, not stored twice; a scan hook exists (null in Phase 1). |
| F3 | Watched scanner folder | M | F2 | G10 | The worker polls the copier's share, waits for each file to stop growing, hashes it, moves it to the quarantine with its original name and source, and dedupes by SHA-256; a failed file stays in `failed/` with a reason. |
| F4 | The marking step | M | F2 | G6 | Nothing can be viewed, filed, downloaded or linked until a person sets kind, marking and date on the intake screen; only then is the `documents` row created, with that marking; a controlled marking is offered only to attested US persons. |
| F5 | Viewing and download | M | F4, D4 | none | Documents open only through a route that checks the policy and logs the download; no direct file URLs; pages render in the browser; the ledger form can point at a document and page. |
| F6 | Supersede and soft delete | S | F5 | none | A re-scan supersedes an earlier upload; a manager can soft-delete and restore; hashes stay auditable; a closed or held folder refuses. |

### G. Reports and search

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| G1 | Report views | M | C5 | G5 | Five `security_invoker` views in a views-only migration 0003: open folders by age with what each waits on; client receivables outstanding by client; vendor and freight payables by vendor; commission earned and received by month; ledger entries by date range. Each has a fixture test. |
| G2 | Report screens with CSV export | M | G1 | none | Each report has a page with filters and a streaming CSV export under the user's own RLS context; an auditor sees exactly the rows the report shows. |
| G3 | Month-end reconciliation export | S | G2 | G5 | A date-range export lists every invoice, bill and payment with document number, party and amount, for matching against the accounting system by hand. |

The five reports are the Q20 and Q21 defaults; no input names them, so one view swaps if the Q20 answer differs. With no due date in the schema, "outstanding" is by invoice date.

### H. Operations

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| H1 | Office server baseline | M | A2 | G6, G8 | A supported Linux LTS (FIPS-capable if 7012 is confirmed) with full-disk encryption, Docker, a static LAN address, NTP from the router and a default-deny outbound firewall; nothing listens except Caddy on 443. |
| H2 | Caddy internal CA and trust on office PCs | S | H1, B2 | none | The app answers on `https://<lan-name>` with a certificate from Caddy's internal CA; `po trust-cert` installs the root on each office PC; no browser warning on any of them. |
| H3 | Egress blocked and proven; health page | M | H1, D6 | G8 | The nightly canary records "egress blocked: OK"; the health page shows profile, egress state, database role, backup age, disk and NTP drift; a canary that succeeds paints a red banner. |
| H4 | Nightly encrypted backups | M | H1, F1 | G10 | Nightly `pg_dump` plus a file-store snapshot, encrypted with a company-held key, to the NAS and rotating encrypted USB drives, one always off-site; the sidecar logs each run and the health page shows the age. |
| H5 | Restore drill | M | H4 | none | A backup restores onto a scratch machine or a second compose stack; row counts match, a folder opens, a document decrypts; the drill is logged with date, who and duration. |
| H6 | Runbook | M | H1 to H5 | G11 | One document covers install, start and stop, upgrade from a USB image, add a user, reset TOTP, restore, the sealed break-glass credential, the first 72 hours of a suspected incident, who to call. |
| H7 | Secrets and key custody | S | H1 | none | A root-owned `0600` secrets file, the master key on an owner-held USB drive, and a printed recovery sheet in the safe; the app reads no secret after settings load. |

Backups use `pg_dump` in Phase 1: one command restores it and the volume is small. pgBackRest (point-in-time recovery) is a Phase 2 upgrade.

### I. Cutover and training

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| I1 | Cutover inventory | S | A1 | G9 | The count of open folders, the opening-balance source per folder (accounting system where possible, else the top sheet) and the cutover date are written down; the closed archive stays on paper. |
| I2 | Opening-balance import | M | E5, C5, I1 | G1 | A CSV template filled from each tab and top sheet imports folders with one ledger entry per side dated at cutover and referenced "opening balance"; variances against the accounting system are listed; the PO counter continues from the highest existing number. |
| I3 | Printed cover sheets | S | I2, E3 | none | Every imported folder gets a printed cover sheet (PO number, client, balances, shelf location once 0002 is applied) stapled to the physical folder. |
| I4 | Provision the tenant on the office server | M | H1 to H4, D1, E10 | G7, G11 | `bootstrap_tenant` run with `onprem`, the retention setting and the `po_api` role; every real user enrolled in TOTP on their own phone; the owner and an admin have attested each other's US-person status so controlled rows are reachable (the schema needs two humans). |
| I5 | Training | S | I4, E8 | none | Two sessions with the office manager and the bookkeeper, a one-page quick guide, and a week of shadowing with an issues list. |
| I6 | First real close | S | I5, E7 | none | The office manager takes at least one real folder from open to closed end to end, on the office server, without the developer touching the keyboard. |

### J. Handoff

| Id | Title | Size | Depends on | Gate | Done when |
|---|---|---|---|---|---|
| J1 | Handoff document | M | all | none | `docs/08-handoff.md` says what was built, how to run it, where every artefact is, what waits on which answer, and the Phase 2 entry list. |
| J2 | Definition-of-done review | S | J1, C6, H5, I6 | none | The section 1 checklist is walked line by line with Ross and the office manager; CI is green including the RLS suite and red-team round 2; the restore drill is logged; both sign. |

Totals: 58 tasks; 23 S, 32 M, 3 L.

## 5. Week-by-week shape

Weeks run Monday to Friday. Real data touches only the office server, from week 3.

| Week | Dates | Ends with |
|---|---|---|
| 1 | Sep 28 to Oct 2 | Discovery done, decision log started (A1 to A3). Repository, compose file, fixtures, guards and adapters exist (B1 to B6). 0001 applied locally, RLS suite a CI gate (C1, C2). Gates G1, G6 to G9 resolved or defaulted. The server is ordered if none exists. |
| 2 | Oct 5 to 9 | Login with TOTP, tenant context, role proof, permissions, theme and worker on the dev stack (D1 to D6). Models and agreement check green (C3, C4). Parties and folder header on fixtures (E1, E2). |
| 3 | Oct 12 to 16 | **Staff enter real open folders on the office server.** The box is installed with TLS, egress blocked and a first nightly backup (H1, H2, H4, H7); the tenant is provisioned and every user has TOTP (I4, first pass). The simplified real screen is live: folder header, line items, ledger entries, computed balances (E2, E4, E5, first cut of E3). Gates G2 to G5 close Friday. |
| 4 | Oct 19 to 23 | 0002 applied through the runner (C5); week-3 folders show "deal type not set". Full folder view, notes, checklist, close and reopen (E3, E6, E7). The pile (E8). Gate G10 closes. |
| 5 | Oct 26 to 30 | Documents: storage, quarantine, watched scanner folder, the marking step, viewing, supersede (F1 to F6). Search (E9). |
| 6 | Nov 2 to 6 | Reports and CSV, reconciliation export (G1 to G3). Audit viewer and user admin complete (E10, E11). Health page and canary (H3). First restore drill (H5). Gate G11 closes. |
| 7 | Nov 9 to 13 | Cutover: inventory, opening-balance import, cover sheets (I1 to I3). Training and shadowing begin (I5). Runbook (H6). Second red-team round (C6). |
| 8 | Nov 16 to 20 | First real close by the office manager (I6). Fixes from the red team and shadowing. Handoff and the definition-of-done review (J1, J2). Anything left over is listed, not hidden. |

If the end-of-week-4 burn-down shows the middle estimate is the true one, weeks 5 to 8 become 5 to 11 in the same order. Nothing is cut from the definition of done to hit a date.

## 6. What is explicitly out of Phase 1

| Item | Moves to |
|---|---|
| AI-assisted capture: extraction, pre-fill, split-screen review. Hooks: `document_pages`, `extraction_jobs`, the `Extractor` adapter set to none. | Phase 2, unmarked documents only, behind the marking gate |
| Quote lines, pricing and quote document generation. Phase 1 records the four quote fields only. | Phase 2 |
| Invoice authoring with its own number series and template. Phase 1 records invoices produced elsewhere. | Phase 2, only if Q15 says the office wants it |
| A payments header showing one check as one record. | Phase 2, only if the bookkeeper asks (G3) |
| Email intake, bulk import of the existing digital folders, and scan-and-index of the closed paper archive with OCR. | Phase 2 |
| VPN remote access with MFA, sanctioned phone capture, sign-in through Microsoft or Google. | Phase 2 |
| Hardening and packaging: malware scanning of uploads (the F2 hook), pgBackRest point-in-time recovery, a signed offline upgrade bundle with rollback. Phase 1 upgrades from a USB image by the runbook. | Phase 2 |
| The written System Security Plan and NIST SP 800-171 control matrix; the software's part is built, the document is the company's. | Phase 2, or sooner if a prime asks |
| QuickBooks connector (one-way, per document type), period lock, reconciliation matches. Hooks: `external_refs` and the CSV export. | Phase 3 |
| Shipment tracking. Hooks: the `tracking_*` columns on line items. | Phase 3 |
| Multi-tenant control plane: onboarding, billing, subdomains, white-label UI, feature-flag admin, the hosted or Supabase edition. | Second-customer edition (Phase 4) |
| A separate PO number series for controlled folders (README open question 5). | Decide in Phase 2 |

## 7. Risks and how the plan handles them

| Risk | What the plan does |
|---|---|
| Discovery answers change the folder shape (Q1) | G1 closes in week 1, before any folder screen is built. The schema already has a primary vendor on the folder and a per-line override, so one-to-one and one-to-many both fit. Many-to-many (one shipment covering several client orders) is the one answer that changes tables, not columns; then E2 stops and a design note is written before week 3. |
| The office has no suitable server | The G8 default orders a small Linux host on Oct 2. Until it arrives everything runs on fixtures. Real data never goes on a developer laptop as a stopgap; week 3 waits for the box rather than bend the standing rule. |
| Ross's time | The plan is calibrated full time and says so. At two or three days a week the calendar roughly doubles; the order and gates do not change. Tasks in A and I need Ross at the office and sit in weeks 1, 3 and 7, so visits are few. |
| Usage limits on AI-assisted development | Sessions are scoped to one task id and end with a commit. The three L tasks (C3, C5, E3) go on days with full capacity. Fixtures are the only data an assistant sees. No task depends on any one tool; every "done when" can be checked by hand. |
| The deal-type question (Q5) is unanswered | The ledger already holds all sides (client, vendor and freight, commission), so balances are right whatever the answer. 0002 adds `deal_type` as nullable and the pile shows "deal type not set" until the office manager fills it in. |
| A real document ends up in the wrong place (an AI session, the repository, a laptop, a cloud drive) | The standing rule is in section 2 and the repository README; B5 blocks PDFs, images, dumps and secrets from being committed. If it happens anyway: treat it as an incident, purge the history, rotate credentials, record it, and if the page carried CUI start the 72-hour DFARS 7012 clock. |
| The second red-team round finds something | C6 runs in week 7 with a day held in week 8 for the fix and its regression test. A medium or higher finding blocks the definition of done; a low one gets a regression test and a written known limit, as round 1's two did. |
| The eight-week calendar does not fit the sized tasks | Stated up front: 40 days available against 53 to 68 estimated. Week 3 is protected by sequencing; the end-of-week-4 burn-down decides whether weeks 5 to 8 become 5 to 11. Nothing leaves the definition of done. |
| Staff do not adopt it (Q28) | The week-3 screen is deliberately small; the printed cover sheet keeps paper-first habits working; training is two short sessions plus a week of shadowing whose issues list feeds week 8. |
| The one box is the whole system | Nightly encrypted backups on the NAS and off-site USB from week 3, a restore drill in week 6, the runbook, the sealed break-glass credential, a spare disk on the shelf. |

## 8. Phase 2 preview

Phase 2 starts once the office has closed folders through the system for a few weeks and the shadowing issues list is worked off. It adds AI-assisted capture behind the marking gate: a local model on the box or CPU layout-and-OCR reads unmarked documents into `extraction_jobs` as a draft, a person confirms beside the page, and nothing posts to the ledger without that confirmation; controlled documents get no AI unless the government-cloud path is enabled with counsel's sign-off. It adds quoting (quote lines, convert-to-folder, quote documents if Q16 asks), invoice authoring if the office wants invoices made here (Q15), the payments header if the bookkeeper wants one check as one record (Q8), email intake, bulk import of the digital folders, VPN access and the packaging items above.

Phase 3 is integrations: one-way accounting export to the confirmed QuickBooks edition, period lock and reconciliation, and shipment tracking by polling. The second-customer edition (tenant onboarding, billing, white-label UI, the hosted profile) waits for a second company to sign.
