/* @ds-bundle: {"format":4,"namespace":"RossMachineryDesignSystem_610e0e","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Eyebrow","sourcePath":"components/core/Eyebrow.jsx"},{"name":"Input","sourcePath":"components/core/Input.jsx"},{"name":"SpecList","sourcePath":"components/core/SpecList.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"2d09635dbd92","components/core/Button.jsx":"729165a26d32","components/core/Card.jsx":"77975f4ccd95","components/core/Eyebrow.jsx":"602dc2b8608c","components/core/Input.jsx":"1cf42f1f0274","components/core/SpecList.jsx":"1c0601e6c172","guidelines/email-signatures/doc-page.js":"f52ae9c02fca","ui_kits/concepts/Finder.jsx":"52fdde12f932","ui_kits/concepts/Showroom.jsx":"53ac38952864","ui_kits/concepts/icons.jsx":"16bc2a14f1ef","ui_kits/concepts/shared.jsx":"044dd09a5270","ui_kits/website/Sections.jsx":"7f320f2d6f95","ui_kits/website/icons.jsx":"16bc2a14f1ef"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.RossMachineryDesignSystem_610e0e = window.RossMachineryDesignSystem_610e0e || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  navy: {
    solid: ['var(--rms-navy)', '#fff'],
    soft: ['var(--blue-100, #dcebf7)', 'var(--rms-navy)']
  },
  blue: {
    solid: ['var(--rms-blue)', '#fff'],
    soft: ['var(--rms-blue-100)', 'var(--rms-blue-700)']
  },
  yellow: {
    solid: ['var(--rms-yellow)', 'var(--rms-navy)'],
    soft: ['var(--rms-yellow-100)', 'var(--rms-yellow-700)']
  },
  neutral: {
    solid: ['var(--steel-700)', '#fff'],
    soft: ['var(--steel-100)', 'var(--steel-700)']
  },
  success: {
    solid: ['var(--status-success)', '#fff'],
    soft: ['#dcefe4', 'var(--status-success)']
  },
  danger: {
    solid: ['var(--status-danger)', '#fff'],
    soft: ['#f6ddda', 'var(--status-danger)']
  }
};

/**
 * Compact status / category label.
 */
function Badge({
  children,
  tone = 'blue',
  variant = 'soft',
  style = {},
  ...rest
}) {
  const t = TONES[tone] || TONES.blue;
  const [bg, fg] = variant === 'solid' ? t.solid : t.soft;
  const isOutline = variant === 'outline';
  const composed = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
    fontFamily: 'var(--font-body)',
    fontWeight: 600,
    fontSize: '12px',
    lineHeight: 1,
    letterSpacing: '0.02em',
    padding: '5px 10px',
    borderRadius: 'var(--radius-pill)',
    background: isOutline ? 'transparent' : bg,
    color: isOutline ? 'var(--rms-navy)' : fg,
    border: isOutline ? '1px solid var(--border-default)' : '1px solid transparent',
    whiteSpace: 'nowrap',
    ...style
  };
  return /*#__PURE__*/React.createElement("span", _extends({
    style: composed
  }, rest), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  useState
} = React;
const SIZES = {
  sm: {
    padding: '7px 14px',
    fontSize: '13px',
    gap: '6px'
  },
  md: {
    padding: '11px 20px',
    fontSize: '15px',
    gap: '8px'
  },
  lg: {
    padding: '15px 28px',
    fontSize: '17px',
    gap: '10px'
  }
};
const VARIANTS = {
  primary: {
    base: {
      background: 'var(--action-primary)',
      color: 'var(--action-primary-text)',
      border: '2px solid var(--action-primary)'
    },
    hover: {
      background: 'var(--action-primary-hover)',
      borderColor: 'var(--action-primary-hover)'
    }
  },
  secondary: {
    base: {
      background: 'var(--action-secondary)',
      color: 'var(--action-secondary-text)',
      border: '2px solid var(--action-secondary)'
    },
    hover: {
      background: 'var(--action-secondary-hover)',
      borderColor: 'var(--action-secondary-hover)'
    }
  },
  accent: {
    base: {
      background: 'var(--action-accent)',
      color: 'var(--action-accent-text)',
      border: '2px solid var(--action-accent)'
    },
    hover: {
      background: 'var(--action-accent-hover)',
      borderColor: 'var(--action-accent-hover)'
    }
  },
  outline: {
    base: {
      background: 'transparent',
      color: 'var(--rms-navy)',
      border: '2px solid var(--border-default)'
    },
    hover: {
      borderColor: 'var(--rms-navy)',
      background: 'var(--steel-50)'
    }
  },
  ghost: {
    base: {
      background: 'transparent',
      color: 'var(--rms-navy)',
      border: '2px solid transparent'
    },
    hover: {
      background: 'var(--steel-100)'
    }
  }
};

/**
 * Ross Machinery primary action button.
 */
function Button({
  children,
  variant = 'primary',
  size = 'md',
  iconLeft = null,
  iconRight = null,
  disabled = false,
  type = 'button',
  onClick,
  style = {},
  ...rest
}) {
  const [hover, setHover] = useState(false);
  const v = VARIANTS[variant] || VARIANTS.primary;
  const s = SIZES[size] || SIZES.md;
  const composed = {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: s.gap,
    fontFamily: 'var(--font-body)',
    fontWeight: 600,
    fontSize: s.fontSize,
    lineHeight: 1,
    padding: s.padding,
    borderRadius: 'var(--radius-md)',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.45 : 1,
    textDecoration: 'none',
    whiteSpace: 'nowrap',
    transition: 'background var(--dur-fast) var(--ease-standard), border-color var(--dur-fast) var(--ease-standard), transform var(--dur-fast) var(--ease-standard)',
    transform: hover && !disabled ? 'translateY(-1px)' : 'translateY(0)',
    ...v.base,
    ...(hover && !disabled ? v.hover : {}),
    ...style
  };
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: composed
  }, rest), iconLeft, children, iconRight);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  useState
} = React;
/**
 * Surface container. Optional yellow accent edge and hover lift.
 */
function Card({
  children,
  accentEdge = false,
  interactive = false,
  padding = 'var(--space-5)',
  style = {},
  ...rest
}) {
  const [hover, setHover] = useState(false);
  const composed = {
    background: 'var(--surface-card)',
    border: '1px solid var(--border-subtle)',
    borderTop: accentEdge ? 'var(--edge-accent)' : '1px solid var(--border-subtle)',
    borderRadius: 'var(--radius-md)',
    padding,
    boxShadow: interactive && hover ? 'var(--shadow-card-hover)' : 'var(--shadow-sm)',
    transform: interactive && hover ? 'translateY(-3px)' : 'translateY(0)',
    transition: 'box-shadow var(--dur-base) var(--ease-standard), transform var(--dur-base) var(--ease-standard)',
    ...style
  };
  return /*#__PURE__*/React.createElement("div", _extends({
    style: composed,
    onMouseEnter: interactive ? () => setHover(true) : undefined,
    onMouseLeave: interactive ? () => setHover(false) : undefined
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Eyebrow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Uppercase tracked label used above headings. Optional yellow tick.
 */
function Eyebrow({
  children,
  tick = true,
  color = 'var(--rms-blue)',
  style = {},
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '10px',
      fontFamily: 'var(--font-body)',
      fontWeight: 600,
      fontSize: '13px',
      textTransform: 'uppercase',
      letterSpacing: '0.14em',
      color,
      ...style
    }
  }, rest), tick && /*#__PURE__*/React.createElement("span", {
    style: {
      width: '22px',
      height: '3px',
      background: 'var(--rms-yellow)',
      display: 'inline-block'
    }
  }), children);
}
Object.assign(__ds_scope, { Eyebrow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Eyebrow.jsx", error: String((e && e.message) || e) }); }

// components/core/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  useState
} = React;
/**
 * Labelled text input / textarea.
 */
function Input({
  label,
  hint,
  error,
  type = 'text',
  multiline = false,
  required = false,
  id,
  style = {},
  ...rest
}) {
  const [focus, setFocus] = useState(false);
  const fieldId = id || (label ? `f-${label.replace(/\s+/g, '-').toLowerCase()}` : undefined);
  const fieldStyle = {
    width: '100%',
    boxSizing: 'border-box',
    fontFamily: 'var(--font-body)',
    fontSize: '15px',
    color: 'var(--rms-navy)',
    background: 'var(--white)',
    padding: '11px 13px',
    border: `1px solid ${error ? 'var(--status-danger)' : focus ? 'var(--focus-ring)' : 'var(--border-default)'}`,
    borderRadius: 'var(--radius-md)',
    outline: 'none',
    boxShadow: focus ? '0 0 0 3px rgba(37,118,188,0.18)' : 'none',
    transition: 'border-color var(--dur-fast) var(--ease-standard), box-shadow var(--dur-fast) var(--ease-standard)',
    resize: multiline ? 'vertical' : undefined,
    minHeight: multiline ? '96px' : undefined,
    ...style
  };
  const Tag = multiline ? 'textarea' : 'input';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '6px'
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: fieldId,
    style: {
      fontFamily: 'var(--font-body)',
      fontWeight: 600,
      fontSize: '13px',
      color: 'var(--rms-navy)'
    }
  }, label, required && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--status-danger)',
      marginLeft: 2
    }
  }, "*")), /*#__PURE__*/React.createElement(Tag, _extends({
    id: fieldId,
    type: multiline ? undefined : type,
    required: required,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: fieldStyle
  }, rest)), (hint || error) && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-body)',
      fontSize: '12px',
      color: error ? 'var(--status-danger)' : 'var(--text-muted)'
    }
  }, error || hint));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Input.jsx", error: String((e && e.message) || e) }); }

// components/core/SpecList.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Monospaced spec sheet — key/value rows for machine specifications.
 * items: [{ label, value }]
 */
function SpecList({
  items = [],
  style = {},
  ...rest
}) {
  return /*#__PURE__*/React.createElement("dl", _extends({
    style: {
      margin: 0,
      ...style
    }
  }, rest), items.map((it, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline',
      gap: '16px',
      padding: '11px 0',
      borderBottom: i === items.length - 1 ? 'none' : '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement("dt", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: '12px',
      fontWeight: 600,
      letterSpacing: '0.04em',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, it.label), /*#__PURE__*/React.createElement("dd", {
    style: {
      margin: 0,
      fontFamily: 'var(--font-mono)',
      fontSize: '14px',
      fontWeight: 500,
      color: 'var(--rms-navy)',
      textAlign: 'right'
    }
  }, it.value))));
}
Object.assign(__ds_scope, { SpecList });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SpecList.jsx", error: String((e && e.message) || e) }); }

