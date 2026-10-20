"""
Quotes: the office's quote form, replacing the Word template. Lives in the django schema for now
(a quick win); moves to schema app with migration 0003 when quotes become the start of a folder.
"""
from decimal import Decimal
from functools import cached_property
from django.conf import settings
from django.db import models

# One per order, for reporting (Ross, 2026-10-20). Values match app.order_type in migration 0004.
ORDER_TYPES = [("custom", "Custom"), ("otr_machine", "Off the Rack (OTR) Machine"), ("parts", "Parts"), ("materials", "Materials"),
               ("accessories", "Accessories"), ("software", "Software"), ("service", "Service / Maintenance"), ("repair", "Repairs"),
               ("misc", "Miscellaneous")]


class Quote(models.Model):
    number = models.CharField(max_length=40, unique=True)
    quote_date = models.DateField()
    to_name = models.CharField(max_length=120, blank=True)
    to_company = models.CharField(max_length=160)
    to_address = models.TextField(blank=True)
    subject = models.CharField(max_length=200)
    reference = models.CharField(max_length=120, blank=True)      # e.g. the client's RFQ number
    intro = models.TextField(blank=True)
    fob = models.CharField(max_length=160, blank=True)
    delivery = models.CharField(max_length=160, blank=True)
    terms = models.CharField(max_length=160, blank=True)
    closing = models.TextField(blank=True)
    signer_name = models.CharField(max_length=120)
    signer_title = models.CharField(max_length=120, blank=True)
    lines = models.JSONField(default=list)   # [{item, description, details:[...], qty, unit_price}]
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    po_id = models.UUIDField(null=True, blank=True)   # the folder this quote started, once it exists
    client_party_id = models.UUIDField(null=True, blank=True)   # app.parties row (the client list); RLS decides what we can see
    contact_ids = models.JSONField(default=list, blank=True)    # app.party_contacts ids, the addressee first
    order_type = models.CharField(max_length=20, blank=True, choices=ORDER_TYPES)

    class Meta:
        db_table = 'django"."quotes_quote'
        ordering = ["-created_at"]

    @cached_property
    def contacts(self):
        """The people on the quote, in order, that this account is allowed to see."""
        from core.models import Contact
        ids = [str(i) for i in (self.contact_ids or [])]
        found = {str(c.id): c for c in Contact.objects.filter(id__in=ids)} if ids else {}
        return [found[i] for i in ids if i in found]

    @property
    def to_lines(self):
        """Names for the To block: saved contacts, then any typed on the form but not saved yet."""
        names = [c.line for c in self.contacts] + list(getattr(self, "extra_names", []))
        return names or ([self.to_name] if self.to_name else [])

    @property
    def salutation_name(self):
        c = self.contacts
        extra = list(getattr(self, "extra_names", []))
        return c[0].name if c else (extra[0].split(",")[0] if extra else self.to_name)

    @property
    def rows(self):
        out = []
        for l in self.lines:
            qty = Decimal(str(l.get("qty") or 0))
            unit = Decimal(str(l.get("unit_price") or 0))
            out.append({**l, "qty": qty, "unit_price": unit, "amount": qty * unit})
        return out

    @property
    def total(self):
        return sum((r["amount"] for r in self.rows), Decimal("0"))
