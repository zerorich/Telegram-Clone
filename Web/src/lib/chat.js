import { mediaUrl } from './env.js'

export function userDisplayName(user) {
  if (!user) return ''
  const name = (user.name ?? '').trim()
  const surname = (user.surname ?? '').trim()
  const combined = [name, surname].filter(Boolean).join(' ').trim()
  if (combined) return combined
  if (user.username) return `@${user.username}`
  if (user.email) return user.email
  if (user.phone) return user.phone
  return 'Без имени'
}

/** Find the other member of a 1:1 chat (the one that isn't me). */
export function peerMember(chat, currentUserId) {
  if (!chat || chat.type !== 'direct' || !chat.members) return null
  return chat.members.find((m) => m.user_id !== currentUserId) ?? null
}

/** Resolve a chat title for the sidebar / header. */
export function chatDisplayTitle(chat, currentUserId) {
  if (!chat) return ''
  if (chat.type === 'saved') return 'Избранное'
  if (chat.type === 'group') return chat.name ?? 'Группа'
  const peer = peerMember(chat, currentUserId)
  if (peer?.user) return userDisplayName(peer.user)
  return 'Чат'
}

/** Resolve an avatar URL for a chat tile / header. */
export function chatAvatarUrl(chat, currentUserId) {
  if (!chat) return ''
  if (chat.type === 'saved') return ''
  if (chat.type === 'group') return mediaUrl(chat.avatar_url, { auth: true })
  const peer = peerMember(chat, currentUserId)
  return mediaUrl(peer?.user?.avatar_url, { auth: true })
}

export function isSavedChat(chat) {
  return chat?.type === 'saved'
}

/**
 * Whether this chat is currently muted.
 *
 * Backend conventions we support:
 *  - field absent / `undefined`            → not muted
 *  - explicit `null` on a muted chat       → muted forever
 *  - ISO date string                       → muted until that time
 *
 * If the backend exposes an `is_muted` boolean we honour it as the source of
 * truth, which avoids ambiguity around `null` between drivers.
 */
export function isChatMuted(chat) {
  if (!chat) return false
  if (typeof chat.is_muted === 'boolean') return chat.is_muted
  if (!('muted_until' in chat)) return false
  const until = chat.muted_until
  if (until === null) return true
  const t = new Date(until).getTime()
  if (Number.isNaN(t)) return false
  return t > Date.now()
}

export function memberCountLabel(count) {
  if (!count) return ''
  const mod10 = count % 10
  const mod100 = count % 100
  if (mod10 === 1 && mod100 !== 11) return `${count} участник`
  if ([2, 3, 4].includes(mod10) && ![12, 13, 14].includes(mod100)) {
    return `${count} участника`
  }
  return `${count} участников`
}

export function isOwnMessage(message, currentUserId) {
  return !!message && !!currentUserId && message.sender_id === currentUserId
}
