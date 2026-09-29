---
name: ross-machinery-design
description: Use this skill to generate well-branded interfaces and assets for Ross Machinery Sales (aerospace & advanced-manufacturing equipment dealer), either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the `readme.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and
create static HTML files for the user to view. If working on production code, you can copy
assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or
design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_
production code, depending on the need.

Key facts to internalize:
- Brand = navy `#003363`, steel-blue `#2576BC`, safety-yellow `#FBB51C` (use yellow sparingly).
- Display type = Saira Condensed (substitute for the logo's Rift), often italic + UPPERCASE.
  Body = Barlow. Specs = IBM Plex Mono. No emoji. Lucide line icons (2px stroke).
- Square-leaning, industrial, photographic. No gradient blobs or glassmorphism.
- Tokens live in `tokens/`; load `styles.css`. Components compile to a runtime bundle and are
  reachable as `window.RossMachineryDesignSystem_610e0e.<Name>` in the design-system project;
  in a downloaded copy, read the `.jsx` in `components/core/` directly.
