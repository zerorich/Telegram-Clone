import { create } from 'zustand'
import { messagesApi } from '../api/messages.js'
import { useAuthStore } from './authStore.js'
import { useChatsStore } from './chatsStore.js'

/**
 * Messages are stored per-chat in chronological order (oldest -> newest).
 *
 * state.byChat: {
 *   [chatId]: {
 *     messages: Message[]
 *     nextCursor: string | null
 *     loading: boolean
 *     loadingMore: boolean
 *     loaded: boolean
 *     error: any
 *   }
 * }
 */

const emptyState = () => ({
  messages: [],
  nextCursor: null,
  loading: false,
  loadingMore: false,
  loaded: false,
  error: null,
})

function applyMessage(state, message, { prepend = false } = {}) {
  if (!message?.chat_id) return state
  const slot = state[message.chat_id] ?? emptyState()
  const idx = slot.messages.findIndex((m) => m.id === message.id)
  let messages
  if (idx === -1) {
    messages = prepend
      ? [message, ...slot.messages]
      : [...slot.messages, message]
  } else {
    messages = [...slot.messages]
    messages[idx] = { ...messages[idx], ...message }
  }
  messages.sort((a, b) => {
    const at = new Date(a.created_at).getTime()
    const bt = new Date(b.created_at).getTime()
    if (at === bt) return a.id.localeCompare(b.id)
    return at - bt
  })
  return { ...state, [message.chat_id]: { ...slot, messages } }
}

