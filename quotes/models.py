"""
Quotes: the office's quote form, replacing the Word template. Lives in the django schema for now
(a quick win); moves to schema app with migration 0003 when quotes become the start of a folder.
"""
from decimal import Decimal
from django.conf import settings
from django.db import models


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

    class Meta:
        db_table = 'django"."quotes_quote'
        ordering = ["-created_at"]

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
