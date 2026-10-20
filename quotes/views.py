import json, os, re, subprocess, tempfile, uuid
from datetime import date
from decimal import Decimal, InvalidOperation
from django.conf import settings
from django.db import DatabaseError, IntegrityError, transaction
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.urls import reverse
from django.views.decorators.clickjacking import xframe_options_sameorigin
from django.views.decorators.http import require_POST

from core import db
from core.models import Party
from .models import Quote

CHROME = os.environ.get("RMS_CHROME", "/opt/pw-browsers/chromium")
DEFAULT_INTRO = "Ross Machinery Sales is pleased to submit a quote for {subject} to meet your needs. The prices are as follows:"
DEFAULT_CLOSING = "Thank you for the opportunity to submit this proposal. If you have any questions, or if we can be of any further assistance, please contact our office."


def _next_number():
    today = date.today()
    prefix = f"SA{today:%y%m}"
    n = Quote.objects.filter(number__startswith=prefix).count() + 1
    return f"{prefix}{n:03d}"


def _parse_lines(post):
    lines = []
    i = 0
    while f"line-{i}-description" in post:
        desc = post.get(f"line-{i}-description", "").strip()
        if desc:
            try:
                qty = Decimal(post.get(f"line-{i}-qty", "1") or "1")
                unit = Decimal((post.get(f"line-{i}-unit_price", "0") or "0").replace(",", "").replace("$", ""))
            except InvalidOperation:
                qty, unit = Decimal("1"), Decimal("0")
            details = [d.strip() for d in post.get(f"line-{i}-details", "").splitlines() if d.strip()]
            lines.append({"item": f"{(len(lines) + 1) * 10:05d}", "description": desc, "details": details,
                          "qty": str(qty), "unit_price": str(unit)})
        i += 1
    return lines


def _uuid(text):
    try:
        return uuid.UUID(str(text))
    except (ValueError, TypeError):
        return None


ADDR_LAST = re.compile(r"^(?P<city>[^,]+),\s*(?P<region>[A-Za-z]{2})\.?\s*(?P<postal>\d{5}(?:-\d{4})?)?\s*$")


def _split_address(text):
    """'6900 Main Street / Stratford, CT 06615' -> line1, line2, city, region, postal. None when empty."""
    lines = [l.strip() for l in (text or "").splitlines() if l.strip()]
    if not lines:
        return None
    out = {"line1": lines[0], "line2": None, "city": None, "region": None, "postal": None}
    rest = lines[1:]
    m = ADDR_LAST.match(rest[-1]) if rest else None
    if m:
        out.update(city=m["city"].strip(), region=m["region"].upper(), postal=m["postal"])
        rest = rest[:-1]
    if rest:
        out["line2"] = ", ".join(rest)
    return out


def _clients():
    """The client list for the form, with what to prefill: the address on file, else the contact
    and address from the last quote to that client."""
    parties = list(Party.objects.filter(is_client=True, is_active=True).order_by("name"))
    last = {}
    for q in Quote.objects.exclude(client_party_id=None).order_by("-created_at")[:500]:
        last.setdefault(q.client_party_id, q)
    data = {}
    for p in parties:
        prev = last.get(p.id)
        data[str(p.id)] = {"name": p.name, "address": p.address_text or (prev.to_address if prev else ""), "contact": prev.to_name if prev else ""}
    return parties, data


def _fill(q, post, user):
    choice = post.get("client", "").strip()
    party = Party.objects.filter(id=_uuid(choice), is_client=True).first() if _uuid(choice) else None
    q.client_party_id = party.id if party else None
    q.to_company = party.name if party else (post.get("to_company", "").strip() if choice in ("new", "") else "")
    q.number = post.get("number", "").strip() or q.number or _next_number()
    q.quote_date = post.get("quote_date") or date.today()
    q.to_name = post.get("to_name", "").strip()
    q.to_address = post.get("to_address", "").strip()
    q.subject = post.get("subject", "").strip()
    q.reference = post.get("reference", "").strip()
    q.intro = post.get("intro", "").strip() or DEFAULT_INTRO.format(subject=q.subject)
    q.fob = post.get("fob", "").strip()
    q.delivery = post.get("delivery", "").strip()
    q.terms = post.get("terms", "").strip()
    q.closing = post.get("closing", "").strip() or DEFAULT_CLOSING
    q.signer_name = post.get("signer_name", "").strip() or (user.get_full_name() or user.get_username())
    q.signer_title = post.get("signer_title", "").strip()
    q.lines = _parse_lines(post)
    return q


def _save_client(q, tenant_id):
    """Keep the client list in step with the quote: reuse the party with this company's name or
    add it; a client on file with no address gets the one typed on the quote."""
    if not q.to_company:
        return
    party = Party.objects.filter(id=q.client_party_id).first() if q.client_party_id else None
    if party is None:
        party = Party.objects.filter(name__iexact=q.to_company).first()
    addr = _split_address(q.to_address)
    if party is None:
        try:
            with transaction.atomic():
                q.client_party_id = db.insert_party(tenant_id, q.to_company, addr)
        except IntegrityError:   # same name filed a moment ago by someone else
            party = Party.objects.filter(name__iexact=q.to_company).first()
    if party is not None:
        q.client_party_id = party.id
        q.to_company = party.name
        if not party.is_client:
            db.mark_client(party.id)
        if addr and not (party.address_line1 or party.city):
            db.update_party_address(party.id, addr)


