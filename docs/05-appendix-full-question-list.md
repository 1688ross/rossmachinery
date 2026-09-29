# Discovery questions for the Ross Machinery Sales office

Date: 2026-09-24
Prepared for: Ross, to take to his father's office.
Second readers: the office manager, the bookkeeper, and the outside accountant.

## How to use this list

- Sit down with the office manager and the bookkeeper for about an hour. Bring this list and a pen.
- Answer what you can. Skip what you cannot. "Don't know" is a valid answer; write it down.
- Every unanswered question has a default. We will build under that default. If the default is wrong, say so. That is also an answer.
- Rough numbers are fine. "About 30 a month" is better than nothing.
- Bring back two or three blank sample forms (a customer invoice, a folder cover sheet, a vendor invoice) filled in with made-up numbers. Never real documents. Some folders may hold export-controlled or contract-restricted pages, and this list was written without seeing any of them.
- Where a question says to look through real folders or contracts, do it at the office and bring back only the answer, not the pages.
- The ten questions in the next section matter most. If you only get ten answers, get those.

### Words used in this list

Each is explained once here so the entries stay short.

| Word | What it means here |
|---|---|
| Folder | One physical or digital Project Order (PO) folder: the tab, the cover sheet, the ledger, and the stack of invoices. |
| Line item | One row on an order or invoice: one machine, one tool, one freight charge. |
| Ledger entry | One dated money event on a folder: an invoice, a payment, a credit, a commission received. |
| Schema | The list of tables and columns the database keeps. Changing it after data is in is expensive. |
| Row-level security (RLS) | Rules inside the database that decide which rows each login is allowed to see. |
| Extraction | The software step that reads a scanned page and pulls out the names and numbers. |
| Hot folder | A network folder the system watches. Anything dropped in gets picked up automatically. |
| MFA | Multi-factor authentication: a second step at login, such as a code from a phone app. |
| VPN | An encrypted tunnel into the office network from outside. |
| Docker Compose | A standard way to package the whole system so it installs on one machine as a set. |
| Audit log | A permanent record of who did what, and when. |
| CUI | Controlled Unclassified Information: government-related information that is not classified but must be protected by rule [7]. |
| ITAR | International Traffic in Arms Regulations: the State Department's export rules for defense articles and their technical data (drawings, specs). |
| US person | The ITAR term for a US citizen or green-card holder (and certain other protected persons). |
| DFARS 252.204-7012 | A clause in defense contracts that requires safeguarding "covered defense information" and reporting cyber incidents [2]. |
| NIST SP 800-171 | The government's checklist of security controls that the 7012 clause requires [3]. |
| CMMC | The Department of Defense program for checking that checklist. |
| SPRS | The government database where self-assessment scores are posted [6]. |
| Prime contractor | The company that holds the government contract and buys from you. |
| Phase 1, 2, 3 | Phase 1 is the first working version at Ross Machinery Sales. Phase 2 is the next round once the office is using it. Phase 3 is integrations and later features. |

### Why some defaults look bigger than one office needs

Ross wants to sell this platform to similar companies once Ross Machinery Sales is live. So a few things are built in from day one even though there is only one customer: a company id on every table, security rules that filter by it, no company-specific hard-coding, and branding and integrations behind configuration. None of that is a question for the office; it is Ross's call.

What waits until there is a second customer: sign-up and billing for new companies, separate web addresses per company, white-label screens, a feature-flag admin, and any hosted multi-company deployment. They wait because they cost time now and change nothing for the office. Most "similar companies" will have the same CUI and ITAR constraints, so the sellable product is most likely the same installable bundle this office gets, plus an optional hosted edition for customers without controlled data.

### Priority key

| Priority | Meaning |
|---|---|
| Before build | The schema or the architecture changes depending on the answer. We need it before writing tables. |
| Before Phase 2 | Phase 1 can ship under the default. The answer shapes the next round. |
| Nice to know | Useful context. No design waits on it. |

## The ten to ask first

Update 2026-09-25: Ross has partly answered 1, 4, 5, 6, 7 and 9 (see "Answered so far" lines under Q1, Q15, Q16, Q18, Q29 and Q31). The office visit should confirm those and settle 2, 3, 8, 10 and the new questions N1, N3 and N4 at the end of the list.

These are the answers that most change the design. One line each; the full entry has the detail.

| # | Ask this | Why first | See |
|---|---|---|---|
| 1 | Is one customer order always one folder with one vendor? | Decides the shape of every table. | Q1 |
| 2 | Do you re-sell the machine, or does the vendor pay you a commission? Or both? | Decides what "money in, money out" and "balanced" mean. | Q5 |
| 3 | What has to be true before a folder is closed, who says so, and can it be reopened? | This is the sticky-note process the tool replaces. | Q13 |
| 4 | Are customer invoices made in QuickBooks, in Word, or by hand? | Decides whether the tool makes invoices or only records them. | Q15 |
| 5 | Did "quoting" mean tracking quotes, or producing the quote document? | A small table versus a whole feature. | Q16 |
| 6 | QuickBooks Online, QuickBooks Desktop, or something else? Who works in it? | Decides the whole accounting connection. | Q18 |
| 7 | Is anything formally classified (SECRET stamps, a safe, a clearance), or is it sensitive and contract-restricted? | If formally classified, it can never go in this system. | Q29 |
| 8 | Do your defense customers' contracts list DFARS 252.204-7012? | Turns "on their server only" from a preference into a legal boundary. | Q30 |
| 9 | Do pages in the folders carry CUI, ITAR or Export Controlled stamps? Which pages? | Decides how much of a folder the system may even look at. | Q31 |
| 10 | What is "their server", physically, and who fixes it? | Decides how the system is packaged and who holds the keys. | Q35 |

## The full list

Within each theme, "Before build" questions come first.

### 1. What a folder is

**Q1: When a customer orders something, does that always become exactly one folder with exactly one vendor? Or does one customer order sometimes need parts from two or three vendors? Or does one vendor shipment sometimes cover two customer orders?**  
Why it matters: This is the single most expensive thing to get wrong in the database. Line items, the ledger and the closing rules all hang off whether a folder is one customer order with one vendor, or a project that spans several vendor orders.  
What changes: If strictly one-to-one, the folder table carries the customer order number and the vendor directly; if one order can span vendors, we need a parent project record with one or more vendor POs under it, and balances roll up at the project level; if many-to-many, each line item points at its own vendor PO.  
Answered so far (Ross, 2026-09-25): every RFQ is stored digitally until it is green-lit; after that it needs its own dashboard; a lost, cancelled or delayed bid stays under the client until it resurfaces; when a project has several deliveries, each item shipped is tracked separately. Still open: several vendors on one project.  
If unanswered we assume: A client holds every RFQ ever received, won or not. An RFQ that is green-lit becomes a project with its own PO number and dashboard; a project holds one or more deliverables (each machine or shipment), and each deliverable is tracked through production, testing, QC, packaging, shipped and installed on its own. Balances roll up at the project level. Still to confirm at the office: whether one project can draw on several vendors.
Priority: Before build.

