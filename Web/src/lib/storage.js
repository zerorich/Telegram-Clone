const ACCESS_TOKEN = 'tg.access_token'
const REFRESH_TOKEN = 'tg.refresh_token'
const USER = 'tg.user'
const THEME = 'tg.theme'
const NOTIFICATIONS = 'tg.notifications'

const safe = {
  get(key) {
    try {
      return window.localStorage.getItem(key)
    } catch {
      return null
    }
  },
  set(key, value) {
    try {
      window.localStorage.setItem(key, value)
    } catch {
      /* ignore quota errors */
    }
  },
  remove(key) {
    try {
      window.localStorage.removeItem(key)
    } catch {
      /* ignore */
    }
  },
}

export const tokenStorage = {
  getAccess: () => safe.get(ACCESS_TOKEN) ?? '',
  getRefresh: () => safe.get(REFRESH_TOKEN) ?? '',
  set(access, refresh) {
    if (access) safe.set(ACCESS_TOKEN, access)
    if (refresh) safe.set(REFRESH_TOKEN, refresh)
  },
  clear() {
    safe.remove(ACCESS_TOKEN)
    safe.remove(REFRESH_TOKEN)
  },
}

export const userStorage = {
  get() {
    const raw = safe.get(USER)
    if (!raw) return null
    try {
      return JSON.parse(raw)
    } catch {
      return null
    }
  },
  set(user) {
    if (user) safe.set(USER, JSON.stringify(user))
    else safe.remove(USER)
  },
  clear: () => safe.remove(USER),
}

export const themeStorage = {
  get: () => safe.get(THEME) ?? 'system',
  set: (value) => safe.set(THEME, value),
}

export const notificationStorage = {
  getEnabled: () => safe.get(NOTIFICATIONS) !== 'off',
  setEnabled: (on) => safe.set(NOTIFICATIONS, on ? 'on' : 'off'),
}
