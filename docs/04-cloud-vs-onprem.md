# 04. Cloud vs on-prem: how the two profiles differ

Status: decided 2026-09-24. Audience: Ross first, then the office staff and the outside accountant at Ross Machinery Sales.

Two architects argued opposite stances, "on-prem first" and "cloud first". Thirty of their 92 factual claims were checked against primary sources. Both recommended the same stack; they disagreed mainly on cloud tenancy.

Terms, explained once:

- **Profile**: a named configuration of the same software. We have two: *sovereign* (on-prem, one server in the office, no internet required) and *cloud*.
- **CUI**: Controlled Unclassified Information. Not classified, but must be safeguarded by law. **FCI**: Federal Contract Information, non-public contract information that is not CUI.
- **ITAR and EAR**: the US export-control regimes for defense articles and for dual-use items. "EAR99" is the EAR's catch-all category.
- **Control marking**: a label on every document and PO: `none`, `fci`, `cui`, `itar` or `ear`.
- **RLS**: row-level security. PostgreSQL filters every query by rules the database enforces, so an application bug cannot return another tenant's rows.
- **Tenant**: one customer company. **Adapter**: code with a fixed interface and swappable implementations. **Egress**: outbound network traffic.

## 1. Decision

**One codebase, one set of containers, two deployment profiles.** The sovereign profile runs on one Linux box on the office LAN and needs no internet for any core function: intake, extraction, human review, ledger, quoting and invoicing views, search, audit, backup and restore. The cloud profile is the identical images and compose file on a rented VM, with a profile switch that swaps adapters (storage, secrets, AI, accounting, mail). Sovereign is the default in development and CI.

**Sovereign is the primary product.** Ross Machinery Sales is customer one, the owner's end state is "this would live on their server only", and most similar companies (aerospace and defense distributors and reps) carry the same CUI and ITAR constraints. The cloud profile is what the same code becomes for a customer without controlled data.

**Tenancy: one instance per tenant, in both profiles.** Each installation gets its own box or VM, database, storage, keys and audit log; the `tenants` table has one row. The schema still carries `tenant_id` on every scoped table with forced RLS, so a shared-database hosted edition for customers with no controlled data stays a deployment change later, not a schema change.

What "later" requires: tenant onboarding and sign-up, billing, per-tenant subdomains, white-label theming beyond one branding row, and a feature-flag admin screen, together the SaaS control plane. Each piece is speculative work that adds a security surface needing its own review, so none of it is built until a second customer signs.

**Stack.** Python and Django (the current long-term-support release) with server-rendered pages and HTMX. Plain PostgreSQL. A Postgres-backed job queue, so no Redis. Local accounts with mandatory TOTP (the six-digit authenticator-app code). Caddy for TLS. A small storage adapter: encrypted local disk on-prem, S3 in cloud. No Supabase platform anywhere; at most hosted Postgres by connection string in the cloud profile.

**AI extraction is keyed on each document's control marking, never on the profile alone.** Unmarked commercial paperwork may go to a commercial API in the cloud profile. CUI, ITAR and EAR documents may only be processed on the box (an open-weight model, or no AI) or through a government-cloud endpoint that is FedRAMP High and DoD IL5 authorized. The fact-checks confirm one exists: Anthropic's public-sector FAQ says "ITAR data can only be processed in Claude via AWS Bedrock, which is IL5 accredited" [1]. We do not pin model ids; section 5 carries the corrections that matter for Phase 2.

| Profile | Where it runs | Who it is for | Internet needed |
|---|---|---|---|
| Sovereign | One Linux server on the customer's LAN. Ross Machinery Sales first. | Anyone with CUI, ITAR or EAR paperwork, or who wants the data to stay in the building. | No. An optional, off-by-default allowlist can permit one government-cloud AI endpoint and QuickBooks Online. |
| Cloud | The same containers on a rented VM, one per customer. | Customers with no controlled data who do not want to run a server. | Yes: public TLS certificates, the commercial AI API, QuickBooks, freight tracking, email. |
| Shared-database hosted edition | Not built. Possible later on the same schema. | Future customers with no controlled data, once a second customer exists. | Yes. |

## 2. Why not the brief's stack

The brief proposed Next.js 15, TypeScript, Tailwind, Shadcn UI, PostgreSQL on Supabase, and a separate FastAPI ingestion service. Both architects rejected it as the core and arrived at the same replacement.

