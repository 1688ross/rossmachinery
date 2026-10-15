import datetime
import re
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.db import DatabaseError, IntegrityError, transaction
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_http_methods

from . import db, storage
from .lights import judge
from .models import Ack, ChecklistItem, Document, Folder, LedgerEntry, LineItem, LineStep, Member, Note, Party
from .steps import STEPS, COLUMNS, LABEL, ORDER as STEP_ORDER, badge, describe, why, worst

DOC_KINDS = [("client_po", "Client purchase order"), ("client_invoice", "Our invoice to the client"),
             ("vendor_invoice", "Vendor invoice"), ("remittance", "Remittance or payment advice"),
             ("packing_slip", "Packing slip or bill of lading"), ("freight_bill", "Freight bill"),
             ("commission_statement", "Commission statement"), ("quote", "Quote"),
             ("correspondence", "Correspondence or order confirmation"), ("other", "Something else")]
MARKINGS = [("none", "None"), ("fci", "FCI"), ("cui", "CUI"), ("itar", "ITAR"), ("ear", "EAR")]
OKAY_PERIODS = [("30", "30 days"), ("60", "60 days"), ("90", "90 days"), ("", "until the folder closes")]

ORDER = {"red": 0, "yellow": 1, "green": 2, "grey": 3}


def _notes_by_po(po_ids):
    out = defaultdict(list)
    for n in Note.objects.filter(po_id__in=po_ids).order_by("created_at"):
        out[n.po_id].append(n)
    return out


def _steps_by_po(po_ids):
    out = defaultdict(list)
    for s in LineStep.objects.filter(po_id__in=po_ids):
        out[s.po_id].append(s)
    return out


def _members():
    return {m.id: m for m in Member.objects.all()}


def _acks_by_po(po_ids):
    out = defaultdict(list)
    for a in Ack.objects.filter(po_id__in=po_ids).order_by("created_at"):
        out[a.po_id].append(a)
    return out


def _ctx_or_403(request):
    return None if request.app_ctx else render(request, "core/no_context.html", status=403)


def fulfillment_bar(steps, members, lines_by_id=None, docs=None, parties=None, today=None):
    """Collapse all lines' steps into one square per step: the worst state across lines.
    Each square carries a hover card: the step name, a check in the corner when every line is
    done, then per line what a person wants to see (date, carrier, tracking, proof, note, owner).
    Returns (bar, waiting): the squares in step order, and the first step the folder is waiting on."""
    lines_by_id, docs, parties = lines_by_id or {}, docs or {}, parties or {}
    by_key = defaultdict(list)
    for s in steps:
        by_key[s.step_key].append(s)
    multi = len({s.line_item_id for s in steps}) > 1
    bar, waiting = [], None
    for key, label in STEPS:
        rows = [r for r in by_key.get(key, []) if r.applicable]
        if not rows:
            bar.append({"key": key, "state": "na", "label": label, "badge": None, "more": 0,
                        "blocks": [{"rows": [{"value": "Not applicable"}]}], "title": f"{label}: Not applicable"})
            continue
        items = []
        for r in rows:
            li = lines_by_id.get(r.line_item_id)
            state, headline, facts = describe(r, today, li, carrier=parties.get(getattr(li, "tracking_carrier_party_id", None)),
                                              doc=docs.get(r.proof_document_id), owner=members.get(r.owner_user_id))
            items.append({"state": state, "headline": headline, "rows": facts, "step": r, "line": li,
                          "flagged": r.flag in ("red", "yellow")})
        # Worst first, then line order.
        items.sort(key=lambda q: (DETAIL_ORDER[q["state"]], q["line"].line_no if q["line"] is not None else 0))
        state = worst([q["state"] for q in items])
        blocks, more = _blocks(items) if multi else ([{"head": None, "rows": items[0]["rows"]}], 0)
        flags = [q["step"].flag for q in items if q["flagged"]]
        corner = "done" if all(q["step"].done_at and not q["flagged"] for q in items) else ("flag" if flags else None)
        summary = "; ".join((f"{q['line'].line_no:05d} " if multi and q["line"] is not None else "") + q["headline"] for q in items[:3])
        bar.append({"key": key, "state": state, "label": label, "badge": corner, "badge_tone": "red" if "red" in flags else "yellow",
                    "blocks": blocks, "more": more, "title": f"{label}: {summary}" + (" …" if len(items) > 3 else "")})
        if waiting is None and state in ("grey", "yellow", "red"):
            owners = {q["step"].owner_user_id for q in items if q["step"].done_at is None}
            names = [members[o].full_name.split()[0] for o in owners if o in members]
            late = [{"why": why(label, q["headline"], q["flagged"])} for q in items if q["state"] in ("yellow", "red")]
            waiting = {"label": label, "state": state, "owners": names, "late": late}
    return bar, waiting


