import styles from './AuthLayout.module.css'

export function AuthLayout({ title, subtitle, children }) {
  return (
    <div className={styles.page}>
      <div className={styles.card}>
        <div className={styles.logo} aria-hidden>
          <svg viewBox="0 0 240 240" width="84" height="84">
            <defs>
              <linearGradient id="logoG" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="#37aee2" />
                <stop offset="1" stopColor="#1e96c8" />
              </linearGradient>
            </defs>
            <circle cx="120" cy="120" r="120" fill="url(#logoG)" />
            <path
              fill="#fff"
              d="M180 70 56 117c-8 3-8 8-1 10l31 10 12 38c2 5 4 7 8 7 4 0 6-2 9-5l17-16 33 24c6 4 10 2 12-6l21-99c2-11-4-15-12-12Z"
            />
            <path
              fill="#c8daea"
              d="M93 137 96 175c2 0 3-1 5-3l20-19-28-16Z"
            />
          </svg>
        </div>
        <h1 className={styles.title}>{title}</h1>
        {subtitle ? <p className={styles.subtitle}>{subtitle}</p> : null}
        {children}
      </div>
    </div>
  )
}
