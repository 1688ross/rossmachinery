-- =============================================================================
-- 0004: the people at each company (party_contacts) and the order type on a folder.
-- Expand-only. Follows schema/README section 13.
-- =============================================================================
BEGIN;
SET LOCAL ROLE app_owner;

-- What kind of order this is, one per folder, for reporting (Ross, 2026-10-20). Set at quote
-- time and carried onto the folder; NULL on folders opened before this existed.
CREATE TYPE app.order_type AS ENUM
  ('custom', 'otr_machine', 'parts', 'materials', 'accessories', 'software', 'service', 'repair', 'misc');
ALTER TABLE app.purchase_orders ADD COLUMN order_type app.order_type;

-- The people we deal with at a company: picked on quotes so names are never retyped and the
-- email and phone come with the person. A division is free text for now ("Stratford Materials");
-- whether a division needs to be its own company is an open question for the office.
CREATE TABLE app.party_contacts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES app.tenants (id),
  party_id    uuid NOT NULL,
  name        text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 160),
  title       text CHECK (title IS NULL OR length(title) <= 120),
  email       text CHECK (email IS NULL OR email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  phone       text CHECK (phone IS NULL OR length(phone) <= 40),
  division    text CHECK (division IS NULL OR length(division) <= 120),
  notes       text,
  is_active   boolean NOT NULL DEFAULT true,
  created_by  uuid REFERENCES app.users (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT party_contacts_tenant_id_id_key UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, party_id) REFERENCES app.parties (tenant_id, id)
);
CREATE UNIQUE INDEX party_contacts_party_name_uniq ON app.party_contacts (tenant_id, party_id, lower(name));
CREATE INDEX party_contacts_party_idx ON app.party_contacts (tenant_id, party_id) WHERE is_active;

ALTER TABLE app.party_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.party_contacts FORCE  ROW LEVEL SECURITY;

CREATE POLICY p_select ON app.party_contacts FOR SELECT
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.is_member()));
CREATE POLICY p_insert ON app.party_contacts FOR INSERT
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()));
CREATE POLICY p_update ON app.party_contacts FOR UPDATE
  USING      (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_write()));
CREATE POLICY p_delete ON app.party_contacts FOR DELETE
  USING (tenant_id = (SELECT app.current_tenant_id()) AND (SELECT app.can_manage_lifecycle()));

CREATE OR REPLACE FUNCTION app.tg_party_contacts_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.name  := btrim(NEW.name);
  NEW.email := NULLIF(lower(btrim(NEW.email)), '');
  NEW.created_by := CASE WHEN app.is_privileged_context()
                         THEN COALESCE(NEW.created_by, app.current_user_id())
                         ELSE app.current_user_id() END;
  NEW.created_at := now();
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION app.tg_party_contacts_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.name  := btrim(NEW.name);
  NEW.email := NULLIF(lower(btrim(NEW.email)), '');
  NEW.created_by := OLD.created_by;
  RETURN NEW;
END $$;

CREATE TRIGGER t10_common        BEFORE UPDATE ON app.party_contacts FOR EACH ROW EXECUTE FUNCTION app.tg_tenant_scoped_before_update();
CREATE TRIGGER t20_before_insert BEFORE INSERT ON app.party_contacts FOR EACH ROW EXECUTE FUNCTION app.tg_party_contacts_before_insert();
CREATE TRIGGER t20_before_update BEFORE UPDATE ON app.party_contacts FOR EACH ROW EXECUTE FUNCTION app.tg_party_contacts_before_update();
GRANT SELECT, INSERT, UPDATE ON app.party_contacts TO app_user;
GRANT SELECT ON app.party_contacts TO app_security;

-- tg_audit is owned by app_security; a superuser attaches it (as in 0001 to 0003).
RESET ROLE;
CREATE TRIGGER t90_audit AFTER INSERT OR UPDATE OR DELETE ON app.party_contacts FOR EACH ROW EXECUTE FUNCTION app.tg_audit();

COMMIT;