export const useMessagesStore = create((set, get) => ({
  byChat: {},
  /** replyTargets: { [chatId]: message | null } */
  replyTargets: {},
  /** editTargets: { [chatId]: message | null } */
  editTargets: {},
  /** pinnedByChat: { [chatId]: { messages: Message[], loaded: boolean } } */
  pinnedByChat: {},

  getChatState(chatId) {
    return get().byChat[chatId] ?? emptyState()
  },

  setReply(chatId, message) {
    set({ replyTargets: { ...get().replyTargets, [chatId]: message ?? null } })
  },

  setEdit(chatId, message) {
    set({ editTargets: { ...get().editTargets, [chatId]: message ?? null } })
  },

  async loadInitial(chatId) {
    if (!chatId) return
    const slot = get().byChat[chatId] ?? emptyState()
    if (slot.loading || slot.loaded) return
    set({
      byChat: {
        ...get().byChat,
        [chatId]: { ...slot, loading: true, error: null },
      },
    })
    try {
      const { messages, nextCursor } = await messagesApi.list(chatId, {
        limit: 50,
      })
      const sorted = [...messages].sort((a, b) => {
        return new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      })
      set({
        byChat: {
          ...get().byChat,
          [chatId]: {
            ...emptyState(),
            messages: sorted,
            nextCursor,
            loading: false,
            loaded: true,
          },
        },
      })
    } catch (e) {
      const cur = get().byChat[chatId] ?? emptyState()
      set({
        byChat: {
          ...get().byChat,
          [chatId]: { ...cur, loading: false, error: e },
        },
      })
    }
  },

  async loadMore(chatId) {
    if (!chatId) return
    const slot = get().byChat[chatId]
    if (!slot || slot.loadingMore || !slot.nextCursor) return
    set({
      byChat: {
        ...get().byChat,
        [chatId]: { ...slot, loadingMore: true },
      },
    })
    try {
      const { messages, nextCursor } = await messagesApi.list(chatId, {
        cursor: slot.nextCursor,
        limit: 50,
      })
      const cur = get().byChat[chatId] ?? emptyState()
      const merged = [...messages, ...cur.messages]
      const dedup = []
      const seen = new Set()
      for (const m of merged) {
        if (seen.has(m.id)) continue
        seen.add(m.id)
        dedup.push(m)
      }
      dedup.sort((a, b) => {
        return new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      })
      set({
        byChat: {
          ...get().byChat,
          [chatId]: {
            ...cur,
            messages: dedup,
            nextCursor,
            loadingMore: false,
          },
        },
      })
    } catch (e) {
      const cur = get().byChat[chatId] ?? emptyState()
      set({
        byChat: {
          ...get().byChat,
          [chatId]: { ...cur, loadingMore: false, error: e },
        },
      })
    }
  },

  async sendText(chatId, { content, replyToId }) {
    const trimmed = content.trim()
    if (!trimmed) return null
    const msg = await messagesApi.sendText(chatId, {
      content: trimmed,
      replyToId,
    })
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    useChatsStore.getState().applyIncomingMessage(msg)
    return msg
  },

  async sendMedia(chatId, payload) {
    const msg = await messagesApi.sendMedia(chatId, payload)
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    useChatsStore.getState().applyIncomingMessage(msg)
    return msg
  },

  async editMessage(chatId, messageId, content) {
    const msg = await messagesApi.edit(chatId, messageId, content)
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    useChatsStore.getState().applyUpdatedMessage(msg)
    return msg
  },

  async deleteMessage(chatId, messageId) {
    const msg = await messagesApi.delete(chatId, messageId)
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    useChatsStore.getState().applyUpdatedMessage(msg)
    return msg
  },

  handleIncomingMessage(message) {
    if (!message?.chat_id) return
    set((state) => ({ byChat: applyMessage(state.byChat, message) }))
  },

  /** Mark all messages from other senders as read up to (and including) the latest. */
  markAllRead(chatId) {
    const slot = get().byChat[chatId]
    if (!slot) return
    const me = useAuthStore.getState().user?.id
    if (!me) return
    const last = [...slot.messages].reverse().find((m) => m.sender_id !== me && !m.is_read)
    if (!last) return
    messagesApi.markRead(chatId, last.id).catch(() => {})
  },

  async forwardMessage(targetChatId, sourceChatId, messageId) {
    const msg = await messagesApi.forward(targetChatId, {
      sourceChatId,
      messageId,
    })
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    useChatsStore.getState().applyIncomingMessage(msg)
    return msg
  },

  async pinMessage(chatId, messageId) {
    const msg = await messagesApi.pin(chatId, messageId)
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    get().refreshPinned(chatId).catch(() => {})
    return msg
  },

  async unpinMessage(chatId, messageId) {
    const msg = await messagesApi.unpin(chatId, messageId)
    set((state) => ({ byChat: applyMessage(state.byChat, msg) }))
    get().refreshPinned(chatId).catch(() => {})
    return msg
  },

  async refreshPinned(chatId) {
    if (!chatId) return []
    try {
      const messages = await messagesApi.listPinned(chatId)
      set({
        pinnedByChat: {
          ...get().pinnedByChat,
          [chatId]: { messages, loaded: true },
        },
      })
      return messages
    } catch {
      set({
        pinnedByChat: {
          ...get().pinnedByChat,
          [chatId]: get().pinnedByChat[chatId] ?? { messages: [], loaded: true },
        },
      })
      return []
    }
  },

  getPinned(chatId) {
    return get().pinnedByChat[chatId]?.messages ?? []
  },

  applyPinChange(message) {
    if (!message?.chat_id) return
    set((state) => ({ byChat: applyMessage(state.byChat, message) }))
    get().refreshPinned(message.chat_id).catch(() => {})
  },

  async clearHistory(chatId) {
    if (!chatId) return
    await messagesApi.clearHistory(chatId)
    set({
      byChat: {
        ...get().byChat,
        [chatId]: { ...emptyState(), loaded: true },
      },
      pinnedByChat: {
        ...get().pinnedByChat,
        [chatId]: { messages: [], loaded: true },
      },
    })
    useChatsStore.getState().applyChatCleared(chatId)
  },

  applyChatCleared(chatId) {
    if (!chatId) return
    set({
      byChat: {
        ...get().byChat,
        [chatId]: { ...emptyState(), loaded: true },
      },
      pinnedByChat: {
        ...get().pinnedByChat,
        [chatId]: { messages: [], loaded: true },
      },
    })
    useChatsStore.getState().applyChatCleared(chatId)
  },

  applyMessageRead({ chat_id: chatId, message_id: messageId }) {
    const slot = get().byChat[chatId]
    if (!slot) return
    let changed = false
    const messages = slot.messages.map((m) => {
      if (m.id === messageId) {
        changed = true
        return { ...m, is_read: true }
      }
      return m
    })
    if (!changed) return
    set({
      byChat: { ...get().byChat, [chatId]: { ...slot, messages } },
    })
    useChatsStore.getState().markLastMessageRead(chatId, messageId)
  },

  reset() {
    set({
      byChat: {},
      replyTargets: {},
      editTargets: {},
      pinnedByChat: {},
    })
  },
}))
