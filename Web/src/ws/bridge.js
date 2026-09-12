import { wsClient } from './client.js'
import { useChatsStore } from '../store/chatsStore.js'
import { useMessagesStore } from '../store/messagesStore.js'
import { useAuthStore } from '../store/authStore.js'
import { callManager } from '../lib/callManager.js'
import { notifyNewMessage } from '../lib/notifications.js'

let installed = false

/**
 * Wire WebSocket events into the Zustand stores. Idempotent.
 */
export function installWsBridge() {
  if (installed) return
  installed = true

  wsClient.addListener((type, data) => {
    switch (type) {
      case 'message.new': {
        useMessagesStore.getState().handleIncomingMessage(data)
        useChatsStore.getState().applyIncomingMessage(data)
        const chats = useChatsStore.getState().chats
        const chat = chats.find((c) => c.id === data.chat_id)
        notifyNewMessage({
          message: data,
          chat,
          currentUserId: useAuthStore.getState().user?.id,
        })
        break
      }
      case 'message.updated':
      case 'message.deleted': {
        useMessagesStore.getState().handleIncomingMessage(data)
        useChatsStore.getState().applyUpdatedMessage(data)
        break
      }
      case 'message.read': {
        useMessagesStore.getState().applyMessageRead(data)
        break
      }
      case 'message.pinned':
      case 'message.unpinned': {
        useMessagesStore.getState().applyPinChange(data)
        useChatsStore.getState().applyUpdatedMessage(data)
        break
      }
      case 'chat.cleared': {
        const chatId = data?.chat_id ?? data?.id
        if (chatId) useMessagesStore.getState().applyChatCleared(chatId)
        break
      }
      case 'chat.deleted': {
        const chatId = data?.chat_id ?? data?.id
        if (!chatId) break
        useChatsStore.getState().removeChat(chatId)
        // AppLayout watches `chats` vs the active chatId and redirects when
        // the active chat disappears, so no navigation needed here.
        break
      }
      case 'chat.muted': {
        const chatId = data?.chat_id ?? data?.id
        const until =
          data?.muted_until ?? data?.until ?? null
        if (chatId) useChatsStore.getState().applyMuted(chatId, until)
        break
      }
      case 'typing': {
        useChatsStore
          .getState()
          .setTyping(data.chat_id, data.user_id, !!data.is_typing)
        break
      }
      case 'user.online': {
        useChatsStore.getState().setOnline(data.user_id, !!data.is_online)
        break
      }
      case 'call.offer': {
        callManager.handleOffer(data)
        break
      }
      case 'call.answer': {
        callManager.handleAnswer(data)
        break
      }
      case 'call.ice': {
        callManager.handleIce(data)
        break
      }
      case 'call.end': {
        callManager.handleEnd(data)
        break
      }
      default:
        break
    }
  })
}
