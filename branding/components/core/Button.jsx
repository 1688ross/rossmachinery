import React, { useState } from 'react';

const SIZES = {
  sm: { padding: '7px 14px', fontSize: '13px', gap: '6px' },
  md: { padding: '11px 20px', fontSize: '15px', gap: '8px' },
  lg: { padding: '15px 28px', fontSize: '17px', gap: '10px' },
};

const VARIANTS = {
  primary: {
    base: { background: 'var(--action-primary)', color: 'var(--action-primary-text)', border: '2px solid var(--action-primary)' },
    hover: { background: 'var(--action-primary-hover)', borderColor: 'var(--action-primary-hover)' },
  },
  secondary: {
    base: { background: 'var(--action-secondary)', color: 'var(--action-secondary-text)', border: '2px solid var(--action-secondary)' },
    hover: { background: 'var(--action-secondary-hover)', borderColor: 'var(--action-secondary-hover)' },
  },
  accent: {
    base: { background: 'var(--action-accent)', color: 'var(--action-accent-text)', border: '2px solid var(--action-accent)' },
    hover: { background: 'var(--action-accent-hover)', borderColor: 'var(--action-accent-hover)' },
  },
  outline: {
    base: { background: 'transparent', color: 'var(--rms-navy)', border: '2px solid var(--border-default)' },
    hover: { borderColor: 'var(--rms-navy)', background: 'var(--steel-50)' },
  },
  ghost: {
    base: { background: 'transparent', color: 'var(--rms-navy)', border: '2px solid transparent' },
    hover: { background: 'var(--steel-100)' },
  },
};

/**
 * Ross Machinery primary action button.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  iconLeft = null,
  iconRight = null,
  disabled = false,
  type = 'button',
  onClick,
  style = {},
  ...rest
}) {
  const [hover, setHover] = useState(false);
  const v = VARIANTS[variant] || VARIANTS.primary;
  const s = SIZES[size] || SIZES.md;

  const composed = {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: s.gap,
    fontFamily: 'var(--font-body)',
    fontWeight: 600,
    fontSize: s.fontSize,
    lineHeight: 1,
    padding: s.padding,
    borderRadius: 'var(--radius-md)',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.45 : 1,
    textDecoration: 'none',
    whiteSpace: 'nowrap',
    transition: 'background var(--dur-fast) var(--ease-standard), border-color var(--dur-fast) var(--ease-standard), transform var(--dur-fast) var(--ease-standard)',
    transform: hover && !disabled ? 'translateY(-1px)' : 'translateY(0)',
    ...v.base,
    ...(hover && !disabled ? v.hover : {}),
    ...style,
  };

  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={composed}
      {...rest}
    >
      {iconLeft}
      {children}
      {iconRight}
    </button>
  );
}
