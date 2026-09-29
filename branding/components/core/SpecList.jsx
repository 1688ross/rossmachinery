import React from 'react';

/**
 * Monospaced spec sheet — key/value rows for machine specifications.
 * items: [{ label, value }]
 */
export function SpecList({ items = [], style = {}, ...rest }) {
  return (
    <dl style={{ margin: 0, ...style }} {...rest}>
      {items.map((it, i) => (
        <div
          key={i}
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'baseline',
            gap: '16px',
            padding: '11px 0',
            borderBottom: i === items.length - 1 ? 'none' : '1px solid var(--border-subtle)',
          }}
        >
          <dt style={{
            fontFamily: 'var(--font-mono)', fontSize: '12px', fontWeight: 600,
            letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--text-muted)',
          }}>
            {it.label}
          </dt>
          <dd style={{
            margin: 0, fontFamily: 'var(--font-mono)', fontSize: '14px', fontWeight: 500,
            color: 'var(--rms-navy)', textAlign: 'right',
          }}>
            {it.value}
          </dd>
        </div>
      ))}
    </dl>
  );
}
