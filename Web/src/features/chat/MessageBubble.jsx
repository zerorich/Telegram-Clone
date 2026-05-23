import { useEffect, useRef } from 'react'
import { Check, CheckCheck, Forward } from 'lucide-react'
import { MediaContent } from './MediaContent.jsx'
import { formatMessageTime } from '../../lib/format.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './MessageBubble.module.css'

const TYPE_LABELS = {
  image: 'Фото',
  video: 'Видео',
  voice: 'Голосовое сообщение',
  file: 'Файл',
}

const URL_REGEX = /(https?:\/\/[^\s]+)/g

function renderLinkified(text) {
  if (!text) return null
  const parts = text.split(URL_REGEX)
  return parts.map((part, i) => {
    if (URL_REGEX.test(part)) {
      URL_REGEX.lastIndex = 0
      return (
        <a
          key={i}
          href={part}
          target="_blank"
          rel="noopener noreferrer"
          className={styles.link}
        >
          {part}
        </a>
      )
    }
    return <span key={i}>{part}</span>
  })
}

function forwardedLabel(message) {
  const fromUser = message?.forwarded_from_user
  if (fromUser) return userDisplayName(fromUser)
  if (message?.forwarded_from_user_id) return 'пользователя'
  return null
}

const LONG_PRESS_MS = 500

/**
 * Pixel width of an invisible inline placeholder (`shadow span`) appended to
 * the text flow. The meta row (edited mark + time + ticks) is positioned
 * absolutely at the bottom-right of the bubble; the placeholder reserves
 * equivalent horizontal space on the last line of text so the meta either
 * fits inline at the right or pushes to a new line — Telegram-style.
 *
 * Numbers are intentionally generous to absorb font metric variance.
 */
function metaShadowWidth(message, isMine) {
  let w = 44 // base: meta left padding + "HH:mm" time + small right margin
  if (message.is_edited && !message.is_deleted) w += 28 // "изм." + gap
  if (isMine && !message.is_deleted) w += 18 // tick icon + gap
  return w
}

/**
 * Single message bubble.
 *
 * Reports user intent (open context menu) upwards via `onRequestMenu({ x, y })`;
 * the parent stage owns the actual menu component so it can run forward / pin
 * flows that need access to other stores. The menu opens via right-click on
 * desktop or touch long-press on mobile — there is no visible trigger.
 */
export function MessageBubble({
  message,
  isMine,
  showSenderName,
  senderName,
  replyTo,
  showTail,
  onRequestMenu,
}) {
  const touchTimerRef = useRef(null)
  const touchStartRef = useRef(null)
  const hasMenu = !!onRequestMenu && !message.is_deleted

  useEffect(() => {
    return () => {
      if (touchTimerRef.current) clearTimeout(touchTimerRef.current)
    }
  }, [])

  function openMenu(x, y) {
    onRequestMenu?.({ x, y })
  }

  function onContextMenu(e) {
    if (!hasMenu) return
    e.preventDefault()
    openMenu(e.clientX, e.clientY)
  }

  function onTouchStart(e) {
    if (!hasMenu) return
    const t = e.touches?.[0]
    if (!t) return
    touchStartRef.current = { x: t.clientX, y: t.clientY }
    if (touchTimerRef.current) clearTimeout(touchTimerRef.current)
    touchTimerRef.current = setTimeout(() => {
      openMenu(t.clientX, t.clientY)
      touchTimerRef.current = null
    }, LONG_PRESS_MS)
  }

  function onTouchMove(e) {
    if (!touchTimerRef.current || !touchStartRef.current) return
    const t = e.touches?.[0]
    if (!t) return
    const dx = Math.abs(t.clientX - touchStartRef.current.x)
    const dy = Math.abs(t.clientY - touchStartRef.current.y)
    if (dx > 10 || dy > 10) {
      clearTimeout(touchTimerRef.current)
      touchTimerRef.current = null
    }
  }

  function onTouchEnd() {
    if (touchTimerRef.current) {
      clearTimeout(touchTimerRef.current)
      touchTimerRef.current = null
    }
  }

  const isMedia = message.type !== 'text' && !message.is_deleted
  const fullBleed =
    isMedia && (message.type === 'image' || message.type === 'video')
  const fwdLabel = forwardedLabel(message)
  const shadowW = metaShadowWidth(message, isMine)
  const metaShadow = (
    <span
      className={styles.metaShadow}
      aria-hidden="true"
      style={{ width: shadowW }}
    />
  )

  return (
    <div
      className={`${styles.row} ${isMine ? styles.rowMine : ''} ${
        message.is_pinned && !message.is_deleted ? styles.pinned : ''
      }`}
      id={`msg-${message.id}`}
      data-message-id={message.id}
      onContextMenu={onContextMenu}
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
      onTouchCancel={onTouchEnd}
    >
      <div
        className={`${styles.bubble} ${
          isMine ? styles.bubbleMine : styles.bubbleOther
        } ${showTail ? styles.withTail : ''} ${
          fullBleed ? styles.media : ''
        }`}
      >
        {showSenderName && senderName ? (
          <div className={styles.sender}>{senderName}</div>
        ) : null}

        {fwdLabel ? (
          <div className={styles.forwarded}>
            <Forward size={12} className={styles.forwardedIcon} />
            <span>Переслано от {fwdLabel}</span>
          </div>
        ) : null}

        {replyTo ? (
          <div className={styles.reply}>
            <span className={styles.replyBody}>
              {replyTo.is_deleted
                ? 'Сообщение удалено'
                : replyTo.content?.trim() ||
                  TYPE_LABELS[replyTo.type] ||
                  ''}
            </span>
          </div>
        ) : null}

        {message.is_deleted ? (
          <div className={styles.deleted}>
            <span>Сообщение удалено</span>
            {metaShadow}
          </div>
        ) : message.type === 'text' ? (
          <div className={styles.text}>
            {renderLinkified(message.content ?? '')}
            {metaShadow}
          </div>
        ) : (
          <div className={fullBleed ? styles.mediaWrap : styles.mediaInline}>
            <MediaContent message={message} isMine={isMine} />
            {message.content && message.type !== 'voice' ? (
              <div className={styles.caption}>
                {renderLinkified(message.content)}
                {metaShadow}
              </div>
            ) : null}
          </div>
        )}

        <div className={styles.meta}>
          {message.is_edited && !message.is_deleted ? (
            <span className={styles.edited}>изм.</span>
          ) : null}
          <span className={styles.time}>
            {formatMessageTime(message.created_at)}
          </span>
          {isMine && !message.is_deleted ? (
            message.is_read ? (
              <CheckCheck size={14} className={styles.tick} />
            ) : (
              <Check size={14} className={styles.tick} />
            )
          ) : null}
        </div>
      </div>
    </div>
  )
}
