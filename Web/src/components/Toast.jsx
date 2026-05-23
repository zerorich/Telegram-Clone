import { useEffect } from 'react'
import { useUiStore } from '../store/uiStore.js'
import styles from './Toast.module.css'

export function Toast() {
  const toast = useUiStore((s) => s.toast)
  const dismiss = useUiStore((s) => s.dismissToast)

  useEffect(() => {
    if (!toast) return undefined
    const id = setTimeout(dismiss, toast.duration ?? 4000)
    return () => clearTimeout(id)
  }, [toast, dismiss])

  if (!toast) return null
  return (
    <div className={styles.wrap} role="status" aria-live="polite">
      <div className={`${styles.toast} ${styles[`k_${toast.kind}`] || ''}`}>
        <span className={styles.text}>{toast.message}</span>
        {toast.action?.label ? (
          <button
            type="button"
            className={styles.action}
            onClick={() => {
              try {
                toast.action.onClick?.()
              } finally {
                dismiss()
              }
            }}
          >
            {toast.action.label}
          </button>
        ) : null}
      </div>
    </div>
  )
}
