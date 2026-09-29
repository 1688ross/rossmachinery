import * as React from 'react';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Show the signature 3px yellow keyline on top. @default false */
  accentEdge?: boolean;
  /** Enable hover lift + elevated shadow. @default false */
  interactive?: boolean;
  /** CSS padding value. @default var(--space-5) */
  padding?: string;
  children?: React.ReactNode;
}

/** Surface container for content blocks, machines, services and testimonials. */
export function Card(props: CardProps): JSX.Element;
