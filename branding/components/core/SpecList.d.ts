import * as React from 'react';

export interface SpecItem {
  label: string;
  value: React.ReactNode;
}

export interface SpecListProps extends React.HTMLAttributes<HTMLDListElement> {
  /** Spec rows rendered as monospaced key/value pairs. */
  items: SpecItem[];
}

/** Monospaced spec sheet for machine specifications (travel, spindle, etc.). */
export function SpecList(props: SpecListProps): JSX.Element;
