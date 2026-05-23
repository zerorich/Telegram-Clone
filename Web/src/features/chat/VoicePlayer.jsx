import { useEffect, useRef, useState } from 'react'
import { Pause, Play } from 'lucide-react'
import { formatVoiceDuration } from '../../lib/format.js'
import styles from './VoicePlayer.module.css'

const PHASES = Array.from({ length: 24 }, (_, i) => Math.sin((i / 24) * Math.PI))

export function VoicePlayer({ url, durationSec, isMine = false }) {
  const audioRef = useRef(null)
  const [playing, setPlaying] = useState(false)
  const [progress, setProgress] = useState(0)
  const [resolvedDuration, setResolvedDuration] = useState(null)

  useEffect(() => {
    const audio = audioRef.current
    if (!audio) return undefined
    function onTime() {
      if (!Number.isFinite(audio.duration) || audio.duration === 0) return
      setProgress(audio.currentTime / audio.duration)
    }
    function onEnd() {
      setPlaying(false)
      setProgress(0)
    }
    function onLoaded() {
      if (Number.isFinite(audio.duration)) {
        setResolvedDuration(Math.round(audio.duration))
      }
    }
    audio.addEventListener('timeupdate', onTime)
    audio.addEventListener('ended', onEnd)
    audio.addEventListener('loadedmetadata', onLoaded)
    return () => {
      audio.removeEventListener('timeupdate', onTime)
      audio.removeEventListener('ended', onEnd)
      audio.removeEventListener('loadedmetadata', onLoaded)
    }
  }, [])

  async function toggle() {
    const audio = audioRef.current
    if (!audio) return
    if (playing) {
      audio.pause()
      setPlaying(false)
    } else {
      try {
        await audio.play()
        setPlaying(true)
      } catch {
        setPlaying(false)
      }
    }
  }

  const total = durationSec ?? resolvedDuration ?? 0
  const remaining = total
    ? formatVoiceDuration(total * (1 - progress))
    : formatVoiceDuration(0)

  return (
    <div className={`${styles.wrap} ${isMine ? styles.mine : ''}`}>
      <audio ref={audioRef} src={url} preload="metadata" />
      <button
        type="button"
        className={styles.play}
        onClick={toggle}
        aria-label={playing ? 'Пауза' : 'Воспроизвести'}
      >
        {playing ? <Pause size={20} /> : <Play size={20} />}
      </button>
      <div className={styles.wave}>
        {PHASES.map((p, i) => {
          const idxRatio = i / PHASES.length
          const filled = idxRatio < progress
          const height = 6 + p * 14
          return (
            <span
              key={i}
              className={`${styles.bar} ${filled ? styles.barFilled : ''}`}
              style={{ height: `${height}px` }}
            />
          )
        })}
      </div>
      <span className={styles.time}>{remaining}</span>
    </div>
  )
}
