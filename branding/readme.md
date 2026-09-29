# Ross Machinery — Design System

**Ross Machinery Sales — Your Partner in Advanced Manufacturing Solutions.**

Ross Machinery Sales is an industrial-equipment dealer and service partner for the
**aerospace and advanced-manufacturing** sectors. They represent a curated roster of
world-class machine-tool builders and provide full-lifecycle support — sales &
consultation, maintenance & service, parts, and operator training. Connecticut-based
(+1.203.269.2950 · office@rossmachinery.com).

**Products / partners represented**
- **Fives Giddings & Lewis** (USA) — heavy-duty horizontal boring mills, machining & vertical turning centers
- **Mitsui Seiki** (Japan) — high-precision 4 & 5 axis machining centers, jig bores/grinders (5-year accuracy guarantee)
- **Breton** (Italy) — gantry-style machine tools for composites & aerospace alloys, large-format additive
- **Index** (Germany) — multi-spindle lathes & 5-axis turn-mill centers

Customers include **Sikorsky**, **Collins Aerospace**, and other precision-manufacturing firms.

> **Note on direction:** The owner *loves the logo* but is **not** happy with the current
> website and explicitly asked that it **not** drive future branding. This system is therefore
> grounded in the **logo** (navy / steel-blue / safety-yellow, geometric, industrial) and
> presents a **refreshed**, cleaner marketing UI — not a copy of the existing site's
> blurred-blob / skewed-block treatment.

---

## Sources used to build this system

- **GitHub (current site):** `1688ross/ross-machinery-solutions` (private) — a Lovable/Vite + React + shadcn + Tailwind build. We lifted the **brand color values**, **typography intent** (Rift display), **content/copy**, **product data**, and **photography** from here. Explore it for deeper context on the existing implementation.
  - Brand tokens came from `src/index.css`; product/services copy from `src/pages/Homepage.tsx`.
  - Photography & vendor logos imported from `src/assets/` → now in `assets/`.
- **Uploaded brand assets:** logo lockups (`RMS-LOGO_Website-Light/Dark.png`), mark/favicon, vector marks (`RMS-LOGO-02/04.svg`), business cards (`RMS-BizCardsPRINT.pdf`).

The reader is encouraged to explore the GitHub repo above to build richer, more accurate
designs against the live product.

---

## CONTENT FUNDAMENTALS — how Ross Machinery writes

