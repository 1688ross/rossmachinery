from decimal import Decimal
from django import template

register = template.Library()

@register.filter
def money(value):
    """$1,234.56 and -$1,234.56. Never $-1234.56."""
    if value is None:
        return ""
    v = Decimal(value)
    sign = "-" if v < 0 else ""
    return f"{sign}${abs(v):,.2f}"

@register.filter
def signed(value):
    v = Decimal(value)
    return f"{'-' if v < 0 else ''}{abs(v):,.2f}"

KIND_LABELS = {
    "client_invoice": "Invoice", "client_payment": "Payment", "vendor_bill": "Bill", "vendor_payment": "Payment",
    "freight_charge": "Freight", "commission_earned": "Commission", "commission_received": "Commission received",
    "credit_memo": "Credit memo", "adjustment": "Adjustment", "reversal": "Reversal",
}

@register.filter
def kind_label(kind):
    return KIND_LABELS.get(kind, kind.replace("_", " ").capitalize())
