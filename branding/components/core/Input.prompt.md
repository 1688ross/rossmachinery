Labelled text field for forms — quote requests, contact, RFQ.

```jsx
<Input label="Company" placeholder="Acme Aerospace" required />
<Input label="Details" multiline hint="Tell us about your application." />
```

Pass `error` to show a validation message and red border; `hint` for helper text; `multiline` for a textarea. Forwards all native input attributes.