**Q2: What is the very first thing that makes someone start a new folder: a customer's purchase order arriving, a quote being accepted, or you sending a PO to the vendor? Who in the office does that?**  
Why it matters: This sets the entry point of the whole workflow, the first status a record can have, and which document has to exist before a folder is real.  
What changes: Fixes the starting status of a folder and the required first document (customer PO, quote, or vendor PO); if quotes come first, the quote becomes the parent that turns into a folder rather than a side note; also fixes which role can create folders.  
Answered so far (Ross, 2026-09-25): the folder begins at the RFQ, not at the client PO, and the owner wants a dashboard that shows these steps. Still open: who moves a step today, and how the office hears that a machine has moved from production to testing (vendor email, phone, status report).  
If unanswered we assume: The record starts when an RFQ is received, under the client. The steps are: RFQ received, preparing quote, quote sent, quote approved, green-lit, then per deliverable: in production, testing, final testing, QC, packaging, ready to ship, shipped, installed or delivered. Steps are set by hand in Phase 1; from documents and emails later.
Priority: Before build.

**Q3: How is the internal PO number assigned today: a stamp, a logbook, the next line in a spreadsheet? Is there one number per folder, or one per vendor order inside a folder? Should the system carry on the same number series, or can it start fresh?**  
Why it matters: The internal PO number is the one identifier everyone in the office already knows. If the system generates it, it must not collide with numbers already on paper, and it must attach to the right thing.  
What changes: Whether the PO number is typed in (with a uniqueness check) or generated by the database from the current highest number; whether it lives on the project or on each vendor PO (ties back to Q1); and whether numbering must have no gaps for audit purposes.  
Answered so far (Ross, 2026-09-25): all three numbers are in use, and an RFQ may already carry a PO number. Still open: which of the three is on the RFQ, and when the internal number is assigned.  
If unanswered we assume: Three numbers are recorded as separate fields, each filled in when it becomes known: the client's RFQ or PO number, Ross Machinery's internal PO number, and the vendor's order number. None of them is the record's identity. The internal number is assigned at green-light unless the office already stamps it at RFQ intake.
Priority: Before build.

**Q4: Besides machines and tooling, do you sell or arrange services: installation, training, rigging, service calls? Are those invoiced separately, by the hour, or bundled into the machine price?**  
Why it matters: Services do not ship and have no tracking number. If they bill by time they need a quantity and a rate rather than a fixed price. The original brief left the line item categories blank.  
What changes: Sets the fixed list of line item categories (machinery, tooling, accessory, software, freight, service), whether service rows skip shipping status, and whether hourly work needs quantity and unit rate fields.  
If unanswered we assume: "Service" is a category, billed as a fixed-amount line with no time tracking.  
Priority: Before Phase 2.

### 2. How money flows

**Q5: On a typical deal, does the company buy the machine from the vendor and re-sell it (you invoice the customer the full price and pay the vendor)? Or does the vendor invoice the customer directly and pay you a commission afterwards? Or does it depend on the vendor, some one way and some the other?**  
Why it matters: The folder cover sheet shows both "Total Billed to Client" and "Company Commission", which suggests both models exist. Resale and commission deals have completely different money flows, and "balanced" means something different for each.  
What changes: Adds a deal type (resale, commission, or mixed) to each folder, or per line item if mixed; resale means money owed by the customer plus money owed to the vendor, commission means a commission owed to you by the vendor instead; this drives the ledger entry types, the balance formula and any later accounting mapping (sales invoice versus commission income).  
If unanswered we assume: Both models exist; deal type is set per folder; every folder's ledger can hold a customer receivable, a vendor payable and a commission receivable.  
Priority: Before build.

**Q6: When you earn a commission, how is the number worked out: a fixed percentage set by the vendor, negotiated deal by deal, or simply the difference between what you charge and what the vendor charges? And how does it actually arrive: a check from the vendor, a credit on their invoice, or something else?**  
Why it matters: Commission is one of the four summary numbers on every folder, so it has to be recorded and reconciled the same way every time. How it arrives decides what kind of ledger entry it is.  
What changes: Whether commission is calculated (a rate on the vendor or the folder times the sale amount) or typed in per folder; whether we need a "commission received" ledger entry or a credit applied against a vendor invoice; whether vendors carry a default rate.  
If unanswered we assume: The commission amount is entered per folder (with an optional default rate on the vendor as a hint), and its receipt is a separate "commission received" ledger entry.  
Priority: Before build.

**Q7: For big machines, do customers pay in stages: a deposit, a payment before shipment, the rest after installation? Do your vendors make you pay in stages too? Are those stages written on the order, or do they just happen when an invoice shows up?**  
Why it matters: Progress billing means one folder has several customer invoices and several vendor invoices tied to milestones. The gap between paying the vendor and getting paid is real cash the business is fronting.  
What changes: Customer invoices and vendor invoices become one-or-many per folder, each with an optional milestone label, and the balance view must show partial state ("30% in, 30% out"); if schedules are agreed up front, a payment schedule table (expected date, expected amount, which side) lets the dashboard show "next payment due".  
If unanswered we assume: Multiple invoices per side per folder with a milestone label; actual payments only in Phase 1, no expected-payment schedule.  
Priority: Before build.

**Q8: When a customer pays, is it always one check or transfer for one folder? Or do you sometimes get one payment that covers several folders, or several partial payments against one folder? Same question for what you pay vendors.**  
Why it matters: If a payment can span folders, a payment cannot simply belong to one invoice; it has to be split. This is cheap to build from the start and painful to add later.  
What changes: A payments table (amount, date, method, reference) plus a payment allocations table (which invoice, how much) so one check can settle several invoices and each folder's balance still adds up.  
If unanswered we assume: A payment that covers several folders is recorded as one ledger entry per folder, all sharing the check or transfer reference, so each folder balances on its own. A separate payments table that shows one check as one record can be added in Phase 2 if the bookkeeper wants it.  
Priority: Before build.

**Q9: Who arranges freight for a machine: you, the vendor, or the customer? On paper, is it a separate freight company invoice to you that you re-bill, a line on the vendor's invoice, or something you absorb? Do you mark it up?**  
Why it matters: Freight is its own summary number on the folder sheet, and it can run to serious money on machinery. Whether it is a pass-through, a marked-up line, or a cost you eat changes how the balance is computed.  
What changes: Whether freight is a line item category with both a vendor cost and a customer price, a folder-level field, or a separate vendor; freight carriers may need to live in the vendor list flagged as carriers; if the company is not the shipper, the shipment-tracking integration in the brief has little to attach to.  
If unanswered we assume: Freight is a line item category with separate vendor cost and customer price; carriers are stored as vendors flagged as carriers.  
Priority: Before Phase 2.

**Q10: How often does an order change after the folder is open: the customer adds an accessory, the vendor issues a credit, something is returned or cancelled? How do you write that on the folder today?**  
Why it matters: Credits and cancellations are negative or extra entries that break a simple "invoice total" field. They can leave a folder looking unbalanced when it is actually fine.  
What changes: Invoices get a kind (invoice or credit memo) with signed amounts, line items get a status (active, cancelled, returned), and the balance is a sum of signed entries rather than one total; also decides whether a "change order" document type exists.  
If unanswered we assume: Credit memos are supported as negative invoices from day one; no formal change-order workflow, just line item edits plus a note.  
Priority: Before Phase 2.

**Q11: Do you usually pay the vendor before or after the customer has paid you? Is there ever a case where the customer pays the vendor directly and you never touch that money?**  
Why it matters: Paying vendors ahead of collection is cash the business is fronting, and the dashboard should show it. Direct-pay deals are a distinct shape where the folder has no customer receivable at all.  
What changes: A "money out ahead of money in" figure per folder with an alert rule; direct-pay deals map to the commission deal type, where the customer owes you nothing and only a commission is due, and must not be flagged as unbalanced.  
If unanswered we assume: The vendor is paid at or after the customer's payment; direct-pay deals are treated as commission deals.  
Priority: Before Phase 2.

