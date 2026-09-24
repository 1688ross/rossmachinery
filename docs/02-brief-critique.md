# Critique of the Gemini brief

Ross Machinery Sales PO platform. Written 2026-09-24 for Ross, then the office staff and the outside accountant.

This merges 63 findings from four reviews (product, security and compliance, engineering and operations, finance and bookkeeping) and 48 fact checks. The appendix indexes every finding by id; bracketed numbers point to Sources. Phases follow the rebuilt plan: Phase 1 is the schema and a manual folder tracker on the office server, Phase 2 is AI-assisted capture and quoting, Phase 3 is integrations, and the multi-customer edition follows a second customer.

## 1. The verdict in one paragraph

The brief read the paper folder correctly. Its account of the folder matches what Ross saw, and its bones are sound: one record per folder, categorized line items, documents and notes attached to that record, a person confirming data before it is saved, PostgreSQL with row-level security (a database rule that hides rows a user may not see) keyed to a tenant id, and Docker for delivery to the office server. Almost everything else is wrong for a first version. It never replaces the sticky note with a way to close a folder, never computes a balance, and omits quoting, users, search, reports and the backlog. It stacks hosted services against the owner's rule that the system lives on their server only. It uses the word classified loosely, oversells what row-level security and AES-256 protect against, names an AI model retired in October 2025, assumes an accounting product nobody has confirmed, and gives the office no screen before week six. The reframing in one sentence: the brief describes a venture-scale software-as-a-service product; the office needs a digital folder that can be balanced and closed; the multi-customer service is a later edition of the same product, so we build the folder first and keep every door to the second edition open.

## 2. What the brief gets right and we keep

All four reviews agree on what survives.

- **The folder is the record.** One record per Project Order folder with the tab fields and four top-sheet totals; the accountant agrees the folder is the job that must balance.
- **Line items with a category.** The list was lost in export (4.3); the idea is right.
- **Documents and notes on the parent record.** Kept as attach-a-file, not a mailbox integration, because email may itself be controlled.
- **A human confirms before anything is saved.** Human-in-the-loop (HITL) verification is right even with no AI: it is the accountant's gate to the books and where a person records what kind of document this is (section 7).
- **PostgreSQL with row-level security on a tenant id.** A tenant is one customer company. Kept on every table from day one because Ross intends to sell the product, with the fixes in 4.4.
- **Schema-constrained extraction.** The AI may only write into a fixed shape; the tooling changes, the principle stays.
- **Docker for delivery.** Moves from week 10 to Phase 1 as the default delivery: two or three containers, a compose file, a runbook.
- **Per-integration switches.** The per-client feature flags become a deployment configuration (logo, on/off per integration, all off on-prem): the seed of the egress policy and how the two editions differ without forking.
- **The accounting system stays the general ledger.** The platform is a job subledger and document system; payroll, bank feeds and tax filings stay out.
- **One application runtime, not three.** The brief's instinct to keep the web app boring is right. The stack itself changes: the decision record (04-cloud-vs-onprem.md) replaces Next.js + Supabase + FastAPI with one Python/Django application, plain PostgreSQL and a Postgres-backed worker, so the whole system is one language and one image.

## 3. What is missing

### 3.1 No close-out workflow

The brief names the sticky notes as the problem and never replaces them: no lifecycle, no rule for when a folder may close, no sign-off, no filed state, only a free-text Overall Status.

**What we do:** Phase 1. Statuses open, needs review, ready to close, closed, filed; a needs-review flag with a reason; a Manager-only Close and Reopen recording who and when; a home screen that is the pile, showing what each folder waits on.

### 3.2 No balance model, ledger or reports, and the deal type is unasked

The brief treats the four totals as extraction targets and dismisses the hand-written payment table as "difficult to decipher". Nothing records a deposit, a partial payment or which payment paid which invoice, so no balance can be computed; there is no posted-versus-draft boundary, reversal, period lock, audit trail, credit memo or report. It never asks whether a deal is buy-and-resell (commission is margin) or manufacturer's-rep (the builder pays a commission).

**What we do:** Phase 1. Typed, append-only ledger entries with a line type and billable-to-client flag; corrections reverse; every row carries who and when; periods lock; a deal type per folder. Five reports, built as database views, plus month-end reconciliation to the accounting system by document number and amount.

### 3.3 Folder shape and master data are unresolved

