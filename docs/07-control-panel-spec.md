# 07. The control panel: how the screens should look and behave

Date: 2026-09-29. From Ross's description. This is the screen spec the first build works to; it is expected to
change once the office uses it.

## The idea

A control panel that checks whether all systems are go. One row per open PO. One light per step. Green means
done and clean. Grey means not reached yet. Yellow means something does not line up but nothing is on fire.
Red means someone has to pick up the phone. The people who act on it are the owner, Tammie and Ross.

## The home screen

- Every open PO as a row: client's PO number, client, vendor, a one-line description, and the lights.
- Lights, left to right: RFQ received, quote sent, quote approved, green-lit, in production, testing, QC,
  packaging, shipped, installed or delivered; then the money: vendor invoiced, vendor paid, customer invoiced,
  customer paid, closed.
- Yellow examples: balances do not line up; customer paid but the vendor is not yet paid (holding money); a
  small surplus with nobody asking for it; a step overdue by a little.
- Red examples: a part missing on arrival; a shipment delay; a vendor bill far from the quote; a customer
  payment badly overdue. Red always means "reach out to the customer or vendor."
- Sorting: reds first, then yellows, then by age. Filters by client and year give the client-year view.
- The system judges the money lights itself from the ledger. Physical steps (production, shipped, part
  missing) are set by a person or by a document until email reading exists. The system never guesses a red.

## Clicking a yellow or red

- The PO opens with the reason at the top, in plain words with the amounts and dates. For example:
  "Customer paid $84,200 on Sept 12. Vendor invoice of $79,000 is unpaid. Holding $5,200 for 17 days."
- Under it: what the system found that relates (the entries, the documents, any note or email attached about
  it), so nobody has to dig.
- Actions: okay it as-is with a one-line reason (it turns green and the reason stays on the record); post the
  fix (credit, adjustment, set aside for the client); or add a note about what was agreed. If extra steps are
  needed, the light stays and the note says what is happening.
- Everything done here is kept forever with who and when.

## Opening any PO

Top of the page, the money at a glance:

| Vendor invoice | Status | Invoiced | Paid |
|---|---|---|---|
| amount, vendor, invoice number | Paid / Not paid | date | date, with the stamped invoice or check stub as a thumbnail |

| Customer total | Status | Invoice sent | Paid |
|---|---|---|---|
| amount, invoice number | Paid / Not paid | date | date, with the stamped invoice or check stub as a thumbnail |

Then the progress lights for this PO. Then line items, documents, notes and history.

## Rules for the screens

1. The first thing on every screen is what needs attention, never a grid.
2. It must not look like a spreadsheet.
3. Anything that sends someone to the paper folder is a bug in the screen.
4. The proof (stamped invoice, check stub) is one click away from the number it proves.

## Revision 2026-10-01: fulfillment track, proof on every step, email intake, compact bar

From Ross after showing the first screens to the office (everyone wants it).

**Two tracks in one folder.** The money track stays on the folder: customer invoiced, customer paid,
vendor invoiced, vendor paid, commission balanced, closed. The fulfillment track lives on each line
item, because one PO can hold a custom-built machine and an off-the-shelf part moving at different
speeds: quote sent, quote approved, order placed, in production (if applicable), carrier determined
(including "client arranges"), processing for shipping, shipped, delivered, installed. The order in
which pay and close happen varies by vendor and is never enforced; "closed" needs every light, in
whatever order they arrived.

**Owners and due dates.** Every step has an owner and an expected date. "Order placed" is the
purchaser's. A line sitting in "approved" past its due date goes yellow with the owner's name and
appears in that person's queue. Each person gets a queue (their lines and what is waiting on them);
the owner sees the whole board. Same data, different views. This is how missed orders stop.

**Proof on every step.** A step turns green only with a reference: a document, an email, or a note
from a person. The green square links to its proof ("Customer paid, Sept 12, EFT" opens the
remittance).

**Documents per folder.** A documents tab on the PO page lists everything acquired: type, date,
source (email, scan, upload), who filed it. Ledger entries and steps link to the same documents.

**Email intake.** A watched mailbox. Every message is scanned for the company's SA number or the
client's PO number; a match files the email and attachments into that folder. Attachment type is
recognised from sender and content: vendor order confirmation flips "order placed"; tracking label
flips "shipped"; vendor invoice posts a draft ledger entry for the bookkeeper to confirm; remittance
allocates payments by PO number. No number found means an inbox for a person to file in two clicks.
Every emailed file passes the marking step before it can be viewed.

**Change detection.** A new order confirmation whose quantities or prices differ from the line
items raises a yellow: "Vendor confirmation shows 8, order was 12. Expect the vendor invoice, the
customer invoice, the commission and freight to change." The platform proposes the updated lines and
recalculated quote; a person okays. A phone-call change is typed as a note and raises the same yellow.

**The compact bar.** On the control panel each folder shows one bar of squares, one per step,
filled grey, green, yellow or red; hover shows step, date and proof link. Labels appear only on the
PO page. Must stay readable at forty lines a month for one client.

**People.** Owner (large machine sales), Ashley (tooling, materials and accessories for the same
clients; around forty orders a month for the biggest client), Zach (purchaser; places the orders),
Tammie (payments). Ross builds and administers.
