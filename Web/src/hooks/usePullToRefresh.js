import { useEffect, useRef, useState } from 'react'

const THRESHOLD = 72

/**
 * Simple pull-to-refresh for a scroll container at scrollTop === 0.
 */
export function usePullToRefresh(containerRef, onRefresh) {
  const [pulling, setPulling] = useState(false)
  const [offset, setOffset] = useState(0)
  const startY = useRef(0)
  const active = useRef(false)
  const offsetRef = useRef(0)
  const onRefreshRef = useRef(onRefresh)
  onRefreshRef.current = onRefresh

  useEffect(() => {
    offsetRef.current = offset
  }, [offset])

  useEffect(() => {
    const el = containerRef.current
    if (!el) return undefined

    function onTouchStart(e) {
      if (el.scrollTop > 0) return
      startY.current = e.touches[0].clientY
      active.current = true
    }

    function onTouchMove(e) {
      if (!active.current) return
      const dy = e.touches[0].clientY - startY.current
      if (dy <= 0) {
        setOffset(0)
        setPulling(false)
        return
      }
      setOffset(Math.min(dy * 0.45, THRESHOLD + 20))
      setPulling(true)
    }

    async function onTouchEnd() {
      if (!active.current) return
      active.current = false
      const current = offsetRef.current
      if (current >= THRESHOLD) {
        try {
          await onRefreshRef.current?.()
        } finally {
          setOffset(0)
          setPulling(false)
        }
        return
      }
      setOffset(0)
      setPulling(false)
    }

    el.addEventListener('touchstart', onTouchStart, { passive: true })
    el.addEventListener('touchmove', onTouchMove, { passive: true })
    el.addEventListener('touchend', onTouchEnd)
    return () => {
      el.removeEventListener('touchstart', onTouchStart)
      el.removeEventListener('touchmove', onTouchMove)
      el.removeEventListener('touchend', onTouchEnd)
    }
  }, [containerRef])

  return { pulling, offset }
}
