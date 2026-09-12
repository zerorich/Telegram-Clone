import { useEffect, useRef } from 'react'

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'

/**
 * Trap focus inside `containerRef` while `active` is true.
 */
export function useFocusTrap(containerRef, active) {
  const previouslyFocused = useRef(null)

  useEffect(() => {
    if (!active || !containerRef.current) return undefined

    previouslyFocused.current = document.activeElement

    const root = containerRef.current
    const nodes = () =>
      [...root.querySelectorAll(FOCUSABLE)].filter(
        (el) => !el.hasAttribute('disabled') && el.offsetParent !== null,
      )

    const focusFirst = () => {
      const list = nodes()
      ;(list[0] ?? root).focus?.()
    }

    focusFirst()

    function onKeyDown(e) {
      if (e.key !== 'Tab') return
      const list = nodes()
      if (!list.length) return
      const first = list[0]
      const last = list[list.length - 1]
      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault()
          last.focus()
        }
      } else if (document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }

    root.addEventListener('keydown', onKeyDown)
    return () => {
      root.removeEventListener('keydown', onKeyDown)
      previouslyFocused.current?.focus?.()
    }
  }, [active, containerRef])
}
