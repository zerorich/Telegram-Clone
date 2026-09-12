import { useEffect } from 'react'
import { useUiStore } from '../store/uiStore.js'

/**
 * Keeps <meta name="theme-color"> in sync with the active theme.
 */
export function ThemeColorMeta() {
  const theme = useUiStore((s) => s.theme)

  useEffect(() => {
    const color =
      getComputedStyle(document.documentElement)
        .getPropertyValue('--theme-color')
        .trim() || (theme === 'light' ? '#ffffff' : '#17212b')
    let meta = document.querySelector('meta[name="theme-color"]')
    if (!meta) {
      meta = document.createElement('meta')
      meta.setAttribute('name', 'theme-color')
      document.head.appendChild(meta)
    }
    meta.setAttribute('content', color)
  }, [theme])

  return null
}
