# Owner context (Ross, 2026-09-24)

This is what the owner said when handing over the Gemini-drafted brief. It is the ground truth for what the
business actually needs; where the brief and this note disagree, this note wins.

## Who and why

- The system is for **Ross Machinery Sales** (Ross's father's business): a small aerospace machinery sales /
  precision tooling distributor. The software is its own entity, built for Ross Machinery Sales as the first
  (and for now only) tenant; it lives in its own private repository, separate from any other project.
- A **brand system for Ross Machinery Sales already exists** (Ross has it). It is not needed for the Phase 1
  planning documents or the schema, but the application UI in Phase 1 should be themed from it rather than
  from generic defaults; treat it as an input to the first UI task.
- The pain: "endless filing nightmares from the endless amounts of both digital and physical Project Order (PO)
  folders." Piles of folders that "need to get closed and filed."
- Ross personally went through a batch of the physical folders and believes a well-built tool would be
  "life changing" for the office.

## What "done" looks like to the owner

- "The most efficient, easy to use, functional tool this company has ever had."
- "One system to help with **invoices, billing, quoting, and keeping everything balanced**."
  (Note: quoting is not in the Gemini brief.)
- Everyday life "not full of piles of folders."

## Security posture (owner's words, lightly condensed)

- "Some of their information is strictly classified with the government."
- "It involves aerospace and the Department of Defense."
- "These POs will include parts and services that are used to build such machinery and that cannot be leaked
  or hacked by any circumstances."
- "This platform must be able to be secured, safe, and not break any laws."
- "**Once fully operational this would live on their server only.**"

## What Ross asked for in Phase 1 (this deliverable)

1. Critique the brief itself: what's missing, risky, or over-scoped for a first version.
2. Design the database schema (tenants, POs, line items, documents, ledger entries, users/roles) and the RLS
   policies that enforce tenant isolation.
3. Decide how the cloud version and the ITAR/on-prem version will differ, so we don't build ourselves into a
   corner.
4. Produce a written Phase 1 plan broken into small tasks.

He also asked to be **asked questions** that help derive what the business really needs, so the tool ends up
efficient, easy to use, and functional.

## What the physical folder looks like (from the brief, confirmed by Ross's walkthrough)

- Tab label: Client Order #, Internal PO #, Vendor Name, Project Name / Items Purchased.
- Top sheet: a paper ledger with summary metrics (Total Billed to Client, Amount Billed from Vendor, Company
  Commission, Freight Charges) and below it a hand-written Date / Time / Comments table tracking payments and
  balances that is hard to decipher.
- Document stack: client invoice on top (sometimes with pay stubs / remittances stapled), then a variable stack
  of vendor invoices ranging from a single-line software purchase to multi-million-dollar capital machinery,
  tooling, accessories, and freight.
- Sticky notes indicating whether a folder / PO should be closed, requiring manual review with management.

## Commercial intent (added 2026-09-24, after the brief review started)

- Ross: "I want to be able to sell this platform to similar companies once we get this all set up here."
- So multi-tenancy and productization are **real goals, not Gemini's invention**. What changes is the order:
  Ross Machinery Sales is customer one and gets a working single-tenant, on-prem system first; the design must
  not paint the product into a corner (tenant_id and RLS on every table from day one, no company-specific
  hard-coding, branding and integrations behind configuration, one codebase with deployment profiles).
- What still waits until there is a second customer: the SaaS control plane (tenant onboarding, billing,
  subdomains, white-label UI, feature-flag admin), and any hosted multi-tenant deployment.
- "Similar companies" are aerospace / defense distributors and reps. Most of them will have the same
  CUI / ITAR constraints, so the sellable product is most likely a deployable bundle (their server or a
  government-eligible cloud) plus an optional hosted edition for customers without controlled data.
