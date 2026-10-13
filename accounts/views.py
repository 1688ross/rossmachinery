"""
Second factor: an authenticator app (TOTP) plus eight one-time backup codes. Enrolment happens
on first sign-in; after that every sign-in asks for a code. Wrong codes are throttled by
django-otp (the wait doubles after each miss).
"""
import base64
from io import BytesIO

import qrcode
import qrcode.image.svg
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.http import require_http_methods
from django_otp import login as otp_login
from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
from django_otp.plugins.otp_totp.models import TOTPDevice

BACKUP_CODES = 8


def _safe_next(request):
    nxt = request.POST.get("next") or request.GET.get("next") or "/"
    ok = url_has_allowed_host_and_scheme(nxt, allowed_hosts={request.get_host()}, require_https=request.is_secure())
    return nxt if ok and nxt.startswith("/") and not nxt.startswith("//") else "/"


def _qr_svg(url):
    img = qrcode.make(url, image_factory=qrcode.image.svg.SvgPathImage, box_size=10, border=2)
    buf = BytesIO()
    img.save(buf)
    return buf.getvalue().decode()


def _new_backup_codes(user):
    dev, _ = StaticDevice.objects.get_or_create(user=user, name="backup", defaults={"confirmed": True})
    if not dev.confirmed:
        dev.confirmed = True
        dev.save()
    dev.token_set.all().delete()
    codes = [StaticToken.random_token() for _ in range(BACKUP_CODES)]
    for c in codes:
        dev.token_set.create(token=c)
    return codes


def _clean(code):
    return code.replace(" ", "").replace("-", "").strip().lower()


def _password_ok(request):
    return request.user.check_password(request.POST.get("password", ""))


def _wait_text(info):
    """How long django-otp's throttle holds the device, in words."""
    from django.utils import timezone
    until = (info or {}).get("locked_until")
    secs = max(1, int((until - timezone.now()).total_seconds())) if until else 1
    return f"{secs} second{'s' if secs != 1 else ''}" if secs < 90 else f"{secs // 60} minutes"


@login_required
@require_http_methods(["GET", "POST"])
def two_factor_setup(request):
    user = request.user
    enrolled = TOTPDevice.objects.filter(user=user, confirmed=True).exists()
    if enrolled and not user.is_verified():
        return redirect("two_factor_verify")      # a password alone cannot replace the authenticator
    # Replacing a working authenticator is a step up: the password is asked again first.
    if enrolled and request.session.get("stepup_setup") != True:
        if request.method == "POST" and request.POST.get("stepup") == "1":
            if _password_ok(request):
                request.session["stepup_setup"] = True
                return redirect("two_factor_setup")
            return render(request, "accounts/stepup.html", {"error": "That password did not match.", "purpose": "set up a new phone", "action": "two_factor_setup"})
        return render(request, "accounts/stepup.html", {"purpose": "set up a new phone", "action": "two_factor_setup"})
    device = TOTPDevice.objects.select_for_update().filter(user=user, confirmed=False).order_by("-id").first()
    if device is None:
        device = TOTPDevice.objects.create(user=user, name="authenticator", confirmed=False)
    error = None
    if request.method == "POST":
        allowed, info = device.verify_is_allowed()
        if not allowed:
            error = "Too many wrong codes. Try again in %s." % _wait_text(info)
        elif device.verify_token(_clean(request.POST.get("code", ""))):
            device.confirmed = True
            device.name = "authenticator"
            device.save()
            TOTPDevice.objects.filter(user=user).exclude(pk=device.pk).delete()
            codes = _new_backup_codes(user)
            otp_login(request, device)
            request.session.pop("stepup_setup", None)
            request.session["new_backup_codes"] = {"codes": codes, "next": _safe_next(request), "fresh": not enrolled}
            if enrolled:
                messages.success(request, "Your authenticator was replaced. The old phone no longer works for this account.")
            return redirect("two_factor_codes")
        else:
            error = "That code did not match. The number changes every 30 seconds; type the one showing now."
    key = base64.b32encode(device.bin_key).decode()
    return render(request, "accounts/2fa_setup.html", {
        "qr": _qr_svg(device.config_url), "key": " ".join(key[i:i + 4] for i in range(0, len(key), 4)),
        "error": error, "next": _safe_next(request), "replacing": enrolled})


@login_required
def two_factor_codes(request):
    """The backup codes, shown once after they are made (kept out of the POST response so a
    reload or a print cannot resubmit the form)."""
    data = request.session.pop("new_backup_codes", None)
    if not data:
        return redirect("account")
    return render(request, "accounts/2fa_codes.html", data)


@login_required
@require_http_methods(["GET", "POST"])
def two_factor_verify(request):
    user = request.user
    if not TOTPDevice.objects.filter(user=user, confirmed=True).exists():
        return redirect("two_factor_setup")
    if user.is_verified():
        return redirect(_safe_next(request))
    error = None
    if request.method == "POST":
        code = _clean(request.POST.get("code", ""))
        # Row locks: the request runs in one transaction, so parallel guesses queue behind each
        # other and the throttle counts every one of them.
        if code.isdigit() and len(code) == 6:
            for d in TOTPDevice.objects.select_for_update().filter(user=user, confirmed=True):
                allowed, info = d.verify_is_allowed()
                if not allowed:
                    error = "Too many wrong codes. Try again in %s." % _wait_text(info)
                    break
                if d.verify_token(code):
                    otp_login(request, d)
                    return redirect(_safe_next(request))
            error = error or "That code did not match."
        else:
            static = StaticDevice.objects.select_for_update().filter(user=user, confirmed=True).first()
            allowed, info = static.verify_is_allowed() if static else (False, None)
            if static and not allowed:
                error = "Too many wrong codes. Try again in %s." % _wait_text(info)
            elif static and static.verify_token(code):
                otp_login(request, static)
                left = static.token_set.count()
                messages.warning(request, f"You signed in with a backup code. {left} left. Make new ones from your account page before they run out.")
                return redirect(_safe_next(request))
            else:
                error = "That backup code did not match. Backup codes are eight letters and numbers; app codes are six digits."
    return render(request, "accounts/2fa_verify.html", {"error": error, "next": _safe_next(request)})


@login_required
def account(request):
    totp = TOTPDevice.objects.filter(user=request.user, confirmed=True).first()
    static = StaticDevice.objects.filter(user=request.user, confirmed=True).first()
    return render(request, "accounts/account.html", {"totp": totp, "backup_left": static.token_set.count() if static else 0})


@login_required
@require_http_methods(["GET", "POST"])
def two_factor_new_codes(request):
    """New backup codes, after the password is entered again (the old codes stop working)."""
    if not request.user.is_verified():
        return redirect("two_factor_verify")
    if request.method == "POST" and request.POST.get("stepup") == "1":
        if _password_ok(request):
            codes = _new_backup_codes(request.user)
            request.session["new_backup_codes"] = {"codes": codes, "next": "/account/", "fresh": False}
            messages.success(request, "New backup codes made. The old ones no longer work.")
            return redirect("two_factor_codes")
        return render(request, "accounts/stepup.html", {"error": "That password did not match.", "purpose": "make new backup codes", "action": "two_factor_new_codes"})
    return render(request, "accounts/stepup.html", {"purpose": "make new backup codes", "action": "two_factor_new_codes"})