def _same(a, b):
    return a.get("label") == b.get("label") and a.get("value") == b.get("value") and (
        getattr(a.get("doc"), "id", None) == getattr(b.get("doc"), "id", None))


def _blocks(items, limit=3):
    """Per-line blocks for a card, without saying the same thing twice: lines whose facts are
    identical share one block ("00010, 00030"); facts every block shares move to the top, as
    long as no block is left empty. Returns (blocks, how many lines were left out)."""
    groups = []
    for q in items:
        for g in groups:
            if len(g["rows"]) == len(q["rows"]) and all(_same(a, b) for a, b in zip(g["rows"], q["rows"])):
                g["lines"].append(q["line"])
                break
        else:
            groups.append({"rows": list(q["rows"]), "lines": [q["line"]]})
    if len(groups) == 1:
        return [{"head": None, "rows": groups[0]["rows"]}], 0
    shared = [r for r in groups[0]["rows"] if all(any(_same(r, x) for x in g["rows"]) for g in groups[1:])]
    if shared and all(len(g["rows"]) > len([r for r in g["rows"] if any(_same(r, x) for x in shared)]) for g in groups):
        for g in groups:
            g["rows"] = [r for r in g["rows"] if not any(_same(r, x) for x in shared)]
        blocks = [{"head": None, "rows": shared}]
    else:
        blocks = []
    for g in groups[:limit]:
        nums = ", ".join(f"{li.line_no:05d}" for li in g["lines"] if li is not None)
        head = f"{nums} · {g['lines'][0].description}" if len(g["lines"]) == 1 and g["lines"][0] is not None else nums
        blocks.append({"head": head, "rows": g["rows"]})
    return blocks, sum(len(g["lines"]) for g in groups[limit:])


DETAIL_ORDER = {"red": 0, "yellow": 1, "grey": 2, "green": 3, "na": 4}
STATE_WORDS = {"green": "Done", "yellow": "Look at this", "red": "Pick up the phone", "grey": "Not yet", "na": "Not applicable"}


def money_bar(verdict):
    """One round square per money light. The hover card: the light's name, a check when it is
    settled, and the amount or state in one line."""
    out = []
    for l in verdict.lights:
        note = l.note or STATE_WORDS.get(l.state, "")
        note = note[:1].upper() + note[1:]
        out.append({"key": l.key, "state": l.state, "label": l.label, "badge": "done" if l.state == "green" else None, "more": 0,
                    "blocks": [{"rows": [{"value": note}]}], "title": f"{l.label}: {note}"})
    return out