// guidelines/email-signatures/doc-page.js
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)
// Copied omelette starter. Re-running copy_starter_component with this kind overwrites this file with the latest version (page content is unaffected).
/* BEGIN USAGE */
/**
 * <doc-page> — paged-document shell for printable HTML.
 *
 * FIRST, decide how the document paginates — up front, before building:
 *
 * - FLOWING document (the default): write the whole document as one
 *   normal HTML flow inside <doc-page>; the browser's print engine
 *   splits it onto pages at export. Use for long-form documents with a
 *   single text flow: reports, memos, letters, essays.
 * - EXPLICIT pagination: a fixed set of pre-paginated pages, one
 *   <section class="page"> child per page. Use when the user asks for a
 *   specific page count, or the design implies one: a one-page resume, a
 *   two-sided flier, a poster, a certificate, a brochure — any richly
 *   laid-out document without a single text flow.
 * - If in doubt, ask the user as part of the build.
 *
 * PAGE SIZING — paper differs by country (letter vs A4), so the printed
 * sheet is not one fixed truth:
 * - FLOWING documents pin NO paper size: the print engine paginates
 *   onto the user's real paper, and the content reflows to it.
 * - EXPLICITLY PAGINATED documents print each page at a FIXED page box
 *   with overflow hidden — letter by default, size="a4" for a clearly
 *   metric user, the user's chosen paper when they export. Design each
 *   page to FILL that box, fitting letter and A4 alike without overlap.
 * - width/height pin an explicit fixed size, ONLY when the user gives
 *   one.
 * Never write your own @page rule or hard-code paper dimensions in the
 * content.
 *
 * Sizing modes (attributes):
 *   (none)                      — portrait: flowing docs use the user's
 *           paper; explicitly paginated pages use the named size box
 *           (letter unless size="a4")
 *   orientation="landscape"     — the same, landscape
 *   width / height              — explicit fixed size, ONLY when the user
 *           gives one (e.g. width="22in" height="30in" for a 22×30
 *           poster): the page IS the design's size, printed at true
 *           dimensions (or scaled onto the user's paper at print time).
 *           Any absolute CSS length: px/in/mm/cm/pt/pc.
 * The component announces the chosen mode to the host app at runtime (a
 * meta tag it injects), so the print path can inject the user's true
 * paper size.
 *
 * On screen the document renders on a desk background: a flowing
 * document as one tall scrolling sheet (Google Docs' pageless view);
 * explicitly paginated documents as one card per page.
 *
 * EXPLICIT pagination usage:
 *   <style>doc-page:not(:defined){visibility:hidden}</style>
 *   <doc-page>
 *     <section class="page" id="p1">…one page's design…</section>
 *     <section class="page" id="p2">…</section>
 *   </doc-page>
 *   <script src="doc-page.js"></script>
 * How the page box works, concretely: each .page prints as ONE full-bleed
 * sheet at a FIXED physical size — letter by default (set size="a4" for
 * a clearly metric user), the user's chosen paper when they export —
 * with overflow hidden. Nothing scrolls and nothing reflows onto a next
 * sheet: content that misses the box is CLIPPED. Design each page to
 * FILL that page box, and to fit it — letter and A4 alike — without
 * overlap. Each page is a size container; don't size anything in
 * viewport units (they track the window, not the page), and never set
 * width or height on the .page section itself (the component sizes the
 * page box; an authored height like 100% is meaningless at print and is
 * overridden). The component owns the page box, the screen card chrome,
 * and the page breaks (never add your own break-before/after). Don't mix
 * .page sections with flowing content or header/footer slots in the same
 * document.
 *
 * FLOWING usage:
 *   <style>doc-page:not(:defined){visibility:hidden}</style>
 *   <doc-page margin="0.75in">
 *     <h1>Title</h1>
 *     <p>…body…</p>
 *   </doc-page>
 *   <script src="doc-page.js"></script>
 * There is no manual page-splitting — the browser's print engine
 * paginates at export. Standard break-hygiene rules (`break-inside:
 * avoid` on figures, code blocks, images and table rows; `orphans/
 * widows: 3`) are applied so paragraphs and groups split cleanly. On
 * screen and at print, headings default to `text-wrap: balance` and
 * body text to `text-wrap: pretty`; the defaults have zero specificity,
 * so any text-wrap you declare wins.
 *
 * Other attributes:
 *   size    — letter | a4 | legal (default letter). Flowing documents:
 *           preview proportion only — it does NOT pin their printed
 *           paper (the print dialog's paper governs); leave it alone
 *           there. Explicitly paginated documents: it sets the page box
 *           the cards and the pinned @page share (the export dialog's
 *           choice overrides both at print) — set size="a4" for a
 *           clearly metric user. Scaled-fit: names the sheet the fit is
 *           computed against, same a4-for-metric-users advice.
 *   content-width / content-height — the design's own fixed dimensions
 *           (CSS lengths), for scaling a fixed-size design ONTO the
 *           named sheet: content lays out at exactly this size, and the
 *           component scales it to fit that sheet's printable area
 *           (centered horizontally, top-aligned; the export dialog
 *           re-fits to the user's actual paper choice where available).
 *           Both must be set; they do not change the page box. For pages
 *           WITHOUT running header/footer slots.
 *   margin  — printable inset on every page of a FLOWING document
 *           (default 0.75in); margin="0" makes pages full-bleed.
 *           Explicitly paginated pages are always full-bleed.
 *
 * Running header/footer (flowing documents only): give an element
 * `slot="header"` or `slot="footer"` and it repeats on every printed
 * page via `position: fixed`. To keep body text from sliding under it,
 * the component prints inside a single-cell table whose <thead>/<tfoot>
 * are spacers sized to the header/footer height — browsers repeat
 * thead/tfoot on every page, so each sheet's content starts below the
 * header and ends above the footer. On screen the header/footer render
 * once at the top/bottom of the sheet.
 *
 * At print the component injects `@page { margin: 0 }` (which leaves
 * Chrome no margin box to draw its date/URL/page-count header in) and
 * moves the visual margin onto the sheet's own padding. It also marks
 * the document as owning its print CSS (a
 * `meta[name="omelette-owns-print"]` it injects at runtime), so the
 * PDF export never injects page-geometry CSS of its own on top.
 *
 * Print best practices for the content you author:
 * - Multi-column text: use CSS columns (`column-count` +
 *   `column-gap`), never side-by-side flex/grid columns — only real
 *   CSS columns flow and break across pages. `column-span: all` lets
 *   a heading span the columns; `hyphens: auto` (needs `lang` on
 *   the html element) keeps narrow columns readable.
 * - Page breaks in flowing documents: `break-before: page` on an
 *   element that must start a new page (a chapter, an appendix). Add
 *   your own kept-together blocks (callouts, stat tiles, cards) to a
 *   `break-inside: avoid` rule, and keep each one shorter than a page.
 * - Extend `orphans: 3; widows: 3` to any custom text blocks you add
 *   (p and li are covered by default).
 * - Give long tables a <thead> — browsers repeat it on every printed
 *   page.
 * - No `position: fixed`/`sticky` and no viewport units in content:
 *   fixed elements stamp every printed page (running headers/footers go
 *   in the component's slots) and `100vh` mis-sizes at print.
 *
 * Author content as static HTML so the user can click-to-edit any text
 * directly. Do not set width/padding/background on the document body —
 * the component owns the sheet box.
 */
/* END USAGE */