| Concern | Brief: Next.js + Supabase + FastAPI | Decision: Django LTS + HTMX + PostgreSQL |
|---|---|---|
| Languages and runtimes | Two languages, two services, a Node build and runtime in production. | One language, one image, two commands: `web` and `worker`. |
| Authentication | Supabase Auth (GoTrue), a hosted-style service that assumes email delivery and a control plane. | django-allauth local accounts with mandatory TOTP, recovery codes, optional passkeys and OpenID Connect [17]. |
| RLS | Keyed to JWT claims passed through PostgREST. | Keyed to session settings our middleware sets in each request transaction. Works on any PostgreSQL. |
| Self-hosting reality | Eleven services in Supabase's self-hosted compose file as of September 2026 [14]; the cloud architect reports its README says the default configuration is not secure for production and self-hosting is community-supported [15]. | Five to seven containers: Caddy, web, worker, Postgres, backup sidecar, optional local model server, optional ClamAV. |
| Support horizon | Next.js releases fast and breaks things (the architects cite 16.0 changing the bundler default, middleware and caching). | Django 5.2 LTS, released April 2, 2025, security updates for at least three years [16]. |
| Government cloud | Names Azure Government Cloud. | No Anthropic source lists Azure Government; the listed government paths are AWS GovCloud and Google Vertex with Assured Workloads [1][12]. |

For one developer and an unattended office server, the brief's stack is three products stitched together, each with its own auth boundary, runtime and upgrade cadence. The extraction pipeline is Python anyway. Django gives sessions, CSRF, forms, migrations and an admin site out of the box, and its LTS cadence suits an install-and-forget server. Supabase is a cloud product that can be self-hosted, not an appliance; the only acceptable use is hosted Postgres through `DATABASE_URL` in the cloud profile, with the app never referencing Supabase schemas, PostgREST, client libraries or Supabase-only extensions.

The trade-off, honestly: no single-page app and a less fashionable front end. HTMX swaps fragments of server-rendered HTML instead of running a large JavaScript application. That is fine for forms-and-tables work. A public-facing portal can be added later in any framework against the same backend.

## 3. What differs between the profiles

Where the two architects disagreed, the more conservative choice is in the cell and the disagreement is listed after the table.

