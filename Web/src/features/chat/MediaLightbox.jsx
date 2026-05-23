import { useEffect } from 'react'
import { createPortal } from 'react-dom'
import { X } from 'lucide-react'
import styles from './MediaLightbox.module.css'

export function MediaLightbox({ item, onClose }) {
  useEffect(() => {
    function onKey(e) {
      if (e.key === 'Escape') onClose?.()
    }
    document.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [onClose])

  if (!item) return null
  return createPortal(
    <div className={styles.backdrop} onClick={onClose}>
      <button
        type="button"
        className={styles.close}
        aria-label="Закрыть"
        onClick={(e) => {
          e.stopPropagation()
          onClose?.()
        }}
      >
        <X size={28} />
      </button>
      <div
        className={styles.content}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        {item.type === 'image' ? (
          <img src={item.src} alt="" />
        ) : (
          <video src={item.src} controls autoPlay playsInline />
        )}
      </div>
    </div>,
    document.body,
  )
}
