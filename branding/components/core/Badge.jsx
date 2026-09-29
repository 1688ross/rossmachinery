import React from 'react';

const TONES = {
  navy:    { solid: ['var(--rms-navy)', '#fff'],         soft: ['var(--blue-100, #dcebf7)', 'var(--rms-navy)'] },
  blue:    { solid: ['var(--rms-blue)', '#fff'],         soft: ['var(--rms-blue-100)', 'var(--rms-blue-700)'] },
  yellow:  { solid: ['var(--rms-yellow)', 'var(--rms-navy)'], soft: ['var(--rms-yellow-100)', 'var(--rms-yellow-700)'] },
  neutral: { solid: ['var(--steel-700)', '#fff'],        soft: ['var(--steel-100)', 'var(--steel-700)'] },
  success: { solid: ['var(--status-success)', '#fff'],   soft: ['#dcefe4', 'var(--status-success)'] },
  danger:  { solid: ['var(--status-danger)', '#fff'],    soft: ['#f6ddda', 'var(--status-danger)'] },
};

/**
 * Compact status / category label.
 */
export function Badge({ children, tone = 'blue', variant = 'soft', style = {}, ...rest }) {
  const t = TONES[tone] || TONES.blue;
  const [bg, fg] = variant === 'solid' ? t.solid : t.soft;
  const isOutline = variant === 'outline';

  const composed = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
    fontFamily: 'var(--font-body)',
    fontWeight: 600,
    fontSize: '12px',
    lineHeight: 1,
    letterSpacing: '0.02em',
    padding: '5px 10px',
    borderRadius: 'var(--radius-pill)',
    background: isOutline ? 'transparent' : bg,
    color: isOutline ? 'var(--rms-navy)' : fg,
    border: isOutline ? '1px solid var(--border-default)' : '1px solid transparent',
    whiteSpace: 'nowrap',
    ...style,
  };

  return <span style={composed} {...rest}>{children}</span>;
}
