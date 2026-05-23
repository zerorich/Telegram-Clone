import { WS_URL } from '../lib/env.js'

const MAX_BACKOFF_MS = 60_000
const INITIAL_BACKOFF_MS = 1_000

/**
 * Self-healing WebSocket client.
 * - Reconnects with exponential backoff (capped at 60s)
 * - Sends connection-event listeners status updates
 * - Drops messages when the socket is closed (caller can retry via REST)
 */
export class WSClient {
  constructor() {
    this._socket = null
    this._token = null
    this._disposed = false
    this._backoff = INITIAL_BACKOFF_MS
    this._reconnectTimer = null
    this._listeners = new Set()
    this._statusListeners = new Set()
    this._status = 'idle'
  }

  connect(token) {
    if (!token) return
    this._token = token
    this._disposed = false
    this._open()
  }

  setToken(token) {
    if (this._token === token) return
    this._token = token
    if (!this._disposed) {
      this._closeSocket()
      this._open()
    }
  }

  disconnect() {
    this._disposed = true
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer)
      this._reconnectTimer = null
    }
    this._closeSocket()
    this._setStatus('idle')
  }

  send(type, payload = {}) {
    if (!this._socket || this._socket.readyState !== WebSocket.OPEN) return false
    try {
      this._socket.send(JSON.stringify({ type, ...payload }))
      return true
    } catch {
      return false
    }
  }

  sendTyping(chatId, isTyping) {
    this.send(isTyping ? 'typing.start' : 'typing.stop', { chat_id: chatId })
  }

  sendRead(chatId, messageId) {
    this.send('message.read', { chat_id: chatId, message_id: messageId })
  }

  addListener(handler) {
    this._listeners.add(handler)
    return () => this._listeners.delete(handler)
  }

  onStatusChange(handler) {
    this._statusListeners.add(handler)
    handler(this._status)
    return () => this._statusListeners.delete(handler)
  }

  _open() {
    if (this._disposed || !this._token || !WS_URL) return
    const url = WS_URL.includes('?')
      ? `${WS_URL}&token=${encodeURIComponent(this._token)}`
      : `${WS_URL}?token=${encodeURIComponent(this._token)}`

    this._setStatus('connecting')
    try {
      const socket = new WebSocket(url)
      this._socket = socket

      socket.addEventListener('open', () => {
        this._backoff = INITIAL_BACKOFF_MS
        this._setStatus('open')
      })
      socket.addEventListener('message', (event) => {
        let parsed
        try {
          parsed = JSON.parse(event.data)
        } catch {
          return
        }
        const type = parsed?.type
        const data = parsed?.data ?? {}
        if (!type) return
        for (const fn of this._listeners) {
          try {
            fn(type, data)
          } catch {
            /* ignore listener errors */
          }
        }
      })
      socket.addEventListener('close', () => {
        this._socket = null
        if (this._disposed) return
        this._setStatus('reconnecting')
        this._scheduleReconnect()
      })
      socket.addEventListener('error', () => {
        try {
          socket.close()
        } catch {
          /* ignore */
        }
      })
    } catch {
      this._scheduleReconnect()
    }
  }

  _scheduleReconnect() {
    if (this._disposed) return
    if (this._reconnectTimer) clearTimeout(this._reconnectTimer)
    const delay = Math.min(this._backoff, MAX_BACKOFF_MS)
    this._reconnectTimer = setTimeout(() => {
      this._reconnectTimer = null
      this._open()
    }, delay)
    this._backoff = Math.min(this._backoff * 2, MAX_BACKOFF_MS)
  }

  _closeSocket() {
    if (this._socket) {
      try {
        this._socket.close()
      } catch {
        /* ignore */
      }
      this._socket = null
    }
  }

  _setStatus(status) {
    if (this._status === status) return
    this._status = status
    for (const fn of this._statusListeners) {
      try {
        fn(status)
      } catch {
        /* ignore */
      }
    }
  }
}

export const wsClient = new WSClient()
