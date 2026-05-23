import { httpClient, unwrap } from './client.js'

export const authApi = {
  async sendCode(email) {
    const res = await httpClient.post('/api/auth/send-code', { email })
    return unwrap(res)
  },

  async verifyCode(email, code) {
    const res = await httpClient.post('/api/auth/verify-code', { email, code })
    return unwrap(res)
  },

  async completeProfile({ email, name, surname, phone }, { registrationToken } = {}) {
    const payload = { email, name }
    if (surname) payload.surname = surname
    if (phone) payload.phone = phone
    const config = registrationToken
      ? { headers: { Authorization: `Bearer ${registrationToken}` } }
      : undefined
    const res = await httpClient.post('/api/auth/complete-profile', payload, config)
    return unwrap(res)
  },

  async logout(refreshToken) {
    if (!refreshToken) return
    await httpClient.post('/api/auth/logout', { refresh_token: refreshToken })
  },
}
