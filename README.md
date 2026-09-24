# Ross Machinery Sales platform

Private repository. The purchase-order folder system for Ross Machinery Sales: one place for every Project
Order folder, its documents, its money, and whether it is balanced and can be closed. Built first for
Ross Machinery Sales on its own server; designed so the same code can later be sold to similar companies.

This repository holds code, documents, synthetic test fixtures and the database schema. It never holds real
purchase orders, invoices, drawings, scans, database dumps, logs or secrets. See "Standing rule on real
data" below.

## Status (2026-09-24)

Phase 1 planning is complete. The database schema (`schema/migrations/0001_init.sql`) is written, passes a
418-check row-level-security test suite on a fresh PostgreSQL 16 database, and has been through one
red-team round (41 attacks, two low-severity leaks found and fixed). The Phase 1 build starts per
`docs/06-phase1-plan.md`.

## Read in this order

| File | What it is |
|---|---|
| `docs/00-gemini-brief-original.md` | The original brief, kept for reference. Superseded by the documents below. |
| `docs/01-owner-context.md` | What the owner actually asked for, the security posture, and the commercial intent. Wins over the brief. |
| `docs/02-brief-critique.md` | What the brief got right, what is missing, risky or over-scoped, corrected facts, and the first version in one paragraph. |
| `docs/03-data-model-and-rls.md` | The database design explained in folder terms: the ledger, closing a folder, roles, export control, tenant isolation, how it was tested and attacked. |
| `docs/04-cloud-vs-onprem.md` | The decision on the on-prem ("sovereign") and cloud profiles, the stack, the AI policy by marking, compliance split, air-gapped mode. |
| `docs/05-discovery-questions.md` | The questions to take to the office, with why each matters and the default we build under if unanswered. |
| `docs/06-phase1-plan.md` | The Phase 1 plan: definition of done, decision gates, 58 small tasks, week-by-week shape, risks. |
| `schema/README.md` | Technical reference for the schema: apply and test, the session-context contract, roles, export-control gating, adding a table safely. |

## Schema quick start

Requires PostgreSQL 16 and a superuser for the test run (the script creates roles and a throwaway database).

```bash
cd schema
PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres tests/run_tests.sh
```

Expected last line: `== ALL RLS TESTS PASSED: 418 checks`.

## Standing rule on real data

1. Never put a real PO, invoice, drawing, ledger sheet, or anything carrying a CUI or ITAR legend into any AI
   coding session, cloud or local, or into any commercial AI API.
2. Never commit real documents or real data to this repository.
3. Develop and test with synthetic fixtures only: made-up companies, PO numbers, amounts and generated PDFs.
4. Real-document testing happens only on the office server, in the sovereign profile, with the extractor off.
5. A bug that only reproduces with a real document is reproduced on-site.

## Layout

```
docs/       planning documents (numbered, read in order)
schema/     SQL migrations (source of truth for the database), tests, README, Supabase adapter
```

The Django application, compose files, fixtures and CI arrive with Phase 1 tasks B1 to B6 in
`docs/06-phase1-plan.md`.