The tab has one Vendor Name and one Vendor Billing Total, yet the brief describes "a variable stack of vendor invoices". Client Order # (customer to company) and Internal PO # (company to vendor) differ, and a folder can hold several of the latter. Clients and vendors are free-text names that drift and break every report by party.

**What we do:** Phase 1 schema: a project (the folder) with one or more vendor orders under it, and a parties table (client, vendor, carrier, builder) referenced by id everywhere. One vendor per folder becomes a screen choice.

### 3.4 Quoting and invoice authoring are undecided

The owner named "invoices, billing, quoting"; the brief has no quote and treats client invoices only as inputs to file. If they are produced here, numbering, templates and a frozen copy shape the ledger; if in the accounting system, the tool must never become a second invoice source.

**What we do:** Ask before the schema freezes. Phase 1 captures quote number, date and quoted totals, records invoices with an origin flag (issued here or captured), and reserves a number-sequence table. Quote lines and invoice generation come in Phase 2.

### 3.5 Users, roles and headcount are undefined

The brief never says who in this office uses the tool, how many, or what each may do. There is no multi-factor authentication (MFA: a second proof at login) and no record of who may see export-controlled documents.

**What we do:** Phase 1: roles in a table (owner, admin, manager, clerk, viewer, auditor, as in the schema); MFA enforced at first login; a recorded US-person and controlled-data authorization per user (an HR decision the software enforces); an append-only audit log.

### 3.6 No search and no physical location

"Find the folder" is the most frequent job in the room, yet the brief has no list, filter or search requirement. The system must also say where the paper is.

**What we do:** Phase 1: one search box over every identifier, filters by status, party, year and balance, a shelf-location field, and a printed cover sheet so paper and record find each other. OCR text joins the index later [40] [41].

### 3.7 No backlog or cutover strategy

The brief gives no volumes. It does not separate the open pile from the closed archive. Go-live starts with hundreds of half-paid folders; without opening balances, month-end shows every legacy folder as mismatched.

**What we do:** Three tracks. Open folders entered by hand as touched, with an opening-balance entry (accounting system where possible, else the top sheet, variance flagged). Closed archive scan-and-index only, OCR on the server, shelf location recorded.

### 3.8 No plan for running the server, testing, or keeping records

"Server only" makes patching, backups, disk, power and monitoring the company's problem; the brief is silent on them. A cross-tenant leak and a silently changed dollar amount are caught by neither a build nor a type check. Nothing says how long records are kept or what stops a user deleting the only copy of an invoice.

**What we do:** Phase 1: nightly encrypted backups on-site and offsite under a company-held key, a logged quarterly restore drill, full-disk encryption and a runbook; database tests for RLS on every table, empty results without a tenant context, and unchangeable posted rows; soft delete only with a retention date and legal-hold flag, and paper kept until the digital copy is verified. If controlled data is confirmed, a FIPS-capable OS chosen before install (FIPS is the US validation standard for encryption software).

### 3.9 No network boundary and no scanner path

The brief assumes an internet-facing service; the owner says the server stays in the building. Nothing says how staff reach it or how a page gets from the copier into the system. A forwarded router port is the likeliest way "cannot be hacked" fails.

**What we do:** Phase 1: the app listens on the office network only; no public DNS, port-forward or tunnel; remote access only over a company-controlled VPN with MFA; outbound allow-list. Scans land in a watched folder, are hashed, and wait in an inbox queue for a person to attach them.

## 4. What is risky

### 4.1 "Strictly classified" is undefined, and compliance is treated as a feature

The owner says some information is "strictly classified with the government"; the brief promises "Docker packaging for classified/defense environments". If any document is classified in the legal sense, it cannot be on a self-built office server under any design (section 7). More likely the folders mix federal contract information (FCI), controlled unclassified information (CUI) and export-controlled drawings (ITAR or EAR; section 7 defines all four), and a machine-tool distributor's own data is more likely EAR than ITAR. The brief also lists "CMMC/DFARS/ITAR compliance readiness" as a stack item; it is an organizational state, not a feature.

**What we do:** First discovery question (section 7). Every folder and document carries a control marking (none, fci, cui, itar, ear), set by a person at intake; where a page is both CUI and export-controlled the more restrictive marking wins, and a separate export-jurisdiction field can be added in Phase 2 if the office turns out to need both recorded; "classified" is a hard stop; unmarked means controlled until confirmed. One short security-posture document: a threat model, a "what the company must do" list, and a control matrix at the FCI level (15 requirements), widened only if a CUI flow-down is confirmed.