(() => {
  const PAPER = {
    letter: ['8.5in', '11in'],
    a4: ['210mm', '297mm'],
    legal: ['8.5in', '14in']
  };
  const CSS_LENGTH = /^\d+(\.\d+)?(px|in|mm|cm|pt|pc)$/;
  // Unitless "0" is a valid CSS length and the natural way to write
  // margin="0"; normalise it to 0px so max()/calc() (which reject a bare
  // number) keep working.
  const safeLen = (v, fb) => {
    v = (v || '').trim();
    return v === '0' ? '0px' : CSS_LENGTH.test(v) ? v : fb;
  };
  // WebKit (Safari and every iOS browser shell) never repeats a table's
  // thead/tfoot on printed pages (WebKit bug 17205), so the spacer-borne
  // vertical margins of a FLOWING document reach only the first page
  // there. Engine check, not browser check: vendor is 'Apple Computer,
  // Inc.' exactly for WebKit and 'Google Inc.' for Blink.
  const WK_PRINT = /apple/i.test(navigator.vendor || '');
  // CSS length → px number (CSS absolute units are exact: 1in = 96px).
  // Returns NaN for anything safeLen would reject — callers gate on it.
  const PX_PER = {
    px: 1,
    in: 96,
    mm: 96 / 25.4,
    cm: 96 / 2.54,
    pt: 96 / 72,
    pc: 16
  };
  const toPx = v => {
    const m = /^(\d+(?:\.\d+)?)(px|in|mm|cm|pt|pc)$/.exec((v || '').trim());
    return m ? parseFloat(m[1]) * PX_PER[m[2]] : NaN;
  };
  const stylesheet = `
    :host {
      position: relative;
      display: block;
      /* When the viewport is narrower than the page, grow to wrap the
       * sheet (plus this padding) instead of staying viewport-width, so
       * the desk background and right margin reach the sheet's far edge
       * in the horizontal scroll. */
      min-width: max-content;
      min-height: 100vh;
      background: #f5f5f4;
      padding: 48px 24px;
      box-sizing: border-box;
      font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
      --doc-page-w: 8.5in;
      --doc-page-h: 11in;
      --doc-page-margin: 0.75in;
      --doc-hdr-h: 0px;
      --doc-ftr-h: 0px;
      --doc-hdr-pad: 0px;
      --doc-ftr-pad: 0px;
    }
    .sheet {
      width: var(--doc-page-w);
      margin: 0 auto;
      background: #fff;
      box-shadow: 0 2px 10px rgba(20, 20, 19, 0.12);
      border-radius: 7px;
      box-sizing: border-box;
      padding: var(--doc-page-margin);
    }
    .frame { width: 100%; border-collapse: collapse; }
    /* Scaled-fit mode (content-width/content-height): the inner .fit box
     * lays the content out at its authored fixed size and scales it onto
     * the printable area; .fit-box reserves the scaled footprint in flow
     * (transforms don't affect layout) and centers it. Without the mode,
     * both divs are unstyled block pass-throughs. */
    /* Explicit pagination: direct .page children are the pages. The sheet
     * becomes a transparent stack and each page carries the card look on
     * screen; at print each page is exactly one full-bleed sheet. The
     * ::slotted defaults are deliberately weak (document CSS wins), so
     * authored page styling can override any of this. */
    .sheet.paginated {
      background: transparent;
      box-shadow: none;
      border-radius: 0;
      padding: 0;
    }
    .paginated ::slotted(.page) {
      position: relative;
      display: block;
      width: 100%;
      aspect-ratio: var(--doc-page-ar);
      container-type: size;
      overflow: hidden;
      box-sizing: border-box;
      background: #fff;
      border-radius: 7px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.25);
      print-color-adjust: exact;
      -webkit-print-color-adjust: exact;
      break-inside: avoid;
    }
    .paginated ::slotted(.page:not(:first-child)) { margin-top: 1rem; }
    @media print {
      .sheet.paginated { padding: 0; }
      /* The flowing-document vertical inset lives on the repeating
       * thead/tfoot spacers, not the sheet padding — they must go too,
       * or each full-sheet .page is pushed ~margin down and spills onto
       * a second sheet. Paginated pages are full-bleed by definition
       * (content owns its insets). */
      .sheet.paginated .hdr-space,
      .sheet.paginated .ftr-space { height: 0; }
      .paginated ::slotted(.page) {
        border-radius: 0 !important;
        box-shadow: none !important;
        margin: 0 !important;
        /* Physical page-box sizing, no viewport units: Safari resolves
         * 100vh against the window, not the page box, so a vh-sized card
         * paginates wrong there. --doc-page-w/h are the named size by
         * default and are overridden to the user's chosen paper by the
         * export path, so every card is exactly one sheet either way.
         * Width + height (same source values as @page size) rather than
         * width + aspect-ratio: the ratio is a 6-decimal rounding of the
         * same division, and a few millionths of overflow would spill a
         * blank sheet after every page. The screen-only aspect-ratio
         * (preview proportions) must not leak into print. cqh typography
         * tracks the same box.
         *
         * Every declaration is !important: per CSS Scoping, unimportant
         * shadow ::slotted rules LOSE to the document context, so a page
         * section's authored inline style would silently beat this print
         * geometry. A model-authored height:100% did exactly that — the
         * percentage resolves as auto in the all-auto print ancestry, the
         * base rule's size containment turns auto into ZERO, and
         * overflow:hidden then paints nothing: a blank PDF with perfect
         * page boxes. At print the component's geometry is the design's
         * whole contract, so it must win over any authored sizing. */
        aspect-ratio: auto !important;
        width: var(--doc-page-w) !important;
        height: var(--doc-page-h) !important;
        overflow: hidden !important;
      }
      .paginated ::slotted(.page:not(:first-child)) {
        break-before: page !important;
        margin-top: 0 !important;
      }
    }
    .fit-mode .fit-box {
      width: calc(var(--doc-fit-w) * var(--doc-fit-scale));
      height: calc(var(--doc-fit-h) * var(--doc-fit-scale));
      margin: 0 auto;
      break-inside: avoid;
    }
    /* Monolithic at print: Blink slices a transform-scaled child at
     * fragmentainer boundaries mapped in UNSCALED layout coordinates
     * (transforms are paint-time), so the .fit box (authored size, e.g.
     * 1400x990) gets cut at the page's free block space and spills onto
     * a second sheet even though its SCALED footprint fits the page by
     * construction. overflow:hidden makes .fit-box a scroll container —
     * monolithic under fragmentation (css-break-3) — so the scaled
     * content prints atomically on one sheet. No clipping for content
     * within the authored box: .fit-box is calc-sized to exactly the
     * scaled footprint. (Content that bleeds past content-width/height
     * is clipped at the footprint — fit mode's contract; it previously
     * painted beyond it at print.) Print-only, so the screen rendering
     * keeps visible overflow for editor affordances.
     * The export path injects the same rule into frozen copies
     * (print-eval.ts om-print-fit-contain). The .fit-mode scope is
     * load-bearing: .fit-box wraps slotted content in EVERY mode, and an
     * unscoped overflow:hidden would make whole flowing documents
     * monolithic (one truncated sheet). overflow:hidden, never clip —
     * clip is not a scroll container, so not monolithic. */
    @media print {
      .fit-mode .fit-box { overflow: hidden; }
    }
    .fit-mode .fit {
      width: var(--doc-fit-w);
      height: var(--doc-fit-h);
      transform: scale(var(--doc-fit-scale));
      transform-origin: top left;
    }
    .frame td, .frame th { padding: 0; text-align: left; font-weight: inherit; }
    .hdr-space { height: var(--doc-hdr-h); }
    .ftr-space { height: var(--doc-ftr-h); }
    ::slotted([slot="header"]),
    ::slotted([slot="footer"]) { display: block; box-sizing: border-box; }
    @media print {
      :host { background: none; padding: 0; min-width: 0; min-height: 0; }
      .sheet {
        width: auto; margin: 0; box-shadow: none; border-radius: 0;
        padding: 0 var(--doc-page-margin);
      }
      /* The thead/tfoot spacers repeat on every page, so they carry the
       * vertical page margin (which the sheet's own padding cannot, since
       * that padding is consumed once on the first/last page). The running
       * header/footer are fixed inside that band. */
      /* The 0.35in is breathing room between a running header/footer and
       * the body; without one the spacer is exactly the page margin, so a
       * margin="0" full-bleed document gets truly full-bleed pages. */
      .hdr-space { height: max(var(--doc-page-margin), calc(var(--doc-hdr-h) + var(--doc-hdr-pad))); }
      .ftr-space { height: max(var(--doc-page-margin), calc(var(--doc-ftr-h) + var(--doc-ftr-pad))); }
      /* WebKit flowing documents: @page carries the vertical margin (see
       * _syncPrintPageRule), so the spacers keep only whatever a running
       * header/footer needs BEYOND it — page 1 would otherwise double its
       * top inset. Paginated sheets already zero their spacers above. */
      .sheet.wk-print:not(.paginated) .hdr-space { height: max(0px, calc(max(var(--doc-page-margin), calc(var(--doc-hdr-h) + var(--doc-hdr-pad))) - var(--doc-page-margin))); }
      .sheet.wk-print:not(.paginated) .ftr-space { height: max(0px, calc(max(var(--doc-page-margin), calc(var(--doc-ftr-h) + var(--doc-ftr-pad))) - var(--doc-page-margin))); }
      ::slotted([slot="header"]) {
        position: fixed; top: 0; left: 0; right: 0; margin: 0;
        padding: calc(var(--doc-page-margin) * 0.45) var(--doc-page-margin) 0;
      }
      ::slotted([slot="footer"]) {
        position: fixed; bottom: 0; left: 0; right: 0; margin: 0;
        padding: 0 var(--doc-page-margin) calc(var(--doc-page-margin) * 0.45);
      }
    }
  `;
  class DocPage extends HTMLElement {
    static get observedAttributes() {
      return ['size', 'width', 'height', 'margin', 'orientation', 'content-width', 'content-height'];
    }
    constructor() {
      super();
      this._root = this.attachShadow({
        mode: 'open'
      });
      this._mo = typeof MutationObserver === 'function' ? new MutationObserver(() => this._scheduleMeasure()) : null;
    }

    /** The named paper's [w, h], swapped when orientation="landscape".
     *  Only the named size swaps — explicit width/height are exact values
     *  the author already oriented. */
    _paperSize() {
      const named = PAPER[(this.getAttribute('size') || '').toLowerCase()] || PAPER.letter;
      const landscape = (this.getAttribute('orientation') || '').trim().toLowerCase() === 'landscape';
      return landscape ? [named[1], named[0]] : named;
    }
    get pageWidth() {
      return safeLen(this.getAttribute('width'), this._paperSize()[0]);
    }
    get pageHeight() {
      return safeLen(this.getAttribute('height'), this._paperSize()[1]);
    }
    get pageMargin() {
      return safeLen(this.getAttribute('margin'), '0.75in');
    }

    /** Scaled-fit mode's content box [w, h] as CSS lengths, or null when
     *  the mode is off (either attribute missing/invalid/zero — a partial
     *  declaration falls back to normal flow rather than guessing). */
    _contentFit() {
      const w = safeLen(this.getAttribute('content-width'), null);
      const h = safeLen(this.getAttribute('content-height'), null);
      if (!w || !h) return null;
      const wPx = toPx(w),
        hPx = toPx(h);
      return wPx > 0 && hPx > 0 ? [w, h, wPx, hPx] : null;
    }
    connectedCallback() {
      if (!this._sheet) this._render();
      this._syncSize();
      this._syncPrintPageRule();
      this._ensureTextWrapDefaults();
      this._ensureOwnsPrintMeta();
      this._syncFixedSizeMeta();
      this._syncPrintSizingMeta();
      if (this._mo) this._mo.observe(this, {
        subtree: true,
        childList: true,
        characterData: true,
        attributes: true
      });
      this._onResize = () => this._scheduleMeasure();
      window.addEventListener('resize', this._onResize);
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(() => this._scheduleMeasure());
      }
      this._scheduleMeasure();
    }
    disconnectedCallback() {
      window.removeEventListener('resize', this._onResize);
      if (this._mo) this._mo.disconnect();
      if (this._raf) {
        cancelAnimationFrame(this._raf);
        this._raf = null;
      }
      // Drop the head rules when the last doc-page leaves, so a deleted
      // document's @page geometry and text-wrap defaults can't apply to
      // whatever replaces it.
      const survivor = document.querySelector('doc-page');
      if (!survivor) {
        ['doc-page-print', 'doc-page-text-wrap', 'doc-page-owns-print', 'doc-page-fixed-size', 'doc-page-print-sizing'].forEach(id => {
          const tag = document.getElementById(id);
          if (tag) tag.remove();
        });
        // A live deck-stage deferred its own print-sizing meta to ours —
        // hand the page-global meta over so the deck isn't left unmarked.
        const deck = document.querySelector('deck-stage');
        if (deck && typeof deck._ensurePrintSizingMeta === 'function') {
          deck._ensurePrintSizingMeta();
        }
      } else {
        // A departed owner hands each page-global meta to whatever
        // doc-page remains (or it's removed).
        if (typeof survivor._syncFixedSizeMeta === 'function') {
          survivor._syncFixedSizeMeta();
        }
        if (typeof survivor._syncPrintSizingMeta === 'function') {
          survivor._syncPrintSizingMeta();
        }
      }
    }
    attributeChangedCallback() {
      if (!this._sheet) return;
      this._syncSize();
      this._syncPrintPageRule();
      this._syncFixedSizeMeta();
      this._syncPrintSizingMeta();
      this._scheduleMeasure();
    }
    _render() {
      this._root.innerHTML = `
        <style>${stylesheet}</style>
        <style id="vars"></style>
        <div class="sheet" data-screen-label="Document">
          <table class="frame" role="presentation">
            <thead><tr><th><div class="hdr-space"><slot name="header"></slot></div></th></tr></thead>
            <tbody><tr><td class="body"><div class="fit-box"><div class="fit"><slot></slot></div></div></td></tr></tbody>
            <tfoot><tr><td><div class="ftr-space"><slot name="footer"></slot></div></td></tr></tfoot>
          </table>
        </div>`;
      this._sheet = this._root.querySelector('.sheet');
      this._vars = this._root.getElementById('vars');
    }

    /** Runtime sizing lives in a shadow <style> :host rule, never on the
     *  light-DOM host element, so serialize-persist can't write it back. */
    _syncSize(hdrH, ftrH) {
      // Scaled-fit mode: content at its authored size, scaled onto the
      // printable area (page minus margins on both axes). The factor is a
      // plain number var so calc(length * number) stays valid; 4 decimals
      // keeps the shadow style stable across re-measures. Upscaling is
      // allowed — print transforms are vector, so text and CSS stay crisp
      // (raster images soften, which the catalog bullet warns about).
      const fit = this._contentFit();
      let fitVars = '';
      if (fit) {
        const marginPx = toPx(this.pageMargin) || 0;
        const availW = toPx(this.pageWidth) - 2 * marginPx;
        const availH = toPx(this.pageHeight) - 2 * marginPx;
        const scale = Math.min(availW / fit[2], availH / fit[3]);
        if (scale > 0 && Number.isFinite(scale)) {
          fitVars = '--doc-fit-w:' + fit[0] + ';' + '--doc-fit-h:' + fit[1] + ';' + '--doc-fit-scale:' + scale.toFixed(4) + ';';
        }
      }
      this._sheet.classList.toggle('fit-mode', !!fitVars);
      // Numeric w/h ratio for the paginated page cards' aspect-ratio —
      // aspect-ratio takes a number, not a length ratio, so compute it
      // here (CSS length division isn't portable). 6 decimals keeps the
      // shadow style stable across re-syncs.
      const arW = toPx(this.pageWidth);
      const arH = toPx(this.pageHeight);
      const ar = arW > 0 && arH > 0 ? (arW / arH).toFixed(6) : '0.772727';
      this._vars.textContent = ':host{' + fitVars + '--doc-page-ar:' + ar + ';' + '--doc-page-w:' + this.pageWidth + ';' + '--doc-page-h:' + this.pageHeight + ';' + '--doc-page-margin:' + this.pageMargin + ';' + '--doc-hdr-h:' + (hdrH || 0) + 'px;' + '--doc-ftr-h:' + (ftrH || 0) + 'px;' + '--doc-hdr-pad:' + (hdrH ? '0.35in' : '0px') + ';' + '--doc-ftr-pad:' + (ftrH ? '0.35in' : '0px') + '}';
    }

    /** @page is a no-op inside shadow DOM, so the rule lives in <head>.
     *  Re-appended on every sync so it stays last in source order — the
     *  @page cascade is source-order per descriptor, so this rule wins
     *  over any other @page rule in the document.
     *
     *  The @page SIZE is pinned where the page box IS part of the design:
     *  explicit-fixed-size mode (width + height authored), scaled-fit
     *  mode (the named sheet the fit targets), and explicit pagination
     *  (the named size the cards share — so card and sheet agree on
     *  every print path, and the export path's chosen paper overrides
     *  BOTH with one later rule). For FLOWING documents no paper size is
     *  emitted at all — the true size comes from the user's preference,
     *  injected by the export path or chosen in the print dialog — so a
     *  flowing document never fights the paper it lands on.
     *  margin: 0 is emitted in every mode: it leaves Chrome no margin box
     *  to draw its date/URL/page-count header in, and the visual margin
     *  lives on the sheet's own padding. */
    _syncPrintPageRule() {
      const id = 'doc-page-print';
      let tag = document.getElementById(id);
      if (!tag) {
        tag = document.createElement('style');
        tag.id = id;
      }
      document.head.appendChild(tag);
      // Three print-geometry regimes:
      // - true-size: the page IS the design — pin its exact size.
      // - scaled-fit (content-width/height): the fit factor is computed
      //   against the NAMED paper's printable area, so that paper must
      //   stay pinned or the scaled content overflows a smaller sheet
      //   (the export path re-fits and re-pins at print time on top).
      // - default modes: no paper size — but landscape still needs the
      //   paper-agnostic 'size: landscape' keyword, because the size
      //   descriptor is what carries orientation; without it a landscape
      //   document prints portrait whenever nothing injects a size.
      const landscape = (this.getAttribute('orientation') || '').trim().toLowerCase() === 'landscape';
      // Explicit pagination pins the page box to the SAME values that
      // size the cards (the named size by default, the export path's
      // chosen paper when its later rule overrides both) — card and
      // sheet agree on every print path, and a mismatched real paper
      // shrinks-to-fit in the dialog instead of clipping a Letter card
      // on A4. Declared before the paginated read below so both derive
      // from one check.
      const paginatedNow = this.querySelector(':scope > .page') !== null;
      const sizeDescriptor = this._trueSizePx() ? 'size: ' + this.pageWidth + ' ' + this.pageHeight + '; ' : this._contentFit() ? 'size: ' + this.pageWidth + ' ' + this.pageHeight + '; ' : paginatedNow ? 'size: ' + this.pageWidth + ' ' + this.pageHeight + '; ' : landscape ? 'size: landscape; ' : '';
      // WebKit never repeats the thead/tfoot spacers that carry a flowing
      // document's vertical page margins (see WK_PRINT above), so pages
      // after the first print edge-to-edge there. Carry the VERTICAL
      // margins on @page for WebKit instead, and the shadow print CSS
      // trims the first-page spacers by the same amount (.sheet.wk-print
      // rules). Horizontal inset stays on the sheet's own padding in
      // every engine. Blink keeps margin: 0 (a nonzero margin there
      // re-opens the box Chrome draws its header furniture in). One cost,
      // learned in testing: Safari's own date/URL headers are a USER
      // dialog setting ("Print headers and footers") that renders in the
      // margin area when room exists — margin: 0 only suppressed it by
      // leaving no room, and no CSS controls it. The export dialog's
      // Safari guide teaches turning the setting off for flowing
      // documents. Explicitly paginated and fixed-size documents keep
      // margin: 0 everywhere: their pages ARE the sheet.
      const wkFlowing = WK_PRINT && !paginatedNow && !this._trueSizePx() && !this._contentFit();
      const marginDescriptor = wkFlowing ? 'margin: ' + this.pageMargin + ' 0; ' : 'margin: 0; ';
      // Shadow-internal marker (never serialized), kept in lockstep with
      // the @page decision above: the print CSS trims the first-page
      // spacers ONLY while @page actually carries the margins — a
      // true-size or scaled-fit sheet keeps margin: 0 and must keep its
      // spacers too. Re-synced here so attribute changes and pagination
      // flips move both together.
      if (this._sheet) this._sheet.classList.toggle('wk-print', wkFlowing);
      tag.textContent = '@page { ' + sizeDescriptor + marginDescriptor + '} ' + '@media print { html, body { margin: 0 !important; padding: 0 !important; background: none !important; height: auto !important; overflow: visible !important; } ' + 'h1,h2,h3,h4,h5,h6 { break-after: avoid; } ' + 'figure,pre,blockquote,img,svg,tr { break-inside: avoid; } ' + 'p,li { orphans: 3; widows: 3; } ' + '* { -webkit-print-color-adjust: exact; print-color-adjust: exact; ' + 'backdrop-filter: none !important; -webkit-backdrop-filter: none !important; } ' + '*, *::before, *::after { animation-delay: -99s !important; animation-duration: .001s !important; ' + 'animation-iteration-count: 1 !important; animation-fill-mode: both !important; ' + 'animation-play-state: running !important; transition-duration: 0s !important; } }';
    }

    /** Typographic defaults for document text: balance headings, avoid
     *  widowed/orphaned words in body copy (browsers without text-wrap
     *  support drop the declarations). Zero-specificity via :where() so
     *  any text-wrap authored on those elements wins; document-level so the
     *  rules reach the slotted (light DOM) content — shadow styles can't.
     *  data-omelette-injected marks the tag for the host editor to strip
     *  at serialize, so it is never written back as authored source. */
    _ensureTextWrapDefaults() {
      if (document.getElementById('doc-page-text-wrap')) return;
      const tag = document.createElement('style');
      tag.id = 'doc-page-text-wrap';
      tag.setAttribute('data-omelette-injected', '');
      tag.textContent = ':where(h1,h2,h3,h4,h5,h6){text-wrap:balance}' + ':where(p,li,blockquote,figcaption){text-wrap:pretty}';
      document.head.appendChild(tag);
    }

    /** Declares that this document owns its print CSS. The instant-PDF
     *  export checks for the meta by NAME PRESENCE alone (content is
     *  ignored) and skips its automatic print-CSS injections, so the
     *  component's @page geometry is never overridden by a heuristic.
     *  data-omelette-injected keeps it out of serialized source. */
    _ensureOwnsPrintMeta() {
      if (document.getElementById('doc-page-owns-print')) return;
      const tag = document.createElement('meta');
      tag.id = 'doc-page-owns-print';
      tag.name = 'omelette-owns-print';
      tag.content = 'true';
      tag.setAttribute('data-omelette-injected', '');
      document.head.appendChild(tag);
    }

    /** This page's valid true-size page box (explicit width AND height)
     *  as [w, h] px ints, or null when the mode is off. */
    _trueSizePx() {
      if (!safeLen(this.getAttribute('width'), null) || !safeLen(this.getAttribute('height'), null)) return null;
      const w = Math.round(toPx(this.pageWidth));
      const h = Math.round(toPx(this.pageHeight));
      return w > 0 && h > 0 ? [w, h] : null;
    }

    /** True-size pages (explicit width AND height) also declare the page
     *  box as the preview size: the in-app preview reads
     *  meta[name="omelette-fixed-size"] (content "W,H" in px ints) and
     *  scales the sheet into view — without it an 18in poster previews at
     *  true size with scrollbars. Never overrides an author-set meta
     *  (only the component's own id is managed). The meta is page-global
     *  while doc-page instances are not, so every sync recomputes the
     *  page-wide owner — the first connected true-size doc-page — and a
     *  non-true-size sibling's sync can never delete the owner's meta.
     *  Removed when no true-size page remains (the owner's disconnect
     *  re-syncs via any survivor) or when an author-set meta exists. */
    _syncFixedSizeMeta() {
      const id = 'doc-page-fixed-size';
      const own = document.getElementById(id);
      const authored = document.querySelector('meta[name="omelette-fixed-size"]:not([data-omelette-injected])');
      // The page-wide owner, not this instance: an upgraded true-size page
      // anywhere in the document keeps the meta alive and sized.
      let box = null;
      for (const el of document.querySelectorAll('doc-page')) {
        box = typeof el._trueSizePx === 'function' ? el._trueSizePx() : null;
        if (box) break;
      }
      if (!box || authored) {
        if (own) own.remove();
        return;
      }
      const tag = own || document.createElement('meta');
      tag.id = id;
      tag.name = 'omelette-fixed-size';
      tag.content = box[0] + ',' + box[1];
      tag.setAttribute('data-omelette-injected', '');
      if (!own) document.head.appendChild(tag);
    }

    /** This page's print-sizing mode: 'fixed' when an explicit width AND
     *  height are authored (the page is the design's own size), else the
     *  default paper in the authored orientation. */
    _printSizingMode() {
      if (this._trueSizePx()) return 'fixed';
      const landscape = (this.getAttribute('orientation') || '').trim().toLowerCase() === 'landscape';
      return landscape ? 'default-landscape' : 'default-portrait';
    }

    /** Announces the print-sizing mode to the host app:
     *  meta[name="omelette-print-sizing"] with content 'default-portrait',
     *  'default-landscape', or 'fixed' (fixed pages also carry the
     *  omelette-fixed-size meta with the page box in px). The export path
     *  probes it to decide what true paper size to inject at print time —
     *  in the default modes the component emits no paper size of its own.
     *  Same page-global ownership rules as the fixed-size meta above:
     *  first connected doc-page owns it, an authored meta is never
     *  overridden, removed when no doc-page remains. */
    _syncPrintSizingMeta() {
      const id = 'doc-page-print-sizing';
      const own = document.getElementById(id);
      const authored = document.querySelector('meta[name="omelette-print-sizing"]:not([data-omelette-injected])');
      // A fixed page wins outright (mirroring the fixed-size loop above,
      // so the two metas can never contradict each other in a mixed
      // multi-page document); otherwise the first page's mode holds.
      let mode = null;
      for (const el of document.querySelectorAll('doc-page')) {
        if (typeof el._printSizingMode !== 'function') continue;
        const m = el._printSizingMode();
        if (m === 'fixed') {
          mode = m;
          break;
        }
        if (mode === null) mode = m;
      }
      if (!mode || authored) {
        if (own) own.remove();
        return;
      }
      // A deck-stage that connected first injected its own meta and
      // defers to any existing one — take it over, or the document ends
      // up with two conflicting injected metas (a doc-page page is the
      // document; the deck re-ensures its meta if every doc-page leaves).
      const deckMeta = document.getElementById('deck-stage-print-sizing');
      if (deckMeta) deckMeta.remove();
      const tag = own || document.createElement('meta');
      tag.id = id;
      tag.name = 'omelette-print-sizing';
      tag.content = mode;
      tag.setAttribute('data-omelette-injected', '');
      if (!own) document.head.appendChild(tag);
    }
    _scheduleMeasure() {
      if (this._raf) return;
      this._raf = requestAnimationFrame(() => {
        this._raf = null;
        this._measure();
      });
    }

    /** Slot heights feed the print spacers (--doc-hdr-h / --doc-ftr-h), so
     *  they re-measure on content mutation, resize, and font load. The
     *  same pass detects explicit pagination (direct .page children) and
     *  toggles the sheet between the flowing-document card and the
     *  page-per-card stack — content edits can add or remove pages at any
     *  time, so this tracks the same mutations the measurement does. */
    _measure() {
      const hdr = this.querySelector(':scope > [slot="header"]');
      const ftr = this.querySelector(':scope > [slot="footer"]');
      const wasPaginated = this._sheet.classList.contains('paginated');
      this._sheet.classList.toggle('paginated', this.querySelector(':scope > .page') !== null);
      // The WebKit @page margin is flowing-only, so a pagination flip
      // must re-emit the rule (content edits can add or remove .page
      // sections at any time).
      if (this._sheet.classList.contains('paginated') !== wasPaginated) {
        this._syncPrintPageRule();
      }
      this._syncSize(hdr ? hdr.offsetHeight : 0, ftr ? ftr.offsetHeight : 0);
    }
  }
  if (!customElements.get('doc-page')) {
    customElements.define('doc-page', DocPage);
  }
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "guidelines/email-signatures/doc-page.js", error: String((e && e.message) || e) }); }

