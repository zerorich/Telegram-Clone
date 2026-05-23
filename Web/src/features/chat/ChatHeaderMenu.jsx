import { useEffect, useRef, useState } from 'react'
import {
  Bell,
  BellOff,
  Phone,
  Search,
  ArrowUp,
  Eraser,
  Trash2,
  ChevronRight,
  ChevronLeft,
} from 'lucide-react'
import { isChatMuted } from '../../lib/chat.js'
import styles from './ChatHeaderMenu.module.css'

/**
 * Three-dot menu shown under the chat header.
 *
 * Notifications has an inline slide-in submenu with mute presets.
 * The whole menu closes on Esc / click outside.
 */
export function ChatHeaderMenu({
  open,
  chat,
  isSaved,
  onClose,
  onToggleSearch,
  onCall,
  onScrollToTop,
  onClearHistory,
  onDeleteChat,
  onMute,
  onUnmute,
}) {
  const ref = useRef(null)
  const [view, setView] = useState('main') // 'main' | 'notifications'

  useEffect(() => {
    if (!open) return undefined
    setView('main')
    function onKey(e) {
      if (e.key === 'Escape') onClose?.()
    }
    function onPointer(e) {
      if (!ref.current?.contains(e.target)) onClose?.()
    }
    document.addEventListener('keydown', onKey)
    document.addEventListener('mousedown', onPointer)
    return () => {
      document.removeEventListener('keydown', onKey)
      document.removeEventListener('mousedown', onPointer)
    }
  }, [open, onClose])

  if (!open) return null

  const muted = isChatMuted(chat)

  function chooseMute(option) {
    onClose?.()
    if (option === 'on') {
      onUnmute?.()
      return
    }
    if (option === 'forever') {
      onMute?.(null)
      return
    }
    const now = Date.now()
    if (option === '1h') onMute?.(new Date(now + 60 * 60 * 1000).toISOString())
    if (option === '1d')
      onMute?.(new Date(now + 24 * 60 * 60 * 1000).toISOString())
  }

  return (
    <div className={styles.wrap} ref={ref} role="menu">
      <span className={styles.pointer} aria-hidden />
      <div
        className={`${styles.pane} ${
          view === 'notifications' ? styles.paneSub : styles.paneMain
        }`}
      >
        {view === 'main' ? (
          <>
            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => setView('notifications')}
            >
              {muted ? (
                <BellOff size={18} className={styles.iconMuted} />
              ) : (
                <Bell size={18} />
              )}
              <span className={styles.label}>Уведомления</span>
              <ChevronRight size={16} className={styles.chev} />
            </button>

            {isSaved ? null : (
              <button
                type="button"
                role="menuitem"
                className={styles.item}
                onClick={() => {
                  onClose?.()
                  onCall?.()
                }}
              >
                <Phone size={18} />
                <span className={styles.label}>Позвонить</span>
              </button>
            )}

            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => {
                onClose?.()
                onToggleSearch?.()
              }}
            >
              <Search size={18} />
              <span className={styles.label}>Поиск</span>
            </button>

            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => {
                onClose?.()
                onScrollToTop?.()
              }}
            >
              <ArrowUp size={18} />
              <span className={styles.label}>В начало</span>
            </button>

            <div className={styles.sep} aria-hidden />

            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => {
                onClose?.()
                onClearHistory?.()
              }}
            >
              <Eraser size={18} />
              <span className={styles.label}>Очистить историю</span>
            </button>

            {isSaved ? null : (
              <button
                type="button"
                role="menuitem"
                className={`${styles.item} ${styles.danger}`}
                onClick={() => {
                  onClose?.()
                  onDeleteChat?.()
                }}
              >
                <Trash2 size={18} />
                <span className={styles.label}>Удалить чат</span>
              </button>
            )}
          </>
        ) : (
          <>
            <button
              type="button"
              role="menuitem"
              className={`${styles.item} ${styles.itemBack}`}
              onClick={() => setView('main')}
            >
              <ChevronLeft size={16} className={styles.chev} />
              <span className={styles.label}>Уведомления</span>
            </button>
            <div className={styles.sep} aria-hidden />
            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => chooseMute('on')}
            >
              <Bell size={18} />
              <span className={styles.label}>Включено</span>
            </button>
            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => chooseMute('forever')}
            >
              <BellOff size={18} />
              <span className={styles.label}>Выключено навсегда</span>
            </button>
            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => chooseMute('1h')}
            >
              <BellOff size={18} />
              <span className={styles.label}>На 1 час</span>
            </button>
            <button
              type="button"
              role="menuitem"
              className={styles.item}
              onClick={() => chooseMute('1d')}
            >
              <BellOff size={18} />
              <span className={styles.label}>На 1 день</span>
            </button>
          </>
        )}
      </div>
    </div>
  )
}
