import * as React from 'react';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Visual style. @default "primary" */
  variant?: 'primary' | 'secondary' | 'accent' | 'outline' | 'ghost';
  /** Size. @default "md" */
  size?: 'sm' | 'md' | 'lg';
  /** Icon element rendered before the label. */
  iconLeft?: React.ReactNode;
  /** Icon element rendered after the label. */
  iconRight?: React.ReactNode;
  disabled?: boolean;
  children?: React.ReactNode;
}

/**
 * Primary action button for Ross Machinery interfaces.
 *
 * @startingPoint section="Core" subtitle="Buttons in every variant & size" viewport="700x260"
 */
export function Button(props: ButtonProps): JSX.Element;