// ui_kits/concepts/Finder.jsx
try { (() => {
// Direction A — Capability Finder. Tool-first: narrow by application, process,
// material and matching machines filter in live.
const React = window.React;
const {
  useState,
  useMemo
} = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const {
  Button,
  Badge,
  Card,
  Eyebrow,
  SpecList
} = DS;
const I = window.RmsIcons;
const A = '../../assets';
const {
  BUILDERS,
  MACHINES,
  APPLICATIONS,
  PROCESSES,
  MATERIALS,
  builderLogo
} = window.RmsData;
function Facet({
  label,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      marginBottom: 26
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-eyebrow)',
      textTransform: 'uppercase',
      letterSpacing: '0.12em',
      color: 'var(--rms-yellow)',
      marginBottom: 12
    }
  }, label), children);
}
function Chip({
  active,
  onClick,
  children
}) {
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    style: {
      border: active ? '1.5px solid var(--rms-yellow)' : '1.5px solid rgba(255,255,255,0.18)',
      background: active ? 'rgba(251,181,28,0.16)' : 'rgba(255,255,255,0.04)',
      color: '#fff',
      cursor: 'pointer',
      borderRadius: 'var(--radius-md)',
      padding: '9px 14px',
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      transition: 'all var(--dur-fast) var(--ease-standard)'
    }
  }, children);
}
function Finder({
  onQuote
}) {
  const [app, setApp] = useState(null);
  const [proc, setProc] = useState(null);
  const [mat, setMat] = useState(null);
  const toggle = (cur, val, set) => set(cur === val ? null : val);
  const results = useMemo(() => MACHINES.filter(m => (!app || m.application.includes(app)) && (!proc || m.process === proc) && (!mat || m.material.includes(mat))), [app, proc, mat]);
  const any = app || proc || mat;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '400px 1fr',
      minHeight: 'calc(100vh - 68px)'
    }
  }, /*#__PURE__*/React.createElement("aside", {
    style: {
      position: 'relative',
      background: 'var(--rms-navy-900)',
      color: '#fff',
      padding: '40px 34px',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/world-map.png`,
    alt: "",
    style: {
      position: 'absolute',
      inset: 0,
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      opacity: 0.06
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(Eyebrow, {
    color: "var(--rms-yellow)"
  }, "Find your machine"), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-display-sm)',
      fontStyle: 'italic',
      textTransform: 'uppercase',
      lineHeight: 1.05,
      margin: '14px 0 10px'
    }
  }, "What are you", /*#__PURE__*/React.createElement("br", null), "machining?"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-sm)',
      color: 'var(--steel-300)',
      margin: '0 0 30px'
    }
  }, "Tell us the job. We'll match it to the right builder and platform from our aerospace-proven lineup."), /*#__PURE__*/React.createElement(Facet, {
    label: "Application"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 10
    }
  }, APPLICATIONS.map(a => {
    const Ic = I[a.icon];
    const active = app === a.id;
    return /*#__PURE__*/React.createElement("button", {
      key: a.id,
      onClick: () => toggle(app, a.id, setApp),
      style: {
        textAlign: 'left',
        cursor: 'pointer',
        borderRadius: 'var(--radius-md)',
        padding: '12px 13px',
        border: active ? '1.5px solid var(--rms-yellow)' : '1.5px solid rgba(255,255,255,0.18)',
        background: active ? 'rgba(251,181,28,0.16)' : 'rgba(255,255,255,0.04)',
        color: '#fff',
        transition: 'all var(--dur-fast) var(--ease-standard)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        color: active ? 'var(--rms-yellow)' : 'var(--rms-blue-400)',
        display: 'block',
        marginBottom: 7
      }
    }, /*#__PURE__*/React.createElement(Ic, {
      size: 22
    })), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-body-sm)',
        fontWeight: 700,
        display: 'block',
        lineHeight: 1.2
      }
    }, a.label), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--steel-400)'
      }
    }, a.desc));
  }))), /*#__PURE__*/React.createElement(Facet, {
    label: "Process"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 9
    }
  }, PROCESSES.map(p => /*#__PURE__*/React.createElement(Chip, {
    key: p.id,
    active: proc === p.id,
    onClick: () => toggle(proc, p.id, setProc)
  }, p.label)))), /*#__PURE__*/React.createElement(Facet, {
    label: "Material"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 9
    }
  }, MATERIALS.map(m => /*#__PURE__*/React.createElement(Chip, {
    key: m.id,
    active: mat === m.id,
    onClick: () => toggle(mat, m.id, setMat)
  }, m.label)))), any && /*#__PURE__*/React.createElement("button", {
    onClick: () => {
      setApp(null);
      setProc(null);
      setMat(null);
    },
    style: {
      border: 'none',
      background: 'transparent',
      color: 'var(--rms-blue-400)',
      cursor: 'pointer',
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      padding: 0,
      textDecoration: 'underline'
    }
  }, "Reset filters"))), /*#__PURE__*/React.createElement("main", {
    style: {
      background: 'var(--steel-50)',
      padding: '34px 40px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      justifyContent: 'space-between',
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: 0
    }
  }, results.length, " ", results.length === 1 ? 'machine' : 'machines', " match"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-body-sm)',
      color: 'var(--text-muted)'
    }
  }, any ? 'Refine further on the left' : 'Showing the full lineup')), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 20
    }
  }, results.map(m => /*#__PURE__*/React.createElement(Card, {
    key: m.id,
    accentEdge: true,
    interactive: true,
    padding: "0"
  }, m.photo ? /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/${m.photo}`,
    alt: m.name,
    style: {
      width: '100%',
      height: 150,
      objectFit: 'cover',
      borderRadius: 'var(--radius-md) var(--radius-md) 0 0'
    }
  }) : /*#__PURE__*/React.createElement("div", {
    style: {
      height: 64,
      background: 'var(--steel-100)',
      borderRadius: 'var(--radius-md) var(--radius-md) 0 0',
      display: 'flex',
      alignItems: 'center',
      padding: '0 var(--space-5)'
    }
  }, builderLogo(m.builder, 28)), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--space-5)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 6
    }
  }, m.photo ? builderLogo(m.builder, 22) : /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-caption)',
      color: 'var(--text-muted)'
    }
  }, m.builder), /*#__PURE__*/React.createElement(Badge, {
    tone: "navy",
    variant: "soft"
  }, m.axes)), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h3)',
      color: 'var(--rms-navy)',
      margin: '0 0 14px'
    }
  }, m.name), /*#__PURE__*/React.createElement(SpecList, {
    items: m.specs
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 15
    }),
    onClick: () => onQuote(m)
  }, "Request a quote")))))), results.length === 0 && /*#__PURE__*/React.createElement(Card, {
    style: {
      textAlign: 'center',
      padding: 'var(--space-8)'
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h3)',
      color: 'var(--rms-navy)',
      margin: '0 0 8px'
    }
  }, "No exact match"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--text-body)',
      margin: '0 0 18px'
    }
  }, "Our specialists source custom configurations every day. Tell us what you need."), /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    onClick: () => onQuote(null)
  }, "Talk to a specialist"))));
}
Object.assign(window, {
  RmsFinder: Finder
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/concepts/Finder.jsx", error: String((e && e.message) || e) }); }

// ui_kits/concepts/Showroom.jsx
try { (() => {
// Direction B — Partner Showroom. Brand-led browse: enter through the four
// prestige builders, then drill into a filterable spec catalog for each.
const React = window.React;
const {
  useState
} = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const {
  Button,
  Badge,
  Card,
  Eyebrow,
  SpecList
} = DS;
const I = window.RmsIcons;
const A = '../../assets';
const {
  BUILDERS,
  MACHINES,
  PROCESSES,
  builderLogo
} = window.RmsData;
const PROC_LABEL = Object.fromEntries(PROCESSES.map(p => [p.id, p.label]));
function MarqueGallery({
  onOpen
}) {
  const heroImg = {
    'Fives Giddings & Lewis': 'giddings-lewis-v1250.png',
    'Mitsui Seiki': 'mitsui-seiki-hpx150.webp',
    'Breton': 'breton-genesi.webp',
    'Index': 'innovation.jpg'
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--steel-50)',
      minHeight: 'calc(100vh - 68px)'
    }
  }, /*#__PURE__*/React.createElement("section", {
    style: {
      background: 'var(--rms-navy)',
      color: '#fff',
      padding: '56px 40px 64px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1280,
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement(Eyebrow, {
    color: "var(--rms-yellow)"
  }, "The Showroom"), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-display-md)',
      fontStyle: 'italic',
      textTransform: 'uppercase',
      margin: '14px 0 10px',
      maxWidth: 760
    }
  }, "Four builders.", /*#__PURE__*/React.createElement("br", null), "One standard of ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--rms-yellow)'
    }
  }, "precision.")), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      color: 'var(--steel-300)',
      maxWidth: 600,
      margin: 0
    }
  }, "We represent the world's finest machine-tool marques. Step into a builder to explore their aerospace-proven lineup."))), /*#__PURE__*/React.createElement("section", {
    style: {
      maxWidth: 1280,
      margin: '0 auto',
      padding: '40px',
      marginTop: -40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 24
    }
  }, Object.entries(BUILDERS).map(([name, b]) => {
    const count = MACHINES.filter(m => m.builder === name).length;
    return /*#__PURE__*/React.createElement(Card, {
      key: name,
      interactive: true,
      padding: "0",
      style: {
        overflow: 'hidden',
        cursor: 'pointer'
      },
      onClick: () => onOpen(name)
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'relative',
        height: 180
      }
    }, /*#__PURE__*/React.createElement("img", {
      src: `${A}/images/${heroImg[name]}`,
      alt: name,
      style: {
        width: '100%',
        height: '100%',
        objectFit: 'cover'
      }
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 0,
        background: 'linear-gradient(180deg, rgba(0,38,71,0.15), rgba(0,38,71,0.82))'
      }
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        left: 0,
        bottom: 0,
        padding: '20px 24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        width: '100%',
        boxSizing: 'border-box'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        background: '#fff',
        borderRadius: 'var(--radius-sm)',
        padding: '8px 12px',
        display: 'flex',
        alignItems: 'center'
      }
    }, builderLogo(name, 28)), /*#__PURE__*/React.createElement(Badge, {
      tone: "yellow",
      variant: "solid"
    }, b.origin))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: 'var(--space-5) var(--space-6) var(--space-6)'
      }
    }, /*#__PURE__*/React.createElement("p", {
      style: {
        font: 'var(--type-body)',
        color: 'var(--text-body)',
        margin: '0 0 16px'
      }
    }, b.blurb), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-mono)',
        color: 'var(--text-muted)'
      }
    }, count, " platforms"), /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        font: 'var(--type-body)',
        fontWeight: 700,
        color: 'var(--rms-blue)'
      }
    }, "Explore lineup ", /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 17
    })))));
  }))));
}
function Catalog({
  builder,
  onBack,
  onQuote
}) {
  const [proc, setProc] = useState(null);
  const b = BUILDERS[builder];
  const all = MACHINES.filter(m => m.builder === builder);
  const procsAvail = [...new Set(all.map(m => m.process))];
  const list = proc ? all.filter(m => m.process === proc) : all;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--steel-50)',
      minHeight: 'calc(100vh - 68px)'
    }
  }, /*#__PURE__*/React.createElement("section", {
    style: {
      background: 'var(--rms-navy)',
      color: '#fff',
      padding: '30px 40px 36px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1280,
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      border: 'none',
      background: 'transparent',
      color: 'var(--rms-blue-400)',
      cursor: 'pointer',
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      padding: 0,
      display: 'inline-flex',
      alignItems: 'center',
      gap: 7,
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      transform: 'rotate(180deg)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(I.ArrowRight, {
    size: 15
  })), " All builders"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 20,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: '#fff',
      borderRadius: 'var(--radius-sm)',
      padding: '12px 16px',
      display: 'flex',
      alignItems: 'center'
    }
  }, builderLogo(builder, 36)), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-h1)',
      margin: 0
    }
  }, builder), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--steel-300)',
      margin: '4px 0 0',
      maxWidth: 560
    }
  }, b.blurb)), /*#__PURE__*/React.createElement("div", {
    style: {
      marginLeft: 'auto',
      textAlign: 'right'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-display-sm)',
      fontStyle: 'italic',
      color: 'var(--rms-yellow)'
    }
  }, b.origin))))), /*#__PURE__*/React.createElement("section", {
    style: {
      maxWidth: 1280,
      margin: '0 auto',
      padding: '28px 40px 48px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 9,
      marginBottom: 22,
      flexWrap: 'wrap',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-eyebrow)',
      textTransform: 'uppercase',
      letterSpacing: '0.12em',
      color: 'var(--text-muted)',
      marginRight: 6
    }
  }, "Filter"), /*#__PURE__*/React.createElement(FilterChip, {
    active: !proc,
    onClick: () => setProc(null)
  }, "All"), procsAvail.map(p => /*#__PURE__*/React.createElement(FilterChip, {
    key: p,
    active: proc === p,
    onClick: () => setProc(p)
  }, PROC_LABEL[p]))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 16
    }
  }, list.map(m => /*#__PURE__*/React.createElement(Card, {
    key: m.id,
    padding: "0",
    style: {
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: m.photo ? '240px 1fr' : '1fr',
      alignItems: 'stretch'
    }
  }, m.photo && /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/${m.photo}`,
    alt: m.name,
    style: {
      width: '100%',
      height: '100%',
      minHeight: 170,
      objectFit: 'cover'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--space-5) var(--space-6)',
      display: 'grid',
      gridTemplateColumns: '1fr 300px',
      gap: 28,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Badge, {
    tone: "navy",
    variant: "soft",
    style: {
      marginBottom: 10
    }
  }, m.axes, " \xB7 ", PROC_LABEL[m.process]), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '0 0 14px'
    }
  }, m.name), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 15
    }),
    onClick: () => onQuote(m)
  }, "Request a quote")), /*#__PURE__*/React.createElement("div", {
    style: {
      borderLeft: '1px solid var(--border-subtle)',
      paddingLeft: 24
    }
  }, /*#__PURE__*/React.createElement(SpecList, {
    items: m.specs
  })))))))));
}
function FilterChip({
  active,
  onClick,
  children
}) {
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    style: {
      border: active ? '1.5px solid var(--rms-navy)' : '1.5px solid var(--border-default)',
      background: active ? 'var(--rms-navy)' : '#fff',
      color: active ? '#fff' : 'var(--text-body)',
      cursor: 'pointer',
      borderRadius: 'var(--radius-pill)',
      padding: '7px 15px',
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      transition: 'all var(--dur-fast) var(--ease-standard)'
    }
  }, children);
}
function Showroom({
  onQuote
}) {
  const [builder, setBuilder] = useState(null);
  return builder ? /*#__PURE__*/React.createElement(Catalog, {
    builder: builder,
    onBack: () => setBuilder(null),
    onQuote: onQuote
  }) : /*#__PURE__*/React.createElement(MarqueGallery, {
    onOpen: setBuilder
  });
}
Object.assign(window, {
  RmsShowroom: Showroom
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/concepts/Showroom.jsx", error: String((e && e.message) || e) }); }

// ui_kits/concepts/icons.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// Lucide-style icons (stroke 2, 24x24) — matches the icon system used in the
// Ross Machinery codebase (lucide-react). Exported to window for the UI kit.
const React = window.React;
function Icon({
  children,
  size = 24,
  stroke = 2,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("svg", _extends({
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: style
  }, rest), children);
}
const ArrowRight = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M5 12h14"
}), /*#__PURE__*/React.createElement("path", {
  d: "m13 6 6 6-6 6"
}));
const Phone = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"
}));
const Mail = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("rect", {
  width: "20",
  height: "16",
  x: "2",
  y: "4",
  rx: "2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"
}));
const Cog = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 2v2"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 22v-2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m17 20.66-1-1.73"
}), /*#__PURE__*/React.createElement("path", {
  d: "M11 10.27 7 3.34"
}), /*#__PURE__*/React.createElement("path", {
  d: "m20.66 17-1.73-1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m3.34 7 1.73 1"
}), /*#__PURE__*/React.createElement("path", {
  d: "M14 12h8"
}), /*#__PURE__*/React.createElement("path", {
  d: "M2 12h2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m20.66 7-1.73 1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m3.34 17 1.73-1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m17 3.34-1 1.73"
}), /*#__PURE__*/React.createElement("path", {
  d: "m11 13.73-4 6.93"
}));
const Wrench = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"
}));
const Shield = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"
}));
const Users = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"
}), /*#__PURE__*/React.createElement("circle", {
  cx: "9",
  cy: "7",
  r: "4"
}), /*#__PURE__*/React.createElement("path", {
  d: "M22 21v-2a4 4 0 0 0-3-3.87"
}), /*#__PURE__*/React.createElement("path", {
  d: "M16 3.13a4 4 0 0 1 0 7.75"
}));
const CheckCircle = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M21.801 10A10 10 0 1 1 17 3.335"
}), /*#__PURE__*/React.createElement("path", {
  d: "m9 11 3 3L22 4"
}));
const Quote = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H21a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M3 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H8a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"
}));
const MapPin = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"
}), /*#__PURE__*/React.createElement("circle", {
  cx: "12",
  cy: "10",
  r: "3"
}));
const X = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M18 6 6 18"
}), /*#__PURE__*/React.createElement("path", {
  d: "m6 6 12 12"
}));
const Menu = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "6",
  y2: "6"
}), /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "12",
  y2: "12"
}), /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "18",
  y2: "18"
}));
const Globe = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("circle", {
  cx: "12",
  cy: "12",
  r: "10"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"
}), /*#__PURE__*/React.createElement("path", {
  d: "M2 12h20"
}));
const Gauge = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "m12 14 4-4"
}), /*#__PURE__*/React.createElement("path", {
  d: "M3.34 19a10 10 0 1 1 17.32 0"
}));
Object.assign(window, {
  RmsIcons: {
    ArrowRight,
    Phone,
    Mail,
    Cog,
    Wrench,
    Shield,
    Users,
    CheckCircle,
    Quote,
    MapPin,
    X,
    Menu,
    Globe,
    Gauge
  }
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/concepts/icons.jsx", error: String((e && e.message) || e) }); }

// ui_kits/concepts/shared.jsx
try { (() => {
// Ross Machinery — concept explorer: shared data + chrome.
const React = window.React;
const {
  useState
} = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const {
  Button,
  Badge,
  Eyebrow,
  Input
} = DS;
const I = window.RmsIcons;
const A = '../../assets';

/* ---------------- Builders ---------------- */
const BUILDERS = {
  'Fives Giddings & Lewis': {
    logo: 'fives-giddings-lewis.png',
    origin: 'USA',
    blurb: 'Heavy-duty horizontal boring mills, machining & vertical turning centers.'
  },
  'Mitsui Seiki': {
    logo: 'mitsui-seiki.webp',
    origin: 'Japan',
    blurb: 'High-precision 4 & 5 axis centers, jig bores & grinders. 5-yr accuracy guarantee.'
  },
  'Breton': {
    logo: 'breton.jpg',
    origin: 'Italy',
    blurb: 'Gantry machine tools for composites & aerospace alloys, large-format additive.'
  },
  'Index': {
    logo: 'index.png',
    origin: 'Germany',
    blurb: 'Multi-spindle lathes & 5-axis turn-mill centers for high-volume production.'
  }
};

/* ---------------- Machine catalog ----------------
   application: structural | engine | composite | precision
   process:     boring | 5axis | turning | gantry
   material:    aluminum | titanium | composite | steel
*/
const MACHINES = [{
  id: 'gl-v1250',
  builder: 'Fives Giddings & Lewis',
  name: 'V1250 Vertical Turning Center',
  photo: 'giddings-lewis-v1250.png',
  process: 'turning',
  application: ['structural', 'precision'],
  material: ['aluminum', 'steel', 'titanium'],
  axes: '4-axis',
  specs: [{
    label: 'Swing',
    value: '1250 mm'
  }, {
    label: 'Max Height',
    value: '900 mm'
  }, {
    label: 'Table Load',
    value: '5,000 kg'
  }, {
    label: 'Origin',
    value: 'USA'
  }]
}, {
  id: 'gl-hbm130',
  builder: 'Fives Giddings & Lewis',
  name: 'HBM-130 Horizontal Boring Mill',
  process: 'boring',
  application: ['structural'],
  material: ['steel', 'aluminum'],
  axes: '4-axis',
  specs: [{
    label: 'Spindle Dia.',
    value: '130 mm'
  }, {
    label: 'X/Y/Z',
    value: '4000×2500×1600'
  }, {
    label: 'Spindle',
    value: '40T · 3,000 rpm'
  }, {
    label: 'Origin',
    value: 'USA'
  }]
}, {
  id: 'gl-ram5000',
  builder: 'Fives Giddings & Lewis',
  name: 'RAM 5000 Floor-Type Mill',
  process: 'boring',
  application: ['structural'],
  material: ['steel'],
  axes: '5-axis',
  specs: [{
    label: 'X Travel',
    value: '12,000 mm'
  }, {
    label: 'Ram Stroke',
    value: '1,500 mm'
  }, {
    label: 'Spindle',
    value: '50T'
  }, {
    label: 'Origin',
    value: 'USA'
  }]
}, {
  id: 'ms-hpx150',
  builder: 'Mitsui Seiki',
  name: 'HPX150 5-Axis Machining Center',
  photo: 'mitsui-seiki-hpx150.webp',
  process: '5axis',
  application: ['engine', 'precision'],
  material: ['titanium', 'aluminum'],
  axes: '5-axis',
  specs: [{
    label: 'X/Y/Z',
    value: '1500×1300×1400'
  }, {
    label: 'Spindle',
    value: '50T · 12,000 rpm'
  }, {
    label: 'Accuracy',
    value: '±0.003 mm'
  }, {
    label: 'Origin',
    value: 'Japan'
  }]
}, {
  id: 'ms-vertex55x',
  builder: 'Mitsui Seiki',
  name: 'Vertex 55X 5-Axis VMC',
  process: '5axis',
  application: ['precision', 'engine'],
  material: ['titanium', 'aluminum', 'steel'],
  axes: '5-axis',
  specs: [{
    label: 'X/Y/Z',
    value: '550×620×510'
  }, {
    label: 'Spindle',
    value: '40T · 20,000 rpm'
  }, {
    label: 'Accuracy',
    value: '±0.002 mm'
  }, {
    label: 'Origin',
    value: 'Japan'
  }]
}, {
  id: 'ms-j350g',
  builder: 'Mitsui Seiki',
  name: 'J350G Jig Grinder',
  process: '5axis',
  application: ['precision'],
  material: ['steel', 'titanium'],
  axes: '4-axis',
  specs: [{
    label: 'Table',
    value: '500×350 mm'
  }, {
    label: 'Spindle',
    value: '60,000 rpm'
  }, {
    label: 'Accuracy',
    value: '±0.001 mm'
  }, {
    label: 'Origin',
    value: 'Japan'
  }]
}, {
  id: 'br-ultrix1000',
  builder: 'Breton',
  name: 'Ultrix 1000 5-Axis Gantry',
  process: 'gantry',
  application: ['composite', 'structural'],
  material: ['composite', 'aluminum'],
  axes: '5-axis',
  specs: [{
    label: 'Work Area',
    value: '10,000×3,000'
  }, {
    label: 'Spindle',
    value: 'HSK-A63 · 24k rpm'
  }, {
    label: 'Heads',
    value: 'Mill + Turn'
  }, {
    label: 'Origin',
    value: 'Italy'
  }]
}, {
  id: 'br-genesi',
  builder: 'Breton',
  name: 'Genesi Trunnion Mill-Turn',
  photo: 'breton-genesi.webp',
  process: 'gantry',
  application: ['composite', 'engine'],
  material: ['composite', 'titanium'],
  axes: '5-axis',
  specs: [{
    label: 'Swing',
    value: '1,600 mm'
  }, {
    label: 'Trunnion',
    value: '±120°'
  }, {
    label: 'Spindle',
    value: 'HSK-A100'
  }, {
    label: 'Origin',
    value: 'Italy'
  }]
}, {
  id: 'br-xceeder',
  builder: 'Breton',
  name: 'Xceeder Large-Format Additive',
  process: 'gantry',
  application: ['composite', 'structural'],
  material: ['composite'],
  axes: '5-axis',
  specs: [{
    label: 'Build Vol.',
    value: '6,000×2,000'
  }, {
    label: 'Process',
    value: 'Hybrid additive'
  }, {
    label: 'Heads',
    value: 'Deposit + Mill'
  }, {
    label: 'Origin',
    value: 'Italy'
  }]
}, {
  id: 'ix-g220',
  builder: 'Index',
  name: 'G220 Turn-Mill Center',
  process: 'turning',
  application: ['precision', 'engine'],
  material: ['titanium', 'steel', 'aluminum'],
  axes: '5-axis',
  specs: [{
    label: 'Swing',
    value: '220 mm'
  }, {
    label: 'Bar Cap.',
    value: '65 mm'
  }, {
    label: 'Spindles',
    value: 'Main + Counter'
  }, {
    label: 'Origin',
    value: 'Germany'
  }]
}, {
  id: 'ix-ms40',
  builder: 'Index',
  name: 'MS40 Multi-Spindle Lathe',
  process: 'turning',
  application: ['precision'],
  material: ['steel', 'aluminum'],
  axes: '4-axis',
  specs: [{
    label: 'Spindles',
    value: '6 × Ø40 mm'
  }, {
    label: 'Bar Cap.',
    value: '40 mm'
  }, {
    label: 'Output',
    value: 'High volume'
  }, {
    label: 'Origin',
    value: 'Germany'
  }]
}, {
  id: 'ix-c200',
  builder: 'Index',
  name: 'C200 Production Turn-Mill',
  process: 'turning',
  application: ['precision', 'structural'],
  material: ['aluminum', 'steel'],
  axes: '4-axis',
  specs: [{
    label: 'Swing',
    value: '200 mm'
  }, {
    label: 'Bar Cap.',
    value: '51 mm'
  }, {
    label: 'Spindle',
    value: '6,000 rpm'
  }, {
    label: 'Origin',
    value: 'Germany'
  }]
}];
const APPLICATIONS = [{
  id: 'structural',
  label: 'Aerospace Structural',
  icon: 'Shield',
  desc: 'Large frames, spars, bulkheads'
}, {
  id: 'engine',
  label: 'Turbine / Engine',
  icon: 'Gauge',
  desc: 'Blades, discs, casings'
}, {
  id: 'composite',
  label: 'Composites',
  icon: 'Globe',
  desc: 'Layups, trimming, additive'
}, {
  id: 'precision',
  label: 'General Precision',
  icon: 'Cog',
  desc: 'Tight-tolerance components'
}];
const PROCESSES = [{
  id: 'boring',
  label: 'Boring / Milling'
}, {
  id: '5axis',
  label: '5-Axis Machining'
}, {
  id: 'turning',
  label: 'Turning / Turn-Mill'
}, {
  id: 'gantry',
  label: 'Gantry / Large-Format'
}];
const MATERIALS = [{
  id: 'aluminum',
  label: 'Aluminum'
}, {
  id: 'titanium',
  label: 'Titanium / Inconel'
}, {
  id: 'composite',
  label: 'Composites'
}, {
  id: 'steel',
  label: 'Steel'
}];
function builderLogo(name, h = 26) {
  return /*#__PURE__*/React.createElement("img", {
    src: `${A}/vendors/${BUILDERS[name].logo}`,
    alt: name,
    style: {
      maxHeight: h,
      maxWidth: 130,
      objectFit: 'contain'
    }
  });
}

/* ---------------- Quote modal ---------------- */
function QuoteModal({
  open,
  machine,
  onClose
}) {
  const [sent, setSent] = useState(false);
  React.useEffect(() => {
    if (open) setSent(false);
  }, [open]);
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'fixed',
      inset: 0,
      zIndex: 110,
      background: 'rgba(15,20,27,0.6)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 20
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      background: '#fff',
      borderRadius: 'var(--radius-md)',
      borderTop: 'var(--edge-accent)',
      width: 'min(540px,100%)',
      boxShadow: 'var(--shadow-lg)',
      maxHeight: '90vh',
      overflow: 'auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'flex-start',
      padding: 'var(--space-5) var(--space-6)',
      borderBottom: '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Eyebrow, null, "Request a Quote"), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '8px 0 0'
    }
  }, machine ? machine.name : 'Tell us about your project'), machine && /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-sm)',
      color: 'var(--text-muted)',
      margin: '4px 0 0'
    }
  }, machine.builder)), /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    style: {
      border: 'none',
      background: 'var(--steel-100)',
      borderRadius: 'var(--radius-md)',
      width: 38,
      height: 38,
      cursor: 'pointer',
      color: 'var(--rms-navy)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(I.X, {
    size: 20
  }))), sent ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--space-8) var(--space-6)',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--status-success)',
      display: 'flex',
      justifyContent: 'center',
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement(I.CheckCircle, {
    size: 48
  })), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '0 0 8px'
    }
  }, "Request received"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--text-body)',
      margin: '0 0 22px'
    }
  }, "A Ross Machinery specialist will be in touch within one business day."), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    onClick: onClose
  }, "Done")) : /*#__PURE__*/React.createElement("form", {
    onSubmit: e => {
      e.preventDefault();
      setSent(true);
    },
    style: {
      padding: 'var(--space-6)',
      display: 'grid',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Full name",
    placeholder: "Jane Doe",
    required: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Company",
    placeholder: "Acme Aerospace",
    required: true
  })), /*#__PURE__*/React.createElement(Input, {
    label: "Email",
    type: "email",
    placeholder: "you@company.com",
    required: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Application notes",
    multiline: true,
    placeholder: "Materials, tolerances, volumes\u2026"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'flex-end',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    type: "button",
    onClick: onClose
  }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    type: "submit",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 17
    })
  }, "Submit request")))));
}

/* ---------------- Top bar + concept switcher ---------------- */
function TopBar({
  concept,
  setConcept,
  onQuote
}) {
  return /*#__PURE__*/React.createElement("header", {
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 60,
      background: '#fff',
      borderBottom: '1px solid var(--border-subtle)',
      boxShadow: 'var(--shadow-xs)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1280,
      margin: '0 auto',
      padding: '0 28px',
      height: 68,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 24
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/logos/rms-logo-color.png`,
    alt: "Ross Machinery",
    style: {
      height: 40
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      background: 'var(--steel-100)',
      borderRadius: 'var(--radius-pill)',
      padding: 4
    }
  }, [['finder', 'Capability Finder'], ['showroom', 'Partner Showroom']].map(([id, label]) => /*#__PURE__*/React.createElement("button", {
    key: id,
    onClick: () => setConcept(id),
    style: {
      border: 'none',
      cursor: 'pointer',
      borderRadius: 'var(--radius-pill)',
      padding: '8px 16px',
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      background: concept === id ? 'var(--rms-navy)' : 'transparent',
      color: concept === id ? '#fff' : 'var(--text-muted)',
      transition: 'all var(--dur-fast) var(--ease-standard)'
    }
  }, label))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 18
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7,
      font: 'var(--type-body-sm)',
      fontWeight: 600,
      color: 'var(--rms-navy)'
    }
  }, /*#__PURE__*/React.createElement(I.Phone, {
    size: 15
  }), " +1.203.269.2950"), /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    onClick: () => onQuote(null)
  }, "Request a Quote"))));
}
Object.assign(window, {
  RmsData: {
    BUILDERS,
    MACHINES,
    APPLICATIONS,
    PROCESSES,
    MATERIALS,
    builderLogo
  },
  RmsConcepts: {
    QuoteModal,
    TopBar
  }
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/concepts/shared.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/Sections.jsx
try { (() => {
// Ross Machinery — marketing website sections.
// Composes design-system primitives from the bundle + RmsIcons.
const React = window.React;
const {
  useState
} = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const {
  Button,
  Badge,
  Card,
  Eyebrow,
  SpecList,
  Input
} = DS;
const I = window.RmsIcons;
const A = '../../assets';
const MAXW = 'var(--container-max)';
const wrap = {
  maxWidth: MAXW,
  margin: '0 auto',
  padding: '0 var(--container-pad)'
};

/* ---------------- Header ---------------- */
function Header({
  onQuote,
  active = 'Home'
}) {
  const nav = ['Machines', 'Services', 'About', 'Contact'];
  return /*#__PURE__*/React.createElement("header", {
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 50
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--rms-navy)',
      color: '#fff'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      height: 38,
      fontSize: 13
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 24,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7
    }
  }, /*#__PURE__*/React.createElement(I.Phone, {
    size: 14
  }), " +1.203.269.2950"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7
    }
  }, /*#__PURE__*/React.createElement(I.Mail, {
    size: 14
  }), " office@rossmachinery.com")), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--rms-yellow)',
      fontWeight: 600,
      letterSpacing: '0.04em',
      textTransform: 'uppercase',
      fontSize: 12
    }
  }, "Serving Aerospace & Advanced Manufacturing"))), /*#__PURE__*/React.createElement("div", {
    style: {
      background: '#fff',
      borderBottom: '1px solid var(--border-subtle)',
      boxShadow: 'var(--shadow-xs)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      height: 76
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/logos/rms-logo-color.png`,
    alt: "Ross Machinery",
    style: {
      height: 44
    }
  }), /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      gap: 34,
      alignItems: 'center'
    }
  }, ['Home', ...nav].map(n => /*#__PURE__*/React.createElement("a", {
    key: n,
    href: "#",
    onClick: e => e.preventDefault(),
    style: {
      fontWeight: 600,
      fontSize: 15,
      textDecoration: 'none',
      color: n === active ? 'var(--rms-navy)' : 'var(--text-body)',
      borderBottom: n === active ? '3px solid var(--rms-yellow)' : '3px solid transparent',
      paddingBottom: 4
    }
  }, n))), /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    onClick: onQuote
  }, "Request Consultation"))));
}

/* ---------------- Hero ---------------- */
function Hero({
  onQuote
}) {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      position: 'relative',
      background: 'var(--rms-navy-900)',
      color: '#fff',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/world-map.png`,
    alt: "",
    style: {
      position: 'absolute',
      inset: 0,
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      opacity: 0.08
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      position: 'relative',
      display: 'grid',
      gridTemplateColumns: '1.05fr 0.95fr',
      gap: 'var(--space-8)',
      alignItems: 'center',
      padding: '84px var(--container-pad)'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Eyebrow, {
    color: "var(--rms-yellow)"
  }, "Aerospace & Advanced Manufacturing"), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-display-lg)',
      lineHeight: 1.04,
      fontStyle: 'italic',
      textTransform: 'uppercase',
      letterSpacing: '-0.01em',
      margin: '18px 0 0'
    }
  }, "Your Partner in", /*#__PURE__*/React.createElement("br", null), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--rms-yellow)'
    }
  }, "Advanced"), " Manufacturing"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      color: 'var(--steel-300)',
      maxWidth: 520,
      margin: '22px 0 32px'
    }
  }, "World-class industrial equipment and comprehensive support services for leading aerospace and advanced manufacturing companies."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    size: "lg",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 18
    }),
    onClick: onQuote
  }, "Explore Our Machines"), /*#__PURE__*/React.createElement(Button, {
    variant: "outline",
    size: "lg",
    iconLeft: /*#__PURE__*/React.createElement(I.Phone, {
      size: 18
    }),
    style: {
      color: '#fff',
      borderColor: 'rgba(255,255,255,0.4)',
      background: 'rgba(255,255,255,0.06)'
    }
  }, "Get In Touch"))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 18,
      left: 18,
      width: '100%',
      height: '100%',
      border: '3px solid var(--rms-yellow)',
      borderRadius: 'var(--radius-md)'
    }
  }), /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/hero-machining.webp`,
    alt: "CNC machining",
    style: {
      position: 'relative',
      width: '100%',
      height: 380,
      objectFit: 'cover',
      borderRadius: 'var(--radius-md)',
      boxShadow: 'var(--shadow-lg)'
    }
  }))));
}

/* ---------------- Trust bar ---------------- */
function TrustBar() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      background: '#fff',
      borderBottom: '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      padding: '34px var(--container-pad)',
      display: 'flex',
      alignItems: 'center',
      gap: 48,
      flexWrap: 'wrap',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-eyebrow)',
      textTransform: 'uppercase',
      letterSpacing: '0.14em',
      color: 'var(--text-muted)'
    }
  }, "Trusted by industry leaders"), /*#__PURE__*/React.createElement("img", {
    src: `${A}/vendors/sikorsky.png`,
    alt: "Sikorsky",
    style: {
      height: 30,
      objectFit: 'contain',
      filter: 'grayscale(1)',
      opacity: 0.7
    }
  }), ['Collins Aerospace', 'Precision Mfg Corp', 'Aerospace Solutions'].map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      font: 'var(--type-body)',
      fontWeight: 600,
      color: 'var(--steel-400)'
    }
  }, c))));
}

/* ---------------- Stats ---------------- */
function Stats() {
  const data = [{
    n: '30+',
    l: 'Years of industrial expertise'
  }, {
    n: '4',
    l: 'World-class manufacturing partners'
  }, {
    n: '5-Axis',
    l: 'Precision machining specialists'
  }, {
    n: '24/7',
    l: 'Service & technical support'
  }];
  return /*#__PURE__*/React.createElement("section", {
    style: {
      background: 'var(--rms-navy)',
      color: '#fff'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      display: 'grid',
      gridTemplateColumns: 'repeat(4,1fr)',
      padding: '46px var(--container-pad)'
    }
  }, data.map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      textAlign: 'center',
      padding: '0 16px',
      borderLeft: i ? '1px solid rgba(255,255,255,0.14)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-display-sm)',
      color: 'var(--rms-yellow)',
      fontStyle: 'italic'
    }
  }, d.n), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-body-sm)',
      color: 'var(--steel-300)',
      marginTop: 6
    }
  }, d.l)))));
}

/* ---------------- Machines / Partners ---------------- */
const VENDORS = [{
  name: 'Fives Giddings & Lewis',
  logo: 'fives-giddings-lewis.png',
  tag: 'Horizontal Boring Mills',
  desc: 'Wisconsin-built heavy-duty horizontal boring mills, machining centers and vertical turning centers with endless custom configurations.',
  specs: [{
    label: 'Type',
    value: 'HBM / VTC'
  }, {
    label: 'Origin',
    value: 'USA'
  }]
}, {
  name: 'Mitsui Seiki',
  logo: 'mitsui-seiki.webp',
  tag: '4 & 5 Axis Precision',
  desc: 'High-precision 4 & 5 axis horizontal and vertical machining centers, jig bores and jig grinders. 5-year accuracy guarantee on every machine.',
  specs: [{
    label: 'Accuracy',
    value: '±0.003 mm'
  }, {
    label: 'Origin',
    value: 'Japan'
  }]
}, {
  name: 'Breton',
  logo: 'breton.jpg',
  tag: 'Gantry Machine Tools',
  desc: 'Highly productive gantry-style machine tools for composites through hard-to-machine aerospace alloys, including large-format additive.',
  specs: [{
    label: 'Type',
    value: '5-Axis Gantry'
  }, {
    label: 'Origin',
    value: 'Italy'
  }]
}, {
  name: 'Index',
  logo: 'index.png',
  tag: '5 Axis Turn-Mills',
  desc: 'High-production turning machines, multi-spindle lathes and 5-axis turn-mill centers combining multiple operations into one platform.',
  specs: [{
    label: 'Type',
    value: 'Turn-Mill'
  }, {
    label: 'Origin',
    value: 'Germany'
  }]
}];
function Machines({
  onQuote
}) {
  const [open, setOpen] = useState(null);
  return /*#__PURE__*/React.createElement("section", {
    style: {
      background: 'var(--steel-50)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      padding: '76px var(--container-pad)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      maxWidth: 720,
      margin: '0 auto 48px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(Eyebrow, null, "World-Class Partners")), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: 'var(--type-display-md)',
      color: 'var(--rms-navy)',
      margin: '14px 0 12px'
    }
  }, "Manufacturing Partners"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      color: 'var(--text-body)',
      margin: 0
    }
  }, "We represent the finest machine-tool builders from Germany, Italy, Japan and the USA \u2014 bringing cutting-edge technology to aerospace and advanced manufacturing.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(2,1fr)',
      gap: 24
    }
  }, VENDORS.map(v => /*#__PURE__*/React.createElement(Card, {
    key: v.name,
    accentEdge: true,
    interactive: true,
    padding: "0"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      height: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 16,
      padding: 'var(--space-5) var(--space-5) var(--space-4)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 48,
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/vendors/${v.logo}`,
    alt: v.name,
    style: {
      maxHeight: 48,
      maxWidth: 170,
      objectFit: 'contain'
    }
  })), /*#__PURE__*/React.createElement(Badge, {
    tone: "yellow",
    variant: "soft"
  }, v.tag)), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 var(--space-5) var(--space-5)',
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '0 0 8px'
    }
  }, v.name), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-sm)',
      color: 'var(--text-body)',
      margin: '0 0 16px'
    }
  }, v.desc), open === v.name && /*#__PURE__*/React.createElement("div", {
    style: {
      marginBottom: 16
    }
  }, /*#__PURE__*/React.createElement(SpecList, {
    items: v.specs
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "outline",
    onClick: () => setOpen(open === v.name ? null : v.name)
  }, open === v.name ? 'Hide specs' : 'View specs'), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 15
    }),
    onClick: onQuote
  }, "Request a quote")))))))));
}

