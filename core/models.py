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
    tracking_number = models.TextField(null=True)
    tracking_carrier_party_id = models.UUIDField(null=True)
    shipped_at = models.DateTimeField(null=True)
    delivered_at = models.DateTimeField(null=True)

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


class Document(models.Model):
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField(null=True)
    kind = models.TextField()
    control_marking = models.TextField()
    title = models.TextField(null=True)
    original_filename = models.TextField(null=True)
    storage_key = models.TextField()
    mime_type = models.TextField()
    byte_size = models.BigIntegerField()
    page_count = models.IntegerField(null=True)
    document_date = models.DateField(null=True)
    source = models.TextField()
    email_from = models.TextField(null=True)
    email_subject = models.TextField(null=True)
    received_at = models.DateTimeField(null=True)
    uploaded_by = models.UUIDField(null=True)
    uploaded_at = models.DateTimeField()
    deleted_at = models.DateTimeField(null=True)

    class Meta:
        managed = False
        db_table = 'app"."documents'


class LineStep(models.Model):
    """One fulfillment step on one line item (migration 0002)."""
    id = models.UUIDField(primary_key=True)
    tenant_id = models.UUIDField()
    po_id = models.UUIDField()
    line_item_id = models.UUIDField()
    step_key = models.TextField()
    applicable = models.BooleanField()
    owner_user_id = models.UUIDField(null=True)
    due_date = models.DateField(null=True)
    done_at = models.DateTimeField(null=True)
    flag = models.TextField(null=True)
    flag_reason = models.TextField(null=True)
    proof_document_id = models.UUIDField(null=True)
    proof_note = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = 'app"."line_steps'


class Member(models.Model):
    """Who is who, for owner names on steps. Read through app.users joined by the view below."""
    id = models.UUIDField(primary_key=True)
    full_name = models.TextField()
    email = models.TextField()

    class Meta:
        managed = False
        db_table = 'app"."users'
