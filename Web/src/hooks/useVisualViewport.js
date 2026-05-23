import { useEffect } from 'react'

/**
 * Track the on-screen keyboard offset on mobile and expose it as the CSS
 * variable --keyboard-inset. Layouts that anchor a compose bar to the bottom
 * can subtract this value to stay above the keyboard.
 */
export function useVisualViewport() {
  useEffect(() => {
    const root = document.documentElement
    const vv = window.visualViewport
    if (!vv) {
      root.style.setProperty('--keyboard-inset', '0px')
      return undefined
    }

    const update = () => {
      const offset = Math.max(0, window.innerHeight - vv.height - vv.offsetTop)
      root.style.setProperty('--keyboard-inset', `${offset}px`)
    }

    update()
    vv.addEventListener('resize', update)
    vv.addEventListener('scroll', update)
    return () => {
      vv.removeEventListener('resize', update)
      vv.removeEventListener('scroll', update)
    }
  }, [])
}