| Area | Cloud profile | Sovereign profile | Shared abstraction | Cloud must never... |
|---|---|---|---|---|
| Authentication and identity | Same as sovereign, plus optional OpenID Connect (Entra ID, Okta) and email password reset via the customer's SMTP relay. | Local accounts only; mandatory TOTP, printed recovery codes, optional passkeys, admin-issued resets. | `IdentityProvider`, modes `local` (always on) and `oidc`. | Make a hosted identity service the source of truth. Require email to log in. |
| Authorization | Identical. | Roles per tenant; a "may access controlled" flag gates `cui`, `itar` and `ear` rows; mirrored in RLS. | `authz.can(user, action, object)` plus forced RLS; runtime DB role not owner, no `BYPASSRLS`. | Move policy to cloud IAM. Derive authorization from JWT claims. |
| Storage of scans | `S3BlobStore`: private bucket, customer-managed key, versioning; downloads stream through the app. | `FileSystemBlobStore` on a LUKS volume; envelope encryption, master key on a TPM or owner-held USB key. | `BlobStore` and `KeyProvider` (`local_file`, `tpm`, `kms`). | Use bucket events as the pipeline. Rely on presigned URLs. Keep the only key beside the data. |
| Database and backups | Same PostgreSQL container (16 today, 17 when the schema suite is re-run against it); managed Postgres allowed via `DATABASE_URL` only; backups to a separate bucket. | PostgreSQL on the encrypted volume. Phase 1 ships nightly `pg_dump` plus a file-store snapshot with an encrypted off-site copy and a logged restore drill; pgBackRest with continuous WAL for point-in-time recovery [44] follows in Phase 2. | `DATABASE_URL`, `BACKUP_REPO=local|s3`, `po backup` / `po restore`. | Use vendor-only schemas or extensions. Rely on provider snapshots alone. |
| AI document extraction | Router keyed on marking; `cui`, `itar` and `ear` never reach the commercial API (section 5). | Local open-weight vision model, else CPU layout/OCR, else no AI; nothing leaves the compose network; a documented "connected" setting, off by default, may allowlist one government-cloud endpoint. | `Extractor` and the `extraction_policy` table. | Extract before marking. Log content. Use stateful features (file uploads, code execution, server-side tools). |
| Integrations and egress | `EGRESS_MODE=allowlist`; QuickBooks by OAuth 2.0 with change-data-capture polling as the primary sync. | `EGRESS_MODE=none`; `CsvAccountingExport` for QuickBooks-importable files a person carries over; `ManualTracker`; `NullMailer` to an in-app inbox. | `OutboundHttp` (the only network client), `AccountingSync`, `ShipmentTracker`, `Mailer`. | Require inbound webhooks. Let a failed integration block closing a PO; the ledger is authoritative. |
| Secrets | `SecretsProvider=cloud`: secrets manager read once by the entrypoint; envelope key under KMS. | `SecretsProvider=file`: root-owned 0600 file from the installer; master key TPM-sealed or on an owner-held USB key; printed recovery sheet in the safe. | `SecretsProvider.get(name)` at settings load only. | Call a cloud secrets SDK from app code. Require an IAM role. |
| Telemetry, error reporting, update checks | Optional scrubbed OpenTelemetry export to the operator's own endpoint; release-feed check; no product analytics. | None outbound; local logs and metrics; errors in an `app_errors` table; update check against the uploaded bundle; health page shows "egress: blocked (expected)". | `Telemetry` (`NullTelemetry` default) and the `outbound_calls` registry. | Initialize vendor SDKs at import. Gate features on a phone-home. Embed third-party scripts or CDN fonts. |
| Software updates and image distribution | Pull by digest from a private registry, `cosign verify`, blue/green switch at Caddy. | Signed offline bundle on USB with checksums, trusted root, SBOM and rollback script; `po upgrade` verifies offline, backs up, migrates, smoke-tests, rolls back on failure. | One signed image set with the same digests for bundle and registry [46]; the `po` CLI. | Pull from a registry at runtime. Ship an irreversible migration. |
| Network topology | Public certificates, but reachable only over VPN or an IP allowlist by default; public exposure only with MFA and rate limiting. | One box on the LAN; Caddy `tls internal` or the company CA, root pushed to PCs by `po trust-cert` [45]; no public DNS, default-deny egress; remote access by WireGuard only. | Caddyfile templated from `TLS_MODE` and `PUBLIC_BASE_URL`. | Terminate TLS in the app. Require a public hostname for any core flow. Expose Postgres or the worker. |
| Tenancy | Instance per tenant: one VM, database, bucket and key per customer; `tenants` has one row. | Instance per tenant by construction; tenant switcher hidden. | `TenantContext` middleware (`SET LOCAL app.tenant_id`) and the `TENANT_TABLES` registry. | Add shared-database tenancy, cross-tenant queries or a control plane before a second customer and a security review. |
| Logging and audit retention | Same audit model; optional forward to the customer's SIEM by syslog or OTLP. | Append-only `audit_events` written in the same transaction, trigger-protected, hash-chained; internal NTP with skew alarm; default retention 3 years. | `audit.record()` and `AUDIT_FORWARD=none|syslog|otlp`. | Store audit only in a vendor service. Make audit writes best-effort. Log document content. |
| Remote and mobile access | Responsive web UI over VPN or MFA-protected HTTPS. | Same UI over LAN or VPN only; PWA install for phone capture of remittances and sticky notes; no native app, no push notifications. | One web UI; `ACCESS_MODE=lan|vpn|public`. | Build a native client needing a push service or public gateway. Serve assets from a CDN. |
| Theming and feature flags | Per-instance `branding` row rendered as CSS custom properties; flags from versioned YAML with DB overrides; admin screen deferred to the control plane. | Same tables, one tenant, theme set at install from the Ross Machinery Sales brand system; `profile_caps` hard-disables cloud-only capabilities regardless of flag rows. | `features.enabled(tenant, flag) = flag_row AND profile_caps[flag]`. | Use a hosted flag service. Fetch fonts or logos from third-party URLs. |
| Document intake (scanner and existing digital folders) | Browser upload; optional mailbox polling on the customer's relay. | The worker watches the scanner's SMB share; a bulk-import source walks the existing digital PO folders; every intake lands in an application-side quarantine (hashed, deduplicated by SHA-256, treated as the most restrictive marking the tenant handles) and a `documents` row is created only when a person sets the marking. | `IntakeSource` (`watch_folder`, `bulk_import`, `upload`, `mailbox`). | Depend on object-store notifications, serverless functions or a hosted OCR pre-step. |

Where the architects disagreed, and what was picked:

- **Tenancy.** The cloud architect wanted a shared database with RLS as primary isolation for cloud customers. Picked instance per tenant everywhere, the more conservative choice.
- **Everything else.** Presigned URLs, optional envelope encryption, a managed database, a public load balancer, hosted telemetry and vendor impersonation were each proposed by one architect for the cloud profile. Picked the conservative option every time.
- **Government-cloud AI from the sovereign box.** The on-prem architect said never; the cloud architect described a "connected sovereign" sub-mode. Picked the no-egress default, which CI proves, with the sub-mode as an opt-in, because the alternative for an office with no GPU is moving the whole system to a cloud VM, which exposes more data. Enabling it requires the security-officer role, an allowlist with only that endpoint, an entry in the company's System Security Plan, and for ITAR, written sign-off from export-control counsel.

