"""
The control panel's judgement. Pure functions over a Folder row plus its notes; no database
access here so it can be unit-tested with plain objects.

A light is one of: 'green' (done and clean), 'grey' (not reached), 'yellow' (something does
not line up, nobody has to phone anyone), 'red' (someone has to pick up the phone).
The money lights the system judges itself. Physical steps are set by people or documents;
the system never guesses a red for them.
"""
from dataclasses import dataclass, field
from decimal import Decimal
from datetime import date

ZERO = Decimal("0")


@dataclass
class Light:
    key: str
    label: str
    state: str  # green | grey | yellow | red
    note: str = ""


@dataclass
class Verdict:
    overall: str
    lights: list = field(default_factory=list)
    reasons: list = field(default_factory=list)   # plain-words explanations, worst first


def _worst(states):
    order = {"red": 3, "yellow": 2, "green": 1, "grey": 0}
    return max(states, key=lambda s: order[s]) if states else "grey"


def money(amount):
    return f"${amount:,.2f}"


def judge(f, notes, today=None):
    """f: a core.models.Folder row (or anything with the same attributes). notes: iterable of
    Note rows. Returns a Verdict."""
    today = today or date.today()
    lights, reasons = [], []

    # --- client side -------------------------------------------------------------
    if f.billed_to_client > ZERO:
        lights.append(Light("client_invoiced", "Customer invoiced", "green", money(f.billed_to_client)))
    else:
        lights.append(Light("client_invoiced", "Customer invoiced", "grey"))
    if f.billed_to_client > ZERO and f.open_client_balance <= ZERO:
        lights.append(Light("client_paid", "Customer paid", "green", money(f.received_from_client)))
    elif f.billed_to_client > ZERO:
        age = (today - f.last_entry_date).days if f.last_entry_date else 0
        state = "red" if age > 90 else ("yellow" if age > 45 else "grey")
        lights.append(Light("client_paid", "Customer paid", state, f"{money(f.open_client_balance)} outstanding"))
        if state != "grey":
            reasons.append((state, f"Customer still owes {money(f.open_client_balance)}; last activity {age} days ago."))
    else:
        lights.append(Light("client_paid", "Customer paid", "grey"))

    # --- vendor side -------------------------------------------------------------
    if f.billed_by_vendors > ZERO:
        lights.append(Light("vendor_invoiced", "Vendor invoiced", "green", money(f.billed_by_vendors)))
    else:
        lights.append(Light("vendor_invoiced", "Vendor invoiced", "grey"))
    if f.billed_by_vendors > ZERO and f.open_vendor_balance <= ZERO:
        lights.append(Light("vendor_paid", "Vendor paid", "green", money(f.paid_to_vendors)))
    elif f.billed_by_vendors > ZERO:
        holding = f.received_from_client - f.paid_to_vendors - f.freight_paid
        if holding > ZERO and f.open_client_balance <= ZERO:
            lights.append(Light("vendor_paid", "Vendor paid", "yellow", f"holding {money(holding)}"))
            reasons.append(("yellow", f"Customer has paid in full. Vendor bill of {money(f.open_vendor_balance)} is still unpaid, so the company is holding {money(holding)}."))
        else:
            lights.append(Light("vendor_paid", "Vendor paid", "grey", f"{money(f.open_vendor_balance)} to pay"))
    else:
        lights.append(Light("vendor_paid", "Vendor paid", "grey"))

    # --- margin sanity: vendor billed more than the customer was billed --------------
    if f.billed_by_vendors > ZERO and f.billed_to_client > ZERO:
        expected_min = f.billed_to_client - f.freight
        if f.billed_by_vendors > f.billed_to_client:
            reasons.append(("red", f"Vendor billed {money(f.billed_by_vendors)}, more than the customer was billed ({money(f.billed_to_client)}). Margin is negative."))
        elif f.gross_margin < ZERO:
            reasons.append(("red", f"Gross margin is negative: {money(f.gross_margin)}."))

    # --- freight -------------------------------------------------------------------
    if f.freight > ZERO:
        state = "green" if f.open_freight_balance <= ZERO else "grey"
        lights.append(Light("freight", "Freight settled", state, money(f.freight)))
    else:
        lights.append(Light("freight", "Freight settled", "grey", "none recorded"))

    # --- sticky notes: the human signal --------------------------------------------
    open_notes = [n for n in notes if n.kind == "sticky" and n.resolved_at is None]
    for n in open_notes:
        text = n.body.lower()
        if any(w in text for w in ("missing", "short", "delay", "damaged", "wrong", "late")):
            reasons.append(("red", f"Note: {n.body}"))
        else:
            reasons.append(("yellow", f"Note: {n.body}"))

    # --- close state ---------------------------------------------------------------
    if f.status == "closed":
        lights.append(Light("closed", "Closed", "green"))
    elif f.ready_to_close:
        lights.append(Light("closed", "Closed", "yellow", "ready to close"))
        reasons.append(("yellow", "Both sides are settled. Ready to close." + (" A note is still open." if open_notes else "")))
    elif f.status == "pending_close":
        lights.append(Light("closed", "Closed", "yellow", "close requested"))
    else:
        lights.append(Light("closed", "Closed", "grey"))

    order = {"red": 0, "yellow": 1, "green": 2, "grey": 3}
    reasons.sort(key=lambda r: order[r[0]])
    states = [l.state for l in lights] + [r[0] for r in reasons]
    overall = _worst([s for s in states if s != "grey"]) if any(s != "grey" for s in states) else "grey"
    if f.status == "closed":
        overall = "green"
    return Verdict(overall=overall, lights=lights, reasons=reasons)
