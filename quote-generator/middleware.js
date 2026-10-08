// Vercel Edge Middleware: an optional passcode gate for the whole site.
// Set QUOTE_PASSCODE in Vercel (Project → Settings → Environment Variables) and redeploy.
// With no passcode set, the site is open. Changing the passcode signs everyone out.
// A passcode shorter than 12 characters is refused (the site answers 503 until it is fixed).
export const config = { matcher: '/:path*' };

const COOKIE = 'rms_quotes';
const OPEN_PATHS = new Set(['/favicon.svg', '/icon-512.png', '/manifest.webmanifest']);
const COOKIE_DAYS = 180;
const MIN_LEN = 12;
const WRONG_GUESS_DELAY_MS = 1500;

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function readCookie(req) {
  const header = req.headers.get('cookie') || '';
  const match = header.match(new RegExp('(?:^|;\\s*)' + COOKIE + '=([a-f0-9]{64})'));
  return match ? match[1] : null;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function unlockPage(error) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow">
<title>Ross Machinery Quote Generator</title>
<style>
:root{color-scheme:light}
body{margin:0;min-height:100vh;display:flex;flex-direction:column;background:#f5f7fa;color:#28303b;font:16px/1.5 Barlow,system-ui,-apple-system,"Segoe UI",sans-serif}
.bar{background:#003363;color:#fff;padding:12px 20px;display:flex;align-items:center;gap:12px;box-shadow:0 2px 0 #fbb51c}
.bar svg{width:36px;height:36px}
.bar strong{font-style:italic;text-transform:uppercase;letter-spacing:.04em;font-size:1.1rem}
main{flex:1;display:grid;place-items:center;padding:32px 16px}
form{background:#fff;border:1px solid #dce2ea;border-top:3px solid #fbb51c;border-radius:4px;padding:24px;width:min(100%,360px);display:flex;flex-direction:column;gap:12px}
h1{margin:0;font-size:1.1rem;font-weight:600;color:#003363}
p{margin:0;color:#515d6b;font-size:.95rem}
label{font-size:.85rem;font-weight:600;color:#515d6b;display:flex;flex-direction:column;gap:4px}
input{font:inherit;padding:9px 10px;border:1px solid #c2cbd6;border-radius:4px}
input:focus-visible{outline:2px solid #2576bc;outline-offset:2px}
button{font:inherit;font-weight:600;padding:10px 16px;border:0;border-radius:4px;background:#fbb51c;color:#003363;cursor:pointer}
button:hover{background:#e0a015}
.err{color:#c2392b;font-size:.9rem}
</style></head>
<body>
<div class="bar"><svg viewBox="0 0 800 800" aria-hidden="true"><polygon fill="#2576BC" points="559.12,313.95 437.88,141.92 675.64,141.92 796.87,313.9"/><polygon fill="#003363" points="800,314.21 559.12,314.21 437.88,486.24 198.52,486.24 319.46,314.21 2.44,314.21 123.68,142.18 440.69,142.18 319.46,314.21 559.12,314.21"/><polygon fill="#FBB51C" points="0,657.82 437.88,657.82 559.12,485.79 121.24,485.79"/></svg><strong>Quote Generator</strong></div>
<main><form method="post" action="/unlock">
<h1>Office passcode</h1>
<p>This page is for Ross Machinery Sales staff. Enter the office passcode to continue.</p>
<label>Passcode<input type="password" name="passcode" autocomplete="current-password" autofocus required></label>
${error ? '<div class="err">That passcode did not match. Try again.</div>' : ''}
<button type="submit">Continue</button>
</form></main>
</body></html>`;
}

function redirect(to) {
  return new Response(null, { status: 303, headers: { location: to, 'cache-control': 'no-store' } });
}

function configPage() {
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Quote Generator</title></head><body style="font:16px system-ui;padding:32px;max-width:560px"><h1 style="font-size:1.2rem">Passcode too short</h1><p>QUOTE_PASSCODE must be at least ' + MIN_LEN + ' characters. Change it in Vercel &rarr; Settings &rarr; Environment Variables, then redeploy.</p></body></html>';
}

function htmlResponse(body, status) {
  return new Response(body, { status, headers: {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'x-robots-tag': 'noindex, nofollow',
    'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  } });
}

export default async function middleware(req) {
  const passcode = process.env.QUOTE_PASSCODE;
  if (!passcode) return; // no passcode configured: serve the site as-is
  if (passcode.length < MIN_LEN) return htmlResponse(configPage(), 503);
  const url = new URL(req.url);
  if (OPEN_PATHS.has(url.pathname)) return;
  if (url.pathname === '/unlock' && req.method !== 'POST') return redirect('/');

  const expected = await sha256Hex('rms-quotes-v1:' + passcode);
  if (readCookie(req) === expected) return url.pathname === '/unlock' ? redirect('/') : undefined; // signed in

  if (url.pathname === '/unlock' && req.method === 'POST') {
    let given = '';
    try { given = String((await req.formData()).get('passcode') || ''); } catch (e) { given = ''; }
    const ok = given.length > 0 && (await sha256Hex('rms-quotes-v1:' + given)) === expected;
    if (!ok) { await new Promise((r) => setTimeout(r, WRONG_GUESS_DELAY_MS)); return redirect('/?retry=1'); }
    return new Response(null, { status: 303, headers: {
      location: '/',
      'set-cookie': COOKIE + '=' + expected + '; Path=/; Max-Age=' + (COOKIE_DAYS * 86400) + '; HttpOnly; Secure; SameSite=Lax',
    } });
  }
  return htmlResponse(unlockPage(url.searchParams.get('retry') === '1'), 401);
}