## 4. Rules that keep the door open

Engineering rules, enforced in CI where possible.

1. **Every external capability sits behind a named adapter with a working offline implementation in the same image.** No exceptions.
2. **The sovereign profile is the default in development and CI.** The sovereign job must pass before the cloud job runs.
3. **A feature that cannot run with egress disabled is not merged.** It gets an offline twin, or is hard-off by `profile_caps`, or waits.
4. **No JWT-based RLS helpers, no PostgREST, no Supabase client libraries.** Policies read only the session settings our middleware sets with `SET LOCAL`.
5. **No foreign keys to `auth.users` or any table outside our own schema.** Users, sessions, roles and MFA state live beside tenant data.
6. **Every tenant-scoped table has `tenant_id NOT NULL` and forced RLS.** The runtime role owns nothing and has no `BYPASSRLS`.
7. **A control marking is a required column on every document and PO.** A file that has not been marked stays in intake quarantine and is treated as the most restrictive marking the tenant handles. Extraction never runs before the marking step. Lowering a marking needs a privileged role and an audit reason.
8. **The extractor router is the only code that may call a model.** A lint rule fails the build if `anthropic`, `boto3`, `httpx` or `requests` is imported outside `integrations/` and `adapters/`.
9. **One shared outbound HTTP client enforces `EGRESS_MODE` and the allowlist.** An empty allowlist means deny all and log the attempt.
10. **Polling is the primary path for every integration.** Webhooks are accelerators. Nothing requires inbound reachability.
11. **No company-specific hard-coding.** Branding, integrations and flags come from the `branding` and `features` tables and from environment.
12. **Releases are reversible and audit is transactional.** Expand/contract migrations so the previous release still runs. Audit writes never best-effort and never contain document content.

## 5. AI extraction policy by marking

"Local" means an open-weight vision model on the box or a GPU host on the LAN, with a CPU layout-and-OCR extractor as fallback and manual keying as the last resort. "GovCloud endpoint" means a FedRAMP High and DoD IL5 authorized endpoint such as Claude on Amazon Bedrock in AWS GovCloud [1][2].

| Marking | Sovereign profile | Cloud profile |
|---|---|---|
| `none` (ordinary commercial paperwork) | Local by default. The only marking for which an operator may enable the commercial API, and only under `EGRESS_MODE=allowlist`. | Commercial API. Batch endpoint (half price, results stored up to 29 days, not zero-data-retention eligible [9]) only with tenant opt-in. No file uploads, code execution or server-side tools. Never a Covered Model. |
| `fci` | Local only as shipped. An operator may extend the `none` rule to `fci` once the organization decides its FAR 52.204-21 obligations are met by the vendor's terms [40]. | Commercial API only under an organization-level zero-data-retention arrangement (arranged through the vendor's sales team [3]), synchronous only. Otherwise local or none. |
| `cui` | Local only by default. GovCloud endpoint only in the opt-in connected setting from section 3. | Never the commercial API. GovCloud endpoint, a customer-run local model over the customer's VPN, or no AI. The endpoint must be in the customer's System Security Plan. |
| `itar` | Local only by default. GovCloud endpoint only in the connected setting plus written counsel sign-off. A commercial extractor cannot be loaded for this marking. | Never the commercial API. GovCloud endpoint only with counsel sign-off and a tenant attestation that operator access is US-person only; otherwise no AI, which is the default. |
| `ear` | Non-EAR99: as `itar`. EAR99: as `fci`. | Non-EAR99: as `itar`. EAR99: as `fci`. |
| Not yet marked (still in intake quarantine) | Treated as the most restrictive marking the tenant handles. For Ross Machinery Sales that is `itar`. No `documents` row exists yet, so nothing can be attached, viewed or extracted. | Same rule. Extraction waits until a person sets the marking. |
| `classified` | Refused at upload. Nothing stored. | Refused at upload. Nothing stored. |

In both profiles output is never auto-committed, and only users with the "may access controlled" flag can view controlled documents.

Three fact-check corrections shape the GovCloud adapter and must be re-checked at Phase 2. Bedrock accepts only inline base64 PDFs and caps the whole request at 20 MB, versus 32 MB and a file-upload option on the first-party API, so large scans are split by page [6][7]. Structured JSON output is listed as unsupported on the Bedrock Messages endpoint, so the adapter uses a strict tool-use JSON schema with client-side Pydantic validation [8][10]. And the retention terms for Anthropic's newest "Covered Models" changed twice in 2026; on Bedrock they now mean up to 30-day retention with human review by AWS personnel, to be assessed before any such model is selected [3][4][5].

