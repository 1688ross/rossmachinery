Monospaced spec sheet — renders machine specifications as aligned key/value rows.

```jsx
<SpecList items={[
  { label: 'X/Y/Z Travel', value: '1500 × 1300 × 1400 mm' },
  { label: 'Spindle', value: '50 taper · 12,000 rpm' },
  { label: 'Accuracy', value: '±0.003 mm' },
]} />
```

Labels render uppercase mono/muted, values right-aligned navy mono. Rows divide with a hairline; last row has none.
