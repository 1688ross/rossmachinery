"""
Unmanaged mirrors of the SQL schema (schema/migrations). Django never creates or alters these.
Reads go through the views app.po_folder and app.po_ledger where possible; RLS applies to all
of them because the connection is the runtime role with SET LOCAL context from the middleware.
"""
from django.db import models


class Party(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    name = models.TextField()
    short_code = models.TextField(null=True)
    is_client = models.BooleanField()
    is_vendor = models.BooleanField()
    is_carrier = models.BooleanField()
    city = models.TextField(null=True)
    region = models.TextField(null=True)
    country = models.TextField(null=True)
    payment_terms = models.TextField(null=True)
    is_active = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'app"."parties'


class Folder(models.Model):
    """One row per PO from the app.po_folder view: tab + top sheet + counts."""
    po_id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_number = models.TextField()
    client_order_number = models.TextField(null=True)
    client_name = models.TextField(null=True)
    vendor_name = models.TextField(null=True)
    title = models.TextField(null=True)
    status = models.TextField()
    control_marking = models.TextField()
    opened_at = models.DateTimeField()
    close_requested_at = models.DateTimeField(null=True)
    closed_at = models.DateTimeField(null=True)
    close_override_reason = models.TextField(null=True)
    reopen_count = models.IntegerField()
    legal_hold = models.BooleanField()
    retain_until = models.DateField(null=True)
    billed_to_client = models.DecimalField(max_digits=16, decimal_places=2)
    received_from_client = models.DecimalField(max_digits=16, decimal_places=2)
    billed_by_vendors = models.DecimalField(max_digits=16, decimal_places=2)
    paid_to_vendors = models.DecimalField(max_digits=16, decimal_places=2)
    freight = models.DecimalField(max_digits=16, decimal_places=2)
    freight_paid = models.DecimalField(max_digits=16, decimal_places=2)
    commission = models.DecimalField(max_digits=16, decimal_places=2)
    commission_received = models.DecimalField(max_digits=16, decimal_places=2)
    gross_margin = models.DecimalField(max_digits=16, decimal_places=2)
    open_client_balance = models.DecimalField(max_digits=16, decimal_places=2)
    open_vendor_balance = models.DecimalField(max_digits=16, decimal_places=2)
    open_freight_balance = models.DecimalField(max_digits=16, decimal_places=2)
    open_commission_balance = models.DecimalField(max_digits=16, decimal_places=2)
    entry_count = models.IntegerField()
    last_entry_date = models.DateField(null=True)
    open_required_items = models.IntegerField()
    checklist_complete = models.BooleanField()
    is_balanced = models.BooleanField()
    ready_to_close = models.BooleanField()
    open_stickies = models.IntegerField()
    document_count = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'app"."po_folder'


class LineItem(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField()
    line_no = models.IntegerField()
    category = models.TextField()
    description = models.TextField()
    quantity = models.DecimalField(max_digits=16, decimal_places=3)
    unit_price = models.DecimalField(max_digits=16, decimal_places=2)
    extended_amount = models.DecimalField(max_digits=16, decimal_places=2)

    class Meta:
        managed = False
        db_table = 'app"."po_line_items'


class LedgerEntry(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField()
    kind = models.TextField()
    side = models.TextField()
    amount = models.DecimalField(max_digits=16, decimal_places=2)
    signed_amount = models.DecimalField(max_digits=16, decimal_places=2)
    flow = models.TextField()
    entry_date = models.DateField()
    counterparty_party_id = models.UUIDField(null=True)
    reference = models.TextField(null=True)
    document_id = models.UUIDField(null=True)
    memo = models.TextField(null=True)
    reverses_entry_id = models.UUIDField(null=True)
    created_by = models.UUIDField(null=True)
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'app"."ledger_entries'


class Note(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField()
    kind = models.TextField()
    body = models.TextField()
    is_pinned = models.BooleanField()
    resolved_at = models.DateTimeField(null=True)
    created_by = models.UUIDField(null=True)
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'app"."po_notes'


class ChecklistItem(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField()
    item_key = models.TextField()
    label = models.TextField()
    is_required = models.BooleanField()
    completed_at = models.DateTimeField(null=True)

    class Meta:
        managed = False
        db_table = 'app"."po_close_checklist_items'
