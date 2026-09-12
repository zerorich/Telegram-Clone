import { X } from 'lucide-react'
import { mediaTypeLabel } from '../../lib/format.js'
import styles from './Composer.module.css'

export function ComposerBanner({ mode, target, onCancel }) {
  if (!target) return null

  const isEdit = mode === 'edit'
  const title = isEdit ? 'Редактирование' : 'Ответ на сообщение'
  const cancelLabel = isEdit ? 'Отмена редактирования' : 'Отменить ответ'

  let preview = ''
  if (isEdit) {
    preview = target.content?.trim() || 'медиа'
  } else if (target.is_deleted) {
    preview = 'Сообщение удалено'
  } else {
    preview =
      target.content?.trim() || mediaTypeLabel(target.type) || ''
  }

  return (
    <div className={styles.banner}>
      <div className={styles.bannerBar} aria-hidden />
      <div className={styles.bannerBody}>
        <div className={styles.bannerTitle}>{title}</div>
        <div className={styles.bannerText}>{preview}</div>
      </div>
      <button
        type="button"
        className={styles.bannerClose}
        aria-label={cancelLabel}
        onClick={onCancel}
      >
        <X size={18} />
      </button>
    </div>
  )
}
