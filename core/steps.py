"""The fulfillment track: step definitions and how a line's steps become squares."""
from datetime import date

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


def square(step, today=None, line=None):
    """Return (state, title) for one LineStep row. `line` (the LineItem) adds tracking detail."""
    today = today or date.today()
    label = LABEL.get(step.step_key, step.step_key)
    if not step.applicable:
        return "na", f"{label}: not applicable"
    # Shipping detail: the delivered step's due_date is the carrier's expected delivery date.
    if step.step_key == "delivered" and not step.done_at and step.due_date and line is not None and getattr(line, "tracking_number", None):
        days = (step.due_date - today).days
        when = "today" if days == 0 else (f"in {days} day{'s' if days != 1 else ''}" if days > 0 else f"{-days} day{'s' if days != -1 else ''} late")
        state = "grey" if days >= 0 else "yellow"
        return state, f"Expected delivery {step.due_date:%b %-d} ({when}) · tracking {line.tracking_number}"
    if step.step_key == "shipped" and step.done_at and line is not None and getattr(line, "tracking_number", None):
        return "green", f"Shipped {step.done_at:%b %-d} · tracking {line.tracking_number}"
    if step.flag == "red":
        return "red", f"{label}: {step.flag_reason}"
    if step.flag == "yellow":
        return "yellow", f"{label}: {step.flag_reason}"
    if step.done_at:
        t = f"{label}: done {step.done_at:%b %-d}"
        if step.proof_note:
            t += f" · {step.proof_note}"
        return "green", t
    if step.due_date and step.due_date < today:
        days = (today - step.due_date).days
        return "yellow", f"{label}: due {step.due_date:%b %-d}, {days} days late"
    if step.due_date:
        return "grey", f"{label}: due {step.due_date:%b %-d}"
    return "grey", f"{label}: not yet"


def squares_for_line(steps, today=None, line=None):
    rows = sorted(steps, key=lambda s: ORDER.get(s.step_key, 99))
    return [dict(zip(("state", "title"), square(s, today, line)), key=s.step_key, step=s) for s in rows]


def worst(states):
    order = {"red": 3, "yellow": 2, "green": 1, "grey": 0, "na": 0}
    return max(states, key=lambda s: order[s]) if states else "grey"
