import { create } from 'zustand'
import { authApi } from '../api/auth.js'
import { usersApi } from '../api/users.js'
import { tokenStorage, userStorage } from '../lib/storage.js'
import { setAuthFailureHandler } from '../api/client.js'
import { wsClient } from '../ws/client.js'

const initialUser = userStorage.get()
const initialAccess = tokenStorage.getAccess()

export const useAuthStore = create((set, get) => ({
  user: initialUser,
  accessToken: initialAccess,
  status: initialAccess && initialUser ? 'authenticated' : 'unauthenticated',
  bootstrapped: false,
  draftEmail: '',
  registrationToken: '',

  setDraftEmail(email) {
    set({ draftEmail: email })
  },

  setUser(user) {
    userStorage.set(user)
    set({ user })
  },

  /**
   * Resolve the initial auth state on app boot. If we have tokens, fetch the
   * profile to validate them. Otherwise we just mark bootstrap done.
   */
  async bootstrap() {
    if (get().bootstrapped) return
    const access = tokenStorage.getAccess()
    if (!access) {
      set({ bootstrapped: true, status: 'unauthenticated' })
      return
    }
    try {
      const user = await usersApi.me()
      userStorage.set(user)
      set({
        user,
        accessToken: tokenStorage.getAccess(),
        status: 'authenticated',
        bootstrapped: true,
      })
      wsClient.connect(tokenStorage.getAccess())
    } catch {
      tokenStorage.clear()
      userStorage.clear()
      set({
        user: null,
        accessToken: '',
        status: 'unauthenticated',
        bootstrapped: true,
      })
    }
  },

  async sendCode(email) {
    await authApi.sendCode(email)
    set({ draftEmail: email })
  },

  /** @returns {Promise<boolean>} true if the user must complete their profile */
  async verifyCode(email, code) {
    const data = await authApi.verifyCode(email, code)
    if (data?.is_new_user) {
      set({ registrationToken: data.registration_token ?? '' })
      return true
    }
    tokenStorage.set(data.tokens.access_token, data.tokens.refresh_token)
    userStorage.set(data.user)
    set({
      user: data.user,
      accessToken: data.tokens.access_token,
      status: 'authenticated',
      registrationToken: '',
    })
    wsClient.connect(data.tokens.access_token)
    return false
  },

  async completeProfile({ email, name, surname, phone }) {
    const registrationToken = get().registrationToken
    const data = await authApi.completeProfile(
      { email, name, surname, phone },
      { registrationToken },
    )
    tokenStorage.set(data.tokens.access_token, data.tokens.refresh_token)
    userStorage.set(data.user)
    set({
      user: data.user,
      accessToken: data.tokens.access_token,
      status: 'authenticated',
      registrationToken: '',
    })
    wsClient.connect(data.tokens.access_token)
  },

  async logout() {
    const refresh = tokenStorage.getRefresh()
    try {
      await authApi.logout(refresh)
    } catch {
      /* ignore: best-effort blacklist call */
    }
    wsClient.disconnect()
    tokenStorage.clear()
    userStorage.clear()
    set({
      user: null,
      accessToken: '',
      status: 'unauthenticated',
      draftEmail: '',
      registrationToken: '',
    })
  },

  forceLogout() {
    wsClient.disconnect()
    tokenStorage.clear()
    userStorage.clear()
    set({
      user: null,
      accessToken: '',
      status: 'unauthenticated',
      registrationToken: '',
    })
  },
}))

setAuthFailureHandler(() => {
  useAuthStore.getState().forceLogout()
})