def _form(request, q, initial, lines, errors=()):
    parties, data = _clients()
    return render(request, "quotes/form.html", {"q": q, "initial": initial, "lines_json": json.dumps(lines), "clients": parties,
                                                "clients_json": data, "errors": list(errors)})


def _validate(q, post):
    errors = []
    if not q.to_company:
        errors.append("Choose a client, or pick \"New client\" and type the company name.")
    if not q.subject:
        errors.append("Add a subject line.")
    if not q.signer_name:
        errors.append("Say who is signing the quote.")
    return errors


def _initial_from_post(post):
    return {k: post.get(k, "") for k in ("number", "quote_date", "reference", "to_name", "to_company", "to_address", "subject", "intro",
                                         "fob", "delivery", "terms", "closing", "signer_name", "signer_title", "client")}


@login_required
def quote_list(request):
    return render(request, "quotes/list.html", {"quotes": Quote.objects.all()[:200]})


@login_required
def quote_new(request):
    if request.method == "POST":
        q = _fill(Quote(), request.POST, request.user)
        errors = _validate(q, request.POST)
        if not errors and request.app_ctx:
            try:
                _save_client(q, request.app_ctx["tenant_id"])
            except DatabaseError as e:
                errors.append("The client could not be added: " + str(e).split("\n")[0])
        if errors:
            return _form(request, None, _initial_from_post(request.POST), q.lines or [{}], errors)
        q.created_by = request.user
        q.save()
        return redirect("quote_preview", pk=q.pk)
    initial = {"number": _next_number(), "quote_date": date.today().isoformat(), "terms": "Net (30) Days",
               "delivery": "", "fob": "", "signer_name": request.user.get_full_name() or request.user.get_username(),
               "closing": DEFAULT_CLOSING, "client": ""}
    return _form(request, None, initial, [{}])


@login_required
def quote_edit(request, pk):
    q = get_object_or_404(Quote, pk=pk)
    if request.method == "POST":
        _fill(q, request.POST, request.user)
        errors = _validate(q, request.POST)
        if not errors and request.app_ctx:
            try:
                _save_client(q, request.app_ctx["tenant_id"])
            except DatabaseError as e:
                errors.append("The client could not be added: " + str(e).split("\n")[0])
        if errors:
            return _form(request, q, _initial_from_post(request.POST), q.lines or [{}], errors)
        q.save()
        return redirect("quote_preview", pk=q.pk)
    initial = {f: getattr(q, f) for f in ("number", "to_name", "to_company", "to_address", "subject", "reference", "intro", "fob", "delivery", "terms", "closing", "signer_name", "signer_title")}
    initial["quote_date"] = q.quote_date.isoformat()
    # Which client is it? The one on record, else the one on the list with this name, else "new".
    party = Party.objects.filter(id=q.client_party_id).first() if q.client_party_id else Party.objects.filter(name__iexact=q.to_company).first()
    initial["client"] = str(party.id) if party else "new"
    return _form(request, q, initial, q.lines or [{}])


QUOTE_FIELDS = ("number", "reference", "to_name", "to_company", "to_address", "subject", "intro", "fob", "delivery", "terms",
                "closing", "signer_name", "signer_title")


def quote_json(q):
    """The quote as the browser-side PDF builder expects it (the standalone quote page's shape)."""
    d = {f: getattr(q, f) or "" for f in QUOTE_FIELDS}
    d["quote_date"] = q.quote_date.isoformat() if q.quote_date else ""
    d["lines"] = [{"description": l.get("description", ""), "details": list(l.get("details") or []),
                   "qty": str(l.get("qty", "1")), "unit_price": str(l.get("unit_price", "0"))} for l in (q.lines or [])]
    return d


@login_required
def quote_preview(request, pk):
    q = get_object_or_404(Quote, pk=pk)
    return render(request, "quotes/preview.html", {"q": q, "q_json": quote_json(q)})


def _document_html(request, q):
    return render_to_string("quotes/document.html", {"q": q, "base": request.build_absolute_uri("/")}, request=request)


@login_required
@require_POST
def quote_live(request):
    """The quote page rendered from the form as it is being filled in (nothing is saved). The form
    posts itself here and shows the answer beside the fields."""
    q = _fill(Quote(), request.POST, request.user)
    return HttpResponse(_document_html(request, q))


@login_required
@xframe_options_sameorigin
def quote_document(request, pk):
    """The quote itself as a page (what the PDF is printed from)."""
    q = get_object_or_404(Quote, pk=pk)
    return HttpResponse(_document_html(request, q))


@login_required
def quote_pdf(request, pk):
    """Server-side fallback (needs a Chromium at RMS_CHROME). The preview page builds the PDF in the
    browser instead, so this only runs when that script did not load."""
    q = get_object_or_404(Quote, pk=pk)
    if not os.path.exists(CHROME):
        return redirect("quote_document", pk=q.pk)
    html = _document_html(request, q)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "quote.html")
        out = os.path.join(tmp, "quote.pdf")
        with open(src, "w") as fh:
            fh.write(html)
        subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
                        "--run-all-compositor-stages-before-draw", "--virtual-time-budget=2000",
                        f"--print-to-pdf={out}", f"file://{src}"], check=True, timeout=60,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with open(out, "rb") as fh:
            pdf = fh.read()
    resp = HttpResponse(pdf, content_type="application/pdf")
    resp["Content-Disposition"] = f'attachment; filename="{q.number}.pdf"'
    return resp