### 4.2 A commercial AI endpoint on controlled documents

Any hosted API moves the document off the premises, which breaks "server only" by itself [7]. For covered defense information, the DFARS 252.204-7012 contract clause requires any external cloud service to be FedRAMP Moderate equivalent (FedRAMP is the US government's cloud security authorization program) [30] [31]; the first-party Claude API is not FedRAMP authorized, and Anthropic's FAQ says "ITAR data can only be processed in Claude via AWS Bedrock, which is IL5 accredited" (a DoD impact level) [8]. The ITAR encryption carve-out cannot help, because a vendor that reads the image holds the means of decryption [18].

**What we do:** Phase 1 builds the provider boundary and marking gate: AI off for controlled documents and off on-prem. Phase 2 wires extraction for unmarked documents only, behind an interface that can later point at Bedrock in AWS GovCloud [9] [42]. No real folder goes to any AI tool, including coding assistants, during development.

### 4.3 Three incompatible deployment stories on hosts that cannot hold the data

The brief specifies Supabase-hosted Postgres, "S3/Supabase Storage", a hosted vision API, "Azure Government Cloud or local on-prem servers". Supabase is not FedRAMP authorized and holds its own at-rest keys; Vercel is not FedRAMP authorized and may process data anywhere its sub-processors operate; Azure Government requires eligibility validation and, per the reviews, has no Claude path as of September 2026. "AES-256 storage" protects against a stolen disk, not a leaked credential; "isolated subdomains" scope cookies, not security. The export also stripped inline code (categories read "(, , , , )"); ask Ross for the original.

**What we do:** One image, two editions, decided now: a controlled edition on the company's server and a hosted edition only for customers without controlled data; adapter interfaces for AI, accounting and shipping from day one, set to none. No real folder ever enters a Supabase cloud project, a Vercel deployment or a developer laptop.

### 4.4 Row-level security is oversold; the worker and the service key are the real holes

Superusers, roles with the BYPASSRLS attribute and, by default, the table owner skip RLS, and Supabase's service key maps to a bypass role by design [16] [17]. For one tenant the real threat is a leaked worker credential or RLS silently off on a new table, and the file store has its own policy surface.

**What we do:** Phase 1: plain PostgreSQL; app and worker on a non-bypass role setting the tenant per transaction; FORCE RLS everywhere; an automated build check for missing policies; documents served only through a policy-checking API route that logs downloads.

### 4.5 QuickBooks is assumed, and two-way sync means two ledgers of record

The owner never mentioned QuickBooks; only the brief does. The office may run QuickBooks Desktop or Enterprise, which use a different Windows-only integration [39]. Two-way sync lets both systems create and change the same invoice, and the Online change feed looks back only 30 days [37].

**What we do:** Ask first: which product and edition, who owns the books, where invoices are made. Decision now: the accounting system is the general ledger, the platform is the subledger, sync is one-way per document type, and the on-prem edition can ship with no connector.

### 4.6 Handwriting extraction will not remove the human

The table the owner calls "difficult to decipher" will not extract better than a person reads it. Shape validation cannot catch a misread digit, and auto-posting the notes table would create phantom payments.

**What we do:** Phase 1: a manual form laid out like the top sheet beside the scanned page, and an extractions table (draft JSON, confidence, model id, schema version, prompt hash) with no path into the ledger. Phase 2: pre-fill only, with invoice arithmetic as a blocking check.

## 5. What is over-scoped for the first version, and when it comes back

Nothing here is dropped; each item has a return condition and a Phase 1 hook.

| Item | Why not now | When it returns | What Phase 1 does to keep the door open |
|---|---|---|---|
| Multi-tenant SaaS | One customer on their own server; hosted multi-tenant cannot hold controlled data. | Second customer, likely a deployable bundle plus an optional hosted edition for uncontrolled data. | tenant_id and RLS on every table; composite (tenant_id, id) foreign keys; no company-specific hard-coding. |
| White-labeling | One brand; Ross holds its brand system. | Second customer. | UI themed from the brand system via a config file. |
| Feature-flag system with admin UI | SaaS polish; the editions still need to differ. | Second customer. | Static deployment config with per-integration switches, off on-prem. |
| Isolated subdomains | Cosmetic; no public hostname on-prem. | Hosted edition. | Nothing; the boundary is the database role and RLS policy. |
| AI vision extraction with split-screen HITL UI | Typeable data; handwriting is the worst target; a hosted API contradicts server-only; the named model is retired. | Phase 2, unmarked documents only, as pre-fill; controlled documents only via a government-authorized route or a local model; the batch endpoint halves backlog cost on the public API [10]. | documents and extraction_runs tables; the marking gate; a provider interface defaulting to none. |
| EasyPost tracking webhooks | The folder tracks money, not shipments; webhooks need an inbound public endpoint; freight coverage unverified. | After three months of real shipments show which carriers occur; polling, not webhooks, on-prem. | A shipments table (carrier, tracking, PRO or BOL number, dates, status) and per-carrier link template. |
| QuickBooks Online bi-directional CDC (change feed) sync | Product unconfirmed; two ledgers of record; 30-day change window; Intuit app review. | Phase 3, one-way per document type, once the product is confirmed. | Accounting reference numbers on ledger entries, an export view, a per-field sync-allowed rule, CSV export. |
| Azure Government and "classified environments" | Classified material can never be here; Azure Government has no Claude path. | A government-eligible cloud (AWS GovCloud is the documented Claude path) only if a customer needs a hosted controlled edition. | Same image with a hosted profile; adapters that can point at Bedrock in GovCloud. |
| The 12-week four-phase plan | Front-loads infrastructure; omits closing, quoting and balancing. | The phase order survives; the calendar does not. | Week three ends with staff entering real open folders. |

## 6. Corrections to facts in the brief

Rows rest on fact checks run on 2026-09-24 (the Next.js row on the engineering review). Some government sites were unreachable, so some rows rest on indexed excerpts; eyeball them before publishing outside the company.

| Claim in brief | What is actually true (as of 2026-09-24) | Source |
|---|---|---|
| "Anthropic Claude 3.5 Sonnet / Vision API" with "Pydantic & Instructor" | Retired from the Claude API October 28, 2025 and since gone from Bedrock. The current lineup is the Claude 5 family (Fable, Opus, Sonnet and Haiku tiers), and which one Anthropic recommends has changed more than once in 2026. Do not pin an id in any plan; choose the current Opus-class model at the time of Phase 2 and record it in the extraction run. PDFs go straight into the messages API and JSON-schema structured outputs are native, so no separate Vision API and no Instructor. | [1] [2] [3] [4] [5] [6] |
| "Next.js 15 (App Router)" | Next.js 16 is the active line (released October 2025; 16.3.x current); 15 receives security patches only; security releases arrive roughly monthly. Confirm against the release notes. | Engineering review, engineering_ops-3 |
| "EasyPost API (real-time tracking webhooks for machinery & freight)" | The standard Tracking API creates a tracker from a carrier tracking code and covers 100+ carriers; it is parcel-centric. Freight and LTL (PRO numbers, bills of lading) sit in the separately sold EasyPost Enterprise product. Freight-carrier coverage is unverified. | [11] [12] [13] |
| "PostgreSQL on Supabase" and "S3/Supabase Storage", alongside "server only" | A self-hosted Docker Compose distribution exists (13 components), but Supabase says the default configuration is not secure for production, self-hosting is community-supported, and there are no managed backups or point-in-time recovery. | [14] [15] |
| "CMMC/DFARS/ITAR compliance readiness" | DFARS 252.204-7012 requires NIST SP 800-171; Class Deviation 2024-O0013 (May 2, 2024, in effect until rescinded) pins that to Revision 2 (110 requirements, 14 families) although Revision 3 (97 requirements, 17 families) was published May 14, 2024. The CMMC rule (32 CFR 170) took effect December 16, 2024; CMMC Phase 2 was suspended July 13, 2026; self-assessments and clause 7012 remain in force. None of it is a software feature. | [30] [32] [33] [34] [35] [36] |
| "AES-256 encrypted storage" as the ITAR answer | The carve-out (22 CFR 120.54(a)(5), effective March 25, 2020) has five conditions: unclassified; end-to-end encrypted, with the means of decryption given to no third party; modules compliant with FIPS 140-2 or successors, or means at least as strong as AES-128; not sent to or stored in a 126.1 country or Russia; not sent from one. Provider-held keys fail the third-party condition. | [18] [20] [22] |
| "RLS policies filter every query by tenant_id" | RLS applies to normal row access by every role except superusers, BYPASSRLS roles and, by default, the table owner. FORCE ROW LEVEL SECURITY extends it to the owner, never to superusers or BYPASSRLS roles; TRUNCATE and REFERENCES are exempt. Any BYPASSRLS service or migration role is an isolation bypass. | [16] [17] |
| "Docker packaging for classified/defense environments" | Classified information may be processed only on a contractor system that the Defense Counterintelligence and Security Agency (DCSA) has authorized in advance, at a facility with a Facility Clearance and approved safeguarding, under the NISPOM, the industrial security rulebook (32 CFR 117, effective February 24, 2021). DCSA's process manual (DAAPM) was superseded by the DCSA Assessment and Authorization Guide dated August 31, 2025. | [23] [24] [25] [26] |
| "QuickBooks Online REST API (OAuth 2.0 ... CDC incremental sync)" | The endpoint exists: OAuth 2.0, one-hour access tokens, refresh tokens with a five-year maximum validity since January 2026, and a change-data-capture call that looks back at most 30 days. QuickBooks Desktop and Enterprise integrate through qbXML and the Windows Web Connector instead. The office's product is unconfirmed. | [37] [38] [39] |

## 7. About the word classified

Four things get called classified. Only one is.

**Classified** means Confidential, Secret or Top Secret under the national security rules. A contractor may hold it only in a facility with a Facility Clearance, on an information system DCSA has authorized before use [23] [25]. Genuinely classified material never enters this system, and the app refuses a "classified" marking.

**Controlled Unclassified Information (CUI)** is unclassified information the government requires to be handled with safeguards. It is a control, not a classification, and by definition excludes classified information [28]. For a DoD supplier it arrives through a contract clause (DFARS 252.204-7012), which points at NIST SP 800-171 and requires any outside cloud service to be FedRAMP Moderate equivalent [30].

**ITAR and EAR technical data** are export-control regimes. ITAR covers information required to design, build, test or repair defense articles: drawings, specifications, instructions [21]. Basic marketing information and general descriptions are excluded, so a purchase-order line is usually not technical data, while the drawing behind it may be. Showing such data to a foreign person inside the United States counts as an export [19]. EAR covers dual-use items such as many machine tools. Government-furnished export-controlled information is also a CUI category [29].

**Federal Contract Information (FCI)** is the mildest: non-public information provided by or generated for the government under a contract, with 15 basic safeguards [27].

Why it matters: each regime decides who may see a document, whether any outside service may touch it, and what the company must do beyond the software. The regime attaches per document, so the schema marks each one.

The one question that decides it: what do the actual documents and contracts say? Has a customer, a contract clause or a government letter ever told the company, in writing, that a specific document or contract is classified, CUI, ITAR or EAR controlled, and does the company hold a Facility Clearance? The answer sorts every folder into one of these buckets.

## 8. The first version, in one paragraph

The first version is a single-tenant-in-practice, multi-tenant-in-schema digital folder for Ross Machinery Sales: two or three Docker containers on the office server, plain PostgreSQL with row-level security on every table, one Django application that owns login with enforced MFA, a Postgres-backed worker, and an encrypted filesystem document store. Each Project Order folder is one record with the tab fields and four top-sheet totals, the client and one or more vendor orders against named parties, and a typed, append-only ledger of invoices, bills, credits, payments, freight and commission, from which balances and margin are computed rather than deciphered, with reversals, period locks and an audit trail. Documents attach through an inbox queue; a needs-review flag replaces the sticky note; a status of open, ready to close, closed and filed is driven by a computed close checklist and a Manager-only Close; the home screen is the pile; five reports reconcile to the accounting system. Every folder and document carries a control marking and export jurisdiction, controlled records require a recorded US-person determination plus MFA, keys and backups stay with the company, and AI extraction sits behind a provider boundary that is off for controlled documents and can later point at Bedrock in AWS GovCloud. Open folders are hand-entered with opening balances; the closed archive is scan-and-index only. It leaves hooks for AI pre-fill, shipment tracking, one-way accounting export and quote authoring. The second-customer edition (tenant onboarding, billing, subdomains, white-label UI, feature-flag admin) waits for a second company; nothing is hard-coded to Ross Machinery Sales, so the same codebase ships as a deployable bundle and, for customers without controlled data, a hosted edition.

## 9. Appendix: finding index

Every non-refuted finding from the workflow output, grouped by lens. Ids marked (s) were added by the skeptic pass. Use the id to look up the full detail, recommendation and skeptic reasoning in the workflow output.

### Product / job-to-be-done (product)

| Id | Severity | Category | Title |
|---|---|---|---|
| product-1 | high | missing | No close-out workflow: the sticky note is named as the problem but never replaced |
| product-2 | high | missing | 'Keeping everything balanced' has no balance model; the hand-written ledger is treated as an extraction target instead of the core data |
| product-3 | medium | missing | Quoting is absent from the brief although the owner named it explicitly |
| product-4 | medium | missing | Users, roles and headcount are never defined; the brief talks about other SMBs but not this office |
| product-5 | medium | missing | No search, list or browse requirement, and no way to say where the paper folder physically is |
| product-6 | medium | missing | No strategy for the backlog of closed folders versus the open pile, nor for the digital folders that already exist |
| product-7 | high | over_scoped | Multi-tenant SaaS, white-labeling, feature flags, subdomains and a commercialization phase do not close a single folder |
| product-8 | medium | over_scoped | AI vision extraction with a split-screen HITL UI is placed on the critical path for data a person can type in two minutes |
| product-9 | medium | over_scoped | EasyPost and bi-directional QuickBooks sync solve problems the folder does not have, and the brief never confirms QuickBooks is in use |
| product-10 | high | risky | 'Classified' is undefined and the brief's three incompatible deployment stories are never reconciled with 'server only' |
| product-11 | medium | incorrect | The brief is not a buildable spec as written: stripped placeholders, wrong noun, and a phase plan that puts no usable screen in front of staff before week 6 |
| product-12 | low | keep | Keep the folder-as-record data model, documents and notes on the parent PO, the HITL stance, Postgres with RLS, and Docker on-prem (moved to Phase 1) |
| product-s1 (s) | medium | missing | Whether the app must generate client invoices ('billing') is undetermined; brief and critic both treat invoices only as inputs |
| product-s2 (s) | high | risky | Folder cardinality is unresolved: one folder may hold several vendors and several internal POs, but every proposal keeps a single-vendor header |
| product-s3 (s) | medium | missing | No client, vendor or carrier master data; names are free text on the header, so per-party balances and search will not group |
| product-s4 (s) | low | missing | Paper does not go away on day one; nothing keeps the physical folder and the digital record in sync during transition |

### Security and regulatory compliance (security_compliance)

| Id | Severity | Category | Title |
|---|---|---|---|
| security_compliance-1 | high | incorrect | "Strictly classified" must be untangled before anything is built: classified vs CUI vs ITAR/EAR vs FCI |
| security_compliance-2 | high | incorrect | Sending scanned POs to the commercial Anthropic API is a DFARS 7012 and export-control problem, and the model named is obsolete |
| security_compliance-3 | medium | incorrect | "CMMC/DFARS/ITAR compliance readiness" is an organizational state, not a product feature; here is where the rules actually stand today |
| security_compliance-4 | high | risky | The proposed cloud stack (Supabase cloud, Vercel) cannot host CUI or ITAR data; "AES-256 storage" and "isolated subdomains" are not the controls that matter |
| security_compliance-5 | high | risky | RLS is a good baseline but the brief oversells it; the ingestion worker and service_role key are the real hole |
| security_compliance-6 | high | missing | No user/identity model, no MFA, and no US-person access control for export-controlled records |
| security_compliance-7 | high | missing | No audit log, no incident-response path, and no way to meet the 72-hour DFARS reporting clock |
| security_compliance-8 | medium | risky | Every integration (QuickBooks Online, EasyPost, email threads) is an outbound data flow to a non-FedRAMP vendor; minimize fields, gate by marking, allowlist egress |
| security_compliance-9 | medium | over_scoped | "Azure Government," "classified environments," and "commercializable SaaS" pull against "lives on their server only"; pick single-tenant on-prem for v1 |
| security_compliance-10 | medium | missing | Key custody, FIPS-validated crypto, and backups are unspecified; on-prem makes them the company's problem |
| security_compliance-11 | low | keep | Keep: RLS-first data layer, split-screen HITL verification, schema-constrained extraction, Docker/on-prem packaging, and per-integration kill switches |
| security_compliance-12 | medium | missing | "Cannot be leaked or hacked by any circumstances" is not a requirement; write a one-page threat model and define "secured" against it |
| security_compliance-s1 (s) | medium | incorrect | The lens treats export control as ITAR; a machine-tool and tooling distributor is more likely EAR-facing, and the two regimes need separate fields |
| security_compliance-s2 (s) | high | missing | The document store is a second policy surface the lens never mentions: Supabase Storage has its own RLS, signed URLs are checked at mint time, and the service key bypasses it |
| security_compliance-s3 (s) | medium | missing | No decision on the network boundary or the scanner path: 'lives on their server only' still has to answer remote access, inbound exposure and how scans reach the host |
| security_compliance-s4 (s) | medium | missing | No retention, deletion or paper-disposition rules: digitizing the folders creates a records-management obligation the brief and the lens both skip |

### Engineering and operations (engineering_ops)

| Id | Severity | Category | Title |
|---|---|---|---|
| engineering_ops-1 | high | over_scoped | Three runtimes and two languages for a solo builder maintaining one office server |
| engineering_ops-2 | high | risky | Supabase as a hard dependency conflicts with 'lives on their server only' |
| engineering_ops-3 | medium | incorrect | Version currency: Next.js 15 and 'Claude 3.5 Sonnet' are stale; plan a patch cadence |
| engineering_ops-4 | high | risky | Most cloud services in the brief cannot exist inside an ITAR/air-gapped deployment |
| engineering_ops-5 | low | over_scoped | EasyPost is a parcel API; this business receives flatbed/LTL machinery freight it did not ship |
| engineering_ops-6 | high | risky | 'Bi-directional QuickBooks Online CDC sync' is the hardest possible shape and assumes they use QBO at all |
| engineering_ops-7 | high | risky | Vision extraction of hand-written ledgers will not remove the human; design it as a draft, and question the backlog |
| engineering_ops-8 | high | missing | Nothing in the brief covers running the server: patching, backups, disk, power, monitoring, encryption |
| engineering_ops-9 | high | over_scoped | The 12-week, four-phase plan builds infrastructure first and the owner's workflow never |
| engineering_ops-10 | medium | missing | No testing strategy beyond placeholder 'run build checks and test suites' |
| engineering_ops-11 | high | missing | What 'add later without refactoring' requires of the schema and repo layout |
| engineering_ops-12 | medium | keep | Keep Postgres RLS, the HITL split-screen concept, schema-constrained extraction and the Docker deliverable |
| engineering_ops-s1 (s) | high | risky | 'Strictly classified' versus CUI/ITAR/EAR is undetermined, and it decides whether this system may exist at all |
| engineering_ops-s2 (s) | medium | missing | No network boundary defined for a LAN-only server: TLS, remote access, OAuth redirect and inbound exposure |
| engineering_ops-s3 (s) | medium | missing | The on-prem ingestion path (scanner to server, and the existing digital folders) is undefined |

### Finance and bookkeeping (finance_bookkeeping)

| Id | Severity | Category | Title |
|---|---|---|---|
| finance_bookkeeping-1 | high | incorrect | PO header collapses many money documents into four scalars and one vendor |
| finance_bookkeeping-2 | high | missing | Business model is unasked: buy-and-resell margin vs. vendor-paid commission changes what 'balanced' means |
| finance_bookkeeping-3 | high | missing | No money-event model: deposits, progress payments, partial vendor payments, and payment applications are absent |
| finance_bookkeeping-4 | medium | incorrect | Freight as a single header scalar cannot distinguish cost from pass-through revenue |
| finance_bookkeeping-5 | high | missing | No immutable ledger, audit trail, or period lock: the accountant and ITAR recordkeeping both require them |
| finance_bookkeeping-6 | high | risky | Bi-directional QuickBooks Online CDC sync creates two ledgers of record and assumes a product nobody has confirmed |
| finance_bookkeeping-7 | medium | missing | No negative-money paths: credit memos, vendor credits, returns, cancellations, write-offs, late fees |
| finance_bookkeeping-8 | medium | missing | Sales tax, exemption certificates, and currency are absent; bare numeric amounts will mix them into 'Total Billed' |
| finance_bookkeeping-9 | high | missing | 'Balanced and eligible to close' is undefined; the sticky-note review needs an explicit checklist and state machine |
| finance_bookkeeping-10 | medium | risky | AI-extracted amounts saved without arithmetic validation will post wrong numbers |
| finance_bookkeeping-11 | medium | over_scoped | Reporting scope: five reconciling reports belong in V1; bank reconciliation, aging, and dashboards do not |
| finance_bookkeeping-12 | low | keep | Keep the folder as the unit, HITL before posting, and QuickBooks as the general ledger |
| finance_bookkeeping-s1 (s) | medium | missing | No counterparty master data: customers, vendors, and carriers exist only as extracted name strings |
| finance_bookkeeping-s2 (s) | medium | missing | Invoice authoring vs. invoice capture is undecided; the owner's 'billing' implies the platform issues invoices |
| finance_bookkeeping-s3 (s) | medium | missing | No cutover or opening-balance strategy for the backlog of existing open folders |
| finance_bookkeeping-s4 (s) | low | missing | No PO-to-bill match: the basic accounts-payable control for a distributor is absent from both brief and critique |

## 10. Sources

Fact-check sources relied on above. Where the fact check noted that the primary site was blocked and text came from an indexed excerpt, the primary URL is still listed so it can be checked directly.

1. https://platform.claude.com/docs/en/about-claude/models/overview
2. https://platform.claude.com/docs/en/about-claude/model-deprecations
3. https://platform.claude.com/docs/en/build-with-claude/pdf-support
4. https://platform.claude.com/docs/en/build-with-claude/structured-outputs
5. https://platform.claude.com/docs/en/build-with-claude/claude-in-amazon-bedrock
6. https://docs.aws.amazon.com/bedrock/latest/userguide/model-lifecycle.html
7. https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
8. https://support.claude.com/en/articles/13756069-public-sector-faqs
9. https://www.anthropic.com/news/claude-in-amazon-bedrock-fedramp-high
10. https://platform.claude.com/docs/en/build-with-claude/batch-processing
11. https://docs.easypost.com/docs/trackers
12. https://www.easypost.com/enterprise
13. https://www.easypost.com/freight-shipping
14. https://github.com/supabase/supabase/blob/master/docker/README.md
15. https://supabase.com/docs/guides/self-hosting/docker
16. https://www.postgresql.org/docs/current/ddl-rowsecurity.html
17. https://www.postgresql.org/docs/current/sql-altertable.html
18. https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.54
19. https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.50
20. https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.56
21. https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.33
22. https://www.federalregister.gov/documents/2019/12/26/2019-27438/international-traffic-in-arms-regulations-creation-of-definition-of-activities-that-are-not-exports
23. https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-D/part-117/section-117.18
24. https://www.federalregister.gov/documents/2020/12/21/2020-27698/national-industrial-security-program-operating-manual-nispom
25. https://www.dcsa.mil/Portals/128/Documents/CTP/tools/NISP%20eMASS%20User%20Account%20Request%20Guide%20Version%203.pdf
26. https://www.dcsa.mil/Portals/128/Documents/CTP/tools/250930%20VOI%20Newsletter.pdf
27. https://www.acquisition.gov/far/52.204-21
28. https://www.ecfr.gov/current/title-32/subtitle-B/chapter-XX/part-2002
29. https://www.archives.gov/cui/registry/category-detail/export-control.html
30. https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.
31. https://dodcio.defense.gov/Portals/0/Documents/CMMC/FedRAMPEquivalency.pdf
32. https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final
33. https://csrc.nist.gov/pubs/sp/800/171/r3/final
34. https://www.acq.osd.mil/dpap/policy/policyvault/USA000718-24-DPC.pdf
35. https://www.federalregister.gov/documents/2024/10/15/2024-22905/cybersecurity-maturity-model-certification-cmmc-program
36. https://www.crowell.com/en/insights/client-alerts/department-of-war-immediately-suspends-cmmc-phase-ii-requirements-launches-60-day-reform-review
37. https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api/change-data-capture
38. https://blogs.intuit.com/2025/11/12/important-changes-to-refresh-token-policy
39. https://developer.intuit.com/app/developer/qbdesktop/docs/get-started/get-started-with-quickbooks-web-connector
40. https://www.postgresql.org/docs/current/textsearch-intro.html
41. https://github.com/ocrmypdf/OCRmyPDF
42. https://aws.amazon.com/about-aws/whats-new/2026/07/claude-opus-5-aws-govcloud/
