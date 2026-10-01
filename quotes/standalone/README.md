# Standalone quote generator (browser-only)

The office's quote form as a single page that runs entirely in the browser: fill in the form,
watch the Letter-size preview, and download a vector PDF built client-side with pdfmake using
the brand fonts (Barlow, IBM Plex Mono, Saira Condensed) embedded from `fonts/rms-fonts.js`.

- `index.html` is the page as published to claude.ai (the publisher wraps it in the document
  skeleton and adds the `<head>`). Open it locally in a browser for the same thing; the
  download then uses a plain link instead of the claude.ai download prompt.
- `lib/pdfmake.min.js` is pdfmake 0.2.20 (MIT) with raw control bytes inside its string
  literals rewritten as `\xNN` escapes so the publisher accepts it. Behaviour is unchanged.
- `fonts/rms-fonts.js` is the seven TTFs under `branding/assets/fonts/` as base64 (OFL).
- Quotes are kept in the browser's localStorage only. Nothing is sent anywhere. Quote
  numbers (`SA` + yymm + 3 digits) are therefore per computer until the platform takes over.

The platform version lives in `quotes/` (Django): same fields, server-side PDF via headless
Chromium, and the quote becomes the start of a folder.
