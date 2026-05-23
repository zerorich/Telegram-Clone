import { tokenStorage } from './storage.js'

const rawBase = import.meta.env.VITE_API_BASE_URL ?? ''

export const API_BASE_URL = rawBase.replace(/\/$/, '')

function deriveWsUrl() {
  const explicit = import.meta.env.VITE_WS_URL
  if (explicit) return explicit.replace(/\/$/, '') + (explicit.endsWith('/ws') ? '' : '/ws')

  if (API_BASE_URL) {
    return API_BASE_URL.replace(/^http/, 'ws') + '/ws'
  }

  if (typeof window !== 'undefined') {
    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws'
    return `${proto}://${window.location.host}/ws`
  }
  return ''
}

export const WS_URL = deriveWsUrl()

/**
 * Resolve a server-provided media path (e.g. "/uploads/...") to a full URL.
 * Already-absolute URLs are returned unchanged. When `auth: true` is passed,
 * the current access token is appended as `?t=...` so we stay compatible
 * with a JWT-gated `/uploads/*` route (forward-compatible: the server may
 * either enforce or ignore the parameter).
 */
export function mediaUrl(path, { auth = false } = {}) {
  if (!path) return ''
  if (/^https?:\/\//i.test(path)) return path
  if (!path.startsWith('/')) path = '/' + path
  const url = API_BASE_URL + path
  if (!auth) return url
  const token = tokenStorage.getAccess()
  if (!token) return url
  const sep = url.includes('?') ? '&' : '?'
  return `${url}${sep}t=${encodeURIComponent(token)}`
}
