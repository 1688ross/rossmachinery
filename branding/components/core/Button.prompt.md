Primary action button — use for the main call-to-action on a view; reach for `accent` (yellow) only for the single most important conversion action.

```jsx
<Button variant="accent" size="lg" iconRight={<ArrowIcon />}>Request a Quote</Button>
```

Variants: `primary` (navy, default), `secondary` (steel blue), `accent` (safety yellow — sparingly), `outline`, `ghost`. Sizes: `sm`, `md`, `lg`. Pass `iconLeft` / `iconRight` as SVG nodes. Hover lifts 1px and darkens; disabled drops opacity.
