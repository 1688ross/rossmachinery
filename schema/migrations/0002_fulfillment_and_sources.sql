-- =============================================================================
-- 0002: the fulfillment track (one row per step per line item) and document sources.
-- Expand-only. Follows schema/README section 13 (tenant-scoped table checklist).
-- =============================================================================
BEGIN;
SET LOCAL ROLE app_owner;

CREATE TYPE app.fulfillment_step AS ENUM
  ('quote_sent','quote_approved','order_placed','in_production','carrier_determined',
   'processing','shipped','delivered','installed');
CREATE TYPE app.step_flag AS ENUM ('yellow','red');

-- Where a document came from, and the email envelope when it came by email.
ALTER TABLE app.documents
  ADD COLUMN source        text NOT NULL DEFAULT 'upload' CHECK (source IN ('upload','scan','email','system')),
  ADD COLUMN email_from    text,
  ADD COLUMN email_subject text,
  ADD COLUMN received_at   timestamptz;

CREATE TABLE app.line_steps (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES app.tenants (id),
  po_id             uuid NOT NULL,
  line_item_id      uuid NOT NULL,
  step_key          app.fulfillment_step NOT NULL,
  applicable        boolean NOT NULL DEFAULT true,
  owner_user_id     uuid REFERENCES app.users (id),
  due_date          date,
  done_at           timestamptz,
  done_by           uuid REFERENCES app.users (id),
  flag              app.step_flag,
  flag_reason       text,
  proof_document_id uuid,
  proof_note        text,
  created_by        uuid REFERENCES app.users (id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, line_item_id, step_key),
  FOREIGN KEY (tenant_id, po_id)             REFERENCES app.purchase_orders (tenant_id, id),
  FOREIGN KEY (tenant_id, line_item_id)      REFERENCES app.po_line_items   (tenant_id, id),
  FOREIGN KEY (tenant_id, proof_document_id) REFERENCES app.documents       (tenant_id, id),
  CONSTRAINT line_steps_flag_needs_reason CHECK (flag IS NULL OR btrim(coalesce(flag_reason, '')) <> ''),
  -- proof on every step: a step is done only with a document or a note from a person
  CONSTRAINT line_steps_done_needs_proof CHECK (done_at IS NULL OR proof_document_id IS NOT NULL OR btrim(coalesce(proof_note, '')) <> '')
);
CREATE INDEX line_steps_po_idx    ON app.line_steps (tenant_id, po_id);
CREATE INDEX line_steps_owner_idx ON app.line_steps (tenant_id, owner_user_id) WHERE done_at IS NULL;

ALTER TABLE app.line_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.line_steps FORCE  ROW LEVEL SECURITY;

CREATE POLICY p_select ON app.line_steps FOR SELECT USING (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = line_steps.tenant_id AND p.id = line_steps.po_id)));
CREATE POLICY p_insert ON app.line_steps FOR INSERT WITH CHECK (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = line_steps.tenant_id AND p.id = line_steps.po_id)));
CREATE POLICY p_update ON app.line_steps FOR UPDATE USING (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = line_steps.tenant_id AND p.id = line_steps.po_id)))
  WITH CHECK (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = line_steps.tenant_id AND p.id = line_steps.po_id)));
CREATE POLICY p_delete ON app.line_steps FOR DELETE USING (
  tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write())
  AND ((SELECT app.current_user_is_us_person()) OR EXISTS (SELECT 1 FROM app.purchase_orders p WHERE p.tenant_id = line_steps.tenant_id AND p.id = line_steps.po_id)));

CREATE OR REPLACE FUNCTION app.tg_line_steps_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_priv boolean := app.is_privileged_context();
  v_tenant uuid; v_po uuid; v_line_po uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN v_tenant := OLD.tenant_id; v_po := OLD.po_id;
  ELSE                     v_tenant := NEW.tenant_id; v_po := NEW.po_id; END IF;
  IF NOT (v_priv OR app.can_write()) THEN
    RAISE EXCEPTION 'role "%" may not change fulfillment steps', COALESCE(app.current_member_role()::text, 'none')
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM app.assert_folder_open(v_tenant, v_po, 'changing fulfillment steps');
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  SELECT po_id INTO v_line_po FROM app.po_line_items WHERE tenant_id = NEW.tenant_id AND id = NEW.line_item_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'line item % not found in this tenant (or not visible)', NEW.line_item_id USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF v_line_po <> NEW.po_id THEN
    RAISE EXCEPTION 'line item belongs to a different purchase order' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.po_id <> OLD.po_id OR NEW.line_item_id <> OLD.line_item_id OR NEW.step_key <> OLD.step_key THEN
      RAISE EXCEPTION 'a step cannot move to another line or change its kind' USING ERRCODE = 'check_violation';
    END IF;
    NEW.created_by := OLD.created_by;
    IF NEW.done_at IS NOT NULL AND OLD.done_at IS NULL THEN NEW.done_by := app.current_user_id(); END IF;
    IF NEW.done_at IS NULL THEN NEW.done_by := NULL; END IF;
  ELSE
    NEW.created_by := app.current_user_id();
    NEW.created_at := now();
    NEW.updated_at := now();
    IF NEW.done_at IS NOT NULL THEN NEW.done_by := COALESCE(NEW.done_by, app.current_user_id()); END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER t10_common BEFORE UPDATE ON app.line_steps FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_guard  BEFORE INSERT OR UPDATE OR DELETE ON app.line_steps FOR EACH ROW EXECUTE FUNCTION app.tg_line_steps_guard();
GRANT SELECT, INSERT, UPDATE, DELETE ON app.line_steps TO app_user;
GRANT SELECT ON app.line_steps TO app_security;

-- The audit trigger function is owned by app_security; only a superuser (as in 0001) may
-- attach it. Everything above ran as app_owner so the table and policies are owned correctly.
RESET ROLE;
CREATE TRIGGER t90_audit  AFTER  INSERT OR UPDATE OR DELETE ON app.line_steps FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

COMMIT;