**Q12: Do any vendors bill you in something other than US dollars: euros, yen, Swiss francs? If so, how do you decide what dollar figure goes on the folder sheet, and what happens when the exchange rate moves between invoice and payment?**  
Why it matters: Machine builders are often overseas. If a vendor invoice is in euros, the invoiced amount and the paid amount will not match in dollars, and the balance rule has to say what counts as settled.  
What changes: If yes, every money field stores currency, amount, US dollar amount, exchange rate and rate date, and the ledger gets an exchange gain or loss entry type; if no, every money row still carries a currency column defaulted to USD so it can be switched on later without reworking old data.  
If unanswered we assume: All money rows carry a currency (default USD) and an amount; no conversion logic in Phase 1.  
Priority: Before Phase 2.

### 3. Closing a folder

**Q13: Walk me through what has to be true before a folder gets its "close" sticky note. Is it simply "customer paid us and we paid the vendor", or are there other checks: freight settled, commission received, install finished, warranty started, everything filed? Who has the final say: always the owner, or can someone else close small ones? Does a closed folder ever get reopened, and for what (a late credit, a return, a warranty issue)?**  
Why it matters: The sticky-note-then-management-review step is exactly what the tool replaces. The system can only propose "ready to close" if it knows the real checklist, and the reopen rules decide whether closing is a simple status or a dated, reversible event with history.  
What changes: The list of allowed folder statuses (open, ready to close, closed, reopened); the computed closing conditions (which balances must be zero, which documents must be present); any non-money check as an explicit checklist column rather than a note; an approver role with "closed by" and "closed at"; a closing rule (one approver, or delegation below a dollar amount); a closing-queue screen as a core Phase 1 view; and whether a ledger entry can post to a closed folder.  
If unanswered we assume: Ready to close when the customer has paid in full, all vendor and freight bills are paid, and (for commission deals) the commission is received. The owner is the sole approver; the office manager can propose closure. The system records who closed it and when. Reopening is allowed by the approver with a reason, and a ledger entry posted to a closed folder reopens it automatically.  
Priority: Before build.

**Q14: When your father says he wants everything "balanced", what does he actually check today to know a folder is right? A per-folder check (money in versus money out versus commission), a monthly check against the bank statement, or both?**  
Why it matters: "Balanced" is the owner's stated definition of done, and the system needs a formula, not a feeling. It also tells us whether bank reconciliation belongs in this tool or stays in the accounting package.  
What changes: Defines the per-folder balance view: customer billed minus customer received, vendor billed minus vendor paid, commission expected minus commission received; if matching against the bank statement is part of it, payments gain a bank-cleared date and bank reference and an "uncleared" view.  
If unanswered we assume: Per-folder only; all three balances at zero means balanced; bank reconciliation stays in the accounting package.  
Priority: Before build.

### 4. Quoting and invoicing

**Q15: How do you make a customer invoice today: inside QuickBooks, from a Word or Excel template, or by hand? Could I get a blank one, plus two or three filled in with made-up numbers?**  
Why it matters: If invoices already come out of an accounting package, this tool must not create a competing invoice number series; it should record and link. If they come from Word, the tool can replace that entirely.  
What changes: Whether the platform generates invoices (its own numbering, a PDF template, tax lines) or only records external ones (number, amount, date, attached PDF); invoice generation is a meaningful chunk of scope and sets the direction of any accounting sync (push to it or pull from it).  
Answered so far (Ross, 2026-09-25): the owner wants client invoices, vendor invoices and quotes all tied to QuickBooks so that vendors are paid, the company is paid, commissions match and no balance is left hanging. Still open: whether the invoice itself is created in QuickBooks or elsewhere.  
If unanswered we assume: Client invoices are produced in QuickBooks and recorded here with number, date, amount and PDF; the platform reads and matches, it does not issue. Reversed only if the office says invoices are made outside QuickBooks.
Priority: Before build.

**Q16: How does a quote get made today (who does it, in what tool, what is on it), and about how many quotes turn into orders? When your father said he wants quoting in the system, did he mean building the actual quote document, or keeping track of which quotes are out, which are stale, and which became folders?**  
Why it matters: Quoting is in the owner's definition of done but absent from the brief. Tracking quotes is a small table. Generating quote documents with pricing, versions and expiry dates is a whole feature.  
What changes: Quote tracking means a quotes table (number, customer, vendor, amount, status, sent date, expiry date, the folder it became) and a "convert to folder" action; quote generation adds quote line items, pricing rules, a PDF template, versioning and vendor cost lookup, which is Phase 2 or later; also decides whether "came from quote" is a core field on every folder.  
Answered so far (Ross, 2026-09-25): tracking every quote sent to clients is a core requirement, not a side note. Still open: where the quote document is produced today.  
If unanswered we assume: Quotes are first-class: a quotes table under the client with status (preparing, sent, approved, lost, cancelled, on hold), amounts, dates and the project it became. Whether the quote document is generated here or in QuickBooks follows the Q15 answer.
Priority: Before build.

**Q17: Do you charge sales tax on what you sell, or do most customers hand you a resale or manufacturing exemption certificate? Do you sell into more than one state?**  
Why it matters: Tax changes the invoice math and the balance calculation. Exemption certificates are documents that have to be kept on file and found again.  
What changes: If taxable, invoices get a tax rate and tax amount, customers get a tax status, and more than one state means a tax lookup; if mostly exempt, a single optional tax amount on invoices plus an exemption-certificate document slot on the customer.  
If unanswered we assume: Most sales are exempt; invoices carry an optional tax amount; customers get an exemption-certificate document slot.  
Priority: Before Phase 2.

### 5. Accounting software (and the reports you wish you had)

