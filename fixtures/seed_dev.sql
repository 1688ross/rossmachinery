-- =============================================================================
-- Synthetic development data for Ross Machinery Sales platform.
-- Every company, person, number and amount here is invented. Shapes copy a real
-- folder: a client PO with numbered lines, a quote, a vendor bill in euros,
-- partial client invoices, a remittance that covers several folders, a hold.
-- Run as a superuser against a database that has migration 0001 applied.
-- =============================================================================
\set ON_ERROR_STOP on

-- Operator step: the tenant and its owner.
SELECT app.bootstrap_tenant('Ross Machinery Sales', 'rms', 'chuck@rms.example', 'Chuck Culliton',
                            p_tenant_id => '11111111-1111-1111-1111-111111111111',
                            p_owner_user_id => '22222222-2222-2222-2222-222222222201',
                            p_deployment_mode => 'onprem');
-- Everything below runs as the application role with the owner's context.
SET ROLE app_user;
SET app.tenant_id = '11111111-1111-1111-1111-111111111111';
SET app.user_id   = '22222222-2222-2222-2222-222222222201';
UPDATE app.users SET auth_subject = 'local|chuck' WHERE id = '22222222-2222-2222-2222-222222222201';

SELECT app.add_member('ross@rms.example',   'Ross Culliton', 'admin',   '22222222-2222-2222-2222-222222222202', 'local|ross');
SELECT app.add_member('tammie@rms.example', 'Tammie Smith',  'manager', '22222222-2222-2222-2222-222222222203', 'local|tammie');
-- The owner attests the others; a second admin will attest the owner (two humans rule).
UPDATE app.users SET is_us_person = true, us_person_basis = 'US citizen (dev fixture)'
 WHERE id IN ('22222222-2222-2222-2222-222222222202', '22222222-2222-2222-2222-222222222203');
SET app.user_id = '22222222-2222-2222-2222-222222222202';
UPDATE app.users SET is_us_person = true, us_person_basis = 'US citizen (dev fixture)'
 WHERE id = '22222222-2222-2222-2222-222222222201';
SET app.user_id = '22222222-2222-2222-2222-222222222203';

-- Parties (invented names)
INSERT INTO app.parties (id, tenant_id, name, short_code, is_client, is_vendor, is_carrier, city, region, country, payment_terms) VALUES
 ('33333333-3333-3333-3333-333333333301', '11111111-1111-1111-1111-111111111111', 'Northstar Rotorcraft',        'NSR',  true,  false, false, 'Stratford',   'CT', 'US', 'Net 90'),
 ('33333333-3333-3333-3333-333333333302', '11111111-1111-1111-1111-111111111111', 'Harbor Boatworks',            'HBW',  true,  false, false, 'Groton',      'CT', 'US', 'Net 45'),
 ('33333333-3333-3333-3333-333333333303', '11111111-1111-1111-1111-111111111111', 'Kleve Furnace GmbH',          'KFG',  false, true,  false, 'Kleve',       NULL, 'DE', '100% on order'),
 ('33333333-3333-3333-3333-333333333304', '11111111-1111-1111-1111-111111111111', 'Lakeside Boring Mills',       'LBM',  false, true,  false, 'Fond du Lac', 'WI', 'US', 'Net 30'),
 ('33333333-3333-3333-3333-333333333305', '11111111-1111-1111-1111-111111111111', 'Bluewater Freight Lines',     'BFL',  false, true,  true,  'Hartford',    'CT', 'US', 'Net 30');

-- Folder 1: modeled on the real one. Software + service on a furnace. Fully paid both sides,
-- still open because of a training question (sticky). Should show YELLOW (hold) not red.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title, description) VALUES
 ('44444444-4444-4444-4444-444444444401', '11111111-1111-1111-1111-111111111111', '4500611234', '33333333-3333-3333-3333-333333333301', '33333333-3333-3333-3333-333333333303',
  'Furnace control software revisions', 'Software control revisions and commissioning on one rotary furnace. Quote SA120001.');
INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 10, 'software', 'Furnace PLC and control system adjustments, commissioning and function test', 1, 73866.00);
-- client side: three partial invoices, all collected
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date, memo) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_invoice', 'client', 22159.80, '33333333-3333-3333-3333-333333333301', 'SA120001',  DATE '2025-12-22', 'Line 00010, first half'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_invoice', 'client', 22159.80, '33333333-3333-3333-3333-333333333301', 'SA120001A', DATE '2025-12-29', 'Line 00010, second half'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_payment', 'client', 44319.60, '33333333-3333-3333-3333-333333333301', 'EFT remit 5108872280', DATE '2025-12-23', 'Collected, EFT'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_invoice', 'client', 29546.40, '33333333-3333-3333-3333-333333333301', 'SA120001B', DATE '2026-06-27', 'Balance of line 00010'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_payment', 'client', 29546.40, '33333333-3333-3333-3333-333333333301', 'EFT remit 5109011122', DATE '2026-07-24', 'Collected, EFT'),
-- vendor side: one bill in euros, paid by check at the rate of the day
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'vendor_bill',    'vendor', 46961.00, '33333333-3333-3333-3333-333333333303', 'Inv 192368', DATE '2026-06-29', 'EUR 41,500.00 at 1.1316'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'vendor_payment', 'vendor', 46961.00, '33333333-3333-3333-3333-333333333303', 'Check 6795', DATE '2026-08-19', 'Paid, TD Bank');
INSERT INTO app.po_notes (tenant_id, po_id, kind, body) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'sticky', 'Keep open per Chuck. Training still owed?');

-- Folder 2: holding money. Client paid in full; vendor bill received, not yet paid. YELLOW.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title) VALUES
 ('44444444-4444-4444-4444-444444444402', '11111111-1111-1111-1111-111111111111', '4500687001', '33333333-3333-3333-3333-333333333301', '33333333-3333-3333-3333-333333333304',
  'Horizontal boring mill, spindle rebuild');
INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444402', 10, 'service', 'Spindle rebuild and re-commissioning', 1, 84200.00);
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444402', 'client_invoice', 'client', 84200.00, '33333333-3333-3333-3333-333333333301', 'SA120044',  DATE '2026-08-28'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444402', 'client_payment', 'client', 84200.00, '33333333-3333-3333-3333-333333333301', 'EFT remit 5109233301', DATE '2026-09-12'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444402', 'vendor_bill',    'vendor', 79000.00, '33333333-3333-3333-3333-333333333304', 'LBM-20411', DATE '2026-09-02');

-- Folder 3: vendor billed more than quoted, and a part arrived missing. RED.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title) VALUES
 ('44444444-4444-4444-4444-444444444403', '11111111-1111-1111-1111-111111111111', 'HB-77812', '33333333-3333-3333-3333-333333333302', '33333333-3333-3333-3333-333333333304',
  'Vertical turning center with tooling package');
INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 10, 'machinery', 'Vertical turning center', 1, 412000.00),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 20, 'tooling',   'Tool holder package', 1, 18500.00),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 30, 'freight',   'Rigging and freight', 1, 9800.00);
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date, memo) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'client_invoice', 'client', 215150.00, '33333333-3333-3333-3333-333333333302', 'SA120051',  DATE '2026-07-15', '50% deposit'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'client_payment', 'client', 215150.00, '33333333-3333-3333-3333-333333333302', 'Check 118822', DATE '2026-08-01', NULL),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'vendor_bill',    'vendor', 401500.00, '33333333-3333-3333-3333-333333333304', 'LBM-20388', DATE '2026-09-10', 'Quoted 386,000. Billed 401,500.'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'freight_charge', 'freight', 9800.00, '33333333-3333-3333-3333-333333333305', 'BFL 44120', DATE '2026-09-18', NULL);
INSERT INTO app.po_notes (tenant_id, po_id, kind, body) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'sticky', 'Tool holder package arrived short: 4 of 12 holders missing. Vendor contacted 9/22.');

