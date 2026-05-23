import { useState } from 'react'
import { Download, File as FileIcon, Play } from 'lucide-react'
import { mediaUrl } from '../../lib/env.js'
import { formatVoiceDuration } from '../../lib/format.js'
import { VoicePlayer } from './VoicePlayer.jsx'
import { MediaLightbox } from './MediaLightbox.jsx'
import styles from './MediaContent.module.css'

function inferFilename(url) {
  if (!url) return 'file'
  const last = url.split('/').pop() || 'file'
  return last.split('?')[0]
}

export function MediaContent({ message, isMine }) {
  const [lightbox, setLightbox] = useState(null)
  const url = mediaUrl(message.media_url, { auth: true })

  if (message.type === 'voice') {
    return (
      <VoicePlayer
        url={url}
        durationSec={message.duration_sec}
        isMine={isMine}
      />
    )
  }

  if (message.type === 'image') {
    return (
      <>
        <button
          type="button"
          className={styles.imageBtn}
          onClick={() => setLightbox({ type: 'image', src: url })}
          aria-label="Открыть изображение"
        >
          <img src={url} alt="" loading="lazy" />
        </button>
        {lightbox ? (
          <MediaLightbox item={lightbox} onClose={() => setLightbox(null)} />
        ) : null}
      </>
    )
  }

  if (message.type === 'video') {
    return (
      <>
        <button
          type="button"
          className={styles.videoBtn}
          onClick={() => setLightbox({ type: 'video', src: url })}
          aria-label="Воспроизвести видео"
        >
          <video src={url} preload="metadata" muted playsInline />
          <span className={styles.playBadge} aria-hidden>
            <Play size={28} />
          </span>
        </button>
        {lightbox ? (
          <MediaLightbox item={lightbox} onClose={() => setLightbox(null)} />
        ) : null}
      </>
    )
  }

  if (message.type === 'file') {
    const filename = inferFilename(message.media_url)
    return (
      <a
        href={url}
        download={filename}
        rel="noopener noreferrer"
        target="_blank"
        className={`${styles.file} ${isMine ? styles.fileMine : ''}`}
      >
        <span className={styles.fileIcon} aria-hidden>
          <FileIcon size={22} />
        </span>
        <span className={styles.fileBody}>
          <span className={styles.fileName}>{filename}</span>
          <span className={styles.fileSub}>
            {message.duration_sec
              ? formatVoiceDuration(message.duration_sec)
              : 'Файл'}
          </span>
        </span>
        <span className={styles.fileDownload} aria-hidden>
          <Download size={18} />
        </span>
      </a>
    )
  }

  return null
}
