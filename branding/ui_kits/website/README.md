# Website UI Kit — Ross Machinery

A **refreshed** marketing homepage for Ross Machinery Sales. This is a brand-grounded
improvement on the existing site (per the owner's request to move away from the current
design while keeping the logo and brand colors), not a 1:1 clone of the live Lovable build.

## Files
- `index.html` — interactive homepage. Loads `styles.css`, the compiled `_ds_bundle.js`,
  then `icons.jsx` and `Sections.jsx`.
- `Sections.jsx` — all page sections (`Header, Hero, TrustBar, Stats, Machines, MediaBand,
  Services, CTA, Footer, QuoteModal`), exported on `window.RmsSite`.
- `icons.jsx` — Lucide-style icon set on `window.RmsIcons`.

## Composes design-system primitives
`Button`, `Badge`, `Card`, `Eyebrow`, `SpecList`, `Input` are pulled from the bundle
(`window.RossMachineryDesignSystem_610e0e`) — the kit does not re-implement them.

## Interactions
- **Request a Quote / Consultation** (header, hero, machine cards, CTA) opens a modal form
  with a success state.
- Each machine card toggles a monospace **SpecList** via *View specs*.
- Nav shows the active-item yellow underline.

## Sections covered
Top contact bar · sticky header · split navy hero w/ world-map texture · trust bar ·
stats band · partners grid (Fives, Mitsui Seiki, Breton, Index) · full-bleed media band ·
services grid · navy CTA · footer.

## Notes
- Built for desktop (~1280px). Mobile breakpoints are not implemented in this recreation.
- Photography and partner logos are the real assets from `assets/`.
