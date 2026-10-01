-- Synthetic steps, documents and two more people. Invented data. Run after seed_dev.sql.
\set ON_ERROR_STOP on
SET ROLE app_user;
SET app.tenant_id = '11111111-1111-1111-1111-111111111111';
SET app.user_id   = '22222222-2222-2222-2222-222222222202';   -- Ross (admin) adds people
SELECT app.add_member('ashley@rms.example', 'Ashley Culliton', 'manager', '22222222-2222-2222-2222-222222222204', 'local|ashley');
SELECT app.add_member('zach@rms.example',   'Zach Morales',    'clerk',   '22222222-2222-2222-2222-222222222205', 'local|zach');
UPDATE app.users SET is_us_person = true, us_person_basis = 'US citizen (dev fixture)'
 WHERE id IN ('22222222-2222-2222-2222-222222222204', '22222222-2222-2222-2222-222222222205');
SET app.user_id = '22222222-2222-2222-2222-222222222203';   -- Tammie (manager) files the rest

-- Documents (metadata only; no files exist in the dev store)
INSERT INTO app.documents (id, tenant_id, po_id, kind, title, original_filename, storage_key, sha256, mime_type, byte_size, page_count, document_date, source, email_from, email_subject, received_at) VALUES
 ('55555555-5555-5555-5555-555555555501', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'client_po',       'Client PO 4500611234',            'PO_4500611234.pdf',  'dev/01', repeat('1',64), 'application/pdf', 182000, 5, DATE '2025-12-09', 'email', 'purchasing@northstar.example', 'PO 4500611234 Ross Machinery Sales', TIMESTAMPTZ '2025-12-09 11:40-05'),
 ('55555555-5555-5555-5555-555555555502', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'quote',           'Quote SA120001 to Northstar',     'SA120001.pdf',       'dev/02', repeat('2',64), 'application/pdf', 64000,  1, DATE '2025-12-04', 'upload', NULL, NULL, NULL),
 ('55555555-5555-5555-5555-555555555503', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'vendor_invoice',  'Kleve invoice 192368 (EUR)',      'Invoice_192368.pdf', 'dev/03', repeat('3',64), 'application/pdf', 91000,  2, DATE '2026-06-29', 'email', 'billing@kleve-furnace.example', 'Invoice 192368 / Order SA120001', TIMESTAMPTZ '2026-06-29 03:12-05'),
 ('55555555-5555-5555-5555-555555555504', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'remittance',      'Remittance 5108872280',            'remit_5108872280.pdf','dev/04', repeat('4',64), 'application/pdf', 120000, 3, DATE '2025-12-23', 'email', 'payments@northstar.example', 'Payment advice 5108872280', TIMESTAMPTZ '2025-12-23 08:02-05'),
 ('55555555-5555-5555-5555-555555555505', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'correspondence',  'Kleve order confirmation 7065268','OC_7065268.pdf',     'dev/05', repeat('5',64), 'application/pdf', 44000,  1, DATE '2026-02-19', 'email', 'orders@kleve-furnace.example', 'Order confirmation 7065268 ref SA120001', TIMESTAMPTZ '2026-02-19 04:30-05'),
 ('55555555-5555-5555-5555-555555555506', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', 'other',           'Check 6795 payment record',        'check_6795.jpg',     'dev/06', repeat('6',64), 'image/jpeg',      210000, 1, DATE '2026-08-19', 'scan', NULL, NULL, NULL),
 ('55555555-5555-5555-5555-555555555507', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'correspondence',  'Lakeside order confirmation 20388','OC_20388.pdf',      'dev/07', repeat('7',64), 'application/pdf', 52000,  2, DATE '2026-07-20', 'email', 'orders@lakeside-boring.example', 'Order confirmation 20388 ref HB-77812', TIMESTAMPTZ '2026-07-20 09:15-05'),
 ('55555555-5555-5555-5555-555555555508', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', 'packing_slip',    'Bluewater BOL 44120',              'BOL_44120.pdf',      'dev/08', repeat('8',64), 'application/pdf', 38000,  1, DATE '2026-09-16', 'email', 'dispatch@bluewater-freight.example', 'BOL 44120 PO HB-77812 shipped', TIMESTAMPTZ '2026-09-16 15:40-05'),
 ('55555555-5555-5555-5555-555555555509', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444405', 'correspondence',  'Kleve order confirmation 7071133','OC_7071133.pdf',     'dev/09', repeat('9',64), 'application/pdf', 47000,  1, DATE '2026-09-24', 'email', 'orders@kleve-furnace.example', 'Order confirmation 7071133 ref 4500701890', TIMESTAMPTZ '2026-09-24 05:05-05');

-- Steps. Helper: one row per step per line. Owners: Ashley (sales side), Zach (order placed), Tammie (money is on the folder, not here).
CREATE TEMP TABLE seed_lines AS
SELECT li.id AS line_id, li.po_id, li.line_no, li.category FROM app.po_line_items li;

INSERT INTO app.line_steps (tenant_id, po_id, line_item_id, step_key, applicable, owner_user_id)
SELECT '11111111-1111-1111-1111-111111111111', po_id, line_id, s.step_key,
       CASE WHEN s.step_key = 'in_production' AND category IN ('accessories','software','service','freight') THEN false
            WHEN s.step_key = 'installed' AND category IN ('accessories','freight','tooling') THEN false
            WHEN category = 'freight' AND s.step_key NOT IN ('carrier_determined','shipped','delivered') THEN false
            ELSE true END,
       CASE WHEN s.step_key = 'order_placed' THEN '22222222-2222-2222-2222-222222222205'::uuid ELSE '22222222-2222-2222-2222-222222222204'::uuid END
FROM seed_lines, unnest(enum_range(NULL::app.fulfillment_step)) AS s(step_key);

-- Folder 1 (furnace software, PO ...4401): everything done.
UPDATE app.line_steps ls SET done_at = d.ts, proof_document_id = d.doc, proof_note = d.note
FROM (VALUES
  ('quote_sent',         TIMESTAMPTZ '2025-12-04 10:00-05', '55555555-5555-5555-5555-555555555502'::uuid, NULL),
  ('quote_approved',     TIMESTAMPTZ '2025-12-09 11:40-05', '55555555-5555-5555-5555-555555555501'::uuid, NULL),
  ('order_placed',       TIMESTAMPTZ '2025-12-29 09:00-05', NULL, 'Ross PO SA120001 sent to Kleve'),
  ('carrier_determined', TIMESTAMPTZ '2026-02-19 09:00-05', '55555555-5555-5555-5555-555555555505'::uuid, 'Vendor ships; service engineer travels'),
  ('processing',         TIMESTAMPTZ '2026-06-01 09:00-05', NULL, 'Software delivered electronically'),
  ('shipped',            TIMESTAMPTZ '2026-06-08 09:00-05', NULL, 'Engineer on site 6/8'),
  ('delivered',          TIMESTAMPTZ '2026-06-08 09:00-05', NULL, 'Engineer on site 6/8'),
  ('installed',          TIMESTAMPTZ '2026-06-30 09:00-05', '55555555-5555-5555-5555-555555555503'::uuid, 'Commissioning complete; invoice references it')
) AS d(step_key, ts, doc, note)
WHERE ls.po_id = '44444444-4444-4444-4444-444444444401' AND ls.step_key = d.step_key::app.fulfillment_step;

-- Folder 2 (spindle rebuild, ...4402): delivered, install due.
UPDATE app.line_steps ls SET done_at = d.ts, proof_note = d.note
FROM (VALUES
  ('quote_sent', TIMESTAMPTZ '2026-08-10 09:00-04', 'Quote SA120044 emailed'),
  ('quote_approved', TIMESTAMPTZ '2026-08-18 09:00-04', 'Client PO 4500687001 received'),
  ('order_placed', TIMESTAMPTZ '2026-08-19 09:00-04', 'Ross PO SA120044 to Lakeside'),
  ('carrier_determined', TIMESTAMPTZ '2026-09-01 09:00-04', 'Lakeside field service, no freight'),
  ('processing', TIMESTAMPTZ '2026-09-02 09:00-04', 'Scheduled'),
  ('shipped', TIMESTAMPTZ '2026-09-08 09:00-04', 'Technician dispatched'),
  ('delivered', TIMESTAMPTZ '2026-09-08 09:00-04', 'On site')
) AS d(step_key, ts, note)
WHERE ls.po_id = '44444444-4444-4444-4444-444444444402' AND ls.step_key = d.step_key::app.fulfillment_step;
UPDATE app.line_steps SET due_date = DATE '2026-10-06' WHERE po_id = '44444444-4444-4444-4444-444444444402' AND step_key = 'installed';

-- Folder 3 (VTC + tooling, ...4403): machine shipped; tooling delivered short (red); freight line.
UPDATE app.line_steps ls SET done_at = d.ts, proof_document_id = d.doc, proof_note = d.note
FROM (VALUES
  ('quote_sent', TIMESTAMPTZ '2026-06-20 09:00-04', NULL, 'Quote SA120051'),
  ('quote_approved', TIMESTAMPTZ '2026-07-10 09:00-04', NULL, 'Client PO HB-77812'),
  ('order_placed', TIMESTAMPTZ '2026-07-20 09:15-04', '55555555-5555-5555-5555-555555555507'::uuid, NULL),
  ('in_production', TIMESTAMPTZ '2026-08-30 09:00-04', NULL, 'Build complete per Lakeside 8/30'),
  ('carrier_determined', TIMESTAMPTZ '2026-09-10 09:00-04', NULL, 'Bluewater, flatbed'),
  ('processing', TIMESTAMPTZ '2026-09-14 09:00-04', NULL, 'Crated'),
  ('shipped', TIMESTAMPTZ '2026-09-16 15:40-04', '55555555-5555-5555-5555-555555555508'::uuid, NULL)
) AS d(step_key, ts, doc, note)
WHERE ls.po_id = '44444444-4444-4444-4444-444444444403' AND ls.step_key = d.step_key::app.fulfillment_step
  AND ls.line_item_id IN (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444403' AND line_no IN (10, 20));
UPDATE app.line_steps SET due_date = DATE '2026-10-03' WHERE po_id = '44444444-4444-4444-4444-444444444403' AND step_key = 'delivered'
  AND line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444403' AND line_no = 10);
UPDATE app.line_steps SET done_at = TIMESTAMPTZ '2026-09-22 10:00-04', proof_note = 'Delivered 9/22', flag = 'red', flag_reason = 'Arrived short: 4 of 12 tool holders missing. Vendor contacted 9/22.'
  WHERE po_id = '44444444-4444-4444-4444-444444444403' AND step_key = 'delivered'
  AND line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444403' AND line_no = 20);
UPDATE app.line_steps ls SET done_at = TIMESTAMPTZ '2026-09-16 15:40-04', proof_document_id = '55555555-5555-5555-5555-555555555508'
  WHERE po_id = '44444444-4444-4444-4444-444444444403' AND step_key IN ('carrier_determined','shipped')
  AND line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444403' AND line_no = 30);

-- Folder 4 (way covers, ...4404): all done.
UPDATE app.line_steps SET done_at = TIMESTAMPTZ '2026-08-20 09:00-04', proof_note = 'Done; see folder documents'
  WHERE po_id = '44444444-4444-4444-4444-444444444404' AND applicable;

-- Folder 5 (hot zone, ...4405): line 10 in production; line 20 (install service) order not yet placed and overdue -> Zach.
UPDATE app.line_steps ls SET done_at = d.ts, proof_document_id = d.doc, proof_note = d.note
FROM (VALUES
  ('quote_sent', TIMESTAMPTZ '2026-09-02 09:00-04', NULL, 'Quote SA120071'),
  ('quote_approved', TIMESTAMPTZ '2026-09-18 09:00-04', NULL, 'Client PO 4500701890'),
  ('order_placed', TIMESTAMPTZ '2026-09-24 05:05-04', '55555555-5555-5555-5555-555555555509'::uuid, NULL)
) AS d(step_key, ts, doc, note)
WHERE ls.po_id = '44444444-4444-4444-4444-444444444405' AND ls.step_key = d.step_key::app.fulfillment_step
  AND ls.line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444405' AND line_no = 10);
UPDATE app.line_steps SET due_date = DATE '2026-11-20' WHERE po_id = '44444444-4444-4444-4444-444444444405' AND step_key = 'in_production'
  AND line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444405' AND line_no = 10);
UPDATE app.line_steps ls SET done_at = d.ts, proof_note = d.note
FROM (VALUES ('quote_sent', TIMESTAMPTZ '2026-09-02 09:00-04', 'Quote SA120071'), ('quote_approved', TIMESTAMPTZ '2026-09-18 09:00-04', 'Client PO 4500701890')) AS d(step_key, ts, note)
WHERE ls.po_id = '44444444-4444-4444-4444-444444444405' AND ls.step_key = d.step_key::app.fulfillment_step
  AND ls.line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444405' AND line_no = 20);
UPDATE app.line_steps SET due_date = DATE '2026-09-25' WHERE po_id = '44444444-4444-4444-4444-444444444405' AND step_key = 'order_placed'
  AND line_item_id = (SELECT line_id FROM seed_lines WHERE po_id = '44444444-4444-4444-4444-444444444405' AND line_no = 20);

-- Tracking on shipped lines (the delivered step's due_date is the carrier's expected delivery date)
UPDATE app.po_line_items SET tracking_number = 'BFL-PRO-44120', tracking_carrier_party_id = '33333333-3333-3333-3333-333333333305', shipped_at = TIMESTAMPTZ '2026-09-16 15:40-04'
  WHERE po_id = '44444444-4444-4444-4444-444444444403' AND line_no IN (10, 30);

-- Folder 1's sticky becomes a yellow flag on 'installed' as well (training question) and stays as a note.
RESET ROLE;
SELECT po_id, count(*) FILTER (WHERE done_at IS NOT NULL) AS done, count(*) FILTER (WHERE flag IS NOT NULL) AS flagged, count(*) AS steps FROM app.line_steps GROUP BY po_id ORDER BY po_id;
