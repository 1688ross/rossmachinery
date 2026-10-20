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

## Update 2026-09-29: numbers, and the build principle

- Sample PO numbers from the folder stack are ten digits starting 4500 (for example 4500681222). That is the
  standard purchase-order number format issued by SAP, the purchasing system large manufacturers run, so these
  are almost certainly Sikorsky's numbers with no date or customer code inside. The tab number is the client's
  number and it is what the office searches by. Rule: any number is a searchable label; the system never
  insists on a format and does not generate its own number unless the office asks for one.
- Build principle, agreed with Ross: fix only the foundations (folder as record, money as a list of events with
  computed balances, the pile on the first screen, on-prem with second-factor logins, nothing ever deleted).
  Everything else is a setting or a screen, learned by putting real folders in front of the office and
  adjusting. Less about how the whole company runs; more about being flexible enough to record whatever
  happens.

## Update 2026-10-01

- **QuickBooks Desktop**, confirmed. Edition and year still to read off the start screen.
- **Tammy closes the folders.** She is the sign-off on the close-out step. In the schema that is the
  manager role (close needs manager or above), which is how she is seeded.
- **All users are US citizens and have been cleared with the client.** The export-control gating is a safety net, not a daily path. Each user still gets an attestation recorded in the system by an admin, so the record exists if anyone asks.

## Update 2026-10-13

- **Quote generator** is a standalone static site in its own repo (`1688ross/rms-quote-generator`) for
  Vercel, with an office passcode gate. Interim only; the platform's quote form is the long-term home.
- **Email intake, Ross's words: "you would be integrated into their email."** The plan stays: a reader on
  the office server with read access to a mailbox, matching PO numbers, filing attachments, suggesting
  facts for a person to confirm, quarantining anything that looks like a drawing or carries a marking.
  Whether that reader is rules-only or also uses an AI model is an owner decision with a real trade-off:
  anything a cloud model reads leaves the building. If a model is wanted, the safe shape is a local model
  on the office server, or a cloud model that only ever sees text a local filter has already screened
  (no attachments, no marked content), under a no-retention agreement. Not decided. Still unknown:
  whether the office is on Microsoft 365 or Google Workspace.
- **Built today:** document upload with the marking step and first-page previews, served from the
  server's own store; a step page behind every square (mark done with a note or a document, raise a
  yellow or red, okay it with a reason, post a fix, set aside as a client credit which posts a credit memo);
  money reasons can be acknowledged for 30/60/90 days with the reason on record (migration 0003, `app.po_acks`).
- **Sign-in with a second factor** is in: authenticator app on the phone (Microsoft Authenticator,
  Google Authenticator, 1Password all work), set up on first sign-in, plus eight backup codes.
  Nobody reaches a page without it.
- **Vercel deploys the quote generator from `rossmachinery/quote-generator`** (Git-connected since
  Oct 8). The separate `rms-quote-generator` repo is a leftover duplicate; Ross may delete it.

## Update 2026-10-15: first look on Ross's Mac, and the hover round

Ross ran the stack with Docker on his MacBook and signed in (first time anyone outside the build saw it).
His feedback, all design, all acted on the same day:

- **Deliverables table.** Room at the top of the box; one-word column headers (Quote, Approved, Ordered,
  Production, Carrier, Processing, Shipped, Delivered, Installed) so the header row is one line tall;
  each cell is the square and nothing else. The date, the proof link and the note moved into the hover.
- **Hover cards, both pages.** Step name, then a white box with a green check in the top-right corner
  when the step is done (a red or yellow "!" when it is flagged), then the facts as labelled rows:
  Done or Due or Expected date, Flag, Carrier, Tracking, Proof (a real link to the document page),
  Note. No owner name (who owns a step stays on the step page). A folder with several lines gets one
  block per line, worst first, three at most; lines that say the same thing share one block, and facts
  every line shares are said once at the top. His words:
  "if its under carrier determined it should just say the carrier and a link to the email or document".
  Nothing says "see folder for documents" any more; the document is linked.
- **Wording.** "Okay it" and "Deal with it" struck him as brash. They are now **Acknowledge** (nothing is
  wrong, say why, it comes off the board for 30/60/90 days or until the folder closes; on a flagged step it
  clears the flag with the reason on record) and **Review** (opens the step page, where the choices are
  Mark done, Raise a flag, Acknowledge, Post a fix, Set aside as a client credit). Database action keys
  are unchanged (`okay`, `fix`, `credit`).
- Mechanics worth knowing: the control-panel row is no longer one big link (links inside a link are not
  allowed), the PO number is the link and it stretches over the row; cards stay open while the pointer
  moves into them, and keyboard focus opens them too.

## Update 2026-10-20: quotes in the platform, the client list, and the real names

- The Quotes tab builds its PDF in the browser (same layout as the standalone page); a "Show
  preview" toggle draws the page beside the form as it is typed; the Company box is a client list
  drawn from the parties table with "+ New client", and saving a quote adds the client (with the
  typed address) to that list. Any role that can write (everyone but an auditor) can add a client;
  Ross will confirm that with Chuck.
- **The people, by name:** Ashley Schena, Ross Culliton, Chuck Culliton (president and owner),
  Tammy Smith, Eric Wold. Logins stay as first names; full names show in the top bar, on quotes
  and wherever a person is named. The sample data's "Tammie" and "Zach" were placeholders.
