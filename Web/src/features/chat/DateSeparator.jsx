import styles from './DateSeparator.module.css'

export function DateSeparator({ label }) {
  return (
    <div className={styles.row}>
      <span className={styles.pill}>{label}</span>
    </div>
  )
}
