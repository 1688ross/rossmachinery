import * as React from 'react';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Color tone. @default "blue" */
  tone?: 'navy' | 'blue' | 'yellow' | 'neutral' | 'success' | 'danger';
  /** Fill style. @default "soft" */
  variant?: 'solid' | 'soft' | 'outline';
  children?: React.ReactNode;
}

/** Compact pill label for status, category, or machine speciality. */
export function Badge(props: BadgeProps): JSX.Element;