/* ---------------- Media band ---------------- */
function MediaBand() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      position: 'relative',
      height: 360,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      color: '#fff'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: `${A}/images/quality-control.png`,
    alt: "Precision turning",
    style: {
      position: 'absolute',
      inset: 0,
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'linear-gradient(180deg, rgba(0,38,71,0.55), rgba(0,38,71,0.78))'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      maxWidth: 700,
      padding: '0 24px'
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      font: 'var(--type-display-md)',
      fontStyle: 'italic',
      textTransform: 'uppercase',
      margin: '0 0 12px'
    }
  }, "Precision ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--rms-yellow)'
    }
  }, "Engineered")), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      opacity: 0.92,
      margin: 0
    }
  }, "Every machine we deliver meets the highest standards of precision and reliability \u2014 backed by comprehensive support and service excellence.")));
}

/* ---------------- Services ---------------- */
const SERVICES = [{
  icon: 'Cog',
  title: 'Machine Sales & Consultation',
  desc: 'Expert guidance selecting the right machinery for your aerospace and manufacturing needs.'
}, {
  icon: 'Wrench',
  title: 'Maintenance & Service',
  desc: 'Comprehensive maintenance programs and emergency repair to keep your operations running.'
}, {
  icon: 'Shield',
  title: 'Parts & Support',
  desc: 'Fast parts ordering and technical support from our experienced team of specialists.'
}, {
  icon: 'Users',
  title: 'Training & Optimization',
  desc: 'Operator training and process optimization to maximize your equipment investment.'
}];
function Services() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      background: '#fff'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      padding: '76px var(--container-pad)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      maxWidth: 720,
      margin: '0 auto 48px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(Eyebrow, null, "Full Lifecycle")), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: 'var(--type-display-md)',
      color: 'var(--rms-navy)',
      margin: '14px 0 12px'
    }
  }, "Comprehensive Support"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      color: 'var(--text-body)',
      margin: 0
    }
  }, "Beyond machinery sales, we provide complete lifecycle support so your equipment operates at peak performance throughout its service life.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(4,1fr)',
      gap: 22
    }
  }, SERVICES.map(s => {
    const Ic = I[s.icon];
    return /*#__PURE__*/React.createElement(Card, {
      key: s.title,
      interactive: true,
      style: {
        textAlign: 'center'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 56,
        height: 56,
        margin: '0 auto 16px',
        borderRadius: 'var(--radius-md)',
        background: 'var(--rms-blue-100)',
        color: 'var(--rms-blue)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }
    }, /*#__PURE__*/React.createElement(Ic, {
      size: 26
    })), /*#__PURE__*/React.createElement("h3", {
      style: {
        font: 'var(--type-h4)',
        color: 'var(--rms-navy)',
        margin: '0 0 8px'
      }
    }, s.title), /*#__PURE__*/React.createElement("p", {
      style: {
        font: 'var(--type-body-sm)',
        color: 'var(--text-body)',
        margin: 0
      }
    }, s.desc));
  }))));
}

