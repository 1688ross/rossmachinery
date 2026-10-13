"""
Second factor on every sign-in. After the password, a person must present a code from their
authenticator app (or a backup code) before any page loads. Someone who has not set one up
yet is sent to the setup page and can go nowhere else. Runs before the tenant-context
middleware, so no database context is ever set for a half-signed-in session.
"""
from django.conf import settings
from django.shortcuts import redirect
from django.urls import reverse
from django.utils.http import urlencode

ALLOWED_PREFIXES = ("/login/", "/logout/", "/2fa/", "/static/")


class SecondFactorMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, "user", None)
        if (settings.REQUIRE_2FA and user is not None and user.is_authenticated
                and not getattr(user, "is_verified", lambda: False)()
                and not request.path_info.startswith(ALLOWED_PREFIXES)):
            from django_otp.plugins.otp_totp.models import TOTPDevice
            has_device = TOTPDevice.objects.filter(user=user, confirmed=True).exists()
            target = reverse("two_factor_verify" if has_device else "two_factor_setup")
            if request.method == "GET" and request.path != "/":
                target += "?" + urlencode({"next": request.get_full_path()})
            return redirect(target)
        return self.get_response(request)