@login_required
def panel(request):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    show = request.GET.get("show", "open")
    qs = Folder.objects.all()
    qs = qs.exclude(status="closed") if show == "open" else qs.filter(status="closed")
    folders = list(qs.order_by("-opened_at"))
    ids = [f.po_id for f in folders]
    notes, steps, members = _notes_by_po(ids), _steps_by_po(ids), _members()
    acks = _acks_by_po(ids)
    lines_by_id = {l.id: l for l in LineItem.objects.filter(po_id__in=ids)}
    docs = {d.id: d for d in Document.objects.filter(po_id__in=ids, deleted_at__isnull=True)}
    parties = {p.id: p for p in Party.objects.filter(is_carrier=True)}
    rows = []
    for f in folders:
        v = judge(f, notes.get(f.po_id, []), acks=acks.get(f.po_id, []))
        fbar, waiting = fulfillment_bar(steps.get(f.po_id, []), members, lines_by_id, docs, parties)
        overall = worst([v.overall] + [q["state"] for q in fbar])
        if f.status == "closed":
            overall = "green"
        reason = v.reasons[0][1] if v.reasons else None
        if waiting and waiting["late"] and (not v.reasons or ORDER[waiting["state"]] <= ORDER[v.reasons[0][0]]):
            reason = waiting["late"][0]["why"]
        elif reason is None and waiting:
            reason = f"Waiting on: {waiting['label'].lower()}"
        rows.append({"f": f, "v": v, "fbar": fbar, "mbar": money_bar(v), "overall": overall, "reason": reason, "waiting": waiting})
    rows.sort(key=lambda r: (ORDER[r["overall"]], -r["f"].opened_at.timestamp()))
    counts = defaultdict(int)
    for r in rows:
        counts[r["overall"]] += 1
    return render(request, "core/panel.html", {"rows": rows, "counts": dict(counts), "show": show})


