"""
Tenant-context middleware: the session-context contract from schema/README section 2.

Every request runs inside one transaction (ATOMIC_REQUESTS). Before any view touches schema
'app', this middleware issues SET LOCAL app.tenant_id / app.user_id from the server-side
session, never from anything the browser sends. With no logged-in user nothing is set, so
every query against 'app' returns zero rows (fail closed).
"""
import uuid
from django.db import connection, transaction


class TenantContextMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # One transaction per request, opened HERE so the SET LOCAL below lives for the whole
        # request (Django's ATOMIC_REQUESTS only wraps the view, which is too late).
        with transaction.atomic():
            ctx = request.session.get("app_ctx")
            request.app_ctx = None
            if request.user.is_authenticated and ctx:
                tenant_id, user_id = ctx.get("tenant_id"), ctx.get("user_id")
                try:
                    uuid.UUID(tenant_id); uuid.UUID(user_id)
                except (TypeError, ValueError):
                    tenant_id = user_id = None
                if tenant_id and user_id:
                    with connection.cursor() as cur:
                        cur.execute("SET LOCAL app.tenant_id = %s", [tenant_id])
                        cur.execute("SET LOCAL app.user_id = %s", [user_id])
                    request.app_ctx = {"tenant_id": tenant_id, "user_id": user_id, "role": ctx.get("role")}
            return self.get_response(request)
