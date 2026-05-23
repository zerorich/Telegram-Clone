import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import {
  Forward,
  Bookmark,
  Pin,
  PinOff,
  Reply,
  Trash2,
  Copy,
  Pencil,
  CheckCheck,
} from 'lucide-react'
import { formatMessageTime } from '../../lib/format.js'
import styles from './MessageContextMenu.module.css'

const MENU_MARGIN = 8
const ROW_WIDTH = 220

/**
 * Telegram-style translucent context menu for a message bubble.
 *
 * Two-pane layout:
 *   1) Status row (optional, own messages only): "✓✓ прочитано в HH:MM:SS"
 *   2) Stacked actions (Переслать, Сохранить, Закрепить/Открепить)
 *   3) Separate floating row of 4 icon buttons (Reply, Delete, Copy, Edit/Forward)
 *
 * Anchored near `anchor: { x, y }` (viewport coords).
 */
export function MessageContextMenu({
  open,
  anchor,
  message,
  isMine,
  isDirect,
  canDelete,
  onClose,
  onReply,
  onCopy,
  onEdit,
  onDelete,
  onForward,
  onSaveToSaved,
  onTogglePin,
}) {
  const containerRef = useRef(null)
  const [pos, setPos] = useState({ left: 0, top: 0 })

  useEffect(() => {
    if (!open) return undefined
    function onKey(e) {
      if (e.key === 'Escape') onClose?.()
    }
    function onPointer(e) {
      if (!containerRef.current?.contains(e.target)) onClose?.()
    }
    document.addEventListener('keydown', onKey)
    document.addEventListener('mousedown', onPointer)
    return () => {
      document.removeEventListener('keydown', onKey)
      document.removeEventListener('mousedown', onPointer)
    }
  }, [open, onClose])

  useLayoutEffect(() => {
    if (!open) return
    const el = containerRef.current
    if (!el || !anchor) return
    const rect = el.getBoundingClientRect()
    const vw = window.innerWidth
    const vh = window.innerHeight
    let left = anchor.x
    let top = anchor.y
    if (left + rect.width + MENU_MARGIN > vw) {
      left = Math.max(MENU_MARGIN, vw - rect.width - MENU_MARGIN)
    }
    if (top + rect.height + MENU_MARGIN > vh) {
      top = Math.max(MENU_MARGIN, vh - rect.height - MENU_MARGIN)
    }
    left = Math.max(MENU_MARGIN, left)
    top = Math.max(MENU_MARGIN, top)
    setPos({ left, top })
  }, [open, anchor])

  if (!open || !anchor) return null

  const isText = message?.type === 'text' && !message?.is_deleted
  const isPinned = !!message?.is_pinned
  const isDeleted = !!message?.is_deleted

  // Status row: shown for own messages only.
  let statusRow = null
  if (isMine && !isDeleted) {
    if (isDirect && message?.is_read) {
      const t = formatMessageTime(message?.read_at ?? message?.created_at)
      statusRow = (
        <div className={styles.statusRow}>
          <CheckCheck size={16} className={styles.statusIcon} />
          <span>прочитано в {t}</span>
        </div>
      )
    } else if (message?.is_read) {
      statusRow = (
        <div className={styles.statusRow}>
          <CheckCheck size={16} className={styles.statusIcon} />
          <span>прочитано</span>
        </div>
      )
    } else {
      statusRow = (
        <div className={styles.statusRow}>
          <CheckCheck size={16} className={styles.statusIcon} />
          <span>доставлено</span>
        </div>
      )
    }
  }

  return createPortal(
    <div
      className={styles.layer}
      ref={containerRef}
      style={{ left: pos.left, top: pos.top, minWidth: ROW_WIDTH }}
      role="menu"
    >
      {!isDeleted ? (
        <div className={styles.panel}>
          {statusRow}
          {isMine ? (
            <button
              type="button"
              className={styles.row}
              role="menuitem"
              onClick={() => {
                onClose?.()
                onForward?.()
              }}
            >
              <Forward size={20} />
              <span>Переслать</span>
            </button>
          ) : null}

          <button
            type="button"
            className={styles.row}
            role="menuitem"
            onClick={() => {
              onClose?.()
              onSaveToSaved?.()
            }}
          >
            <Bookmark size={20} />
            <span>Сохранить</span>
          </button>

          <button
            type="button"
            className={styles.row}
            role="menuitem"
            onClick={() => {
              onClose?.()
              onTogglePin?.()
            }}
          >
            {isPinned ? <PinOff size={20} /> : <Pin size={20} />}
            <span>{isPinned ? 'Открепить' : 'Закрепить'}</span>
          </button>
        </div>
      ) : null}

      {!isDeleted ? (
        <div className={styles.iconRow}>
          <button
            type="button"
            className={styles.iconBtn}
            aria-label="Ответить"
            onClick={() => {
              onClose?.()
              onReply?.()
            }}
          >
            <Reply size={20} />
          </button>
          {canDelete ? (
            <button
              type="button"
              className={`${styles.iconBtn} ${styles.iconDanger}`}
              aria-label="Удалить"
              onClick={() => {
                onClose?.()
                onDelete?.()
              }}
            >
              <Trash2 size={20} />
            </button>
          ) : null}
          {isText ? (
            <button
              type="button"
              className={styles.iconBtn}
              aria-label="Копировать"
              onClick={() => {
                onClose?.()
                onCopy?.()
              }}
            >
              <Copy size={20} />
            </button>
          ) : null}
          {isMine && isText ? (
            <button
              type="button"
              className={styles.iconBtn}
              aria-label="Изменить"
              onClick={() => {
                onClose?.()
                onEdit?.()
              }}
            >
              <Pencil size={20} />
            </button>
          ) : !isMine ? (
            <button
              type="button"
              className={styles.iconBtn}
              aria-label="Переслать"
              onClick={() => {
                onClose?.()
                onForward?.()
              }}
            >
              <Forward size={20} />
            </button>
          ) : null}
        </div>
      ) : null}
    </div>,
    document.body,
  )
}
