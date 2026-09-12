import { useEffect, useRef } from 'react'
import {
  Mic,
  MicOff,
  Phone,
  PhoneOff,
  Video,
  VideoOff,
} from 'lucide-react'
import { Avatar } from '../../components/Avatar.jsx'
import { useCallStore } from '../../store/callStore.js'
import { callManager } from '../../lib/callManager.js'
import styles from './CallOverlay.module.css'

function VideoEl({ stream, className, muted = false }) {
  const ref = useRef(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    el.srcObject = stream ?? null
  }, [stream])
  if (!stream) return null
  return (
    <video
      ref={ref}
      className={className}
      autoPlay
      playsInline
      muted={muted}
    />
  )
}

export function CallOverlay() {
  const status = useCallStore((s) => s.status)
  const peerName = useCallStore((s) => s.peerName)
  const media = useCallStore((s) => s.media)
  const muted = useCallStore((s) => s.muted)
  const videoEnabled = useCallStore((s) => s.videoEnabled)
  const localStream = useCallStore((s) => s.localStream)
  const remoteStream = useCallStore((s) => s.remoteStream)

  if (status === 'idle' || status === 'ending') return null

  const showVideo = media === 'video' || videoEnabled
  const statusLabel =
    status === 'incoming'
      ? 'Входящий звонок…'
      : status === 'outgoing'
        ? 'Вызов…'
        : status === 'active'
          ? 'Разговор'
          : ''

  return (
    <div
      className={styles.overlay}
      role="dialog"
      aria-modal="true"
      aria-label="Звонок"
    >
      {showVideo && status === 'active' ? (
        <div className={styles.videos}>
          <VideoEl stream={remoteStream} className={styles.remoteVideo} />
          <VideoEl
            stream={localStream}
            className={styles.localVideo}
            muted
          />
        </div>
      ) : (
        <div className={styles.avatarWrap}>
          {(status === 'incoming' || status === 'outgoing') && (
            <span className={styles.pulse} aria-hidden />
          )}
          <Avatar src="" name={peerName} size={112} />
        </div>
      )}

      <div>
        <h2 className={styles.name}>{peerName}</h2>
        <p className={styles.status}>{statusLabel}</p>
      </div>

      <div className={styles.controls}>
        {status === 'incoming' ? (
          <>
            <button
              type="button"
              className={`${styles.controlBtn} ${styles.acceptBtn}`}
              aria-label="Принять"
              onClick={() => callManager.acceptCall()}
            >
              <Phone size={24} />
            </button>
            <button
              type="button"
              className={`${styles.controlBtn} ${styles.endBtn}`}
              aria-label="Отклонить"
              onClick={() => callManager.rejectCall()}
            >
              <PhoneOff size={24} />
            </button>
          </>
        ) : (
          <>
            {status === 'active' ? (
              <>
                <button
                  type="button"
                  className={`${styles.controlBtn} ${muted ? styles.controlBtnActive : ''}`}
                  aria-label={muted ? 'Включить микрофон' : 'Выключить микрофон'}
                  aria-pressed={muted}
                  onClick={() => callManager.toggleMute()}
                >
                  {muted ? <MicOff size={22} /> : <Mic size={22} />}
                </button>
                {media === 'video' ? (
                  <button
                    type="button"
                    className={`${styles.controlBtn} ${!videoEnabled ? styles.controlBtnActive : ''}`}
                    aria-label={videoEnabled ? 'Выключить камеру' : 'Включить камеру'}
                    aria-pressed={!videoEnabled}
                    onClick={() => callManager.toggleVideo()}
                  >
                    {videoEnabled ? (
                      <Video size={22} />
                    ) : (
                      <VideoOff size={22} />
                    )}
                  </button>
                ) : null}
              </>
            ) : null}
            <button
              type="button"
              className={`${styles.controlBtn} ${styles.endBtn}`}
              aria-label="Завершить звонок"
              onClick={() => callManager.endCall('hangup')}
            >
              <PhoneOff size={24} />
            </button>
          </>
        )}
      </div>
    </div>
  )
}
