import { useEffect } from 'react'
import { Pin, X } from 'lucide-react'
import { useMessagesStore } from '../../store/messagesStore.js'
import styles from './PinnedBanner.module.css'

const TYPE_LABELS = {
  image: 'Фото',
  video: 'Видео',
  voice: 'Голосовое сообщение',
  file: 'Файл',
}

function snippetFor(message) {
  if (!message) return ''
  if (message.is_deleted) return 'Сообщение удалено'
  if (message.type === 'text') return (message.content ?? '').trim()
  return TYPE_LABELS[message.type] || message.content || ''
}

/**
 * Sticky 44px banner showing the latest pinned message of a chat.
 *
 * Fetches pinned messages from the server on mount / chat change and surfaces
 * them via `messagesStore.pinnedByChat`. Clicking the banner scrolls to the
 * pinned message via `onJump`.
 */
export function PinnedBanner({ chatId, onJump, onUnpin }) {
  const pinnedSlot = useMessagesStore((s) =>
    chatId ? s.pinnedByChat[chatId] : null,
  )
  const refreshPinned = useMessagesStore((s) => s.refreshPinned)

  useEffect(() => {
    if (!chatId) return
    refreshPinned(chatId).catch(() => {})
  }, [chatId, refreshPinned])

  const messages = pinnedSlot?.messages ?? []
  if (!messages.length) return null

  // The most recently pinned message bubbles to the top.
  const latest = messages[0]
  const count = messages.length

  return (
    <button
      type="button"
      className={styles.bar}
      onClick={() => onJump?.(latest)}
      aria-label="Перейти к закреплённому сообщению"
    >
      <Pin size={16} className={styles.pin} />
      <div className={styles.body}>
        <div className={styles.title}>
          Закреплённое сообщение
          {count > 1 ? <span className={styles.count}> · {count}</span> : null}
        </div>
        <div className={styles.snippet}>{snippetFor(latest) || ' '}</div>
      </div>
      {onUnpin ? (
        <button
          type="button"
          className={styles.unpin}
          onClick={(e) => {
            e.stopPropagation()
            onUnpin?.(latest)
          }}
          aria-label="Открепить"
        >
          <X size={16} />
        </button>
      ) : null}
    </button>
  )
}
