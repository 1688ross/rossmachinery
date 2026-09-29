import * as React from 'react';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  /** Field label rendered above the control. */
  label?: string;
  /** Helper text below the field. */
  hint?: string;
  /** Error message — turns the field red and replaces the hint. */
  error?: string;
  /** Render a multi-line textarea instead of an input. @default false */
  multiline?: boolean;
  required?: boolean;
}

/** Labelled text input or textarea for forms (quote requests, contact). */
export function Input(props: InputProps): JSX.Element;
