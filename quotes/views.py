import json, os, subprocess, tempfile
from datetime import date
from decimal import Decimal, InvalidOperation
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.urls import reverse
from django.views.decorators.clickjacking import xframe_options_sameorigin

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


def _fill(q, post, user):
    q.number = post.get("number", "").strip() or q.number or _next_number()
    q.quote_date = post.get("quote_date") or date.today()
    q.to_name = post.get("to_name", "").strip()
    q.to_company = post.get("to_company", "").strip()
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


@login_required
def quote_list(request):
    return render(request, "quotes/list.html", {"quotes": Quote.objects.all()[:200]})


@login_required
def quote_new(request):
    if request.method == "POST":
        q = _fill(Quote(), request.POST, request.user)
        q.created_by = request.user
        q.save()
        return redirect("quote_preview", pk=q.pk)
    initial = {"number": _next_number(), "quote_date": date.today().isoformat(), "terms": "Net (30) Days",
               "delivery": "", "fob": "", "signer_name": request.user.get_full_name() or request.user.get_username(),
               "closing": DEFAULT_CLOSING}
    return render(request, "quotes/form.html", {"q": None, "initial": initial, "lines_json": json.dumps([{}])})


@login_required
def quote_edit(request, pk):
    q = get_object_or_404(Quote, pk=pk)
    if request.method == "POST":
        _fill(q, request.POST, request.user).save()
        return redirect("quote_preview", pk=q.pk)
    initial = {f: getattr(q, f) for f in ("number", "to_name", "to_company", "to_address", "subject", "reference", "intro", "fob", "delivery", "terms", "closing", "signer_name", "signer_title")}
    initial["quote_date"] = q.quote_date.isoformat()
    return render(request, "quotes/form.html", {"q": q, "initial": initial, "lines_json": json.dumps(q.lines or [{}])})


@login_required
def quote_preview(request, pk):
    q = get_object_or_404(Quote, pk=pk)
    return render(request, "quotes/preview.html", {"q": q})


def _document_html(request, q):
    return render_to_string("quotes/document.html", {"q": q, "base": request.build_absolute_uri("/")}, request=request)


@login_required
@xframe_options_sameorigin
def quote_document(request, pk):
    """The quote itself as a page (what the PDF is printed from)."""
    q = get_object_or_404(Quote, pk=pk)
    return HttpResponse(_document_html(request, q))


@login_required
def quote_pdf(request, pk):
    q = get_object_or_404(Quote, pk=pk)
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