**Q18: Do you use QuickBooks or something else? If QuickBooks, is it QuickBooks Online or the Desktop version? Who actually works in it (someone in the office, an outside bookkeeper, the CPA), and is that where the official invoices and bills live?**  
Why it matters: The brief assumes QuickBooks Online's cloud connection. The Desktop version has no equivalent, and an outside bookkeeper changes who the users are. For the on-prem version, sending data to a cloud accounting service from an isolated server is itself a data-flow decision.  
What changes: QuickBooks Online keeps the Phase 3 live connection on the table; Desktop means a file export (CSV or IIF) or the Web Connector instead; anything else means a different integration; either way invoices, bills and payments get a generic "external reference" (which system, its id, when synced) so the schema stays neutral, and the on-prem build must run with the integration switched off.  
Answered so far (Ross, 2026-09-25): probably Desktop, edition unknown. The difference matters for how the connection is built (see 04, and the plan's Phase 2); it does not change the ledger.  
If unanswered we assume: QuickBooks Desktop. The connector uses Intuit's Windows-side connector on a machine with QuickBooks installed, which keeps the books in the building. The edition (Pro, Premier, Enterprise) and whether it is still under support must be confirmed from the QuickBooks start screen. The accounting adapter is built so that a later move to Online changes only the connector.
Priority: Before build.

**Q19: Who reconciles the bank account, how often, and where: inside the accounting software, or by hand against the folders?**  
Why it matters: If reconciliation already happens in the accounting package, duplicating it creates two sources of truth. If it is done by hand against folders, this tool's ledger becomes the reconciliation tool.  
What changes: Whether payments need a bank-cleared date, a bank reference and a "not yet cleared" view, or whether Phase 1 stores only payment date, method and reference number.  
If unanswered we assume: Bank reconciliation stays in the accounting package; the platform stores date, method and reference number only.  
Priority: Before Phase 2.

**Q20: If you could get one report every Monday morning, what would it show? For example: who owes us money and how old is it, what we owe vendors, commission earned this month, folders open more than 90 days.**  
Why it matters: The reports people actually want tell us which totals the ledger must produce cheaply and which dates have to be captured. An aging report is impossible without due dates.  
What changes: Which views and indexes exist in Phase 1 (receivables by age per customer, payables by vendor, commission by month, open folders by age) and whether invoices need a due date.  
If unanswered we assume: Four views: receivables aging, payables outstanding, commission by month, open folders by age; invoices carry a due date.  
Priority: Before Phase 2.

**Q21: What does your accountant ask for at year-end or tax time that currently means digging through folders?**  
Why it matters: Reveals which exports must exist and which documents must be findable by date range instead of by folder.  
What changes: A CSV export by date range for invoices, bills, payments and commission, plus document search by date rather than only by folder.  
If unanswered we assume: CSV export of all ledger entries by date range.  
Priority: Nice to know.

### 6. Volumes and backlog

**Q22: Roughly how many new folders get started in a typical month, how many are open at any one time, and how long does a typical one stay open? Separately for a quick tooling order and for a big machine.**  
Why it matters: A list of 30 open folders and a list of 300 need different screens. Volume also decides whether document extraction can run as an overnight batch or needs to be near-instant.  
What changes: Whether the main screen is a simple list or needs filters, search and saved views; whether extraction runs in batches or in real time; which indexes matter (open status, age, next action); long-lived machine folders argue for an expected close date and an age measure on each folder.  
If unanswered we assume: 20 to 40 new folders per month, 60 to 120 open at once; tooling closes in 30 to 60 days, machines in 6 to 18 months.  
Priority: Before build.

**Q23: How many closed folders are in the filing cabinets, how far back do they go, and how often does anyone actually pull one out? Would you be happy starting the system with only new and currently open folders, and scanning old ones only when needed?**  
Why it matters: Digitizing years of closed folders is a big scanning and extraction cost. If they are rarely opened, "scan and attach on demand" avoids most of it. Government contract record-keeping may still require keeping them, but keeping is not the same as extracting.  
What changes: Whether Phase 1 needs a bulk historical import path (a batch queue and header-only "archive" records with a PDF attached) or only live-folder intake; a record-source flag (live or archived) so archived records can skip validation rules that live ones must pass.  
If unanswered we assume: Start forward: open and new folders get full extraction; the closed backlog is scan-and-attach only, header fields only, done on demand.  
Priority: Before build.

**Q24: Where do the digital versions of folders live today: a shared drive letter, Dropbox, OneDrive, Google Drive, QuickBooks attachments, email, or personal desktops? What format are they (PDFs, emails, spreadsheets)? Roughly how many files, and is there a naming pattern such as the PO number in the file name? Are they organized the same way as the paper ones?**  
Why it matters: This is both the migration source and a second intake path. The brief treats intake as scanning paper; if half the folders are already PDFs on a shared drive or in email, a consistent naming pattern lets us bulk-link existing files to folder records without re-scanning. A consumer-cloud location holding controlled data needs to be flagged.  
What changes: Sets the intake sources (manual upload, watched network folder, email) and the original path and file name kept on each document; shapes the Phase 2 migration task (a bulk importer that reads PO numbers from file names); decides whether the on-prem file store must read from a Windows share; if email is a primary source, email-file parsing joins Phase 2.  
Answered so far (Ross, 2026-09-25): digital folders exist on the shared server but not always with the same contents as the paper folder; staff found pulling the paper easier than searching the computer. The goal is to retire the paper documents, keeping them stored for reference.  
If unanswered we assume: The digital folders live on the shared Ross Machinery server, in the same place the system will run, so the cutover reads them in place. Paper and digital sets drift and either may be the more current; the system becomes the single copy and the cutover reconciles both sets per folder.
Priority: Before Phase 2.

### 7. People and roles

**Q25: How many people would use this, and what does each one do with a folder today? For each person: their role, and whether they open folders, add invoices, write in the ledger, enter payments, chase vendors or customers, or decide a folder is done. Does anyone outside the company (bookkeeper, CPA, a customer) ever need to see anything?**  
Why it matters: Roles should mirror who actually touches paper. A three-to-six-person office needs a handful of roles, not the enterprise permission matrix the brief implies, and each extra role is another security rule to test. An outside party needing access changes the security boundary, which matters a great deal for export-controlled material.  
What changes: Fixes the Phase 1 role list (for example owner/approver, office admin, sales/purchasing, finance read-only) and the row-level security rules for each; whether an external-viewer role exists and what it may see (money summary but not technical documents); whether export-controlled documents need a per-document permission flag on top of company isolation; the user count sets how many MFA devices to set up and whether two people editing at once matters.  
If unanswered we assume: Three to six users: owner (approver), office manager (admin), one or two sales/purchasing people, and a bookkeeper (finance); no external access in Phase 1.  
Priority: Before build.

**Q26: Is everyone who would ever touch this system, including employees, the bookkeeper, any outside accountant or IT contractor, and family members who help out, a US citizen or green-card holder? Does anyone work from outside the United States, even occasionally while traveling?**  
Why it matters: ITAR technical data may only go to a US person in the United States or someone otherwise authorized to receive it [5]. One non-US-person login, or one session from abroad, changes the whole access model. Outside accountants and IT contractors are the usual blind spot.  
What changes: A US-person status on each user with a record of who verified it; a security rule that denies export-controlled documents to anyone without it; an IP or geography allowlist on the server's front door; a finance read-only role for an outside bookkeeper that sees ledger numbers but not attachments; contractor accounts with expiry dates.  
If unanswered we assume: All users are US persons; one outside bookkeeper exists and gets a role without document access.  
Priority: Before build.

**Q27: Who will be the boss of this system: the person who decides who gets an account, resets passwords, and answers for it if an auditor or customer asks?**  
Why it matters: Every compliance regime wants a named system owner. This is probably Ross, but the owner has to agree and the office has to know who to call.  
What changes: A system-owner flag on one user, who is named in the runbooks and in any written security plan; the account-administration duties in the plan attach to that person.  
If unanswered we assume: The owner is the system owner; Ross is the sole administrator (see Q42).  
Priority: Before build.

**Q28: Who in the office is least comfortable with computers, and what do they already use without help (email, QuickBooks, Excel, a phone)? What is the one thing about a new system that would make them refuse to use it?**  
Why it matters: Adoption is the real risk. If one key person will not use it, paper folders persist and the system becomes a second filing nightmare rather than the replacement.  
What changes: Sets the scope of the first screens: few screens, large targets, a printable folder cover sheet and ledger so paper-first habits survive the transition; whether keyboard-driven entry or phone capture matters; training and shadowing tasks in the plan.  
If unanswered we assume: Mixed comfort. Design for the least comfortable user and ship a printable cover sheet in Phase 1.  
Priority: Before Phase 2.

### 8. Which rules apply to us (compliance)

A note before this section. The regulation facts below were checked on 2026-09-24, but the checking tool could not open the official government pages directly and relied on search-engine excerpts of them plus law-firm summaries. Treat them as a starting point, not legal advice, and confirm with counsel or a compliance advisor before relying on them.

**Q29: When you say some information is "strictly classified", has the government ever formally classified anything you hold? That means pages stamped CONFIDENTIAL, SECRET or TOP SECRET, kept in a GSA-approved safe, with someone in the office holding a personal security clearance. Does the company have a Facility Security Clearance or a Facility Security Officer? Or do you mean the information is sensitive and contract-restricted?**  
Why it matters: Truly classified material may only be held by a facility with a facility clearance under the NISPOM (32 CFR Part 117), and the government must authorize a contractor's computer system before it processes classified information [1]. So it can never be placed on this or any other unclassified system. If the answer is yes, that material is out of scope by law rather than by choice. Most likely "classified" is shorthand for CUI or ITAR-sensitive, which changes every downstream design decision.  
What changes: If anything is formally classified, the plan gains a hard rule that it is never scanned, the intake screen shows a stop gate with a sign-off, and a folder can carry only a "classified attachments held separately" flag with no content; if nothing is, the word "classified" is removed from all project documents and the architecture targets CUI and ITAR handling instead.  
Answered so far (Ross, 2026-09-25): staff have access into customer facilities such as Sikorsky and Air Force sites; Sikorsky sends material described as "confidential", which almost certainly means proprietary, not classified. Still to confirm: no Facility Security Officer, no safe, no DD Form 254.  
If unanswered we assume: Nothing is formally classified. Ross Machinery Sales has facility access at customers (badges, escorted visits), not a Facility Clearance, and receives customer-proprietary material rather than government-classified material.
Priority: Before build.

**Q30: Look at two or three recent purchase orders or contracts from your biggest defense customers, or from the prime contractors you sell through. In the fine print, do any of them list DFARS 252.204-7012 (Safeguarding Covered Defense Information) or DFARS 252.204-7021 (CMMC)? If you are not sure, note down the clause numbers you see, or we will read the terms pages together at the office.**  
Why it matters: DFARS 252.204-7012 is what legally obligates the NIST SP 800-171 Revision 2 safeguards, reporting of a cyber incident to DoD within 72 hours of discovery, and, for any outside cloud service that stores or processes the data, security equivalent to the government's FedRAMP Moderate baseline [2][3]. Without it, "on their server only" is a preference we honor. With it, it is a legal boundary that also governs whether scanned pages may ever be sent to a cloud AI service.  
What changes: If 7012 is present, the on-prem profile becomes the only launch profile; the extractor becomes a swappable module whose default in the controlled profile never sends page images off the box (cloud extraction only for documents explicitly marked "none", and only after the provider's FedRAMP equivalence is confirmed); the audit log becomes append-only with at least 90 days' retention; and an incident-report runbook joins the Phase 1 deliverables. If absent, the hosted profile is viable and cloud extraction of unmarked documents can ship in Phase 2 without a gate.  
If unanswered we assume: 7012 applies. No document image leaves the server in Phase 1; extraction is a swappable module with the cloud implementation disabled in the on-prem profile.  
Priority: Before build.

**Q31: At the office, flip through five typical folders. Do any pages carry a stamp or header like "CUI", "Controlled Unclassified Information", "ITAR", "Export Controlled", "Distribution Statement" or "FOUO"? Roughly what share of folders have at least one such page? Is it usually the customer's PO, the vendor's quote or invoice, or attached drawings and specs?**  
Why it matters: Marked pages are the concrete trigger for handling rules. If markings appear only on drawings and specs, we can keep those out of the system entirely and shrink the compliance boundary to commercial paperwork (POs, invoices, ledgers).  
What changes: Whether markings live at the document level or the page level (a per-page table filled in during verification); whether the intake screen needs a "do not scan this page" rule; whether the extractor may see the page at all. If marked material is rare, Phase 1 can exclude it with a "controlled attachment held in paper file" flag and the hosted profile becomes viable sooner.  
Answered so far (Ross, 2026-09-25): the sensitive items are drawings and blueprints, which are typically not part of this side of the orders. Still to confirm at the office: the exact wording of any stamp on a Sikorsky PO or quote.  
If unanswered we assume: Drawings and blueprints are the sensitive material and they do not normally travel in these order folders; the folders hold commercial paperwork. Drawings stay outside the system with at most a pointer to where the package is kept. Export-control gating remains for the exception.
Priority: Before build.

**Q32: Is the company registered with the State Department's Directorate of Defense Trade Controls (DDTC)? You would have a registration code (usually starting with "M") and pay a yearly fee. If not, has any customer or vendor ever asked for your ITAR registration number or made you sign an ITAR certification?**  
Why it matters: Registration is required for anyone in the business of manufacturing, exporting, temporarily importing or brokering defense articles (22 CFR Part 122) [4], but a purely domestic distributor can still receive ITAR-controlled technical data (drawings, specs) from vendors and customers. The answer decides whether US-person access restrictions are a legal requirement or merely good practice.  
What changes: If registered or handling ITAR technical data: users get a US-person status with who verified it and when; documents get an export-control marking (none, ITAR, EAR, CUI, unreviewed); a security rule denies ITAR-marked documents to any non-US-person user regardless of role; and the on-prem profile keeps the encryption keys under company control, because the ITAR encryption carve-out (22 CFR 120.54) only treats encrypted storage as "not an export" when the data is end-to-end encrypted with FIPS 140-2-class modules (or at least AES-128-equivalent strength) and the means of decryption are not given to any third party [5]. If not, the same columns exist, default to "none", and the rule is inert.  
If unanswered we assume: Not registered, but some vendor drawings or specs are ITAR technical data. Build the marking column and the US-person gate now.  
Priority: Before build.

**Q33: Has anyone at the company ever filled out a NIST SP 800-171 self-assessment, posted a score to the government's SPRS system, or been asked by a customer for your "SPRS score" or "CMMC level"? Who did it, when, and do you still have the spreadsheet or letter?**  
Why it matters: An existing self-assessment is the only inventory of security controls the office has, and it tells us what evidence a prime will ask for again. As of September 2026, DoD has suspended CMMC Phase 2 (the third-party certification step, suspended on July 13, 2026 pending a review) and is enforcing NIST SP 800-171 Revision 2 through CMMC Level 1 and Level 2 self-assessments; DFARS 252.204-7012 remains in force, and the 7019/7020 clauses that post summary scores to SPRS are still on the books [3][6]. So a prime asking for a score today may be asking under either route.  
What changes: If a self-assessment exists, the system's control mapping (MFA, per-user accounts, audit logging, encryption at rest, session timeout) is written against those specific 800-171 control families in Phase 1, and the schema gains what the evidence needs (when each user enrolled in MFA; who, what, which record, before and after on every audit entry). If none exists, we build the same controls but defer the written system security plan to Phase 2.  
If unanswered we assume: No score exists. Build 800-171-aligned basics (individual accounts, mandatory MFA, tamper-proof audit log, encrypted storage) from day one, because they are cheap now and expensive to retrofit.  
Priority: Before Phase 2.

**Q34: Has a customer, prime contractor or government agency ever audited you or sent a security questionnaire (a supplier cyber questionnaire, a DCMA or DCAA visit, an export-compliance review)? Do you still have the paperwork and your answers?**  
Why it matters: A past questionnaire is the cheapest possible requirements document. It says exactly what evidence the customer will ask for again.  
What changes: Adds specific evidence exports (user list with MFA status, audit-log export, backup proof) and may pull the written system security plan forward into Phase 1.  
If unanswered we assume: No formal audit yet; a prime's supplier questionnaire arrives within a year.  
Priority: Before Phase 2.

### 9. The server and IT reality

**Q35: Describe "their server". What is it physically: a tower under a desk, a rack, a NAS like Synology or QNAP, or a rented machine somewhere else? What operating system, and how old? Who set it up, and who fixes it when it breaks: an employee, a local IT company, or nobody?**  
Why it matters: "Lives on their server only" is the central constraint. An aging Windows box that nobody administers is a very different target from a supported Linux host. The answer dictates whether Docker packaging is even viable and who holds the administrator credential.  
What changes: Chooses the on-prem packaging (Docker Compose on Linux, a Windows-hosted stack, or a new small dedicated host we specify); whether Phase 1 includes a "hardware and operating system baseline" task; the patching and upgrade path; where the database, file store and backups physically sit.  
If unanswered we assume: No suitable server exists. Phase 1 specifies one new small Linux host running Docker Compose (database, app, file store), administered by Ross with written runbooks.  
Priority: Before build.

**Q36: How do people log in to their computers today: a shared password everyone knows, individual Windows accounts, Microsoft 365 or Google Workspace accounts, or something an IT company set up (Active Directory)? Does everyone have their own account, or are some computers shared?**  
Why it matters: Decides whether the app can lean on an existing company login system for accounts and MFA, or must keep its own user list. Shared accounts break the per-person audit trail the compliance rules expect.  
What changes: The Phase 1 login choice: local accounts with app-based MFA (the default) versus sign-in through Microsoft or Google; users gain an external identity link; mapping of directory groups to roles lands in Phase 1 or Phase 2 accordingly.  
If unanswered we assume: No directory. The app owns its users with mandatory MFA; sign-in through a company identity provider is a Phase 2 configuration option.  
Priority: Before build.

**Q37: How reliable is the office internet, and would work stop if it dropped for a day? Does anyone, including the owner, need to open folders from home, on the road, or on a phone? Is there a VPN today?**  
Why it matters: An on-prem system reachable only inside the office is the simplest secure design. Every remote-access need adds a door that must be guarded with a VPN, MFA and device rules.  
What changes: Whether Phase 1 ships office-network-only with no public exposure, or adds a VPN-only remote path; whether phone-sized layouts move from nice-to-have to required; whether the intake queue must tolerate internet outages (only relevant if any extraction or integration calls leave the box).  
If unanswered we assume: Office network only at launch. Remote access through a company-managed VPN with MFA is Phase 2; the app is never exposed directly to the internet.  
Priority: Before build.

**Q38: If the system ran on a computer with no internet connection at all, so you could only use it from inside the office, would that be acceptable or a deal-breaker? What would you lose: email attachments, vendor web portals, QuickBooks Online, shipment tracking?**  
Why it matters: The strictest reading of the owner's security wish is a machine with no outside connection. That rules out cloud AI extraction, live shipping tracking, QuickBooks Online sync and email intake unless we build a controlled bridge. Knowing the real tolerance avoids designing for a constraint nobody wants.  
What changes: If fully isolated is acceptable, the on-prem extractor must be hosted locally or replaced by template-assisted manual entry, and every integration moves to a later phase behind an explicit export/import file format; if not, the on-prem profile gets an outbound-only allowlist (AI service, accounting, carriers) with per-document release rules based on its marking.  
If unanswered we assume: Not fully isolated. Outbound-only allowlisted connections; any document marked controlled, or still unreviewed, never leaves the box.  
Priority: Before build.

**Q39: What gets backed up today, where does it go (external drive, a cloud service, tape, nothing), how often, and when did anyone last actually restore a file from it and confirm it worked?**  
Why it matters: The new system will hold the only copy of years of financial records, and an untested backup is not a backup. Backups of controlled data that flow to a consumer cloud service are themselves a compliance problem.  
What changes: The backup design in the on-prem profile (a nightly encrypted database dump plus a file-store snapshot to an encrypted local drive, with an offsite copy only to a location that satisfies the controlled-data rule); a restore drill becomes a Phase 1 acceptance test; how much data we can afford to lose and how long a restore may take are written into the plan.  
If unanswered we assume: No reliable backup exists. The plan includes nightly encrypted local backups with a monthly restore test; the offsite copy is decided after the contract-clause and markings answers (Q30, Q31).  
Priority: Before build.

**Q40: What do you scan with today: the office copier, a desktop scanner, phone cameras? What is the make and model, can it scan both sides of a page in one pass, and can it be set to drop scans straight into a network folder or email them automatically?**  
Why it matters: Digitizing thousands of pages is the real bottleneck. A copier that can scan both sides at 300 dpi straight to a network folder turns intake into a watched hot folder instead of a manual upload button.  
What changes: Intake design: a hot-folder service on the server with a drop folder per user (so we know who scanned what) versus browser upload only; a written scan profile (300 dpi, PDF, both sides, blank-page removal); whether the plan budgets a dedicated document scanner; the fixed list of document sources (scanner, upload, email).  
If unanswered we assume: The existing copier can scan to a network folder. Phase 1 accepts browser upload only; hot-folder intake arrives in Phase 2.  
Priority: Before Phase 2.

**Q41: Where does company email live: Microsoft 365, Google Workspace, an internet-provider mailbox, or on the server? Do most vendor invoices and customer POs arrive by email, and whose inbox do they land in?**  
Why it matters: Most "digital folders" are probably email attachments, so where email lives decides whether an email intake path is feasible. It also tells us whether controlled data is already sitting in a commercial cloud mailbox today, which changes the compliance conversation even though fixing it is outside this project.  
What changes: Documents gain a source of "email" plus the message id and sender; Phase 2 decides on a mailbox poller limited to allowlisted senders; the plan carries a flagged note if CUI is currently arriving in a non-government mailbox.  
If unanswered we assume: Commercial Microsoft 365. Email intake in Phase 1 is manual: save the attachment, then upload.  
Priority: Before Phase 2.

**Q42: If Ross were unavailable for a month, who could restart the server, restore a backup, or add a user? Is there a local IT company you would trust with that, and would their technicians be US persons willing to sign a confidentiality agreement?**  
Why it matters: A one-person-administered system is both a business-continuity gap and a compliance gap, because contractor access to controlled data must itself be controlled.  
What changes: Runbooks become a Phase 1 deliverable; a sealed break-glass admin credential (an emergency password kept in a sealed envelope); a contractor account type with an expiry date and no document access; a "second administrator" task in the plan.  
If unanswered we assume: Ross is the sole administrator. Runbooks and a sealed break-glass credential ship in Phase 1.  
Priority: Nice to know.

### 10. Access, retention and what a bad day looks like

**Q43: Tell me about the worst filing day you have had: a folder that went missing, an audit or customer request where you could not find the paperwork, a vendor paid twice, or a time you worried a document reached the wrong person. What happened, and what did it cost?**  
Why it matters: Real incidents rank which failure the system must prevent first (findability, double payment, or leakage) and define what "audit-ready" means in practice.  
What changes: Reorders Phase 1 feature priority (search and retrieval, ledger reconciliation, or access controls); whether a "bundle everything for folder X into one PDF" export ships early; whether a duplicate-invoice check (same vendor, same invoice number) with a warning is Phase 1.  
If unanswered we assume: Findability is the top pain. The duplicate-invoice check ships in Phase 1 regardless.  
Priority: Before Phase 2.

**Q44: How long do you keep closed folders, and why that long: the accountant's advice, a customer contract, an auditor? Have you ever thrown any out, and do you have folders older than seven years?**  
Why it matters: Retention drives storage sizing and whether a deletion or legal-hold feature is needed. Defense contracts and ITAR each carry their own record-keeping periods, so deleting too early and too late are both risks.  
What changes: A retention class on folders and documents, a legal-hold flag, and a purge job in Phase 3 or never (default: soft delete only); disk sizing for the on-prem host.  
If unanswered we assume: Keep everything forever; soft delete only; no purge job.  
Priority: Nice to know.

**Q45: Do people take photos of paperwork with personal phones, text them to each other, or use personal email for work? Does anyone use a personal laptop for company files?**  
Why it matters: Personal devices are the most common leak path for controlled data, and the system cannot protect what flows around it. A sanctioned phone-capture path can reduce leakage by replacing the phone-photo habit.  
What changes: Whether Phase 2 includes a sanctioned mobile capture route (over VPN) and an acceptable-use rule; whether device-bound sessions or IP allowlisting go into the server's front-door configuration.  
If unanswered we assume: Some phone photos happen. The plan carries a policy note; no personal-device support in Phase 1.  
Priority: Nice to know.

## Questions Ross can answer without the office

These are really for Ross. Settle them before the office visit, or confirm them with the owner in one sentence.

- **System owner (Q27).** Will Ross be the named system owner: the person who creates accounts, resets passwords and answers an auditor? Or will that be the owner on paper, with Ross administering? Decide, then tell the office who to call.
- **Server administration and the second administrator (Q35, Q42).** Ross can inspect the existing server himself: what it is, which operating system, how old, and whether it is fit for Docker Compose. He should also decide who the backup administrator will be if he is away, and whether an outside IT company is acceptable under the US-person rule.
- **The brand system.** Not one of the 48 discovery questions; it comes from the owner context. A brand system for Ross Machinery Sales already exists and Ross has it. It is not needed for the schema or the plan, but the first UI task should be themed from it rather than from generic defaults. Ross should confirm where it lives and put it in the repository before the first screen is built.
- **Look-and-see checks.** Ross can answer the factual half of these by looking, and leave only the human half for the office:
  - Q36: how a PC logs in (shared password, Windows account, Microsoft 365, Active Directory). The office still answers "are any computers shared?"
  - Q37: whether a VPN exists. The office still answers "who needs remote access?"
  - Q39: where backups go and how often. The office still answers "when did a restore last work?"
  - Q40: the copier's make and model, and whether it scans both sides to a network folder.
  - Q41: where company email is hosted. The office still answers "whose inbox do invoices land in?"
- **Multi-company groundwork.** Everything in "Why some defaults look bigger than one office needs" is Ross's decision, not the office's. The office never needs to hear the words tenant or white-label.

## Added 2026-09-25 from Ross's answers

These came out of the first round of answers and are not in the original 45.

**N1: Confirm the pipeline steps and who moves them.** The proposed list is: RFQ received, preparing quote, quote sent, quote approved, green-lit; then per deliverable: in production, testing, final testing, QC, packaging, ready to ship, shipped, installed or delivered. Are any missing, unused, or in a different order? Who in the office would change a step, and how do they find out today that a machine has moved (vendor email, phone call, vendor status report, a site visit)?  
Why it matters: The dashboard is built from this list, and the answer decides whether steps are set by hand in Phase 1 or read from documents and emails.  
What changes: The step list in the schema; whether the first version is manual; which emails the Phase 2 intake has to read.  
If unanswered we assume: The list above, set by hand, with a date and a note per step.  
Priority: Before build.

**N2: Lost, cancelled and delayed bids.** How often does an RFQ that was lost or shelved come back later, and under what name: the same RFQ number, a new one, a new PO? Does anyone review old RFQs, and would a reminder help?  
Why it matters: Decides how an old RFQ is found again and whether the client folder needs a "resurfaced" action or just a status.  
What changes: Statuses for a quote (lost, cancelled, on hold) and whether a new project can be linked back to an old quote.  
If unanswered we assume: Quotes keep their status under the client; a new project may link to any earlier quote by hand.  
Priority: Before Phase 2.

**N3: The three numbers.** On a typical deal, which number appears first and on which document: the client's RFQ or PO number, Ross Machinery's own PO number, or the vendor's order number? When is the internal number assigned, and by whom?  
Why it matters: The three are separate fields, but the timing decides when the internal number is handed out and whether lost bids use up numbers.  
What changes: When the internal PO number is allocated (RFQ intake or green-light) and whether the series may have gaps.  
If unanswered we assume: Internal number at green-light; the client's number recorded at RFQ intake; vendor number when the order is placed.  
Priority: Before build.

**N4: Several deliveries on one project.** When one order has several machines or shipments, how is that written up today: one folder with several lines, several folders, a packing list per shipment? Does each delivery get its own invoice or its own install date?  
Why it matters: Each deliverable is tracked separately through the steps and may carry its own invoices and dates.  
What changes: Whether ledger entries and documents attach to the project or to a specific deliverable.  
If unanswered we assume: Deliverables sit under the project; money attaches to the project; step dates attach to the deliverable.  
Priority: Before build.

**N5: What is done inside QuickBooks today.** Are quotes, client invoices, vendor bills and payments all entered in QuickBooks, or only some? Who enters them, and how soon after the paper arrives? Which edition and year is on the start screen?  
Why it matters: The owner wants quotes, vendor invoices and client invoices tied to QuickBooks. What is already there decides the direction of each connection and how much double entry the platform removes.  
What changes: Per document type: platform records and pushes to QuickBooks, or QuickBooks is the source and the platform reads.  
If unanswered we assume: QuickBooks Desktop holds invoices and bills; the platform records and matches them; quotes are recorded here first.  
Priority: Before Phase 2.

**N6: Whose inbox.** Where do vendor status updates, vendor invoices and client POs arrive: one shared mailbox, individual inboxes, both? Is email on the server or hosted (Microsoft 365, Google)?  
Why it matters: Reading emails for status and documents is a Phase 2 feature and the most sensitive data flow in the system; it needs a single known mailbox.  
What changes: Whether an email intake is feasible and which mailbox it watches.  
If unanswered we assume: No email intake in Phase 1; documents are uploaded or scanned by hand.  
Priority: Before Phase 2.

**N7: Proof documents per step.** For each step, is there a document that proves it happened (a quote PDF for "quote sent", a signed PO for "green-lit", a packing list for "shipped", an install report for "installed")? Which steps have none and rely on a phone call?  
Why it matters: Steps with a proof document can be advanced from the document; the rest stay manual.  
What changes: Which document kinds the intake screen offers and which steps they can advance.  
If unanswered we assume: Quote, client PO, vendor order confirmation, packing list and install report are the proof documents; other steps are manual.  
Priority: Before Phase 2.

**N8: Why folders end up out of balance.** Think of the last five folders that did not balance cleanly. What caused each one: a part shipped short, a substitution after payment, a vendor not charging for something, freight billed twice, a rounding or currency difference? How was each resolved, and where was that written down?  
Why it matters: The platform should name the cause in plain words and offer the right fix; the real causes decide the list it starts with.  
What changes: The discrepancy categories and the resolution actions (credit, adjustment, set aside for the client, write off).  
If unanswered we assume: Short shipment, substitution, vendor did not charge, vendor over-billed, freight difference, other with a note.  
Priority: Before build.

**N9: Money held or set aside.** When the company is holding money for a client, or owes a client a make-good from an earlier order, where is that written today: the folder, a spreadsheet, QuickBooks, someone's memory? Roughly how many such balances exist right now and how old is the oldest? Does anyone owe the company the same way?  
Why it matters: These balances have to survive the cutover and be visible at year-end; if they live only in memory, the first job is to write them down.  
What changes: Whether client credits are imported at cutover with opening balances, and whether vendor-side credits are needed too.  
If unanswered we assume: Client credits are imported at cutover from the office's list; vendor credits handled as ledger credit memos.  
Priority: Before build.

**N10: The client-year list.** Could I see the layout of the per-client, per-year spreadsheet, with made-up numbers? Which columns does your father actually look at, and which questions send him to the paper folder?  
Why it matters: That spreadsheet is the hub the platform replaces, and the questions that send him to the paper are the ones the screen must answer first.  
What changes: The columns and grouping of the client-year view and what the folder screen shows at the top.  
If unanswered we assume: Per client per year: ready to close, waiting on client payment, vendor to be paid, waiting on invoices, money held or set aside.  
Priority: Before build.

## Printable checklist

Tick each line when you have an answer or a "don't know". Group headings match the full list.

**What a folder is**
- [ ] Q1 One customer order = one folder with one vendor, always? Or several vendors, or shared shipments?
- [ ] Q2 What starts a folder (customer PO, accepted quote, our vendor PO), and who does it?
- [ ] Q3 How is the internal PO number assigned; one per folder or per vendor order; keep the series?
- [ ] Q4 Do you sell services (install, training, rigging); separate, hourly, or bundled?

**How money flows**
- [ ] Q5 Resale (we invoice and pay the vendor) or commission (vendor invoices, pays us)? Or both?
- [ ] Q6 How is commission worked out, and how does it arrive?
- [ ] Q7 Stage payments on big machines, from customers and to vendors? Written on the order?
- [ ] Q8 One payment per folder, or payments that span folders or come in parts?
- [ ] Q9 Who arranges freight; how does it appear on paper; is it marked up?
- [ ] Q10 How often do orders change after opening (add-ons, credits, returns, cancellations)?
- [ ] Q11 Do you pay the vendor before or after the customer pays? Any customer-pays-vendor-direct deals?
- [ ] Q12 Any vendors billing in a foreign currency? How is the dollar figure decided?

**Closing a folder**
- [ ] Q13 What must be true to close; who has the final say; can a folder reopen, and why?
- [ ] Q14 What does "balanced" mean: per-folder check, bank statement check, or both?

**Quoting and invoicing**
- [ ] Q15 How are customer invoices made (QuickBooks, Word/Excel, by hand)? Blank sample with made-up numbers?
- [ ] Q16 How are quotes made, how many convert, and did "quoting" mean tracking or producing the document?
- [ ] Q17 Sales tax charged, or mostly exemption certificates? More than one state?

**Accounting software**
- [ ] Q18 QuickBooks Online, Desktop, or other? Who works in it? Where do official invoices live?
- [ ] Q19 Who reconciles the bank account, how often, and where?
- [ ] Q20 The one Monday-morning report you wish you had?
- [ ] Q21 What does the accountant ask for at year-end that means digging through folders?

**Volumes and backlog**
- [ ] Q22 New folders per month; open at once; how long open (tooling versus machine)?
- [ ] Q23 How many closed folders in the cabinets; how far back; how often pulled? OK to start forward?
- [ ] Q24 Where do digital folders live; what format; how many; naming pattern?

**People and roles**
- [ ] Q25 Who uses it and what does each person do with a folder? Anyone outside the company?
- [ ] Q26 Is everyone who touches it a US citizen or green-card holder? Anyone working from abroad?
- [ ] Q27 Who is the boss of the system (accounts, resets, answers to auditors)?
- [ ] Q28 Who is least comfortable with computers, and what would make them refuse it?

**Which rules apply to us**
- [ ] Q29 Formally classified (stamps, safe, clearance, FSO), or sensitive and contract-restricted?
- [ ] Q30 Do customer or prime contracts list DFARS 252.204-7012 or 7021? (Look at the office; note clause numbers.)
- [ ] Q31 CUI / ITAR / Export Controlled stamps in folders? What share, and on which pages?
- [ ] Q32 Registered with DDTC (an "M" code, yearly fee)? Ever asked for an ITAR number or certification?
- [ ] Q33 Ever done a NIST SP 800-171 self-assessment or posted an SPRS score? Asked for a CMMC level?
- [ ] Q34 Ever audited or sent a security questionnaire (supplier cyber, DCMA/DCAA, export review)? Paperwork kept?

**The server and IT reality**
- [ ] Q35 What is "the server" physically; operating system; age; who set it up; who fixes it?
- [ ] Q36 How do people log in (shared password, Windows accounts, Microsoft 365, Active Directory)? Shared PCs?
- [ ] Q37 How reliable is the internet; who needs remote or phone access; is there a VPN?
- [ ] Q38 Would a no-internet, office-only system be acceptable? What would you lose?
- [ ] Q39 What is backed up, where, how often, and when did a restore last work?
- [ ] Q40 What do you scan with; make and model; both sides; scan-to-folder or email?
- [ ] Q41 Where does email live; do invoices and POs arrive by email; whose inbox?
- [ ] Q42 If Ross were away a month, who could restart, restore or add a user? Trusted IT company? US persons?

**Access, retention and what a bad day looks like**
- [ ] Q43 Worst filing day: lost folder, unfindable paperwork, vendor paid twice, document to the wrong person?
- [ ] Q44 How long are closed folders kept, and why? Ever thrown out? Older than seven years?
- [ ] Q45 Personal phones, texts, personal email or personal laptops used for work paperwork?

## Sources

Regulation facts in this document were fact-checked on 2026-09-24. The checker could not open the official pages directly and used search-engine excerpts of them plus law-firm summaries; the source pages themselves are listed here for confirmation.

1. NISPOM, 32 CFR Part 117 (facility clearances, the Facility Security Officer, and government authorization of contractor systems before they process classified information): https://www.ecfr.gov/current/title-32/subtitle-A/chapter-I/subchapter-D/part-117 and https://www.dcsa.mil/Industrial-Security/National-Industrial-Security-Program-Oversight/32-CFR-Part-117-NISPOM-Rule/
2. DFARS 252.204-7012, Safeguarding Covered Defense Information and Cyber Incident Reporting (72-hour reporting; FedRAMP Moderate-equivalent requirement for external cloud services): https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.
3. NIST SP 800-171 Revision 2 remains the required version under 7012, and CMMC Phase 2 was suspended on July 13, 2026 with self-assessment enforced in the meantime: https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final ; https://www.acq.osd.mil/dpap/dars/classdev/DFARS_RFO/Part-240/2026-O0025_TAB_A_Deviation_Memo_DFARS_240.pdf ; https://federalnewsnetwork.com/cybersecurity/2026/07/pentagon-suspends-cmmc-phase-two-requirements-launches-review-of-program/ ; https://www.pivotpointsecurity.com/revision-3-of-dars-class-deviation-2026-o0025/
4. ITAR registration, 22 CFR Part 122: https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-122/section-122.1
5. ITAR encryption carve-out and who may receive technical data, 22 CFR 120.54: https://www.ecfr.gov/current/title-22/chapter-I/subchapter-M/part-120/subpart-C/section-120.54 and https://www.law.cornell.edu/cfr/text/22/120.54
6. DFARS 252.204-7019 and 252.204-7020 (NIST SP 800-171 DoD assessment requirements; summary scores posted in SPRS): https://www.acquisition.gov/dfars/252.204-7019-notice-nistsp-800-171-dod-assessment-requirements. and https://www.acquisition.gov/dfars/252.204-7020-nist-sp-800-171dod-assessment-requirements.
7. What CUI is (Executive Order 13556, 32 CFR Part 2002): https://www.archives.gov/cui/about
