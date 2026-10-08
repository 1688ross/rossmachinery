# Ross Machinery Quote Generator

The office's quote form as a static website: fill in the form, watch the Letter-size preview,
download a branded PDF. Everything runs in the browser. No server, no database, no account.

- `index.html` — the whole app (form, preview, PDF builder).
- `lib/pdfmake.min.js` — pdfmake 0.2.20 (MIT), with the raw control bytes inside its string
  literals rewritten as `\xNN` escapes so publishers accept the file. Behaviour is unchanged.
- `fonts/rms-fonts.js` — the brand fonts (Barlow, IBM Plex Mono, Saira Condensed; OFL) as
  base64 TTFs, embedded in every PDF. Sources: `../branding/assets/fonts/`.
- `middleware.js` — optional office passcode gate (see below).
- `vercel.json` — security headers and caching.
- `favicon.svg`, `icon-512.png`, `manifest.webmanifest` — icon and "install as app" support.

Quotes a person works on are kept in their own browser (localStorage) and listed under
"Recent quotes". Nothing is sent anywhere. Quote numbers (`SA` + yymm + 001, 002, …) are
therefore per computer; the number field is editable.

## Deploy to Vercel

### Option A — Vercel dashboard (no tools needed)

1. Push this folder's contents to a GitHub repository (for example `rms-quote-generator`),
   with `index.html` at the top level of the repo.
2. In Vercel: **Add New… → Project → Import** that repository.
3. Leave **Framework Preset** on **Other**. Leave Build Command and Output Directory empty.
   If the files live in a subfolder of the repo instead, set **Root Directory** to that folder.
4. Click **Deploy**. The site is live at `https://<project>.vercel.app` in about a minute.

### Option B — Vercel CLI (from VS Code or a terminal)

```bash
npm i -g vercel
cd quote-generator
vercel login
vercel --prod
```

Accept the defaults when asked (no framework, no build command, output directory `.`).

### Which Vercel plan

Vercel's free **Hobby** plan is licensed for personal, non-commercial use, and a quoting tool for
a business counts as commercial. Put the project on a **Pro** team (one seat is enough). Pro also
lifts a Hobby limitation that matters here: on Hobby, a push only deploys when the commit's author
is the GitHub account connected to Vercel, so commits made by anyone else (including commits
Claude authored) are silently ignored.

### Office passcode (recommended)

Without a passcode the page is open to anyone who has the address. To require one:

1. Vercel → the project → **Settings → Environment Variables**.
2. Add `QUOTE_PASSCODE`, at least 12 characters (three unrelated words work well). Apply it to
   **Production and Preview**.
3. **Redeploy** (Deployments → ⋯ on the latest → Redeploy). Environment variables only take
   effect on a new deployment.
4. Check it: open the site in a private/incognito window. You must see the "Office passcode"
   page. If the quote form appears instead, the passcode is not active (wrong variable name,
   not applied to this environment, or not redeployed).

Visitors then see the passcode page once; a cookie keeps them signed in for 180 days on that
browser. Changing the passcode signs everyone out. A passcode shorter than 12 characters is
refused and the site shows a short "fix the passcode" notice until it is corrected. A wrong
guess is answered after a 1.5 second pause; there is no lockout beyond that, which is why the
length minimum exists.

### Custom address (optional)

Vercel → the project → **Settings → Domains** → add `quotes.rossmachinery.com`, then create
the CNAME record Vercel shows at the DNS host for rossmachinery.com.

## Updating

Edit `index.html`, commit, push. Vercel redeploys from the connected repository (on Hobby, only
for commits authored by the connected GitHub account; see "Which Vercel plan"). If you change
`lib/` or `fonts/`, people who used the page in the last few minutes may need a normal reload.
The platform's own quote document (`../quotes/templates/quotes/document.html`) is kept in step
with this page by hand.
