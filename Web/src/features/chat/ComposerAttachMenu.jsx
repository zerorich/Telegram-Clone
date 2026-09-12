import {
  Paperclip,
  Image as ImageIcon,
  Video as VideoIcon,
  File as FileIcon,
  Mic,
} from 'lucide-react'
import styles from './Composer.module.css'

export function ComposerAttachMenu({
  open,
  disabled,
  onToggle,
  onPickImage,
  onPickVideo,
  onPickFile,
  onStartRecording,
}) {
  return (
    <div className={styles.attachWrap} data-attach-menu>
      <button
        type="button"
        className={styles.iconBtn}
        aria-label="Прикрепить"
        aria-expanded={open}
        aria-haspopup="menu"
        onClick={onToggle}
        disabled={disabled}
      >
        <Paperclip size={22} />
      </button>
      {open ? (
        <div className={styles.attachMenu} role="menu">
          <button type="button" role="menuitem" onClick={onPickImage}>
            <ImageIcon size={18} /> Фото
          </button>
          <button type="button" role="menuitem" onClick={onPickVideo}>
            <VideoIcon size={18} /> Видео
          </button>
          <button type="button" role="menuitem" onClick={onPickFile}>
            <FileIcon size={18} /> Файл
          </button>
          <button type="button" role="menuitem" onClick={onStartRecording}>
            <Mic size={18} /> Голосовое
          </button>
        </div>
      ) : null}
    </div>
  )
}
