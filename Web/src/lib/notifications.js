import { notificationStorage } from './storage.js'
import { chatDisplayTitle } from './chat.js'
import { formatMessagePreview } from './format.js'

export function notificationsEnabled() {
  return notificationStorage.getEnabled()
}

export async function requestNotificationPermission() {
  if (!('Notification' in window)) {
    return 'unsupported'
  }
  if (Notification.permission === 'granted') {
    notificationStorage.setEnabled(true)
    return 'granted'
  }
  if (Notification.permission === 'denied') {
    return 'denied'
  }
  const result = await Notification.requestPermission()
  if (result === 'granted') {
    notificationStorage.setEnabled(true)
  }
  return result
}

export async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return null
  try {
    return await navigator.serviceWorker.register('/sw.js')
  } catch {
    return null
  }
}

/**
 * Show an in-page or system notification for a new message when the tab is hidden.
 */
export function notifyNewMessage({ message, chat, currentUserId }) {
  if (!notificationsEnabled()) return
  if (!document.hidden) return
  if (!message || !chat) return
  if (message.sender_id === currentUserId) return

  const title = chatDisplayTitle(chat, currentUserId)
  const body = formatMessagePreview({
    content: message.content,
    type: message.type,
    isMine: false,
    isGroup: chat.type === 'group',
    isDeleted: message.is_deleted,
  })

  if ('Notification' in window && Notification.permission === 'granted') {
    try {
      const n = new Notification(title, {
        body,
        icon: '/favicon.svg',
        tag: `chat-${chat.id}`,
        renotify: true,
      })
      n.onclick = () => {
        window.focus()
        window.location.href = `/chats/${chat.id}`
        n.close()
      }
      return
    } catch {
      /* fall through to SW */
    }
  }

  navigator.serviceWorker?.ready
    ?.then((reg) =>
      reg.showNotification(title, {
        body,
        icon: '/favicon.svg',
        tag: `chat-${chat.id}`,
        renotify: true,
        data: { chatId: chat.id },
      }),
    )
    .catch(() => {})
}