## 6. If anything is genuinely classified

If any of the company's information is truly classified, nothing in this project may store, display, index, extract, back up or transmit it, ever. Classified information may only be handled by a contractor holding a Facility Clearance under the NISPOM, codified at 32 CFR Part 117 and in effect since February 24, 2021. Under section 117.18 the cognizant security agency must authorize a contractor's information system before it processes classified information. The fact-check corrected one term: DoD is the cognizant security agency, and DCSA is the cognizant security office that administers it for DoD [36]. A Django app on an office server is not, and will never be, such a system.

The practical position: the marking enum contains `classified` purely as a hard stop. The intake rejects the file. A PO may carry only an unclassified pointer such as "classified attachment held per FSO log #123" so the folder can still be closed and balanced.

How to find out which regime applies, before Phase 1 ends: ask whether the company holds a Facility Clearance and has a Facility Security Officer, and whether any contract carries a DD Form 254 [42]. If there is no clearance, the company cannot lawfully possess classified material, and "strictly classified" in the owner's words almost certainly means CUI, ITAR technical data, EAR-controlled technology, or plain contractual confidentiality. Until those answers are in, every document in the pilot is treated as `itar`.

## 7. Compliance: what the software does and what the company must do

The governing rules, as verified. DFARS 252.204-7012 requires contractors handling covered defense information to implement NIST SP 800-171 Revision 2 (110 requirements in 14 families) [38][34]. That holds by DoD class deviation (2024-O0013 of May 2, 2024, carried into the 2026-O0025 series), not by the clause's own text [29][25]. Rev 3 was published May 14, 2024; a proposed FAR rule of June 23, 2026 would make it the government-wide baseline but is not final [30][31]. The clause also requires reporting cyber incidents within 72 hours and requires any external cloud service handling covered defense information to meet FedRAMP Moderate-equivalent security [38].

CMMC status is in flux and must be re-checked against the company's actual contracts. The CMMC rule (32 CFR Part 170) was published October 15, 2024; its Level 2 is the same 110 requirements [32][33]. The Department suspended CMMC Phase 2 on July 13, 2026, and Class Deviation 2026-O0025 Revision 3 (September 3, 2026 per most sources) directs contracting officers to accept Level 1 and Level 2 self-assessments [28][25]. Revision 3 moved no date: November 10, 2028 has been the Phase 4 date since the September 2025 final rule, and a task force may still change it [26][27]. Only four control numbers were spot-checked [34]; the rest must be checked when the SSP is written.

**The software implements** (Rev 2 numbering):

- Access control (3.1.x): accounts, roles, RLS, marking-based flow control, non-owner database role, lockout (3.1.8), login banner, idle lock, proxy-only remote access with MFA, the egress allowlist.
- Audit (3.3.x): append-only records traceable to one user, written in the same transaction; alert on audit failure; synchronized time (3.3.7).
- Identification and authentication (3.5.x): unique identities, MFA for every account (3.5.3), replay-resistant authenticators, salted password hashes.
- System and communications protection (3.13.x): default-deny egress, TLS everywhere, encryption at rest, FIPS-validated cryptography (3.13.11) via the host's FIPS mode and the OS crypto provider.
- Configuration, integrity and media (3.4.x, 3.14.x, 3.8.x): signed image and SBOM as baseline, least functionality, malware scan of every upload, encrypted backups, crypto-shred on delete.
- Assessment and DFARS 7012 support: audit exports, configuration report, egress proof, a report of which cloud services processed CUI, 90-day log retention after an incident.
- ITAR: the marking model, the controlled-access flag tied to the US-person determination, and end-to-end encryption so the organization can rely on the 22 CFR 120.54 carve-out.

**The organization owns:**

- Deciding the regime: Facility Clearance and FSO status, DD Form 254 review, which contracts flow down DFARS 7012, 7019, 7020, 7021 and FAR 52.204-21, DDTC registration under 22 CFR Part 122 [41], EAR classifications, who counts as a US person.
- The System Security Plan, Plan of Action and Milestones, the SPRS score under DFARS 252.204-7019 and 7020 [39], and any CMMC self-assessment.
- Training (3.2.x), incident response (3.6.x) including the 72-hour report, maintenance (3.7.x), physical protection (3.10.x), personnel security (3.9.x), media handling, change control, FIPS-mode upkeep and key custody.
- Export-control legal review of remote access, backup locations and AI endpoints. The fact-check on 22 CFR 120.54 adds a condition the architects missed: the data must also not be sent from a proscribed country or Russia, and the means of decryption must not be provided to any third party [35]. A cloud provider may hold ciphertext but never keys, so provider-managed encryption at rest does not satisfy the carve-out on its own.

