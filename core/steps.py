"""The fulfillment track: step definitions and how a line's steps become squares."""
import datetime
from django.utils import timezone

STEPS = [
    ("quote_sent", "Quote sent"),
    ("quote_approved", "Quote approved"),
    ("order_placed", "Order placed"),
    ("in_production", "In production"),
    ("carrier_determined", "Carrier determined"),
    ("processing", "Processing for shipping"),
    ("shipped", "Shipped"),
    ("delivered", "Delivered"),
    ("installed", "Installed"),
]
LABEL = dict(STEPS)
ORDER = {k: i for i, (k, _) in enumerate(STEPS)}
# One word per column header, so the header row is always one line tall. The hover card names the step in full.
SHORT = {
    "quote_sent": "Quote", "quote_approved": "Approved", "order_placed": "Ordered", "in_production": "Production",
    "carrier_determined": "Carrier", "processing": "Processing", "shipped": "Shipped", "delivered": "Delivered",
    "installed": "Installed",
}
COLUMNS = [(k, label, SHORT[k]) for k, label in STEPS]
SHIPPING_STEPS = ("carrier_determined", "shipped", "delivered")


def when(d, today=None):
    """Oct 3, or Oct 3, 2025 when it is not this year. Takes a date or a datetime; a datetime is
    shown in the office's time zone, so a step marked done at 9 pm says today's date, not UTC's."""
    today = today or timezone.localdate()
    if isinstance(d, datetime.datetime) and timezone.is_aware(d):
        d = timezone.localtime(d)
    return f"{d:%b %-d}" if d.year == today.year else f"{d:%b %-d, %Y}"


def _days(n, word="late"):
    return f"{n} day{'s' if n != 1 else ''} {word}".strip()


def describe(step, today=None, line=None, carrier=None, doc=None, owner=None):
    """One step on one line, the way a person reads it.

    Returns (state, headline, rows).
      state    green | grey | yellow | red | na
      headline one short phrase: the square's label and the control panel's reason column
      rows     what the hover card lists, in reading order: dicts with a label and either a
               value (text) or a doc (a Document row the template links to); tone marks a row
               to colour (late, yellow, red).
    `line` is the LineItem (tracking number), `carrier` the carrier Party and `doc` the proof
    Document. All optional. (`owner` is accepted and ignored: who owns a step is on the step
    page, not in the card, by Ross's choice.)
    """
    today = today or timezone.localdate()
    if not step.applicable:
        return "na", "Not applicable", [{"value": "Not applicable"}]
    rows, state, headline = [], "grey", "Not yet"
    tracked = step.step_key == "delivered" and line is not None and getattr(line, "tracking_number", None)
    if step.done_at:
        state, headline = "green", f"Done {when(step.done_at, today)}"
        rows.append({"label": "Done", "value": when(step.done_at, today)})
    elif step.due_date:
        word = "Expected" if tracked else "Due"   # the delivered step's due date is the carrier's expected date
        days = (today - step.due_date).days
        if days > 0:
            state = "yellow"
            headline = f"{word} {when(step.due_date, today)}, {_days(days)}"
            rows.append({"label": word, "value": f"{when(step.due_date, today)} · {_days(days)}", "tone": "late"})
        else:
            soon = "today" if days == 0 else f"in {_days(-days, '')}"
            headline = f"{word} {when(step.due_date, today)}" + (f" ({soon})" if tracked else "")
            rows.append({"label": word, "value": when(step.due_date, today) + (f" · {soon}" if tracked else "")})
    if step.flag in ("red", "yellow"):
        state, headline = step.flag, step.flag_reason
        rows.append({"label": "Flag", "value": step.flag_reason, "tone": step.flag})
    if step.step_key in SHIPPING_STEPS and carrier is not None:
        rows.append({"label": "Carrier", "value": carrier.name})
    if step.step_key in ("shipped", "delivered") and line is not None and getattr(line, "tracking_number", None):
        rows.append({"label": "Tracking", "value": line.tracking_number})
    if doc is not None:
        rows.append({"label": "Proof", "doc": doc})
    if step.proof_note:
        rows.append({"label": "Note", "value": step.proof_note})
    if not step.done_at and not step.due_date and step.flag not in ("red", "yellow"):
        rows.insert(0, {"value": "Not yet"})
    return state, headline, rows


def why(label, headline, flagged=False):
    """The control panel's reason column: 'Order placed: due Sep 25, 20 days late'. A flag reason
    is someone's own words, so it keeps its capital."""
    if not headline:
        return label
    if flagged:
        return f"{label} · {headline}"
    return f"{label}: {headline[:1].lower() + headline[1:]}"


def badge(step):
    """What sits in the hover card's corner: 'done' (white box, green check), 'flag', or None."""
    if step.flag in ("red", "yellow"):
        return "flag"
    return "done" if step.done_at else None


def worst(states):
    order = {"red": 3, "yellow": 2, "green": 1, "grey": 0, "na": 0}
    return max(states, key=lambda s: order[s]) if states else "grey"
