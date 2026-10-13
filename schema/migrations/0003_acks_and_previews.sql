-- =============================================================================
-- 0003: acknowledgements (okay / fix / client credit against a problem) and the
-- first-page preview key on documents. Expand-only. Follows schema/README section 13.
-- =============================================================================
BEGIN;
SET LOCAL ROLE app_owner;

-- The first page of the file rendered as PNG, stored beside it (core/storage.py).
ALTER TABLE app.documents
  ADD COLUMN thumbnail_key text CHECK (thumbnail_key IS NULL OR length(thumbnail_key) BETWEEN 1 AND 1024);

-- One row each time a person deals with a yellow or red: "okay, here is why", "fixed, here is
-- what was done", or "set aside as a client credit" (which also posts the credit memo). The
-- subject names what was dealt with: a money reason key, a fulfillment step, or a note.
-- Append-only: a second thought is a second row.
CREATE TABLE app.po_acks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES app.tenants (id),
  po_id           uuid NOT NULL,
  subject         text NOT NULL CHECK (subject ~ '^(money:[a-z0-9_]+|step:[0-9a-f-]{36}|note:[0-9a-f-]{36})$'),
  action          text NOT NULL CHECK (action IN ('okay', 'fix', 'credit')),
  reason          text NOT NULL CHECK (length(btrim(reason)) BETWEEN 3 AND 2000),
  ledger_entry_id uuid,
  document_id     uuid,
  expires_on      date,                       -- a money okay resurfaces after this date
  created_by      uuid REFERENCES app.users (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, po_id)           REFERENCES app.purchase_orders (tenant_id, id),
  FOREIGN KEY (tenant_id, ledger_entry_id) REFERENCES app.ledger_entries  (tenant_id, id),
  FOREIGN KEY (tenant_id, document_id)     REFERENCES app.documents       (tenant_id, id),
  CONSTRAINT po_acks_credit_has_entry CHECK (action <> 'credit' OR ledger_entry_id IS NOT NULL)
);
CREATE INDEX po_acks_po_idx ON app.po_acks (tenant_id, po_id, subject);

ALTER TABLE app.po_acks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.po_acks FORCE  ROW LEVEL SECURITY;

CREATE POLICY p_select ON app.po_acks FOR SELECT USING (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_acks.tenant_id AND p.id = po_acks.po_id)));
CREATE POLICY p_insert ON app.po_acks FOR INSERT WITH CHECK (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = po_acks.tenant_id AND p.id = po_acks.po_id)));
-- no UPDATE or DELETE policy: nobody rewrites an acknowledgement

CREATE OR REPLACE FUNCTION app.tg_po_acks_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT (app.is_privileged_context() OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not acknowledge problems', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM app.assert_folder_open(NEW.tenant_id, NEW.po_id, 'acknowledging a problem');
  IF NEW.ledger_entry_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM app.ledger_entries e WHERE e.tenant_id = NEW.tenant_id AND e.id = NEW.ledger_entry_id AND e.po_id = NEW.po_id) THEN
    RAISE EXCEPTION 'ledger entry % is not on this purchase order (or not visible)', NEW.ledger_entry_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF NEW.document_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM app.documents d WHERE d.tenant_id = NEW.tenant_id AND d.id = NEW.document_id AND d.po_id = NEW.po_id AND d.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'document % is not filed on this purchase order (or not visible)', NEW.document_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  NEW.created_by := app.current_user_id();
  NEW.created_at := now();
  RETURN NEW;
END $$;

CREATE TRIGGER t00_append_only BEFORE UPDATE OR DELETE ON app.po_acks FOR EACH ROW EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t00_no_truncate BEFORE TRUNCATE ON app.po_acks FOR EACH STATEMENT EXECUTE FUNCTION app.tg_append_only();
CREATE TRIGGER t20_guard       BEFORE INSERT ON app.po_acks FOR EACH ROW EXECUTE FUNCTION app.tg_po_acks_guard();
GRANT SELECT, INSERT ON app.po_acks TO app_user;
GRANT SELECT ON app.po_acks TO app_security;

-- tg_audit is owned by app_security; a superuser attaches it (as in 0001 and 0002).
RESET ROLE;
CREATE TRIGGER t90_audit AFTER INSERT ON app.po_acks FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

COMMIT;