## 8. Air-gapped mode

With the uplink absent, or the firewall denying all egress, the sovereign profile is fully functional.

- **Self-check.** With `EGRESS_MODE=none` the app refuses to boot if any adapter has a remote endpoint. The worker's first job tries one outbound canary connection and records "egress blocked: OK"; if it succeeds, the health page shows a red banner.
- **Extraction.** Local model on a GPU, else CPU layout/OCR with every field flagged, else no AI, in which case the clerk keys fields beside the page image.
- **Time, TLS, accounts.** NTP from the office router; drift warnings; backdated audit rows blocked. Caddy's internal CA with `po trust-cert` for office PCs. No email: printed one-time setup links, admin-driven resets, printed recovery codes.
- **Accounting, shipping, notifications.** QuickBooks-importable exports and remittance imports carried by file share, the app's ledger authoritative; manual tracking numbers with deep links; in-app inbox and a daily "folders to close" list.
- **Updates and backups.** Signed offline bundle on USB, verified offline against a trusted root shipped at install [46], with pre-upgrade backup and rollback; antivirus signatures and model weights in the bundle. pgBackRest to a NAS and rotating encrypted USB drives, one always off-site.
- **Telemetry, licensing, remote help.** None, and no phone-home ever; the empty `outbound_calls` registry is itself an audit artifact. `po support-bundle` writes a scrubbed diagnostics archive to USB. Remote help only through a customer-initiated WireGuard tunnel the owner enables per session.

## 9. How we prove both profiles work

One variable, `PO_PROFILE=sovereign|cloud`, selects adapter defaults. CI runs both on every push against the same image; a pull request cannot merge unless both are green, and the sovereign job runs first.

**Sovereign job.** The stack boots on a Docker network with `internal: true` and a DNS sink that fails every lookup. Unit and integration tests, then a browser end-to-end run from intake through extraction (recorded fixtures), human edit, ledger, close, export, backup and restore. A no-egress canary asserts every outbound attempt fails and the `outbound_calls` registry is empty. RLS leak tests run as the runtime role: seed two tenants, try every path with the wrong `app.tenant_id`, assert zero rows; a schema test fails if any `tenant_id` table lacks forced RLS or the runtime role has `BYPASSRLS` or ownership. On every tag: build and sign the offline bundle, install it on a clean VM with no network, upgrade from the previous tag, roll back.

**Cloud job.** Same image with `PO_PROFILE=cloud`: S3 against a test double, secrets against a mock, OIDC against a throwaway identity provider, the commercial API and QuickBooks adapters against recorded cassettes with fixture PDFs containing no real data. Marking-policy tests assert `cui`, `itar` and `ear` documents can never reach the commercial adapter.

**Both.** A nightly "same scans, both profiles" job diffs both extractor paths against golden JSON; the local model adapter runs nightly on a GPU runner with an accuracy threshold; SBOM, vulnerability, secret and FIPS-mode gates. Release gate: both jobs green, artifacts signed, and a manual install on a machine that was never online.

## 10. Standing rule on real data

From the owner conversation. A rule for everyone on the project, including AI coding assistants.

1. Never put a real PO, invoice, drawing, ledger sheet, or anything carrying a CUI or ITAR legend into any AI coding session, cloud or local, or into the commercial API.
2. Never commit real documents or real data to the repository: no scans, exports, database dumps or log files.
3. Develop and test with synthetic fixtures: made-up companies, PO numbers, amounts and generated PDFs. The fixture set in the repository is the only data CI ever sees.
4. Real-document testing happens only on the office server, in the sovereign profile, with the extractor off or pointed at the local model. If the government-cloud path is ever used for testing, it is enabled exactly as in production.
5. A bug that only reproduces with a real document is reproduced on-site.

## 11. Known weaknesses of this decision

Merged from both architects. None changes the decision; all need planning for.

