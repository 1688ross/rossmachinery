# Deployment notes (collected as the build goes; the install guide grows from this)

- **Document store.** Filed documents live on the server's disk under `RMS_DOCUMENT_ROOT`
  (default `var/documents` next to the code). Content-addressed by SHA-256 per tenant; the
  first page is rendered to PNG beside each file. Back this directory up with the database;
  one without the other is incomplete.
- **Upload size.** The app refuses anything over 25 MB before reading it, but only when the
  browser sends a Content-Length. The front server must also cap request bodies so a chunked
  upload cannot stream past it: nginx `client_max_body_size 26m;`, IIS
  `maxAllowedContentLength`. Do this at install time.
- **Preview rendering** runs inside the upload request today, bounded to 1000 x 1500 pixels
  and 40 megapixels of source image. Fine for an office. If uploads ever come in bulk (the
  email reader), move rendering to a queued job that fills `documents.thumbnail_key`
  afterwards; `core.db.set_document_thumbnail` already exists for that.
- **Served files** go out with `Content-Security-Policy: default-src 'none'; sandbox` and
  `X-Content-Type-Options: nosniff`, inline for PDF, PNG and JPEG only.
- **Database roles.** The app connects as the runtime role only (`po_api`, a member of
  `app_user`, no BYPASSRLS). Migrations run as a superuser (they `SET LOCAL ROLE app_owner`
  and attach the audit trigger as the superuser). `schema/tests/run_tests.sh` is the gate
  before any migration reaches the office server.
- **Second factor.** Every account signs in with a password and a six-digit code from an
  authenticator app; eight one-time backup codes are issued at enrolment. `RMS_REQUIRE_2FA=0`
  switches it off for a throwaway dev box only. Wrong codes are throttled (the wait doubles
  after each miss). Replacing the phone or making new backup codes asks for the password again.
  To reset someone who lost both phone and codes, the administrator runs
  `docker compose exec app python manage.py reset_2fa <username>` (or deletes their devices in
  the Django admin, where secrets are hidden); they enrol again at their next sign-in. The office
  administrator account is made once with `docker compose exec app python manage.py createsuperuser`.
  The container refuses to start with the second factor off unless it is a demo (`RMS_SEED_DEMO=1`)
  or `RMS_ALLOW_NO_2FA=1` is set deliberately.
- **Sample logins.** `seed_dev_users` only runs with `RMS_SEED_DEMO=1`. It prints each sample
  user's authenticator key and backup codes once; nothing about them is derived from the code.
