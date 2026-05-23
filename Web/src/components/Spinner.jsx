import styles from './Spinner.module.css'

export function Spinner({ size = 22, className = '', label }) {
  return (
    <span
      className={`${styles.spinner} ${className}`}
      style={{ width: size, height: size }}
      role={label ? 'status' : undefined}
      aria-label={label}
    />
  )
}
