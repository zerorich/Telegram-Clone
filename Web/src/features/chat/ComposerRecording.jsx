import { SendHorizontal, Trash2 } from 'lucide-react'
import { formatVoiceDuration } from '../../lib/format.js'
import styles from './Composer.module.css'

export function ComposerRecording({
  duration,
  onCancel,
  onFinish,
}) {
  return (
    <div className={styles.recording}>
      <span className={styles.recordingDot} aria-hidden />
      <span className={styles.recordingTime}>
        {formatVoiceDuration(duration)}
      </span>
      <span className={styles.recordingHint}>Запись…</span>
      <button
        type="button"
        className={styles.recordCancel}
        onClick={onCancel}
        aria-label="Отменить запись"
      >
        <Trash2 size={20} />
      </button>
      <button
        type="button"
        className={styles.sendBtn}
        onClick={onFinish}
        aria-label="Отправить голосовое"
      >
        <SendHorizontal size={20} />
      </button>
    </div>
  )
}
