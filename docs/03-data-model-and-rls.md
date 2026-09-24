# 03. Data model and row-level security

Status: schema written and tested 2026-09-24. Audience: Ross first, then the office staff and the outside accountant at Ross Machinery Sales.

This document explains the database design in folder terms and records why. The technical reference is `schema/README.md`; the source of truth is `schema/migrations/0001_init.sql` (about 2,800 lines of SQL), which nobody has to read.

Terms, explained once:

- **Table**: one kind of record, stored as rows. **View**: a saved query that looks like a table but is computed on every read.
- **Tenant**: one customer company. Ross Machinery Sales is the only one at launch.
- **Row-level security (RLS)**: rules inside PostgreSQL that decide which rows a query may see or change. **Trigger**: a rule that runs inside the database when a row is written; here they refuse bad writes and stamp who did what.
- **Control marking**: the label on every folder and document: `none`, `fci`, `cui`, `itar` or `ear` (02-brief-critique.md section 7). **US person**: a US citizen or green-card holder.
- **SQLSTATE**: PostgreSQL's error code. `42501` is "insufficient privilege"; `23505` is "already taken".

## 1. What the database holds, in folder terms

Take one paper folder off the pile. The **tab** (client order number, internal PO number, vendor, project name) is one row in `purchase_orders`. The **top sheet** with its four totals is not typed in at all: it is the `po_balances` view, computed from the money events underneath it, so it can never disagree with them. The **hand-written payments table**, the one that is hard to decipher, is `ledger_entries`: one dated row per invoice, payment, credit or commission, never edited, corrected only by a reversal row. The **stack of invoices and remittances** is `documents` (one row per file; the bytes live in encrypted storage) and `document_pages` (one row per page, for the viewer and OCR in Phase 2). The **sticky notes** are `po_notes` rows of kind `sticky`. The **"close this one?" sticky note** becomes two things: a close-out checklist (`po_close_checklist_items`, copied from the company's `close_checklist_templates` when the folder is created) and a status history (`po_status_history`) recording who asked for the close, who signed it off, and the balances at that moment. The **filing cabinet** is `parties` (every client, vendor and carrier by id, so names stop drifting) and `tenants` (the company). Around all of it sits `audit_log`, a permanent record of every change, written by the database itself.

## 2. Entity diagram

Sixteen tables and four views. Arrows mean "belongs to".

```
                      tenants  (one row per company)
                         |  tenant_id on every company-scoped table
     +-------------------+-----------------------+
     |                   |                       |
   users <-- tenant_memberships       po_number_counters
  (global)     (role per company)     close_checklist_templates (copied per folder)
   parties (clients, vendors, carriers)             |
     |  client_party_id, vendor_party_id            v
     v
  purchase_orders   THE FOLDER: tab, status, control_marking, close stamps, hold
     +--> po_line_items             what was bought
     +--> documents                 the stack --> document_pages  (one per page)
     |        ^                               --> extraction_jobs (Phase 2)
     +--> ledger_entries            money events, append-only; may cite a page
     +--> po_notes                  sticky notes and comments
     +--> po_close_checklist_items  close-out questions, ticked per folder
     +--> po_status_history         status changes + balance snapshot, append-only

  audit_log   every change above; trigger-written, append-only

  Views (computed, never stored)
    po_balances        the top sheet: totals, open balances, ready_to_close
    po_ledger          entries with reversal status and counterparty
    current_documents  documents not superseded and not deleted
    po_folder          tab + top sheet + counts, one row per folder
```

| Table | Purpose | Key columns |
|---|---|---|
| `tenants` | One row per company. | `name`, `deployment_mode`, `max_control_marking`, `retention_years` |
| `users` | One row per person, global. | `email`, `full_name`, `auth_subject`, `is_us_person`, `us_person_attested_by`, `us_person_basis` |
| `tenant_memberships` | Who belongs to which company, with what role. | `tenant_id`, `user_id`, `role`, `is_active` |
| `parties` | Clients, vendors and carriers, referenced by id. | `name`, `is_client`, `is_vendor`, `is_carrier`, `external_refs` |
| `po_number_counters` | Hands out the next PO number without gaps. | `prefix` (default `PO-`), `next_value` |
| `close_checklist_templates` | The company's close-out questions, copied into each new folder. | `item_key`, `label`, `is_required` |
| `purchase_orders` | The folder: tab fields plus lifecycle. | `po_number`, `client_order_number`, `client_party_id`, `vendor_party_id`, `title`, `status`, `control_marking`, `close_override_reason`, `legal_hold`, `retain_until` |
| `po_line_items` | What was bought, one row per line. | `category`, `description`, `quantity`, `unit_price`, `extended_amount` (computed), shipment placeholders |
| `documents` | One row per file in the stack. | `po_id` (empty means "in the inbox"), `kind`, `control_marking`, `storage_key`, `sha256`, `page_count`, `supersedes_document_id`, `deleted_at` |
| `document_pages` | One row per page, for the viewer and OCR. | `page_number`, `storage_key`, `ocr_text`, `ocr_confidence` |
| `extraction_jobs` | One row per AI extraction attempt; empty in Phase 1. | `status`, `engine`, `confidence`, `result`, `reviewed_by`, `applied_po_id` |
| `ledger_entries` | The money events; positive amounts, never edited. | `kind`, `side`, `amount`, `signed_amount` (computed), `flow` (computed), `entry_date`, `counterparty_party_id`, `reference`, `document_id`, `evidence_page`, `reverses_entry_id` |
| `po_notes` | Sticky notes and comments. | `kind`, `body`, `is_pinned`, `resolved_at` |
| `po_close_checklist_items` | The folder's own checklist, ticked item by item. | `item_key`, `label`, `is_required`, `completed_at`, `completed_by` |
| `po_status_history` | Every status change, with a balance snapshot. | `from_status`, `to_status`, `changed_by`, `reason`, `was_ready_to_close`, `balances`, `checklist` |
| `audit_log` | Every change, with before and after values. | `seq` (per company), `table_name`, `action`, `old_data`, `new_data`, `po_id`, `control_marking`, `actor_user_id`, `actor_role`, `tx_started_at` |

Money is stored as exact decimals, never floating point. Every id is a random UUID.

## 3. How the three candidates became one

Three schemas were written independently, then scored by one judge on seven criteria: tenant isolation, portability, the ledger, Phase 2 readiness, export control, simplicity and operations. The judge applied each to a real PostgreSQL 16 database and probed its claims.

| Lens | What it optimised for | Score of 70 |
|---|---|---|
| Candidate 0: "the ledger is the heart" | Money events that cannot drift, a computed top sheet, a close-out state machine with sign-off history. | **53** (isolation 9, portability 7, ledger 9, Phase 2 7, export control 8, simplicity 4, operations 9) |
| Candidate 1: "the folder as it arrives" | Scanned intake batches, page rows, extraction jobs, every entry citing the exact page. | 49 (8, 8, 7, 9, 4, 6, 7) |
| Candidate 2: "isolation and compliance first" | The smallest surface, tenant-scoped users, retention and legal hold, a schema lock. | 42 (8, 6, 6, 6, 5, 6, 5) |

**Why the ledger-first candidate won.** Its ledger was the best of the three: the sign of every entry is derived from its kind by the database, so it cannot be keyed wrong; a reversal must reference one original, once, for the full amount; a memo is required on every correction; and the ledger is append-only at three layers. Its balances view produced every top-sheet figure plus `ready_to_close`, and the worked example (99,000 billed, 21,500 gross margin) checked out. It was the only candidate whose audit log hid controlled folders from non-US persons, the only one that blocked an admin from attesting their own US-person status, and the only one that let management close a folder that will never balance, with a recorded reason. The other two let a non-US admin read the ITAR folder's audit rows and flip their own flag; Candidate 2 also let a manager back-date a close to 2001.

**Grafts from the other two.** The judge found real problems in the winner too, and most grafts are their fixes. From Candidate 1: marking inheritance (a document takes its folder's marking on filing and refiling, and moving one out of a controlled folder needs a manager; before this, an unmarked scan filed into an ITAR folder and refiled out became visible to a non-US manager); the last-owner guard; the tenant marking ceiling; page-level evidence (`evidence_page` and `document_pages`); the `extraction_jobs` placeholder; the session-bootstrap and search functions; the `auth_subject` login link; and the actor's role on every audit row. From Candidate 2: retention and legal hold, `security_invoker` views, and symmetric update policies. Also fixed: any clerk could create a tenant (now operator-only), and the period lock and reconciliation table moved to Phase 3. Candidate 2's schema lock was left out: it needs a superuser to install.

## 4. The ledger and how a folder balances

Every money event is one row in `ledger_entries`, with a **kind** (what happened), a **side** (which column of the top sheet: client, vendor, freight or commission) and a positive **amount**. The database derives and stores `signed_amount` and `flow` (accrual: something was billed or earned; cash: money moved). Nobody types a sign.

| Kind | Side | Sign | Flow | Meaning |
|---|---|---|---|---|
| `client_invoice` | client | + | accrual | we billed the client |
| `client_payment` | client | - | cash | the client paid |
| `vendor_bill` | vendor | + | accrual | the vendor billed us |
| `vendor_payment` | vendor or freight | - | cash | we paid the vendor or carrier |
| `freight_charge` | freight | + | accrual | a carrier or vendor billed freight |
| `commission_earned` | commission | + | accrual | commission due to us |
| `commission_received` | commission | - | cash | commission received |
| `credit_memo` | any | - | accrual | reduces the billed amount on its side; memo required |
| `adjustment` | any | + | accrual | increases the billed amount on its side; memo required |
| `reversal` | copied | flipped | copied | full-amount undo of one entry, once, never of a reversal; memo required |

**Reversals instead of edits.** A ledger row is never updated or deleted, by anyone. If a payment was keyed as 39,500 instead of 39,000, the fix is two new rows: a reversal of the wrong one and a correct one. The reversal copies the original's folder, side, amount and counterparty, so the pair nets to zero and the history still shows what happened.

**The balances view.** `po_balances` computes, per folder: billed and received on each of the four sides; the four open balances (billed minus received); `gross_margin` (billed to client, minus billed by vendors, minus freight, plus commission); `entry_count`; and `checklist_complete`. `is_balanced` is true when the folder has at least one entry and all four open balances are zero. `ready_to_close` is true when `is_balanced` and no required checklist item is open.

**Worked example** (folder PO-00001 in the test suite). An invoice of 100,000 to the client; payments of 60,000 and 39,500 (keyed wrong); a reversal of the 39,500; a corrected payment of 39,000; a vendor bill of 80,000, paid in full; a 10 adjustment and a 10 credit memo on that bill; freight of 2,500 charged and paid; commission of 5,000 earned and received; a 1,000 goodwill credit memo to the client.

| Bucket | Value |
|---|---:|
| billed_to_client | 100,000 - 1,000 = **99,000** |
| received_from_client | 60,000 + 39,500 - 39,500 + 39,000 = **99,000** |
| billed_by_vendors / paid_to_vendors | 80,000 + 10 - 10 = 80,000 / 80,000 |
| freight / freight_paid | 2,500 / 2,500 |
| commission / commission_received | 5,000 / 5,000 |
| open balances | 0 / 0 / 0 / 0 |
| gross_margin | 99,000 - 80,000 - 2,500 + 5,000 = **21,500** |
| is_balanced | true (14 entries) |
| ready_to_close | false until the one required checklist item is ticked, then true |

`po_folder` joins the tab to these balances, the open sticky count and the document count: that is the home screen, the pile.

## 5. Closing a folder

A folder has three states: `open`, `pending_close` and `closed`.

- **Open to pending_close.** Anyone who can write (clerk and up) requests a close. This is the sticky note; the database stamps who and when.
- **To closed.** A manager, admin or owner signs off. The database reads `po_balances` at that moment. If `ready_to_close` is true, the folder closes. If not, the close is refused with a message naming the open balances and open required items, unless the closer supplies a `close_override_reason`. An override is a legitimate management action (a cancelled order, a written-off balance) and shows in the history with `was_ready_to_close = false`.
- **Closed to open.** A manager, admin or owner reopens with a required `reopen_reason`. The database stamps who and when, increments `reopen_count`, and clears the close stamps and the retention date.

**The checklist.** The ledger cannot know that no more vendor bills are coming; the checklist holds those human attestations. Five items are seeded: client invoicing is final; all vendor and freight bills are posted; the commission statement is reconciled or not applicable; the invoices, remittances and freight bills are attached; the physical folder is scanned and archived. All five are **advisory** as shipped, so the paper backlog can be closed on the ledger math alone; an owner or admin makes items required later.

**The sign-off record.** Every transition writes one append-only row to `po_status_history`: from and to status, who, when, why, whether the folder was ready, and a snapshot of the balances and the checklist. The management review still happens; now it leaves a record.

**What freezes when closed.** A closed folder refuses changes to its header, line items, checklist, documents and ledger. Notes may still be added; only the legal hold may change. On close the database stamps `retain_until` as the close date plus `retention_years` (the test bootstrap uses 7 years as an example; the plan's default is empty, meaning keep forever, until the owner sets a number under Q44). Closed or held folders cannot be deleted, even by an operator.

## 6. Who can do what

The role lives on `tenant_memberships.role`. The matrix is enforced twice on purpose: in the RLS policies (a failure returns zero rows or a bare `42501`) and in the write triggers (a precise message). Both paths are tested.

| May ... | owner | admin | manager | clerk | viewer | auditor |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| read folders, lines, documents, pages, jobs, ledger, notes, parties, history | x | x | x | x | x | x |
| read the audit log | x | x | x | | | x |
| create and edit parties, open folders, lines, documents, notes; post ledger entries; request and withdraw a close; tick checklist items; create pages and extraction jobs | x | x | x | x | | |
| raise a marking (none or fci up to cui, itar or ear) | x | x | x | x (US persons only) | | |
| close a folder (needs `ready_to_close` or an override reason); reopen (needs a reason) | x | x | x | | | |
| lower or change a controlled marking; move a document out of a controlled folder; restore a deleted document; place or lift a legal hold; delete parties, checklist items, extraction jobs; edit or delete other people's notes | x | x | x | | | |
| add members, deactivate users, change e-mail or login link, attest US persons (never oneself), edit checklist templates, renumber a folder | x | x | | | | |
| grant or revoke the owner role; change company name, slug, settings, retention | x | | | | | |
| change `tenants.is_active` or the marking ceiling; create tenants | operator only (a superuser or the migration role running `bootstrap_tenant`) | | | | | |

Nobody may change their own membership; the last active owner cannot be demoted, deactivated or removed, not even by an operator; authors may edit their own notes. The likely office mapping: the business owner as `owner`, Ross as `admin`, the office manager as `manager`, sales and purchasing as `clerk`, the outside accountant as `auditor` (Q25 confirms).

## 7. Export control in the database

**Markings and their order.** `control_marking` is `none`, `fci`, `cui`, `itar` or `ear`, in that order. The order is a visibility ladder, not a legal ranking: when two markings meet the database keeps the higher one, and "lowering" means moving down the list. `none` and `fci` are visible to everyone in the company; `fci` is contract-sensitive but not export-controlled. `cui`, `itar` and `ear` are **controlled**. `classified` is not in the list and never will be.

**US-person attestation.** `users.is_us_person` is the gate and defaults to false. Only an owner or admin of the same company can set it, for somebody else. The database stamps who attested and when; a check constraint makes self-attestation impossible even for a superuser; `us_person_basis` records the evidence. A new installation therefore needs two humans before anyone can see a controlled row. That is intended.

**What a non-US person cannot see.** For a user whose flag is false, controlled rows do not exist. Folders and documents are checked on their own marking. Everything under a folder (lines, ledger entries, notes, checklist items, history) is visible only if the folder is, through a lookup on `purchase_orders` that itself runs under the same rules; pages and extraction jobs inherit from their document. The views are `security_invoker`, meaning they run with the reader's permissions, so joins and views cannot widen visibility; search runs as the caller too. Every audit row is gated against the live folder it belongs to, so a non-US auditor sees no controlled row, title, memo or amount. Non-US persons cannot create controlled rows or raise a folder into a marking they may not see.

**Marking inheritance.** When a document is filed or refiled, its marking becomes the highest of its own, the folder's, and the version it replaces. Raising a folder raises every document in it; lowering never cascades. Moving a document out of a controlled folder needs a manager, and the document keeps its marking, so refiling a scan somewhere harmless cannot declassify it. One caveat: a document's history while it sat in the inbox stays readable if it was marked only later, so the application should set the marking at intake.

**The tenant ceiling.** `tenants.max_control_marking` is the highest marking any folder or document of the company may carry. On-prem is provisioned with `ear` (everything); the hosted profile with `fci`, so a hosted tenant cannot store a controlled row at all. Only an operator can change it, never below existing rows. It is the data-layer twin of 04-cloud-vs-onprem.md.

**The known side channel.** PO numbers are one series per company. If PO-00041 and PO-00043 are visible and PO-00042 is not, a non-US person can infer that a controlled folder exists, though nothing about it. The same holds for the per-company `seq` on audit rows. The mitigation is a separate number series for controlled folders: one line in the folder insert trigger, plus a matching rule for the audit sequence. It changes how folders are numbered on paper, so it is the owner's call (section 12, question 5).

## 8. Tenant isolation, and how it is enforced

**`tenant_id` on every company table, with RLS enabled and forced on all 16 tables.** Fourteen tables carry `tenant_id NOT NULL`; `tenants` is the company itself, and `users` is global by design so one person can belong to several companies in a hosted edition (section 9 covers what a company may learn about outsiders). Forcing RLS means the policies bind the table owner as well as ordinary roles.

**Composite foreign keys.** Every child points at its parent with two columns: `(tenant_id, po_id)` must match `(tenant_id, id)` on `purchase_orders`, and so on for every link. PostgreSQL checks foreign keys without applying RLS, so a one-column key would accept a parent in another company. The composite key makes "child and parent share a company" a hard rule for every code path, including superusers.

**Policies only call helper functions**: which company, who, are they an active member, what may their role do, which markings may they see, is the parent folder visible. No policy holds business logic, and only two helpers change on a different platform (section 10).

**The session-context contract.** The database never learns who is asking from the connection. The application tells it, inside every transaction:

```sql
BEGIN;
SET LOCAL app.tenant_id = '<tenant uuid>';
SET LOCAL app.user_id   = '<user uuid>';
-- ... statements ...
COMMIT;
```

`SET LOCAL` dies with the transaction, so a pooled connection cannot carry one request's identity into the next. The application asserts **who** and **where**, nothing else; the role and the US-person flag are looked up by the database.

**Fail closed.** A missing, empty or malformed setting parses to NULL, never to an error. With NULL every helper is false, every select returns zero rows and every write is refused with `42501`. A non-member, a deactivated user or an inactive company gets the same.

**Three database roles** (PostgreSQL roles, not office roles). `BYPASSRLS` is a role attribute that makes PostgreSQL skip row-level security entirely; superusers skip it too. That is why the brief's "RLS filters every query" was oversold (02-brief-critique.md section 4.4): any service connecting with a bypass role is an isolation bypass.

| Role | Logs in | Bypasses RLS | Purpose |
|---|---|---|---|
| `app_owner` | no | no | Owns the schema. Migrations and operator tasks only; without a context it sees zero rows. |
| `app_user` | no | no | The runtime role. A login role (for example `po_api`) is granted it. It owns nothing and cannot weaken the schema. |
| `app_security` | no | **yes** | The only bypass role. It logs in nowhere and owns only the privileged functions that read memberships, write the protected logs, and provision tenants. |

The migration refuses to run if `app_user` or `app_owner` can bypass RLS or if `app_security` can log in.

**The append-only triple lock.** `ledger_entries`, `po_status_history` and `audit_log` are append-only at three layers: `app_user` has no update or delete privilege; there is no update or delete policy; and a trigger refuses update, delete and truncate even for the owner and superusers.

**The audit log** is written only by a trigger running as `app_security`; the application has no insert privilege on it, so it cannot forge rows. Every row carries before and after values, the folder, the effective marking, the actor and their role.

**"The application is the trust boundary", honestly.** Any connection holding the `app_user` credential may assert any tenant and user pair. The database trusts that for who and where, and derives only role and US-person status from it. A direct connection with that credential can therefore act as any user in any company by naming their ids. The red team confirmed this, and that it is by design: it is inherent to any session-settings or token model. What contains it is the posture: the credential lives on the office server only; the middleware sets the context from an authenticated login session, never from anything the browser sends; the database is unreachable from outside the compose network; and the on-prem installation has one company. The database credential is as sensitive as full access to every folder, and the runbook must treat it that way.

## 9. How it was tested and attacked

**The 418-check suite.** `schema/tests/rls_tests.sql` is a self-checking script; every check prints `PASS:` or aborts the run. `schema/tests/run_tests.sh` drops and re-creates a database, applies the migration, runs the suite and exits non-zero on any failure. It is the CI gate for every change under `schema/migrations`. The operator ran the final migration and suite on a fresh PostgreSQL 16 database on 2026-09-24 and all 418 checks passed. The suite runs almost entirely as `app_user` with the same `SET LOCAL` context the application would set; a superuser is used only for setup, two labelled belt-and-braces sections and the red-team regression bookends.

What it asserts: every table is enabled and forced, no one-column key points at a company table, every update policy is symmetric, exactly 16 tables; no context, a malformed context, a non-member or a deactivated user see and write nothing; the membership, attestation and last-owner rules; every table's write rules and the ledger worked example; the close-out lifecycle; export-control gating for a non-US manager through every table, view, join and search; tenant isolation (an owner of company A against every row of company B, inserts with the other company's id, cross-company children); the audit log; the superuser belt-and-braces (append-only and composite keys hold with RLS bypassed, closed and held folders cannot be deleted, the ceiling cannot be lowered under existing rows); the migration role fails closed; `app_user` cannot weaken the schema; and one regression per red-team break.

**The red team.** A separate pass ran 41 attacks in one round against a live database. What held: tenant isolation of business data (zero rows of the other company readable, updatable or deletable across all 16 tables and 4 views; every cross-company child insert rejected); export-control gating (a non-US manager could not reach the ITAR folder or anything under it, directly, through joins, views, search or the audit log, and could not self-attest); fail-closed behaviour; the append-only rules and the state machine; role gates; the schema itself (`app_user` could not disable or replace any trigger, helper or policy, or grant itself a privileged role); and error-message hygiene (a cross-company, a controlled and a nonexistent parent all produce the same "not found" message).

**The two leaks found.** Both low severity. No business data ever crossed companies, and both are moot for a single-company on-prem installation. Both were fixed, with a regression check each.

- **RT-1: identity oracle.** The login helpers `resolve_user` and `resolve_user_by_subject` resolved any e-mail or login subject to a user id from any context, and `add_member` would then attach that person from another company and reveal their name. The README had claimed the helpers "return only the caller's own rows", which was false. Fix: the helpers run only in a context-free transaction (the login path) and raise `42501` inside any request; `add_member` refuses (`23505`, changing nothing) to link an identity with no membership in the caller's company; and the application's insert privilege on `users` was revoked. What remains, documented: an owner or admin who tries to add an e-mail registered in another company learns that it exists somewhere, and nothing else. Closing that needs the hosted edition's invitation flow.
- **RT-2: write-volume side channel.** `audit_log.seq` was one counter shared by every company, so gaps in a company's visible numbering disclosed how many writes other companies and hidden controlled rows had made; the transaction id column had the same property. Fix: every company gets its own audit sequence at provisioning, so it sees 1 to n over its own n rows, and the transaction id was replaced by the transaction's start timestamp.

**What was not done.** The fixes were regression-tested but not re-attacked; the red team ran in lean mode, one round. The Phase 1 plan schedules a second round against the fixed schema. The suite is thorough, but it was written by the people who wrote the schema, and it tests what they thought of.

## 10. Running it on Supabase later

The decided stack uses no Supabase platform; this section exists because portability was designed in and checked. Nothing in the migration references any hosted-platform object. `schema/supabase/0002_supabase.sql` does three things: it redefines the two context helpers so that `current_user_id()` reads the platform's login id and `current_tenant_id()` reads a `tenant_id` claim from the request token (missing or malformed means NULL, which means zero rows, as on-prem); it grants `app_user`'s privileges to the platform's `authenticated` role; and nothing else. Every policy, trigger and view keeps working because they only ever call those two helpers.

The caveat: the adapter is **untested against a real Supabase project**. It has only been shown to parse and behave against a stub `auth` schema on plain PostgreSQL 16 (`tests/supabase_stub_check.sh`). Creating the bypass role needs a superuser on some hosted versions, and the file store's policies would have to mirror the document rules. Real validation is a Phase 4 task, only if a hosted edition is built.

## 11. What is deliberately not in Phase 1 and where it plugs in

**Phase 2 hooks in place.** `documents.po_id IS NULL` is the inbox; `documents.extraction_status` stays `not_started`. `document_pages` holds page images and, later, OCR text with its search index already defined. `extraction_jobs` is the placeholder for AI extraction: status, engine, confidence, the JSON result, the reviewing human, and `applied_po_id`; nothing in it reaches the ledger without a person. Quote tracking starts with the four quote reference fields in migration 0002; a full quotes table is a Phase 2 design. On-prem, extraction gates on the document's marking, so controlled scans never leave the box.

**Phase 3 hooks in place.** `parties.external_refs` and `purchase_orders.external_refs` are JSON slots for accounting-system ids; no connector is built. The `tracking_*`, `shipped_at` and `delivered_at` columns on line items are the shipment placeholders; no carrier integration is built. The period lock and a reconciliation-matches table were removed on purpose; they return with the accounting integration.

**Migration 0002, after the discovery answers.** These gaps between the schema as built and what the critique and questions call for are known. They wait for the office's answers rather than editing 0001 now.

| Addition | What it is | Decided by |
|---|---|---|
| `deal_type` on `purchase_orders` | resale, commission or mixed; changes what "balanced" means. | Q5, Q6, Q11 |
| Quote reference fields | `quote_number`, `quote_date`, `quoted_client_total`, `quoted_vendor_cost`, so quote and actual can be compared. | Q15, Q16 |
| A `filed` state and a shelf or physical-location field | After `closed`: "the paper is in cabinet 3, drawer 2", so the printed cover sheet and the record find each other. | Q13, Q23, critique 3.6 |
| A `proprietary` control marking | For NDA-covered customer material such as Sikorsky's: confidential by contract rather than by export law. | Q29, Q31 |
| An optional payments header table | One check covering several folders shown as one record with allocations; today it is one ledger entry per folder sharing the reference. | Q8, if the bookkeeper wants it |

One more item, resolved in the plan rather than in 0002: the decision record and the critique say an unmarked document is treated as controlled until a person confirms it, but the marking list has no "unreviewed" value. The application enforces it: an incoming file waits in an intake quarantine, treated as the most restrictive marking the company handles, and the `documents` row is created only when a person sets the marking (plan tasks F2 and F4). No enum value is needed.

## 12. Open questions for the owner

Each has a default the build proceeds under.

1. **Freight.** Billed through to the client (then it nets out on the client side) or absorbed? Today freight has its own open balance, and an unpaid freight bill stops a folder from being ready to close. (Q9)
2. **Commission per folder.** If one commission statement covers several POs, the office must split it per folder for the commission balance to reach zero. Acceptable? (Q6)
3. **Which checklist items block a close**, for the paper backlog and for new folders? Today all five are advisory. (Q13)
4. **Retention.** How long are closed folders kept (the build default is forever; the test example uses 7 years), and who may place a legal hold? (Q44)
5. **A separate PO number series for controlled folders**, so non-US staff cannot infer their existence from numbering gaps. It changes how folders are numbered on paper; the same choice covers the audit numbering. (Q3, Q26)
6. **Who attests US-person status**, and on what evidence? Two humans, an owner and an admin, are needed before anyone can see ITAR rows. (Q26, Q27)
7. **Controlled documents in uncontrolled folders.** Does the office ever hold an ITAR drawing inside an otherwise commercial order? The schema allows it; the screens should make it visible. (Q31)
8. **Hosted edition only.** When a person already on the platform is invited into a second company, should that be an operator action (today) or a self-service invitation the person accepts after logging in?

For the builder: whether to keep the real transaction id for forensics in a hidden column; whether the login path should get its own database role (deferred); confirming one audit sequence per company suits provisioning and the backup runbooks; and that any database made from an earlier draft of 0001 (none exist for the launch customer) needs an expand-and-contract migration rather than a re-run.
