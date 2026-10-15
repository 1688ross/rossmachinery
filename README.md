# Ross Machinery Sales platform

Private repository. The purchase-order folder system for Ross Machinery Sales: one place for every Project
Order folder, its documents, its money, and whether it is balanced and can be closed. Built first for
Ross Machinery Sales on its own server; designed so the same code can later be sold to similar companies.

This repository holds code, documents, synthetic test fixtures and the database schema. It never holds real
purchase orders, invoices, drawings, scans, database dumps, logs or secrets. See "Standing rule on real
data" below.

## Status (2026-10-13)

The platform runs on synthetic data: control panel, folders with money and deliverables, document
filing with previews, the actions behind every square, quotes with PDF, and a second-factor sign-in.
Schema migrations 0001 to 0003 pass a 436-check row-level-security suite. Next: quotes into the main
schema with "start a folder", the automatic readers, then the office install.

## Run it on your Mac (or any machine with Docker)

1. Install Docker Desktop from docker.com and start it.
2. Get the code: in VS Code, clone `github.com/1688ross/rossmachinery` (or `git pull` if you have it).
3. In a terminal inside that folder:

   ```bash
   docker compose up
   ```

   The first start downloads Postgres and builds the app (a few minutes). When the log says
   `serving on :8000`, open **http://localhost:8000** and sign in as `ashley` / `devpass123`.
   Other sample logins: `chuck`, `tammie`, `zach`, `ross` (same password).

Everything you see is invented sample data. Stop with Ctrl+C; start again with the same command and
the data is still there. `docker compose down -v` wipes it and the next start is fresh.

To pick up a new version: stop it (Ctrl+C), then

   ```bash
   git pull
   docker compose up --build
   ```

`--build` matters: the app image carries a copy of the code, so a plain `up` keeps running the old one.

The office install uses the same two files with four settings changed in a `.env` beside them:
real passwords (`RMS_DB_ADMIN_PASSWORD`, `RMS_DB_APP_PASSWORD`, `DJANGO_SECRET_KEY`), the server's
name in `DJANGO_ALLOWED_HOSTS`, `RMS_SEED_DEMO=0`, and `RMS_REQUIRE_2FA=1`. The container refuses to start
with the second factor off on anything that is not a demo.
See `docs/09-deployment-notes.md`.

## Read in this order

| File | What it is |
|---|---|
| `docs/00-gemini-brief-original.md` | The original brief, kept for reference. Superseded by the documents below. |
| `docs/01-owner-context.md` | What the owner actually asked for, the security posture, and the commercial intent. Wins over the brief. |
| `docs/02-brief-critique.md` | What the brief got right, what is missing, risky or over-scoped, corrected facts, and the first version in one paragraph. |
| `docs/03-data-model-and-rls.md` | The database design explained in folder terms: the ledger, closing a folder, roles, export control, tenant isolation, how it was tested and attacked. |
| `docs/04-cloud-vs-onprem.md` | The decision on the on-prem ("sovereign") and cloud profiles, the stack, the AI policy by marking, compliance split, air-gapped mode. |
| `docs/05-before-we-start.md` | The five things to know before starting, and the rule that everything else is learned by using the screens. (The long question list is kept as an appendix.) |
| `docs/06-phase1-plan.md` | The Phase 1 plan: definition of done, decision gates, 58 small tasks, week-by-week shape, risks. |
| `docs/07-control-panel-spec.md` | The screens: the control panel with green, yellow and red lights, what clicking a light shows, and the top of a PO page. |
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
