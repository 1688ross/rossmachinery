import React, { useState } from 'react';

/**
 * Surface container. Optional yellow accent edge and hover lift.
 */
export function Card({
  children,
  accentEdge = false,
  interactive = false,
  padding = 'var(--space-5)',
  style = {},
  ...rest
}) {
  const [hover, setHover] = useState(false);
  const composed = {
    background: 'var(--surface-card)',
    border: '1px solid var(--border-subtle)',
    borderTop: accentEdge ? 'var(--edge-accent)' : '1px solid var(--border-subtle)',
    borderRadius: 'var(--radius-md)',
    padding,
    boxShadow: interactive && hover ? 'var(--shadow-card-hover)' : 'var(--shadow-sm)',
    transform: interactive && hover ? 'translateY(-3px)' : 'translateY(0)',
    transition: 'box-shadow var(--dur-base) var(--ease-standard), transform var(--dur-base) var(--ease-standard)',
    ...style,
  };
  return (
    <div
      style={composed}
      onMouseEnter={interactive ? () => setHover(true) : undefined}
      onMouseLeave={interactive ? () => setHover(false) : undefined}
      {...rest}
    >
      {children}
    </div>
  );
}
