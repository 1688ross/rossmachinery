"""
Ross Machinery Sales platform. Django settings.

Profile: PO_PROFILE=sovereign (default) or cloud. Sovereign means no outbound network is
needed for anything; the app must run with egress disabled.

The SQL migrations under schema/ are the source of truth for the database. Django models in
core/ are unmanaged mirrors. Never run makemigrations for schema 'app'.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
PO_PROFILE = os.environ.get("PO_PROFILE", "sovereign")
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-change-me")
DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")
CSRF_TRUSTED_ORIGINS = [o for o in os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if o]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django_otp",
    "django_otp.plugins.otp_totp",
    "accounts",
    "core",
    "quotes",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django_otp.middleware.OTPMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "core.middleware.TenantContextMiddleware",
]

ROOT_URLCONF = "rms.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [BASE_DIR / "templates"],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
        "core.context_processors.branding",
    ]},
}]
WSGI_APPLICATION = "rms.wsgi.application"

# Two connections: 'default' is the runtime role (po_api -> app_user, subject to RLS).
# Django's own tables (auth, sessions, otp) live in the same database under schema 'django',
# owned by the runtime role so RLS never applies to them. See docs/03 and schema/README.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("PGDATABASE", "rms_dev"),
        "USER": os.environ.get("PGUSER", "po_api"),
        "PASSWORD": os.environ.get("PGPASSWORD", "po_api_dev"),
        "HOST": os.environ.get("PGHOST", "127.0.0.1"),
        "PORT": os.environ.get("PGPORT", "5432"),
        "OPTIONS": {"options": "-c search_path=django,app,public"},
        "ATOMIC_REQUESTS": False,  # the tenant-context middleware opens the per-request transaction
        "CONN_MAX_AGE": 0,
    }
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"
LOGIN_URL = "/login/"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/login/"

SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_AGE = 60 * 60 * 10
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
X_FRAME_OPTIONS = "DENY"
SECURE_CONTENT_TYPE_NOSNIFF = True

LANGUAGE_CODE = "en-us"
TIME_ZONE = "America/New_York"
USE_I18N = False
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "branding"]

# The single tenant this installation serves (instance-per-tenant). Set at provisioning.
TENANT_SLUG = os.environ.get("RMS_TENANT_SLUG", "rms")
