import * as React from 'react';

export interface EyebrowProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Show the leading yellow tick mark. @default true */
  tick?: boolean;
  /** Text color. @default var(--rms-blue) */
  color?: string;
  children?: React.ReactNode;
}

/** Uppercase tracked kicker label that sits above a heading. */
export function Eyebrow(props: EyebrowProps): JSX.Element;
