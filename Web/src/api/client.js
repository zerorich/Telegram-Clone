import axios from 'axios'
import { API_BASE_URL } from '../lib/env.js'
import { tokenStorage } from '../lib/storage.js'

export const httpClient = axios.create({
  baseURL: API_BASE_URL || '/',
  timeout: 30000,
})

let onAuthFailure = null

/** Wire a callback that fires when refresh fails (logout from anywhere). */
export function setAuthFailureHandler(fn) {
  onAuthFailure = fn
}

httpClient.interceptors.request.use((config) => {
  const token = tokenStorage.getAccess()
  if (token && !config.headers?.Authorization) {
    config.headers = config.headers ?? {}
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

let refreshPromise = null

async function refreshTokens() {
  if (refreshPromise) return refreshPromise
  const refresh = tokenStorage.getRefresh()
  if (!refresh) {
    refreshPromise = Promise.resolve(false)
    return refreshPromise
  }
  refreshPromise = (async () => {
    try {
      const res = await axios.post(
        `${API_BASE_URL || ''}/api/auth/refresh`,
        { refresh_token: refresh },
      )
      const data = res.data?.data
      if (!data?.access_token || !data?.refresh_token) return false
      tokenStorage.set(data.access_token, data.refresh_token)
      return true
    } catch {
      return false
    } finally {
      // small microtask so concurrent retries see the resolved value before we
      // forget the in-flight promise
      queueMicrotask(() => {
        refreshPromise = null
      })
    }
  })()
  return refreshPromise
}

httpClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config
    const status = error.response?.status

    if (
      status === 401 &&
      original &&
      !original._retried &&
      !original.url?.includes('/api/auth/')
    ) {
      original._retried = true
      const ok = await refreshTokens()
      if (ok) {
        const token = tokenStorage.getAccess()
        original.headers = original.headers ?? {}
        original.headers.Authorization = `Bearer ${token}`
        return httpClient(original)
      }
      tokenStorage.clear()
      if (onAuthFailure) onAuthFailure()
    }

    return Promise.reject(error)
  },
)

/**
 * Unwrap the standard `{ success, data, error }` envelope.
 * Throws an Error with the server-provided message on failure.
 */
export function unwrap(response) {
  const body = response?.data
  if (body && typeof body === 'object' && 'success' in body) {
    if (body.success) return body.data
    const err = new Error(body.error || 'Запрос не выполнен')
    err.serverError = true
    throw err
  }
  return body
}

/** Friendly error message for catch blocks. */
export function describeError(error) {
  if (!error) return 'Что-то пошло не так'
  if (error.response) {
    const data = error.response.data
    if (typeof data?.error === 'string' && data.error) return data.error
    if (typeof data?.message === 'string') return data.message
    if (error.response.status === 401) return 'Сессия истекла, войдите снова'
    if (error.response.status === 429) {
      return 'Слишком много запросов, попробуйте позже'
    }
    return `Ошибка ${error.response.status}`
  }
  if (error.request) return 'Нет соединения с сервером'
  return error.message || 'Что-то пошло не так'
}