/* ---------------- CTA ---------------- */
function CTA({
  onQuote
}) {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      background: 'var(--rms-navy)',
      color: '#fff'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      padding: '72px var(--container-pad)',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      font: 'var(--type-display-md)',
      fontStyle: 'italic',
      textTransform: 'uppercase',
      margin: '0 0 14px'
    }
  }, "Ready to Enhance Your ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--rms-yellow)'
    }
  }, "Capabilities?")), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-lg)',
      color: 'var(--steel-300)',
      maxWidth: 600,
      margin: '0 auto 30px'
    }
  }, "Our team of experts is ready to help you find the perfect machinery solution for your aerospace and manufacturing needs."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    size: "lg",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 18
    }),
    onClick: onQuote
  }, "Request a Quote"), /*#__PURE__*/React.createElement(Button, {
    variant: "outline",
    size: "lg",
    style: {
      color: '#fff',
      borderColor: 'rgba(255,255,255,0.4)',
      background: 'rgba(255,255,255,0.06)'
    }
  }, "Call +1.203.269.2950"))));
}

/* ---------------- Footer ---------------- */
function Footer() {
  const cols = [{
    h: 'Machines',
    items: ['Fives Giddings & Lewis', 'Mitsui Seiki', 'Breton', 'Index']
  }, {
    h: 'Services',
    items: ['Sales & Consultation', 'Maintenance', 'Parts & Support', 'Training']
  }, {
    h: 'Company',
    items: ['About Us', 'Our Process', 'Careers', 'Contact']
  }];
  return /*#__PURE__*/React.createElement("footer", {
    style: {
      background: 'var(--rms-navy-950)',
      color: 'var(--steel-300)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      display: 'grid',
      gridTemplateColumns: '1.4fr 1fr 1fr 1fr',
      gap: 40,
      padding: '56px var(--container-pad) 36px'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("img", {
    src: `${A}/logos/rms-logo-white.png`,
    alt: "Ross Machinery",
    style: {
      height: 40,
      marginBottom: 18
    }
  }), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body-sm)',
      maxWidth: 280,
      margin: '0 0 16px'
    }
  }, "Your partner in advanced manufacturing solutions for the aerospace industry."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      font: 'var(--type-body-sm)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(I.Phone, {
    size: 15
  }), " +1.203.269.2950"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(I.Mail, {
    size: 15
  }), " office@rossmachinery.com"))), cols.map(c => /*#__PURE__*/React.createElement("div", {
    key: c.h
  }, /*#__PURE__*/React.createElement("h4", {
    style: {
      font: 'var(--type-h4)',
      color: '#fff',
      margin: '0 0 16px'
    }
  }, c.h), /*#__PURE__*/React.createElement("ul", {
    style: {
      listStyle: 'none',
      padding: 0,
      margin: 0,
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, c.items.map(it => /*#__PURE__*/React.createElement("li", {
    key: it
  }, /*#__PURE__*/React.createElement("a", {
    href: "#",
    onClick: e => e.preventDefault(),
    style: {
      color: 'var(--steel-300)',
      textDecoration: 'none',
      font: 'var(--type-body-sm)'
    }
  }, it))))))), /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: '1px solid rgba(255,255,255,0.1)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...wrap,
      padding: '18px var(--container-pad)',
      display: 'flex',
      justifyContent: 'space-between',
      font: 'var(--type-caption)',
      color: 'var(--steel-500)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "\xA9 2026 Ross Machinery Sales. All rights reserved."), /*#__PURE__*/React.createElement("span", null, "Aerospace & Advanced Manufacturing \xB7 Connecticut, USA"))));
}

