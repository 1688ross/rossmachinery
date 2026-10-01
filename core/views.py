from collections import defaultdict
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, render

from .lights import judge
from .models import ChecklistItem, Document, Folder, LedgerEntry, LineItem, LineStep, Member, Note, Party
from .steps import STEPS, LABEL, ORDER as STEP_ORDER, square, squares_for_line, worst

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


def fulfillment_bar(steps, members, lines_by_id=None):
    """Collapse all lines' steps into one square per step: the worst state across lines.
    Title lists per-line detail. Returns list of dicts in step order."""
    by_key = defaultdict(list)
    for s in steps:
        by_key[s.step_key].append(s)
    bar, waiting = [], None
    for key, label in STEPS:
        rows = by_key.get(key, [])
        if not rows or all(not r.applicable for r in rows):
            bar.append({"key": key, "state": "na", "title": f"{label}: not applicable"})
            continue
        sq = [dict(zip(("state", "title"), square(r, None, (lines_by_id or {}).get(r.line_item_id))), key=r.step_key, step=r) for r in rows]
        state = worst([q["state"] for q in sq])
        titles = [q["title"] for q in sq if q["state"] != "na"]
        bar.append({"key": key, "state": state, "title": " / ".join(titles[:3]) + (" …" if len(titles) > 3 else "")})
        if waiting is None and state in ("grey", "yellow", "red"):
            owners = {r.owner_user_id for r in rows if r.done_at is None and r.applicable}
            names = [members[o].full_name.split()[0] for o in owners if o in members]
            waiting = {"label": label, "state": state, "owners": names,
                       "late": [q for q in sq if q["state"] in ("yellow", "red")]}
    return bar, waiting


def money_bar(verdict):
    return [{"key": l.key, "state": l.state, "title": f"{l.label}{': ' + l.note if l.note else ''}"} for l in verdict.lights]


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
    lines_by_id = {l.id: l for l in LineItem.objects.filter(po_id__in=ids)}
    rows = []
    for f in folders:
        v = judge(f, notes.get(f.po_id, []))
        fbar, waiting = fulfillment_bar(steps.get(f.po_id, []), members, lines_by_id)
        overall = worst([v.overall] + [q["state"] for q in fbar])
        if f.status == "closed":
            overall = "green"
        reason = v.reasons[0][1] if v.reasons else None
        if waiting and waiting["late"] and (not v.reasons or ORDER[waiting["state"]] <= ORDER[v.reasons[0][0]]):
            reason = waiting["late"][0]["title"] + (f" (owner: {', '.join(waiting['owners'])})" if waiting["owners"] else "")
        elif reason is None and waiting:
            reason = f"Waiting on: {waiting['label'].lower()}" + (f" ({', '.join(waiting['owners'])})" if waiting["owners"] else "")
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
    v = judge(f, notes)
    members = _members()
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
        l.squares = squares_for_line(steps.get(l.id, []), line=l)
        for q in l.squares:
            q["doc"] = docs.get(q["step"].proof_document_id)
            q["owner"] = members.get(q["step"].owner_user_id)
            q["label"] = LABEL[q["key"]]
    fbar, waiting = fulfillment_bar([s for ss in steps.values() for s in ss], members, {l.id: l for l in lines})
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
                reasons.append((q["state"], f"Line {l.line_no:05d} {q['label'].lower()}: {q['step'].flag_reason}"))
            elif q["state"] == "yellow":
                who = f" Owner: {q['owner'].full_name}." if q["owner"] else ""
                reasons.append(("yellow", f"Line {l.line_no:05d}: {q['title']}.{who}"))
    reasons.sort(key=lambda r: ORDER[r[0]])
    overall = worst([v.overall] + [q["state"] for q in fbar]) if f.status != "closed" else "green"
    return render(request, "core/po_detail.html", {
        "f": f, "v": v, "overall": overall, "reasons": reasons, "notes": notes, "lines": lines, "checklist": checklist,
        "client_entries": client_entries, "vendor_entries": vendor_entries, "docs": doc_list,
        "fbar": fbar, "mbar": money_bar(v), "tab": request.GET.get("tab", "folder"), "step_labels": STEPS,
    })


@login_required
def doc_detail(request, doc_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    d = get_object_or_404(Document, id=doc_id, deleted_at__isnull=True)
    f = Folder.objects.filter(po_id=d.po_id).first() if d.po_id else None
    uploader = Member.objects.filter(id=d.uploaded_by).first()
    return render(request, "core/doc_detail.html", {"d": d, "f": f, "uploader": uploader})