- **Commercial reach is narrow.** An appliance sold one installation at a time has no self-serve sign-up or free trial, and selling dedicated instances is a services business, not SaaS economics.
- **Operations cost scales linearly.** N customers means N boxes to upgrade, back up and restore; margins depend on unglamorous installer and backup tooling.
- **Feature velocity is throttled.** Every feature needs an offline implementation, roughly doubling integration work; the first months go into packaging and the egress gate rather than the ledger and quoting screens the office wants.
- **Extraction quality on controlled documents will be lower.** An open-weight model on a workstation GPU is less accurate than frontier hosted models on messy handwriting and stamps, and the office may own no suitable GPU. That is the accepted price of never sending them out.
- **One box is the whole business system.** Disk, power or a bad upgrade takes everyone down; this needs a spare machine, tested restores and an owner who follows the USB routine. The box is only as safe as the LAN and the people with physical access.
- **Compliance is still the customer's problem.** The design makes the lawful path easy but does not deliver NIST 800-171 or CMMC compliance; the company must still write an SSP, run FIPS mode, train people and assess.
- **The hosted edition later is not free.** A real SaaS pivot is a second product effort with its own security review, even though the schema allows it; shared-database RLS is only as good as the discipline around `SET LOCAL` and connection pooling.
- **Regulatory and vendor facts move quickly.** CMMC is under review, Rev 3 exists while DoD assesses Rev 2, and the GovCloud retention conditions changed twice in 2026. A product has to track all of it.

## 12. Facts we verified and facts to re-verify at build time

**Verified against primary sources (as of 2026-09-24):**

- ITAR data may be processed in Claude only via AWS Bedrock (IL5); Bedrock in GovCloud and Vertex with Assured Workloads are FedRAMP High; Claude for Government is "in pilot" [1][48]; Bedrock approval announced June 11, 2025 [2].
- The Bedrock and retention facts in section 5 [3][4][6][7][8][9][10].
- Foundry (GA June 29, 2026) is commercial Azure only, so the brief's "Azure Government Cloud" is not a supported AI path [12]; Claude Gov models are for classified environments only [13].
- Tooling: section 2 [14][15][16][17][18]; MinIO archived April 25, 2026, alternatives SeaweedFS, RustFS, Garage [19][20]; Qwen3-VL Apache-2.0 on vLLM 0.11 or later [21][22]; Docling MIT [23].
- The regulatory facts in sections 6 and 7 [25][26][27][28][29][30][31][32][33][35][36][37][38][39].

**To re-verify at build time (Phase 2 for AI, Phase 3 for integrations):**

