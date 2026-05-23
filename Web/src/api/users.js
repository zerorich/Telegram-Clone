import { httpClient, unwrap } from './client.js'

export const usersApi = {
  async me() {
    const res = await httpClient.get('/api/users/me')
    return unwrap(res)
  },

  async updateMe({ name, surname, username }) {
    const res = await httpClient.patch('/api/users/me', {
      name,
      surname: surname ?? null,
      username: username ?? null,
    })
    return unwrap(res)
  },

  async uploadAvatar(file) {
    const form = new FormData()
    form.append('avatar', file)
    const res = await httpClient.post('/api/users/me/avatar', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    return unwrap(res)
  },

  async get(id) {
    const res = await httpClient.get(`/api/users/${id}`)
    return unwrap(res)
  },

  async search(query) {
    const res = await httpClient.get('/api/users/search', {
      params: { q: query },
    })
    return unwrap(res) || []
  },
}
