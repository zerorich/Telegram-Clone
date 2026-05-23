import { NavLink } from 'react-router-dom'
import { Check, CheckCheck, VolumeX, Pin } from 'lucide-react'
import { Avatar } from '../../components/Avatar.jsx'
import {
  chatAvatarUrl,
  chatDisplayTitle,
  isChatMuted,
  isSavedChat,
  peerMember,
} from '../../lib/chat.js'
import { formatChatListTime, formatMessagePreview } from '../../lib/format.js'
import { useChatsStore } from '../../store/chatsStore.js'
import styles from './ChatListItem.module.css'

export function ChatListItem({ chat, currentUserId }) {
  const last = chat.last_message
  const title = chatDisplayTitle(chat, currentUserId)
  const saved = isSavedChat(chat)
  const muted = isChatMuted(chat)
  const isGroup = chat.type === 'group'
  const isMine = last?.sender_id === currentUserId
  const time = last?.created_at ?? chat.created_at
  const peer = !isGroup && !saved ? peerMember(chat, currentUserId) : null
  const online = useChatsStore((s) =>
    peer ? !!s.onlineUsers[peer.user_id] : false,
  )
  const typingUid = useChatsStore((s) => s.typing[chat.id])
  const avatar = saved ? '' : chatAvatarUrl(chat, currentUserId)

  let senderName = null
  if (isGroup && last && !isMine && chat.members) {
    const senderMember = chat.members.find((m) => m.user_id === last.sender_id)
    if (senderMember?.user) {
      const n = senderMember.user.name?.trim()
      const sn = senderMember.user.surname?.trim() || ''
      senderName = [n, sn].filter(Boolean).join(' ') || null
    }
  }

  const previewText = last
    ? formatMessagePreview({
        content: last.content,
        type: last.type,
        isMine,
        senderName,
        isGroup,
        isDeleted: last.is_deleted,
      })
    : saved
      ? 'Сохраняйте важные сообщения здесь'
      : 'Нет сообщений'

  const showTyping = !!typingUid && (!currentUserId || typingUid !== currentUserId)

  return (
    <NavLink
      to={`/chats/${chat.id}`}
      className={({ isActive }) =>
        `${styles.item} ${isActive ? styles.active : ''} ${
          saved ? styles.savedItem : ''
        }`
      }
      role="listitem"
    >
      <Avatar
        src={avatar}
        name={title}
        size={54}
        online={online && !isGroup && !saved}
        saved={saved}
      />
      <div className={styles.body}>
        <div className={styles.row}>
          <span className={styles.titleWrap}>
            <span className={styles.title}>{title}</span>
            {muted ? (
              <VolumeX
                size={14}
                className={styles.mutedIcon}
                aria-label="Без звука"
              />
            ) : null}
            {saved ? (
              <Pin
                size={12}
                className={styles.pinIcon}
                aria-label="Закреплено"
              />
            ) : null}
          </span>
          <span
            className={`${styles.time} ${
              chat.unread_count ? styles.timeUnread : ''
            }`}
          >
            {formatChatListTime(time)}
          </span>
        </div>
        <div className={styles.row}>
          {isMine && last && !last.is_deleted ? (
            <span className={styles.ticks} aria-hidden>
              {last.is_read ? <CheckCheck size={16} /> : <Check size={16} />}
            </span>
          ) : null}
          <span
            className={`${styles.preview} ${
              chat.unread_count ? styles.previewUnread : ''
            } ${showTyping ? styles.typing : ''}`}
          >
            {showTyping ? 'печатает…' : previewText}
          </span>
          {chat.unread_count ? (
            <span
              className={`${styles.badge} ${muted ? styles.badgeMuted : ''}`}
            >
              {chat.unread_count > 999 ? '999+' : chat.unread_count}
            </span>
          ) : null}
        </div>
      </div>
    </NavLink>
  )
}
