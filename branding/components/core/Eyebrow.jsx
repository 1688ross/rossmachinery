import React from 'react';

/**
 * Uppercase tracked label used above headings. Optional yellow tick.
 */
export function Eyebrow({ children, tick = true, color = 'var(--rms-blue)', style = {}, ...rest }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '10px',
        fontFamily: 'var(--font-body)',
        fontWeight: 600,
        fontSize: '13px',
        textTransform: 'uppercase',
        letterSpacing: '0.14em',
        color,
        ...style,
      }}
      {...rest}
    >
      {tick && <span style={{ width: '22px', height: '3px', background: 'var(--rms-yellow)', display: 'inline-block' }} />}
      {children}
    </span>
  );
}
