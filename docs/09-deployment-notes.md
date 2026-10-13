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
  after each miss). To reset someone who lost both phone and codes: an administrator deletes
  their TOTP device and static device in the Django admin, and they enrol again at their next
  sign-in. The dev seed gives every dev user a known authenticator key except `ross`, who goes
  through first-time setup.
