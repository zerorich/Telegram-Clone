import { forwardRef } from 'react'
import styles from './Input.module.css'

export const Input = forwardRef(function Input(
  { label, error, hint, className = '', as = 'input', ...rest },
  ref,
) {
  const Tag = as
  return (
    <label className={`${styles.field} ${className}`}>
      {label ? <span className={styles.label}>{label}</span> : null}
      <Tag
        ref={ref}
        className={`${styles.input} ${error ? styles.inputError : ''}`}
        {...rest}
      />
      {error ? (
        <span className={styles.error}>{error}</span>
      ) : hint ? (
        <span className={styles.hint}>{hint}</span>
      ) : null}
    </label>
  )
})
