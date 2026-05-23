import { create } from 'zustand'
import { themeStorage } from '../lib/storage.js'

function resolveTheme(setting) {
  if (setting === 'light' || setting === 'dark') return setting
  if (typeof window !== 'undefined' && window.matchMedia) {
    return window.matchMedia('(prefers-color-scheme: light)').matches
      ? 'light'
      : 'dark'
  }
  return 'dark'
}

function applyTheme(theme) {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-theme', theme)
}

const initialSetting = themeStorage.get()
const initialResolved = resolveTheme(initialSetting)
applyTheme(initialResolved)

if (typeof window !== 'undefined' && window.matchMedia) {
  const mq = window.matchMedia('(prefers-color-scheme: light)')
  mq.addEventListener?.('change', () => {
    const setting = useUiStore.getState().themeSetting
    if (setting === 'system') {
      const next = resolveTheme(setting)
      applyTheme(next)
      useUiStore.setState({ theme: next })
    }
  })
}

export const useUiStore = create((set) => ({
  themeSetting: initialSetting,
  theme: initialResolved,
  toast: null,

  setThemeSetting(value) {
    themeStorage.set(value)
    const theme = resolveTheme(value)
    applyTheme(theme)
    set({ themeSetting: value, theme })
  },

  showToast(message, opts = {}) {
    const id = Math.random().toString(36).slice(2)
    set({
      toast: {
        id,
        message,
        kind: opts.kind ?? 'info',
        duration: opts.duration ?? 4000,
        action: opts.action ?? null,
      },
    })
  },

  dismissToast() {
    set({ toast: null })
  },
}))