- **Voice:** confident, technical, partnership-oriented. Speaks as **"we"** ("We work directly
  with world-renowned manufacturers…") and addresses the customer as **"you / your"**
  ("…for *your* specific aerospace needs"). Authoritative but not boastful.
- **Tone:** precision-engineering pride. Leans on concrete capability (axis counts, tolerances,
  guarantees, country of origin) over vague hype.
- **Casing:** Title Case for headings and nav; sentence case for body. Display headlines are
  frequently **UPPERCASE + italic** to echo the logo wordmark.
- **Signature phrasings:** "Your Partner in Advanced Manufacturing Solutions", "World-Class
  Manufacturing Partners", "Precision Engineered", "Uncompromising Quality", "Serving Aerospace
  & Advanced Manufacturing". A two-part heading device is common: a setup phrase + a
  **yellow-highlighted** payoff word ("Precision **Engineered**", "Innovation in **Motion**").
- **CTAs:** imperative and specific — "Request a Quote", "Explore Our Machines", "Request
  Consultation", "Get In Touch". Avoid generic "Learn more" where a stronger verb fits.
- **Emoji:** **never.** This is a B2B industrial brand. Iconography is line-icon only.
- **Numbers/specs:** embrace them — "4 & 5 axis", "±0.003 mm", "5-year accuracy guarantee",
  "+1.203.269.2950". Render technical specs in the **monospace** type.
- **Vibe:** heavy industry meets aerospace precision — clean, engineered, trustworthy.

---

## VISUAL FOUNDATIONS

- **Color:** Three brand colors straight from the logo — **navy `#003363`** (primary / authority),
  **steel-blue `#2576BC`** (secondary / links & accents), **safety-yellow `#FBB51C`** (accent,
  used *sparingly* for the single most important action and highlight words). A cool-tinted
  **steel-gray** neutral ramp carries surfaces, text and borders. Backgrounds are mostly white
  / `steel-50`; dark sections use **navy** (`--rms-navy` / `--rms-navy-900` / `-950`).
- **Type:** Display = **Saira Condensed** (athletic, semi-condensed industrial grotesque —
  our open substitute for the logo's *Rift*), used big, often **italic + uppercase**. Body =
  **Barlow** (humanist grotesque, highly legible). Technical specs & part numbers = **IBM Plex
  Mono**. Eyebrows are uppercase, tracked `0.14em`, with a leading yellow tick.
- **Spacing:** 4px base scale (`--space-1`…`--space-10`). Generous section padding (~76px).
  Content max-width 1200px.
- **Backgrounds:** real **photography** of machines/machining (warm-neutral, industrial, *not*
  graded blue), often with a navy gradient scrim for text legibility. Subtle **world-map**
  texture at ~8% opacity behind the hero. **No** decorative blurred gradient blobs, **no** skewed
  color blocks (a deliberate departure from the old site).
- **Animation:** purposeful and mechanical — short fades / 1px lifts on `--ease-standard`
  (cubic-bezier(.2,0,.1,1)), `140–220ms`. **No bounce, no float loops.**
- **Hover states:** buttons darken to the `-hover` token + lift 1px; cards lift 3px with an
  elevated cool shadow; nav links reveal a yellow underline.
- **Press / active:** settle back to translateY(0); rely on the darkened fill for feedback.
- **Borders:** 1px `--border-subtle` hairlines; 2px for strong/emphasis. Buttons use a 2px border
  matching their fill so outline/solid variants align optically.
- **Signature device:** the **3px yellow keyline** (`--edge-accent`) on the top edge of feature
  cards and modals.
- **Shadows:** cool-tinted, restrained (`--shadow-xs`…`-lg`); hover cards use a navy-tinted
  `--shadow-card-hover`. Industrial, grounded — never floaty.
- **Corner radius:** small & mechanical — **4px** default (`--radius-md`), 8px max for large
  surfaces; **pill** reserved for badges/chips. The brand reads square.
- **Cards:** white surface, 1px subtle border, 4px radius, `--shadow-sm`; optional yellow
  accent edge; hover lifts.
- **Transparency / blur:** used only for image scrims (navy gradients over photos) and the modal
  backdrop (`rgba(15,20,27,.6)`). No glassmorphism.
- **Imagery vibe:** real CNC / machining / shop-floor photography, warm-neutral and crisp.

---

## ICONOGRAPHY

- The codebase uses **Lucide** (`lucide-react`) line icons throughout. This system keeps that:
  `ui_kits/website/icons.jsx` provides a **Lucide-style** set (24×24, 2px stroke, round caps) —
  `ArrowRight, Phone, Mail, Cog, Wrench, Shield, Users, CheckCircle, Quote, MapPin, Globe, Gauge,
  Menu, X`. For new work, pull additional icons from **Lucide** (https://lucide.dev) to stay
  consistent (2px stroke, no fill).
- **No emoji.** **No** unicode-glyph icons. **No** multi-color/duotone icon styles.
- Icons are monochrome and inherit `currentColor` — typically `--rms-blue` inside tinted chips,
  navy on light, white on dark.
- **Logo / mark:** `assets/logos/` holds the full-color lockup, white (reversed) lockup, the
  raster mark, and a **corrected vector mark** (`rms-mark.svg`) with the brand fills restored
  (the uploaded SVGs shipped without their fill definitions — fixed here).

---

## INDEX / MANIFEST

**Root**
- `styles.css` — global entry (import this one file). `@import`s the token files only.
- `readme.md` — this guide.
- `SKILL.md` — Agent-Skills-compatible front-matter for use in Claude Code.

**`tokens/`** — `fonts.css` · `colors.css` · `typography.css` · `spacing.css`

**`assets/`**
- `logos/` — `rms-logo-color.png`, `rms-logo-white.png`, `rms-mark.png`, `rms-mark.svg`
- `images/` — machining / quality / innovation / hero photography, `world-map.png`
- `vendors/` — partner logos (Fives, Mitsui Seiki, Breton, Index, Sikorsky)

**`guidelines/foundations/`** — specimen cards (Colors, Type, Spacing, Brand) shown in the Design System tab.

**`components/core/`** — reusable primitives (each `.jsx` + `.d.ts` + `.prompt.md`):
- `Button` · `Badge` · `Card` · `Input` · `Eyebrow` · `SpecList`
- `core.card.html` — combined showcase card.

**`ui_kits/website/`** — refreshed marketing homepage (recreation/refresh of the live site):
- `index.html` (interactive) · `Sections.jsx` · `icons.jsx` · `README.md`

> Components are reachable at runtime as `window.RossMachineryDesignSystem_610e0e.<Name>`.
