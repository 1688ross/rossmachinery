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
