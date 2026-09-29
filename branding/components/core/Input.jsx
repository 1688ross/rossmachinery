import React, { useState } from 'react';

/**
 * Labelled text input / textarea.
 */
export function Input({
  label,
  hint,
  error,
  type = 'text',
  multiline = false,
  required = false,
  id,
  style = {},
  ...rest
}) {
  const [focus, setFocus] = useState(false);
  const fieldId = id || (label ? `f-${label.replace(/\s+/g, '-').toLowerCase()}` : undefined);

  const fieldStyle = {
    width: '100%',
    boxSizing: 'border-box',
    fontFamily: 'var(--font-body)',
    fontSize: '15px',
    color: 'var(--rms-navy)',
    background: 'var(--white)',
    padding: '11px 13px',
    border: `1px solid ${error ? 'var(--status-danger)' : focus ? 'var(--focus-ring)' : 'var(--border-default)'}`,
    borderRadius: 'var(--radius-md)',
    outline: 'none',
    boxShadow: focus ? '0 0 0 3px rgba(37,118,188,0.18)' : 'none',
    transition: 'border-color var(--dur-fast) var(--ease-standard), box-shadow var(--dur-fast) var(--ease-standard)',
    resize: multiline ? 'vertical' : undefined,
    minHeight: multiline ? '96px' : undefined,
    ...style,
  };

  const Tag = multiline ? 'textarea' : 'input';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
      {label && (
        <label htmlFor={fieldId} style={{ fontFamily: 'var(--font-body)', fontWeight: 600, fontSize: '13px', color: 'var(--rms-navy)' }}>
          {label}{required && <span style={{ color: 'var(--status-danger)', marginLeft: 2 }}>*</span>}
        </label>
      )}
      <Tag
        id={fieldId}
        type={multiline ? undefined : type}
        required={required}
        onFocus={() => setFocus(true)}
        onBlur={() => setFocus(false)}
        style={fieldStyle}
        {...rest}
      />
      {(hint || error) && (
        <span style={{ fontFamily: 'var(--font-body)', fontSize: '12px', color: error ? 'var(--status-danger)' : 'var(--text-muted)' }}>
          {error || hint}
        </span>
      )}
    </div>
  );
}
