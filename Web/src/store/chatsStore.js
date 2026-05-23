import { create } from 'zustand'
import { chatsApi } from '../api/chats.js'
import { useAuthStore } from './authStore.js'

function sortByActivity(chats) {
  return [...chats].sort((a, b) => {
    if (a.type === 'saved' && b.type !== 'saved') return -1
    if (b.type === 'saved' && a.type !== 'saved') return 1
    const aT = a.last_message?.created_at ?? a.created_at
    const bT = b.last_message?.created_at ?? b.created_at
    return new Date(bT).getTime() - new Date(aT).getTime()
  })
}

export const useChatsStore = create((set, get) => ({
  chats: [],
  loading: false,
  error: null,
  /** typing: { [chatId]: userId | null } */
  typing: {},
  /** onlineUsers: { [userId]: boolean } */
  onlineUsers: {},
  activeChatId: null,

  setActiveChatId(id) {
    set({ activeChatId: id })
    if (id) get().clearUnread(id)
  },

  async load() {
    set({ loading: true, error: null })
    try {
      const chats = await chatsApi.list()
      // Ensure the user's Saved Messages chat is in the list. The list endpoint
      // may or may not return it depending on backend version.
      let list = Array.isArray(chats) ? [...chats] : []
      if (!list.some((c) => c.type === 'saved')) {
        try {
          const saved = await chatsApi.getSavedChat()
          if (saved?.id) list = [saved, ...list]
        } catch {
          // Saved-chat endpoint may not be deployed yet; ignore.
        }
      }
      set({ chats: sortByActivity(list), loading: false })
    } catch (e) {
      set({ loading: false, error: e })
    }
  },

  upsertChat(chat) {
    if (!chat?.id) return
    const list = get().chats
    const idx = list.findIndex((c) => c.id === chat.id)
    if (idx === -1) {
      set({ chats: sortByActivity([chat, ...list]) })
    } else {
      const merged = { ...list[idx], ...chat }
      const next = [...list]
      next[idx] = merged
      set({ chats: sortByActivity(next) })
    }
  },

  applyIncomingMessage(message) {
    if (!message?.chat_id) return
    const me = useAuthStore.getState().user?.id
    const list = get().chats
    const idx = list.findIndex((c) => c.id === message.chat_id)
    const isMine = message.sender_id === me
    const activeId = get().activeChatId

    if (idx === -1) {
      get().load()
      return
    }
    const chat = list[idx]
    const isActive = activeId === chat.id
    const isDuplicate = chat.last_message?.id === message.id
    const next = [...list]
    next[idx] = {
      ...chat,
      last_message: message,
      unread_count:
        message.is_deleted || isMine || isActive || isDuplicate
          ? chat.unread_count
          : (chat.unread_count || 0) + 1,
    }
    set({ chats: sortByActivity(next) })
  },

  applyUpdatedMessage(message) {
    if (!message?.chat_id) return
    const list = get().chats
    const idx = list.findIndex((c) => c.id === message.chat_id)
    if (idx === -1) return
    const chat = list[idx]
    if (chat.last_message?.id !== message.id) return
    const next = [...list]
    next[idx] = { ...chat, last_message: message }
    set({ chats: next })
  },

  markLastMessageRead(chatId, messageId) {
    const list = get().chats
    const idx = list.findIndex((c) => c.id === chatId)
    if (idx === -1) return
    const chat = list[idx]
    if (chat.last_message?.id !== messageId) return
    const next = [...list]
    next[idx] = {
      ...chat,
      last_message: { ...chat.last_message, is_read: true },
    }
    set({ chats: next })
  },

  clearUnread(chatId) {
    const list = get().chats
    const idx = list.findIndex((c) => c.id === chatId)
    if (idx === -1) return
    if (!list[idx].unread_count) return
    const next = [...list]
    next[idx] = { ...list[idx], unread_count: 0 }
    set({ chats: next })
  },

  setTyping(chatId, userId, isTyping) {
    const me = useAuthStore.getState().user?.id
    if (userId && me && userId === me) return
    const typing = { ...get().typing }
    if (isTyping) typing[chatId] = userId
    else if (typing[chatId] === userId) delete typing[chatId]
    set({ typing })
  },

  setOnline(userId, isOnline) {
    if (!userId) return
    set({ onlineUsers: { ...get().onlineUsers, [userId]: isOnline } })
  },

  removeChat(chatId) {
    set({ chats: get().chats.filter((c) => c.id !== chatId) })
  },

  applyMuted(chatId, mutedUntil) {
    const list = get().chats
    const idx = list.findIndex((c) => c.id === chatId)
    if (idx === -1) return
    const next = [...list]
    next[idx] = { ...next[idx], muted_until: mutedUntil ?? null }
    set({ chats: next })
  },

  applyChatCleared(chatId) {
    const list = get().chats
    const idx = list.findIndex((c) => c.id === chatId)
    if (idx === -1) return
    const next = [...list]
    next[idx] = { ...next[idx], last_message: null, unread_count: 0 }
    set({ chats: next })
  },

  /** Find the user's "Saved Messages" chat in the cached list. */
  findSavedChat() {
    return get().chats.find((c) => c.type === 'saved') ?? null
  },

  reset() {
    set({
      chats: [],
      loading: false,
      error: null,
      typing: {},
      onlineUsers: {},
      activeChatId: null,
    })
  },
}))
