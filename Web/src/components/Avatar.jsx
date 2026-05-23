import { useMemo, useState } from 'react'
import { Bookmark } from 'lucide-react'
import { avatarColor, avatarInitial } from '../lib/format.js'
import styles from './Avatar.module.css'

export function Avatar({
  src,
  name,
  size = 44,
  alt,
  className = '',
  online,
  saved = false,
}) {
  const [errored, setErrored] = useState(false)
  const initial = avatarInitial(name)
  const colorIdx = useMemo(() => avatarColor(name || src || 'x'), [name, src])

  if (saved) {
    return (
      <div
        className={`${styles.wrap} ${className}`}
        style={{ width: size, height: size }}
      >
        <div
          className={`${styles.circle} ${styles.saved}`}
          style={{ width: size, height: size }}
          aria-hidden="true"
        >
          <Bookmark size={Math.round(size * 0.5)} strokeWidth={2.4} />
        </div>
      </div>
    )
  }

  const style = {
    width: size,
    height: size,
    fontSize: Math.max(12, size * 0.42),
    background: `var(--av-${colorIdx})`,
  }

  const showImage = src && !errored

  return (
    <div
      className={`${styles.wrap} ${className}`}
      style={{ width: size, height: size }}
    >
      <div
        className={styles.circle}
        style={style}
        aria-hidden={showImage ? 'true' : 'false'}
      >
        {showImage ? (
          <img
            src={src}
            alt={alt ?? name ?? ''}
            onError={() => setErrored(true)}
            loading="lazy"
          />
        ) : (
          <span>{initial}</span>
        )}
      </div>
      {online ? <span className={styles.online} aria-label="В сети" /> : null}
    </div>
  )
}
