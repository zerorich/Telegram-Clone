import { httpClient, unwrap } from './client.js'

export const messagesApi = {
  async list(chatId, { cursor, limit = 50 } = {}) {
    const params = { limit }
    if (cursor) params.cursor = cursor
    const res = await httpClient.get(`/api/chats/${chatId}/messages`, { params })
    const data = unwrap(res) || {}
    return {
      messages: data.messages ?? [],
      nextCursor: data.next_cursor ?? null,
    }
  },

  async sendText(chatId, { content, replyToId }) {
    const payload = { content }
    if (replyToId) payload.reply_to_id = replyToId
    const res = await httpClient.post(`/api/chats/${chatId}/messages`, payload)
    return unwrap(res)
  },

  async sendMedia(chatId, { type, file, durationSec, replyToId, filename }) {
    const form = new FormData()
    form.append('type', type)
    form.append('file', file, filename ?? file.name ?? 'file')
    if (durationSec != null) form.append('duration_sec', String(durationSec))
    if (replyToId) form.append('reply_to_id', replyToId)
    const res = await httpClient.post(
      `/api/chats/${chatId}/messages/media`,
      form,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    )
    return unwrap(res)
  },

  async edit(chatId, messageId, content) {
    const res = await httpClient.patch(
      `/api/chats/${chatId}/messages/${messageId}`,
      { content },
    )
    return unwrap(res)
  },

  async delete(chatId, messageId) {
    const res = await httpClient.delete(
      `/api/chats/${chatId}/messages/${messageId}`,
    )
    return unwrap(res)
  },

  async markRead(chatId, messageId) {
    await httpClient.post(`/api/chats/${chatId}/messages/read`, {
      message_id: messageId,
    })
  },

  async forward(targetChatId, { sourceChatId, messageId }) {
    const res = await httpClient.post(
      `/api/chats/${targetChatId}/messages/forward`,
      {
        source_chat_id: sourceChatId,
        message_id: messageId,
      },
    )
    return unwrap(res)
  },

  async pin(chatId, messageId) {
    const res = await httpClient.post(
      `/api/chats/${chatId}/messages/${messageId}/pin`,
    )
    return unwrap(res)
  },

  async unpin(chatId, messageId) {
    const res = await httpClient.delete(
      `/api/chats/${chatId}/messages/${messageId}/pin`,
    )
    return unwrap(res)
  },

  async listPinned(chatId) {
    const res = await httpClient.get(`/api/chats/${chatId}/pinned`)
    const data = unwrap(res) || {}
    return data.messages ?? []
  },

  async search(chatId, { q, limit = 50 } = {}) {
    const res = await httpClient.get(
      `/api/chats/${chatId}/messages/search`,
      { params: { q, limit } },
    )
    const data = unwrap(res) || {}
    return data.messages ?? []
  },

  async clearHistory(chatId) {
    await httpClient.delete(`/api/chats/${chatId}/messages`)
  },
}
