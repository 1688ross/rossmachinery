"""
On login, translate the Django identity into the app.users identity and the tenant, using the
schema's login-path helpers. This runs inside the login request's transaction BEFORE any
tenant context is set (the middleware sets nothing for an anonymous request), which is exactly
the context-free condition app.resolve_user_by_subject requires.
"""
from django.contrib.auth.signals import user_logged_in
from django.db import connection
from django.dispatch import receiver
from django.conf import settings


@receiver(user_logged_in)
def bind_app_context(sender, request, user, **kwargs):
    with connection.cursor() as cur:
        cur.execute("SELECT app.resolve_user_by_subject(%s)", [user.auth_subject])
        row = cur.fetchone()
        user_id = row[0] if row else None
        if not user_id:
            request.session.pop("app_ctx", None)
            return
        cur.execute("SET LOCAL app.user_id = %s", [str(user_id)])
        cur.execute("SELECT tenant_id, slug, role FROM app.my_tenants()")
        tenants = cur.fetchall()
    chosen = next((t for t in tenants if t[1] == settings.TENANT_SLUG), tenants[0] if tenants else None)
    if not chosen:
        request.session.pop("app_ctx", None)
        return
    request.session["app_ctx"] = {"tenant_id": str(chosen[0]), "user_id": str(user_id), "role": chosen[2]}
