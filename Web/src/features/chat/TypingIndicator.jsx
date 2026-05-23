import styles from './TypingIndicator.module.css'

export function TypingIndicator({ label = 'печатает' }) {
  return (
    <div className={styles.row} aria-label={`${label}…`}>
      <span className={styles.dot} />
      <span className={styles.dot} />
      <span className={styles.dot} />
      <span className={styles.text}>{label}…</span>
    </div>
  )
}
