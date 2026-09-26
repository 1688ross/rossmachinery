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

## Update 2026-09-25: how the folders really work (from Ross)

- There is a **digital set of folders on the shared Ross Machinery server** as well as the paper set. They were
  meant to be identical; in practice either one can be the more current, and staff found pulling the paper
  easier than searching the computer. The goal is to **retire the paper documents** (kept for reference) and
  make the system the single copy.
- A folder begins at the **RFQ**, not at the client's purchase order. Every RFQ is stored digitally under the
  client until it is green-lit; a lost, cancelled or delayed bid stays under the client until it resurfaces.
- Once green-lit, a project gets **its own dashboard** showing where it is: RFQ received, preparing quote,
  quote sent, quote approved, green-lit, in production, testing, final testing, QC, packaging, ready to ship,
  shipped, installed or delivered. Steps would be updated from emails, from documents, or by hand.
- When one project has **several deliveries**, each item shipped is tracked separately.
- **Three numbers are in use**: the client's RFQ or PO number, Ross Machinery's internal PO number, and the
  vendor's order number. An RFQ may already carry a PO number. Details to follow.
- The platform must track **every quote sent, every vendor invoice received and every client invoice sent,
  all tied to QuickBooks** (probably Desktop; edition to confirm), so that vendors are paid, the company is
  paid, commissions match, and any remaining balance is clearly flagged on the company-wide hub.
- **Drawings and blueprints are the sensitive material and are not normally part of these order folders.**
  Ross Machinery has access into customer facilities (Sikorsky, Air Force sites) but that is facility access,
  not a security clearance; Sikorsky's "confidential" material is customer-proprietary, not classified.
  Drawings stay outside the system.

## Update 2026-09-26: discrepancies, held money and the client-year view (from Ross)

- When the checks and balances do not align, the platform should **explain why**, help resolve it, and keep a
  record that the folder was unbalanced and how it was resolved. Examples: an item shipped without a part and
  the difference was fixed later; the client wanted a dearer item, took a cheaper one after paying, and said in
  an email "make it up to me next time."
- **Money must be tracked even when a folder is closed before everything is reconciled.** Cases: the client
  has paid but the vendor has not yet been paid (the company is holding a balance); the client paid for
  everything, a small item was dropped, the vendor never charged and is not asking to be reimbursed, so the
  surplus is set aside for that client in the future.
- Seeing a discrepancy should **trigger a reminder of related conversations**: at first entered by hand, later
  found in email ("just add it to the next invoice", "get me back next time").
- There is a **master spreadsheet or dashboard per client per year** listing that client's POs: ready to be
  closed, waiting on payment from the client, needing a vendor payment, waiting on invoices. The platform
  replaces it.
- **The platform must not look like spreadsheets.** It should anticipate the user's need and show the
  information before they start looking. The reason: the owner walks across the office to pull the paper
  folder because it is faster than the computer, which requires two identical sets of folders; when they
  differ a whole reconciliation project appears and bottlenecks the office. That is what they are dealing
  with now, at their September year-end.

Design consequences noted for the follow-up migration and plan: client-level credits ("money set aside for
this client from PO-123, per the email of ..."), a discrepancy record (cause, amount, resolution, linked note
or email), closing allowed when every balance is zero or moved to a tracked place, "holding a balance" and
"set aside" surfaced on the folder, the hub and the client-year view, and an "anticipate the need" rule that
every screen is reviewed against.