- Which Claude models are available in GovCloud *and* carry FedRAMP High / IL5 authorization; AWS tracks these separately and its list could not be read [47].
- The retention mode for the configured model: it changed between the June 2026 launch (provider data-share opt-in) and September 2, 2026 (AWS-internal review with up to 30-day retention) [4][5].
- The model lineup and prices (the architects' default is now listed as legacy; one small model has a retirement floor of October 15, 2026) [11], and whether structured outputs have arrived on the Bedrock Messages endpoint [8][10].
- GPU sizing: "a 7B-class 4-bit model fits a 12 GB GPU" is an inference from the vendor's theoretical memory table, not a vendor statement; benchmark on the office's scans [24].
- Intuit's November 2025 refresh-token change rests on search snippets [43]; freight-tracking coverage for LTL carriers was not confirmed; the Rev 2 control numbers beyond the four spot-checked; the CMMC task force outcome [26].

## 13. Sources

1. Anthropic, Public Sector FAQs: https://support.claude.com/en/articles/13756069-public-sector-faqs
2. Anthropic, Bedrock FedRAMP High announcement: https://www.anthropic.com/news/claude-in-amazon-bedrock-fedramp-high
3. Anthropic, API and data retention: https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
4. Anthropic, Covered Models: https://support.claude.com/en/articles/15425695-covered-models and https://support.claude.com/en/articles/15425996-data-retention-practices-for-covered-models
5. AWS, Bedrock data retention (not fetchable): https://docs.aws.amazon.com/bedrock/latest/userguide/data-retention.html
6. Anthropic, PDF support: https://platform.claude.com/docs/en/build-with-claude/pdf-support
7. Anthropic, API overview: https://platform.claude.com/docs/en/api/overview
8. Anthropic, Claude in Amazon Bedrock: https://platform.claude.com/docs/en/build-with-claude/claude-in-amazon-bedrock
9. Anthropic, Batch processing: https://platform.claude.com/docs/en/build-with-claude/batch-processing
10. Anthropic, Structured outputs: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
11. Anthropic, Models and deprecations: https://platform.claude.com/docs/en/about-claude/models/overview and https://platform.claude.com/docs/en/about-claude/model-deprecations
12. Anthropic, Foundry GA: https://claude.com/blog/claude-in-microsoft-foundry
13. Anthropic, Claude Gov models: https://www.anthropic.com/news/claude-gov-models-for-u-s-national-security-customers
14. Supabase self-hosted docker-compose.yml: https://raw.githubusercontent.com/supabase/supabase/master/docker/docker-compose.yml
15. Supabase self-hosting README (architect-reported): https://github.com/supabase/supabase/blob/master/docker/README.md
16. Django 5.2 release notes: https://raw.githubusercontent.com/django/django/stable/5.2.x/docs/releases/5.2.txt
17. django-allauth MFA docs: https://raw.githubusercontent.com/pennersr/django-allauth/main/docs/mfa/introduction.rst
18. Rails 8.0 release notes: https://raw.githubusercontent.com/rails/rails/main/guides/source/8_0_release_notes.md
19. MinIO repository (archived): https://github.com/minio/minio
20. SeaweedFS, RustFS, Garage: https://github.com/seaweedfs/seaweedfs and https://github.com/rustfs/rustfs and https://github.com/deuxfleurs-org/garage/tags
21. Qwen3-VL: https://github.com/QwenLM/Qwen3-VL
22. vLLM README: https://raw.githubusercontent.com/vllm-project/vllm/main/README.md
23. Docling README: https://raw.githubusercontent.com/docling-project/docling/main/README.md
24. Qwen2.5-VL README memory table: https://raw.githubusercontent.com/QwenLM/Qwen2.5-VL/main/README.md
25. Pivot Point Security on Rev 3: https://www.pivotpointsecurity.com/revision-3-of-dars-class-deviation-2026-o0025/
26. Redspin on Rev 3: https://redspin.com/blog/class-deviation-revision-3-still-in-the-holding-pattern/
27. Hive Systems on the 2028 date: https://www.hivesystems.com/blog/no-cmmc-wasnt-pushed-to-2028
28. Holland & Knight on the Phase 2 suspension: https://www.hklaw.com/en/insights/publications/2026/07/dow-suspends-cmmc-phase-ii-requirements
29. DoD Class Deviation 2024-O0013 (not fetchable): https://www.acq.osd.mil/dpap/policy/policyvault/USA001074-24-DPC.pdf
30. NIST SP 800-171 Rev 3 and Rev 2: https://csrc.nist.gov/pubs/sp/800/171/r3/final and https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final
31. Secureframe on the FAR CUI proposed rule: https://secureframe.com/blog/far-cui-rule
32. Federal Register, CMMC final rule: https://www.federalregister.gov/documents/2024/10/15/2024-22905/cybersecurity-maturity-model-certification-cmmc-program
33. 32 CFR 170.14: https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-G/part-170/subpart-D/section-170.14
34. CSF Tools, NIST SP 800-171 Rev 2: https://csf.tools/reference/nist-sp-800-171/r2/
35. 22 CFR 120.54; Baker McKenzie summary: https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.54 and https://sanctionsnews.bakermckenzie.com/ddtc-issues-itar-rule-affecting-technology-transfers-encryption-and-cloud-computing/
36. 32 CFR Part 117 (NISPOM), 117.18 and 117.24: https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-D/part-117 and https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-D/part-117/section-117.18 and https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-D/part-117/section-117.24
37. 32 CFR Part 2002 and DoDI 5200.48: https://www.ecfr.gov/current/title-32/subtitle-B/chapter-XX/part-2002 and https://www.esd.whs.mil/Portals/54/Documents/DD/issuances/dodi/520048p.PDF
38. DFARS 252.204-7012: https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.
39. DFARS 252.204-7020: https://www.acquisition.gov/dfars/252.204-7020-nist-sp-800-171dod-assessment-requirements.
40. FAR 52.204-21: https://www.acquisition.gov/far/52.204-21
41. 22 CFR Part 122: https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-122
42. DD Form 254: https://www.esd.whs.mil/Directives/forms/dd0001_0499/DD254/
43. Intuit refresh token policy (not fetchable): https://blogs.intuit.com/2025/11/12/important-changes-to-refresh-token-policy
44. pgBackRest README: https://raw.githubusercontent.com/pgbackrest/pgbackrest/main/README.md
45. Caddy automatic HTTPS: https://raw.githubusercontent.com/caddyserver/website/master/src/docs/markdown/automatic-https.md
46. cosign; offline verification: https://raw.githubusercontent.com/sigstore/cosign/main/README.md and https://edu.chainguard.dev/open-source/sigstore/cosign/verifying-in-air-gapped-environments/
47. AWS GovCloud announcement; FedRAMP model list (not fetchable): https://aws.amazon.com/about-aws/whats-new/2026/07/claude-sonnet-5-govcloud/ and https://aws.amazon.com/compliance/services-in-scope/FedRAMP/amazon-bedrock-models/
48. Anthropic, government solutions page: https://claude.com/solutions/government
