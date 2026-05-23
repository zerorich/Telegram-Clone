import styles from './Button.module.css'

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  className = '',
  type = 'button',
  ...rest
}) {
  const cls = [
    styles.btn,
    styles[`v_${variant}`],
    styles[`s_${size}`],
    loading ? styles.loading : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      type={type}
      className={cls}
      disabled={loading || rest.disabled}
      {...rest}
    >
      {loading ? <span className={styles.spinner} aria-hidden /> : null}
      <span className={styles.label}>{children}</span>
    </button>
  )
}
