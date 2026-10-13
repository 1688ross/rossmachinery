"""
Writes to schema app. Raw SQL with explicit casts: the tables use enum and uuid columns, and
psycopg sends Python strings as text, which Postgres will not silently cast. Every statement
runs inside the request's transaction, so the middleware's SET LOCAL context (tenant, user)
applies and RLS plus the triggers decide what is allowed.
"""
import uuid
from django.db import connection


def _one(sql, params):
    with connection.cursor() as cur:
        cur.execute(sql, params)
        row = cur.fetchone()
    return row[0] if row else None


def insert_document(tenant_id, po_id, kind, marking, title, filename, key, sha, mime, size, pages, doc_date, thumb_key):
    return _one(
        """INSERT INTO app.documents (id, tenant_id, po_id, kind, control_marking, title, original_filename, storage_key,
                                      sha256, mime_type, byte_size, page_count, document_date, source, thumbnail_key)
           VALUES (%s::uuid, %s::uuid, %s::uuid, %s::app.document_kind, %s::app.control_marking, %s, %s, %s,
                   %s, %s, %s, %s, %s::date, 'upload', %s)
           RETURNING id""",
        [str(uuid.uuid4()), tenant_id, po_id, kind, marking, title, filename, key, sha, mime, size, pages, doc_date, thumb_key])


def set_document_thumbnail(doc_id, thumb_key, pages):
    return _one("UPDATE app.documents SET thumbnail_key = %s, page_count = COALESCE(page_count, %s) WHERE id = %s::uuid RETURNING id",
                [thumb_key, pages, str(doc_id)])


def set_step_proof(step_id, doc_id=None, note=None, mark_done=True):
    """Attach a document and/or a note as proof; mark the step done unless told not to."""
    return _one(
        """UPDATE app.line_steps
              SET proof_document_id = COALESCE(%s::uuid, proof_document_id),
                  proof_note        = COALESCE(NULLIF(btrim(%s), ''), proof_note),
                  done_at           = CASE WHEN %s AND done_at IS NULL THEN now() ELSE done_at END
            WHERE id = %s::uuid RETURNING id""",
        [str(doc_id) if doc_id else None, note or "", bool(mark_done), str(step_id)])


def set_step_flag(step_id, flag, reason):
    return _one("UPDATE app.line_steps SET flag = %s::app.step_flag, flag_reason = %s WHERE id = %s::uuid RETURNING id",
                [flag, reason, str(step_id)])


def clear_step_flag(step_id):
    return _one("UPDATE app.line_steps SET flag = NULL, flag_reason = NULL WHERE id = %s::uuid RETURNING id", [str(step_id)])


def insert_ack(tenant_id, po_id, subject, action, reason, ledger_entry_id=None, document_id=None, expires_on=None):
    return _one(
        """INSERT INTO app.po_acks (id, tenant_id, po_id, subject, action, reason, ledger_entry_id, document_id, expires_on)
           VALUES (%s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s::uuid, %s::uuid, %s::date) RETURNING id""",
        [str(uuid.uuid4()), tenant_id, po_id, subject, action, reason,
         str(ledger_entry_id) if ledger_entry_id else None, str(document_id) if document_id else None, expires_on])


def client_party_id(po_id):
    return _one("SELECT client_party_id FROM app.purchase_orders WHERE id = %s::uuid", [str(po_id)])


def insert_credit_memo(tenant_id, po_id, amount, memo, reference, document_id=None):
    """A client credit: always posts as a negative on the client side (the sign is derived by the
    DB), against the folder's customer."""
    return _one(
        """INSERT INTO app.ledger_entries (id, tenant_id, po_id, kind, side, amount, memo, reference, document_id, counterparty_party_id)
           VALUES (%s::uuid, %s::uuid, %s::uuid, 'credit_memo', 'client', %s, %s, %s, %s::uuid, %s::uuid) RETURNING id""",
        [str(uuid.uuid4()), tenant_id, po_id, amount, memo, reference, str(document_id) if document_id else None,
         (lambda cp: str(cp) if cp else None)(client_party_id(po_id))])


def insert_note(tenant_id, po_id, body, kind="comment"):
    return _one("INSERT INTO app.po_notes (id, tenant_id, po_id, kind, body) VALUES (%s::uuid, %s::uuid, %s::uuid, %s::app.note_kind, %s) RETURNING id",
                [str(uuid.uuid4()), tenant_id, po_id, kind, body])


def resolve_note(note_id):
    return _one("UPDATE app.po_notes SET resolved_at = now(), resolved_by = app.current_user_id() WHERE id = %s::uuid AND resolved_at IS NULL RETURNING id",
                [str(note_id)])