-- Folder 4: clean and ready to close. GREEN.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title) VALUES
 ('44444444-4444-4444-4444-444444444404', '11111111-1111-1111-1111-111111111111', '4500690555', '33333333-3333-3333-3333-333333333301', '33333333-3333-3333-3333-333333333304',
  'Replacement way covers');
INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444404', 10, 'accessories', 'Way cover set', 2, 3150.00);
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444404', 'client_invoice', 'client', 6300.00, '33333333-3333-3333-3333-333333333301', 'SA120060', DATE '2026-08-05'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444404', 'client_payment', 'client', 6300.00, '33333333-3333-3333-3333-333333333301', 'EFT remit 5109233301', DATE '2026-09-12'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444404', 'vendor_bill',    'vendor', 5400.00, '33333333-3333-3333-3333-333333333304', 'LBM-20402', DATE '2026-08-20'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444404', 'vendor_payment', 'vendor', 5400.00, '33333333-3333-3333-3333-333333333304', 'Check 6820', DATE '2026-09-05');

-- Folder 5: in progress, nothing paid yet, nothing wrong. GREY/GREEN so far.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title) VALUES
 ('44444444-4444-4444-4444-444444444405', '11111111-1111-1111-1111-111111111111', '4500701890', '33333333-3333-3333-3333-333333333301', '33333333-3333-3333-3333-333333333303',
  'Vacuum furnace, hot zone replacement');
INSERT INTO app.po_line_items (tenant_id, po_id, line_no, category, description, quantity, unit_price) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444405', 10, 'machinery', 'Hot zone assembly', 1, 148000.00),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444405', 20, 'service',   'Installation and bake-out', 1, 22000.00);
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date, memo) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444405', 'client_invoice', 'client', 51000.00, '33333333-3333-3333-3333-333333333301', 'SA120071', DATE '2026-09-20', '30% deposit');

-- Folder 6: closed last year, for the closed list.
INSERT INTO app.purchase_orders (id, tenant_id, client_order_number, client_party_id, vendor_party_id, title) VALUES
 ('44444444-4444-4444-4444-444444444406', '11111111-1111-1111-1111-111111111111', 'HB-76102', '33333333-3333-3333-3333-333333333302', '33333333-3333-3333-3333-333333333304',
  'Probe kit and calibration');
INSERT INTO app.ledger_entries (tenant_id, po_id, kind, side, amount, counterparty_party_id, reference, entry_date) VALUES
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444406', 'client_invoice', 'client', 12400.00, '33333333-3333-3333-3333-333333333302', 'SA119880', DATE '2025-11-03'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444406', 'client_payment', 'client', 12400.00, '33333333-3333-3333-3333-333333333302', 'Check 117201', DATE '2025-12-01'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444406', 'vendor_bill',    'vendor', 10900.00, '33333333-3333-3333-3333-333333333304', 'LBM-19977', DATE '2025-11-10'),
 ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444406', 'vendor_payment', 'vendor', 10900.00, '33333333-3333-3333-3333-333333333304', 'Check 6611', DATE '2025-12-05');
UPDATE app.purchase_orders SET status = 'pending_close' WHERE id = '44444444-4444-4444-4444-444444444406';
UPDATE app.purchase_orders SET status = 'closed', close_signoff_note = 'Balanced. Closed at year end.' WHERE id = '44444444-4444-4444-4444-444444444406';

RESET ROLE;
SELECT po_number, client_order_number, status, billed_to_client, received_from_client, billed_by_vendors, paid_to_vendors, gross_margin, is_balanced, ready_to_close, open_stickies
  FROM app.po_folder ORDER BY po_number;
