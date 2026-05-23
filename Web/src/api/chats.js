import { httpClient, unwrap } from './client.js'

export const chatsApi = {
  async list() {
    const res = await httpClient.get('/api/chats')
    return unwrap(res) || []
  },

  async createDirect(userId) {
    const res = await httpClient.post('/api/chats/direct', { user_id: userId })
    return unwrap(res)
  },

  async createGroup({ name, memberIds, avatar }) {
    if (avatar) {
      const form = new FormData()
      form.append('name', name)
      form.append('member_ids', JSON.stringify(memberIds))
      form.append('avatar', avatar)
      const res = await httpClient.post('/api/chats/group', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      })
      return unwrap(res)
    }
    const res = await httpClient.post('/api/chats/group', {
      name,
      member_ids: memberIds,
    })
    return unwrap(res)
  },

  async get(chatId) {
    const res = await httpClient.get(`/api/chats/${chatId}`)
    const data = unwrap(res)
    return { chat: data.chat, members: data.members ?? [] }
  },

  async updateGroup(chatId, { name, avatar } = {}) {
    if (avatar) {
      const form = new FormData()
      if (name) form.append('name', name)
      form.append('avatar', avatar)
      const res = await httpClient.patch(`/api/chats/${chatId}`, form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      })
      return unwrap(res)
    }
    const res = await httpClient.patch(`/api/chats/${chatId}`, { name })
    return unwrap(res)
  },

  async addMembers(chatId, memberIds) {
    await httpClient.post(`/api/chats/${chatId}/members`, {
      member_ids: memberIds,
    })
  },

  async removeMember(chatId, userId) {
    await httpClient.delete(`/api/chats/${chatId}/members/${userId}`)
  },

  async leave(chatId) {
    await httpClient.delete(`/api/chats/${chatId}/leave`)
  },

  async getSavedChat() {
    const res = await httpClient.get('/api/chats/saved')
    return unwrap(res)
  },

  async deleteChat(chatId) {
    await httpClient.delete(`/api/chats/${chatId}`)
  },

  async muteChat(chatId, until) {
    await httpClient.post(`/api/chats/${chatId}/mute`, {
      until: until ?? null,
    })
  },

  async unmuteChat(chatId) {
    await httpClient.delete(`/api/chats/${chatId}/mute`)
  },
}
