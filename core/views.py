from collections import defaultdict
from django.contrib.auth.decorators import login_required
from django.db import connection
from django.http import Http404
from django.shortcuts import get_object_or_404, render

from .lights import judge
from .models import ChecklistItem, Folder, LedgerEntry, LineItem, Note, Party

ORDER = {"red": 0, "yellow": 1, "green": 2, "grey": 3}


def _notes_by_po(po_ids):
    out = defaultdict(list)
    for n in Note.objects.filter(po_id__in=po_ids).order_by("created_at"):
        out[n.po_id].append(n)
    return out


@login_required
def panel(request):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    show = request.GET.get("show", "open")
    qs = Folder.objects.all()
    qs = qs.exclude(status="closed") if show == "open" else qs.filter(status="closed")
    folders = list(qs.order_by("-opened_at"))
    notes = _notes_by_po([f.po_id for f in folders])
    rows = []
    for f in folders:
        v = judge(f, notes.get(f.po_id, []))
        rows.append({"f": f, "v": v})
    rows.sort(key=lambda r: (ORDER[r["v"].overall], -r["f"].opened_at.timestamp()))
    counts = defaultdict(int)
    for r in rows:
        counts[r["v"].overall] += 1
    return render(request, "core/panel.html", {"rows": rows, "counts": dict(counts), "show": show})


@login_required
def po_detail(request, po_id):
    if not request.app_ctx:
        return render(request, "core/no_context.html", status=403)
    f = get_object_or_404(Folder, po_id=po_id)
    notes = list(Note.objects.filter(po_id=po_id).order_by("created_at"))
    v = judge(f, notes)
    parties = {p.id: p for p in Party.objects.all()}
    entries = list(LedgerEntry.objects.filter(po_id=po_id).order_by("entry_date", "created_at"))
    for e in entries:
        e.counterparty = parties.get(e.counterparty_party_id)
    lines = list(LineItem.objects.filter(po_id=po_id).order_by("line_no"))
    checklist = list(ChecklistItem.objects.filter(po_id=po_id).order_by("item_key"))
    client_entries = [e for e in entries if e.side == "client"]
    vendor_entries = [e for e in entries if e.side in ("vendor", "freight", "commission")]
    return render(request, "core/po_detail.html", {
        "f": f, "v": v, "notes": notes, "lines": lines, "checklist": checklist,
        "client_entries": client_entries, "vendor_entries": vendor_entries,
    })
