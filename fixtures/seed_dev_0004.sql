-- Synthetic contacts at the sample companies and order types on the open sample folders.
-- Invented data. Run after seed_dev_0002.sql and migration 0004.
\set ON_ERROR_STOP on
SET ROLE app_user;
SET app.tenant_id = '11111111-1111-1111-1111-111111111111';
SET app.user_id   = '22222222-2222-2222-2222-222222222204';   -- Ashley (manager) keeps the contacts

INSERT INTO app.party_contacts (tenant_id, party_id, name, title, email, phone, division) VALUES
 ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333301', 'Dana Whitfield', 'Purchasing Manager', 'dana.whitfield@northstar.example', '860-555-0142', 'Stratford Materials'),
 ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333301', 'Priya Raman',    'Facilities Engineer', 'priya.raman@northstar.example',   '860-555-0177', 'Stratford Operations'),
 ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333302', 'Tom Beckett',    'Owner',               'tom@harborboatworks.example',     '860-555-0120', NULL);

-- The order type on the open folders (folder 1 is closed and predates the field: left empty).
UPDATE app.purchase_orders SET order_type = 'service'     WHERE id = '44444444-4444-4444-4444-444444444402';
UPDATE app.purchase_orders SET order_type = 'otr_machine' WHERE id = '44444444-4444-4444-4444-444444444403';
UPDATE app.purchase_orders SET order_type = 'parts'       WHERE id = '44444444-4444-4444-4444-444444444404';
UPDATE app.purchase_orders SET order_type = 'custom'      WHERE id = '44444444-4444-4444-4444-444444444405';
RESET ROLE;
SELECT p.name, count(c.id) AS contacts FROM app.parties p LEFT JOIN app.party_contacts c ON c.party_id = p.id WHERE p.is_client GROUP BY p.name ORDER BY p.name;