@login_required
def po_detail(request, po_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    f = get_object_or_404(Folder, po_id=po_id)
    notes = list(Note.objects.filter(po_id=po_id).order_by("created_at"))
    acks = list(Ack.objects.filter(po_id=po_id).order_by("created_at"))
    v = judge(f, notes, acks=acks)
    members = _members()
    for a in acks:
        a.who = members.get(a.created_by)
    step_acks = defaultdict(list)
    for a in acks:
        if a.subject.startswith("step:"):
            step_acks[a.subject[5:]].append(a)
    parties = {p.id: p for p in Party.objects.all()}
    docs = {d.id: d for d in Document.objects.filter(po_id=po_id, deleted_at__isnull=True)}
    entries = list(LedgerEntry.objects.filter(po_id=po_id).order_by("entry_date", "created_at"))
    for e in entries:
        e.counterparty = parties.get(e.counterparty_party_id)
        e.doc = docs.get(e.document_id)
    lines = list(LineItem.objects.filter(po_id=po_id).order_by("line_no"))
    steps = defaultdict(list)
    for s in LineStep.objects.filter(po_id=po_id):
        steps[s.line_item_id].append(s)
    for l in lines:
        carrier = parties.get(l.tracking_carrier_party_id)
        l.squares = []
        for st in sorted(steps.get(l.id, []), key=lambda x: STEP_ORDER.get(x.step_key, 99)):
            doc, owner = docs.get(st.proof_document_id), members.get(st.owner_user_id)
            state, headline, facts = describe(st, None, l, carrier=carrier, doc=doc, owner=owner)
            label = LABEL.get(st.step_key, st.step_key)
            l.squares.append({"key": st.step_key, "step": st, "state": state, "headline": headline, "label": label, "doc": doc,
                              "owner": owner, "badge": badge(st), "badge_tone": st.flag, "blocks": [{"rows": facts}], "more": 0,
                              "title": f"{label}: {headline}"})
    fbar, waiting = fulfillment_bar([s for ss in steps.values() for s in ss], members, {l.id: l for l in lines}, docs, parties)
    checklist = list(ChecklistItem.objects.filter(po_id=po_id).order_by("item_key"))
    client_entries = [e for e in entries if e.side == "client"]
    vendor_entries = [e for e in entries if e.side in ("vendor", "freight", "commission")]
    doc_list = sorted(docs.values(), key=lambda d: (d.document_date or d.uploaded_at.date()), reverse=True)
    for d in doc_list:
        d.uploader = members.get(d.uploaded_by)
    # reasons: money reasons plus any flagged or late steps
    reasons = list(v.reasons)
    for l in lines:
        for q in l.squares:
            if q["state"] in ("yellow", "red") and q["step"].flag:
                reasons.append((q["state"], f"Line {l.line_no:05d} {q['label'].lower()} · {q['step'].flag_reason}", f"step:{q['step'].id}"))
            elif q["state"] == "yellow":
                reasons.append(("yellow", f"Line {l.line_no:05d} {q['label'].lower()}: {q['headline'][:1].lower() + q['headline'][1:]}.", f"step:{q['step'].id}"))
            q["acks"] = step_acks.get(str(q["step"].id), [])
    reasons.sort(key=lambda r: ORDER[r[0]])
    acked = [(text, a, members.get(a.created_by)) for text, a in v.acked]
    overall = worst([v.overall] + [q["state"] for q in fbar]) if f.status != "closed" else "green"
    return render(request, "core/po_detail.html", {
        "f": f, "v": v, "overall": overall, "reasons": reasons, "acked": acked, "notes": notes, "lines": lines, "checklist": checklist,
        "client_entries": client_entries, "vendor_entries": vendor_entries, "docs": doc_list,
        "fbar": fbar, "mbar": money_bar(v), "tab": request.GET.get("tab", "folder"), "step_cols": COLUMNS,
    })


@login_required
def doc_detail(request, doc_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    d = get_object_or_404(Document, id=doc_id, deleted_at__isnull=True)
    f = Folder.objects.filter(po_id=d.po_id).first() if d.po_id else None
    uploader = Member.objects.filter(id=d.uploaded_by).first()
    lines = {l.id: l for l in LineItem.objects.filter(po_id=d.po_id)} if d.po_id else {}
    proves = [(lines.get(st.line_item_id), LABEL.get(st.step_key, st.step_key), st) for st in LineStep.objects.filter(proof_document_id=d.id)]
    entries = list(LedgerEntry.objects.filter(document_id=d.id).order_by("entry_date"))
    on_disk = storage.open_file(d.storage_key) if storage.KEY_RE.match(d.storage_key or "") else None
    if on_disk:
        on_disk.close()
    return render(request, "core/doc_detail.html", {"d": d, "f": f, "uploader": uploader, "proves": proves, "entries": entries,
                                                    "on_disk": bool(on_disk), "has_preview": bool(d.thumbnail_key)})


def _send(request, d, key, mime, download_name):
    fh = storage.open_file(key) if key and storage.KEY_RE.match(key) else None
    if fh is None:
        raise Http404("That file is not in the document store on this server.")
    resp = FileResponse(fh, content_type=mime)
    resp["Content-Disposition"] = 'inline; filename="%s"' % re.sub(r"[^A-Za-z0-9._ -]+", "_", download_name)[:120]
    resp["X-Content-Type-Options"] = "nosniff"
    resp["Content-Security-Policy"] = "default-src 'none'; sandbox"
    resp["Cache-Control"] = "private, max-age=600"
    return resp


@login_required
def doc_file(request, doc_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    d = get_object_or_404(Document, id=doc_id, deleted_at__isnull=True)   # RLS decides what is visible
    return _send(request, d, d.storage_key, d.mime_type, d.original_filename or f"{d.id}.pdf")


@login_required
def doc_preview(request, doc_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    d = get_object_or_404(Document, id=doc_id, deleted_at__isnull=True)
    return _send(request, d, d.thumbnail_key, "image/png", f"{d.id}-page1.png")


def _step_choices(po_id):
    lines = list(LineItem.objects.filter(po_id=po_id).order_by("line_no"))
    steps = list(LineStep.objects.filter(po_id=po_id))
    out = []
    for l in lines:
        for st in sorted((x for x in steps if x.line_item_id == l.id and x.applicable), key=lambda x: STEP_ORDER.get(x.step_key, 99)):
            out.append((str(st.id), f"{l.line_no:05d} {l.description[:38]} · {LABEL.get(st.step_key, st.step_key)}", st))
    return out


def _parse_date(text):
    try:
        return datetime.date.fromisoformat(text) if text else None
    except ValueError:
        return None


@login_required
@require_http_methods(["GET", "POST"])
def doc_upload(request, po_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    f = get_object_or_404(Folder, po_id=po_id)
    choices = _step_choices(po_id)
    if request.method == "POST" and int(request.META.get("CONTENT_LENGTH") or 0) > storage.MAX_BYTES + 256 * 1024:
        # Refuse before Django parses the body, so an oversized upload never spools to disk.
        return render(request, "core/doc_upload.html", {"f": f, "form": {"marking": "none", "mark_done": True}, "kinds": DOC_KINDS,
                                                        "markings": MARKINGS, "choices": choices,
                                                        "errors": ["That file is over 25 MB. Scan it at a lower resolution or split it."]})
    form = {"kind": request.POST.get("kind", request.GET.get("kind", "")), "marking": request.POST.get("marking", "none"),
            "title": request.POST.get("title", ""), "document_date": request.POST.get("document_date", ""),
            "note": request.POST.get("note", ""), "step": request.POST.get("step", request.GET.get("step", "")),
            "mark_done": request.POST.get("mark_done", "on" if request.method == "GET" else "") == "on"}
    errors = []
    if request.method == "POST":
        if f.status == "closed":
            errors.append("This folder is closed. Reopen it before filing documents.")
        up = request.FILES.get("file")
        if not up:
            errors.append("Choose a file.")
        elif up.size > storage.MAX_BYTES:
            errors.append("That file is over 25 MB. Scan it at a lower resolution or split it.")
        if form["kind"] not in dict(DOC_KINDS):
            errors.append("Say what the document is.")
        if form["marking"] not in dict(MARKINGS):
            errors.append("Pick a marking.")
        if request.POST.get("attest") != "on":
            errors.append("Confirm that you looked at the document and it is not a drawing, schematic or blueprint.")
        if form["document_date"] and _parse_date(form["document_date"]) is None:
            errors.append("The document date is not a real date.")
        if form["step"] and form["step"] not in {c[0] for c in choices}:
            errors.append("That step is not on this folder.")
        if not errors:
            try:
                data = up.read()
                key, sha, mime, ext = storage.identify(request.app_ctx["tenant_id"], data)
                title = form["title"].strip()[:200] or up.name[:200]
                existing = Document.objects.filter(storage_key=key).first()   # what this person is allowed to see
                if existing is not None and existing.deleted_at is None and str(existing.po_id) == str(po_id):
                    with transaction.atomic():
                        if form["step"]:
                            db.set_step_proof(form["step"], doc_id=existing.id, note=form["note"], mark_done=form["mark_done"])
                    messages.info(request, "Those exact bytes were already filed here as \"%s\"." % (existing.title or existing.original_filename)
                                  + (" They are attached to the step as proof." if form["step"] else ""))
                    return redirect(f"/po/{po_id}/?tab=documents")
                if existing is not None:
                    where = "another folder" if str(existing.po_id) != str(po_id) else "this folder, then removed"
                    errors.append("That exact file is already filed in %s as \"%s\". File a scan with a date or stamp on it instead of the same bytes twice." % (where, existing.title or existing.original_filename))
                else:
                    # Row first (the database decides whether this person may file it), then bytes, then
                    # the preview; a refusal at any point rolls the row back and leaves no file behind.
                    with transaction.atomic():
                        doc_id = db.insert_document(request.app_ctx["tenant_id"], str(po_id), form["kind"], form["marking"], title,
                                                    up.name[:200], key, sha, mime, len(data), None, form["document_date"] or None, None)
                        storage.store(key, data)
                        try:
                            thumb_key, pages = storage.render_first_page(key, mime)
                            if thumb_key or pages:
                                db.set_document_thumbnail(doc_id, thumb_key, pages)
                            if form["step"]:
                                db.set_step_proof(form["step"], doc_id=doc_id, note=form["note"], mark_done=form["mark_done"])
                        except Exception:
                            storage.remove(key)
                            raise
                    messages.success(request, f"Filed {title}." + (" The step is marked done with it as proof." if form["step"] and form["mark_done"] else ""))
                    return redirect(f"/po/{po_id}/?tab=documents")
            except storage.RejectedFile as e:
                errors.append(str(e))
            except IntegrityError:
                errors.append("That exact file is already filed somewhere this account cannot see, so it cannot be filed again here.")
            except DatabaseError as e:
                errors.append("The database refused it: " + str(e).split("\n")[0])
    return render(request, "core/doc_upload.html", {"f": f, "form": form, "errors": errors, "kinds": DOC_KINDS, "markings": MARKINGS,
                                                    "choices": choices})


@login_required
@require_http_methods(["GET", "POST"])
def step_action(request, po_id, step_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    f = get_object_or_404(Folder, po_id=po_id)
    st = get_object_or_404(LineStep, id=step_id, po_id=po_id)
    line = get_object_or_404(LineItem, id=st.line_item_id)
    if not st.applicable:
        messages.info(request, f"{LABEL.get(st.step_key, st.step_key)} does not apply to line {line.line_no:05d}.")
        return redirect(f"/po/{po_id}/")
    members = _members()
    label = LABEL.get(st.step_key, st.step_key)
    acks = list(Ack.objects.filter(po_id=po_id, subject=f"step:{st.id}").order_by("-created_at"))
    for a in acks:
        a.who = members.get(a.created_by)
    doc = Document.objects.filter(id=st.proof_document_id, deleted_at__isnull=True).first() if st.proof_document_id else None
    carrier = Party.objects.filter(id=line.tracking_carrier_party_id).first() if line.tracking_carrier_party_id else None
    state, title, _facts = describe(st, None, line, carrier=carrier, doc=doc)
    errors, action = [], request.POST.get("action", "")
    if request.method == "POST":
        text = request.POST.get("text", "").strip()
        tenant = request.app_ctx["tenant_id"]
        try:
          with transaction.atomic():
              if f.status == "closed":
                  errors.append("This folder is closed.")
              elif action == "done":
                  if len(text) < 3:
                      errors.append("Say what shows this step is done (a note, or upload a document instead).")
                  else:
                      db.set_step_proof(st.id, note=text, mark_done=True)
                      messages.success(request, f"Line {line.line_no:05d} {label.lower()} marked done.")
              elif action == "flag":
                  colour = request.POST.get("flag", "")
                  if colour not in ("yellow", "red"):
                      errors.append("Pick yellow or red.")
                  elif len(text) < 3:
                      errors.append("Say what the problem is.")
                  else:
                      db.set_step_flag(st.id, colour, text)
                      messages.success(request, f"Line {line.line_no:05d} {label.lower()} flagged {colour}.")
              elif action == "okay":
                  if len(text) < 3:
                      errors.append("Say why it is fine as it is.")
                  else:
                      db.clear_step_flag(st.id)
                      db.insert_ack(tenant, str(po_id), f"step:{st.id}", "okay", text)
                      messages.success(request, f"Acknowledged line {line.line_no:05d} {label.lower()}; the flag is cleared.")
              elif action == "fix":
                  if len(text) < 3:
                      errors.append("Say what was done.")
                  else:
                      db.clear_step_flag(st.id)
                      if request.POST.get("mark_done") == "on":
                          db.set_step_proof(st.id, note=text, mark_done=True)
                      db.insert_ack(tenant, str(po_id), f"step:{st.id}", "fix", text)
                      messages.success(request, f"Fix posted on line {line.line_no:05d} {label.lower()}.")
              elif action == "credit":
                  try:
                      amount = Decimal(request.POST.get("amount", "").replace(",", "").replace("$", "").strip())
                      if not amount.is_finite():
                          raise InvalidOperation
                      amount = amount.quantize(Decimal("0.01"))
                  except InvalidOperation:
                      amount = Decimal("0")
                  if amount <= 0:
                      errors.append("Enter the credit amount.")
                  elif len(text) < 3:
                      errors.append("Say what the credit is for; it prints on the ledger.")
                  else:
                      ref = f"Credit · line {line.line_no:05d} {label.lower()}"
                      entry_id = db.insert_credit_memo(tenant, str(po_id), amount, text, ref, doc.id if doc else None)
                      db.clear_step_flag(st.id)
                      db.insert_ack(tenant, str(po_id), f"step:{st.id}", "credit", text, ledger_entry_id=entry_id)
                      messages.success(request, f"Client credit of ${amount:,.2f} posted and the flag cleared.")
              else:
                  errors.append("Unknown action.")
        except DatabaseError as e:
            errors.append("The database refused it: " + str(e).split("\n")[0])
        if not errors:
            return redirect(f"/po/{po_id}/")
    return render(request, "core/step_action.html", {"f": f, "st": st, "line": line, "state": state, "title": title, "label": label,
                                                     "owner": members.get(st.owner_user_id), "doc": doc, "acks": acks, "errors": errors,
                                                     "action": action, "text": request.POST.get("text", "")})


@login_required
@require_http_methods(["GET", "POST"])
def okay_reason(request, po_id, key):
    """Okay a money reason (grey until it expires) or resolve a sticky note."""
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    f = get_object_or_404(Folder, po_id=po_id)
    notes = list(Note.objects.filter(po_id=po_id).order_by("created_at"))
    acks = list(Ack.objects.filter(po_id=po_id).order_by("created_at"))
    v = judge(f, notes, acks=acks)
    match = next((r for r in v.reasons if r[2] == key), None)
    if match is None:
        messages.info(request, "That item is no longer open.")
        return redirect(f"/po/{po_id}/")
    is_note = key.startswith("note_")
    errors = []
    if request.method == "POST":
        text = request.POST.get("text", "").strip()
        period = request.POST.get("period", "30")
        if len(text) < 3:
            errors.append("Say why it is fine. The next person will read it.")
        elif period not in dict(OKAY_PERIODS):
            errors.append("Pick when it should come back.")
        else:
            try:
                with transaction.atomic():
                    if is_note:
                        note = next((n for n in notes if str(n.id).replace("-", "") == key[5:]), None)
                        if note is None or db.resolve_note(note.id) is None:
                            errors.append("That note could not be resolved from this account. Its author or a manager can.")
                        else:
                            db.insert_ack(request.app_ctx["tenant_id"], str(po_id), f"note:{note.id}", "okay", text)
                    else:
                        expires = (datetime.date.today() + datetime.timedelta(days=int(period))) if period else None
                        db.insert_ack(request.app_ctx["tenant_id"], str(po_id), f"money:{key}", "okay", text, expires_on=expires)
            except DatabaseError as e:
                errors.append("The database refused it: " + str(e).split("\n")[0])
        if not errors:
            messages.success(request, "Acknowledged. It is off the board" + (" until the note is reopened." if is_note else (" for " + dict(OKAY_PERIODS)[period] + "." if period else ".")))
            return redirect(f"/po/{po_id}/")
    return render(request, "core/okay.html", {"f": f, "state": match[0], "reason_text": match[1], "key": key, "is_note": is_note,
                                              "periods": OKAY_PERIODS, "errors": errors, "text": request.POST.get("text", "")})