/* ---------------- Quote modal ---------------- */
function QuoteModal({
  open,
  onClose
}) {
  const [sent, setSent] = useState(false);
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'fixed',
      inset: 0,
      zIndex: 110,
      background: 'rgba(15,20,27,0.6)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 20
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      background: '#fff',
      borderRadius: 'var(--radius-md)',
      borderTop: 'var(--edge-accent)',
      width: 'min(560px, 100%)',
      boxShadow: 'var(--shadow-lg)',
      maxHeight: '90vh',
      overflow: 'auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: 'var(--space-5) var(--space-6)',
      borderBottom: '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Eyebrow, null, "Request a Quote"), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '8px 0 0'
    }
  }, "Tell us about your project")), /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    style: {
      border: 'none',
      background: 'var(--steel-100)',
      borderRadius: 'var(--radius-md)',
      width: 38,
      height: 38,
      cursor: 'pointer',
      color: 'var(--rms-navy)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(I.X, {
    size: 20
  }))), sent ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--space-8) var(--space-6)',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--status-success)',
      display: 'flex',
      justifyContent: 'center',
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement(I.CheckCircle, {
    size: 48
  })), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: 'var(--type-h2)',
      color: 'var(--rms-navy)',
      margin: '0 0 8px'
    }
  }, "Request received"), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--text-body)',
      margin: '0 0 22px'
    }
  }, "A Ross Machinery specialist will be in touch within one business day."), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    onClick: onClose
  }, "Done")) : /*#__PURE__*/React.createElement("form", {
    onSubmit: e => {
      e.preventDefault();
      setSent(true);
    },
    style: {
      padding: 'var(--space-6)',
      display: 'grid',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Full name",
    placeholder: "Jane Doe",
    required: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Company",
    placeholder: "Acme Aerospace",
    required: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Email",
    type: "email",
    placeholder: "you@company.com",
    required: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Phone",
    placeholder: "+1 (203) 555-0100"
  })), /*#__PURE__*/React.createElement(Input, {
    label: "What are you looking to machine?",
    multiline: true,
    placeholder: "Application, materials, tolerances, volumes\u2026"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'flex-end',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    type: "button",
    onClick: onClose
  }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
    variant: "accent",
    type: "submit",
    iconRight: /*#__PURE__*/React.createElement(I.ArrowRight, {
      size: 17
    })
  }, "Submit request")))));
}
Object.assign(window, {
  RmsSite: {
    Header,
    Hero,
    TrustBar,
    Stats,
    Machines,
    MediaBand,
    Services,
    CTA,
    Footer,
    QuoteModal
  }
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/Sections.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/icons.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// Lucide-style icons (stroke 2, 24x24) — matches the icon system used in the
// Ross Machinery codebase (lucide-react). Exported to window for the UI kit.
const React = window.React;
function Icon({
  children,
  size = 24,
  stroke = 2,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("svg", _extends({
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: style
  }, rest), children);
}
const ArrowRight = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M5 12h14"
}), /*#__PURE__*/React.createElement("path", {
  d: "m13 6 6 6-6 6"
}));
const Phone = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"
}));
const Mail = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("rect", {
  width: "20",
  height: "16",
  x: "2",
  y: "4",
  rx: "2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"
}));
const Cog = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 2v2"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 22v-2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m17 20.66-1-1.73"
}), /*#__PURE__*/React.createElement("path", {
  d: "M11 10.27 7 3.34"
}), /*#__PURE__*/React.createElement("path", {
  d: "m20.66 17-1.73-1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m3.34 7 1.73 1"
}), /*#__PURE__*/React.createElement("path", {
  d: "M14 12h8"
}), /*#__PURE__*/React.createElement("path", {
  d: "M2 12h2"
}), /*#__PURE__*/React.createElement("path", {
  d: "m20.66 7-1.73 1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m3.34 17 1.73-1"
}), /*#__PURE__*/React.createElement("path", {
  d: "m17 3.34-1 1.73"
}), /*#__PURE__*/React.createElement("path", {
  d: "m11 13.73-4 6.93"
}));
const Wrench = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"
}));
const Shield = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"
}));
const Users = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"
}), /*#__PURE__*/React.createElement("circle", {
  cx: "9",
  cy: "7",
  r: "4"
}), /*#__PURE__*/React.createElement("path", {
  d: "M22 21v-2a4 4 0 0 0-3-3.87"
}), /*#__PURE__*/React.createElement("path", {
  d: "M16 3.13a4 4 0 0 1 0 7.75"
}));
const CheckCircle = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M21.801 10A10 10 0 1 1 17 3.335"
}), /*#__PURE__*/React.createElement("path", {
  d: "m9 11 3 3L22 4"
}));
const Quote = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H21a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"
}), /*#__PURE__*/React.createElement("path", {
  d: "M3 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H8a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"
}));
const MapPin = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"
}), /*#__PURE__*/React.createElement("circle", {
  cx: "12",
  cy: "10",
  r: "3"
}));
const X = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "M18 6 6 18"
}), /*#__PURE__*/React.createElement("path", {
  d: "m6 6 12 12"
}));
const Menu = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "6",
  y2: "6"
}), /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "12",
  y2: "12"
}), /*#__PURE__*/React.createElement("line", {
  x1: "4",
  x2: "20",
  y1: "18",
  y2: "18"
}));
const Globe = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("circle", {
  cx: "12",
  cy: "12",
  r: "10"
}), /*#__PURE__*/React.createElement("path", {
  d: "M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"
}), /*#__PURE__*/React.createElement("path", {
  d: "M2 12h20"
}));
const Gauge = p => /*#__PURE__*/React.createElement(Icon, p, /*#__PURE__*/React.createElement("path", {
  d: "m12 14 4-4"
}), /*#__PURE__*/React.createElement("path", {
  d: "M3.34 19a10 10 0 1 1 17.32 0"
}));
Object.assign(window, {
  RmsIcons: {
    ArrowRight,
    Phone,
    Mail,
    Cog,
    Wrench,
    Shield,
    Users,
    CheckCircle,
    Quote,
    MapPin,
    X,
    Menu,
    Globe,
    Gauge
  }
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/icons.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Eyebrow = __ds_scope.Eyebrow;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.SpecList = __ds_scope.SpecList;

})();
