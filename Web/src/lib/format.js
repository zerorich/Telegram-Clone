import {
  format,
  isToday,
  isYesterday,
  isThisWeek,
  isThisYear,
} from 'date-fns'
import { ru } from 'date-fns/locale'

function parseDate(value) {
  if (!value) return null
  if (value instanceof Date) return value
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? null : d
}

/** Telegram-style time label for the chat list. */
export function formatChatListTime(value) {
  const d = parseDate(value)
  if (!d) return ''
  if (isToday(d)) return format(d, 'HH:mm', { locale: ru })
  if (isThisWeek(d, { locale: ru })) return format(d, 'EEEEEE', { locale: ru })
  if (isThisYear(d)) return format(d, 'd MMM', { locale: ru })
  return format(d, 'dd.MM.yy', { locale: ru })
}

/** Date pill above message groups in the chat. */
export function formatChatDateSeparator(value) {
  const d = parseDate(value)
  if (!d) return ''
  if (isToday(d)) return 'Сегодня'
  if (isYesterday(d)) return 'Вчера'
  if (isThisYear(d)) return format(d, 'd MMMM', { locale: ru })
  return format(d, 'd MMMM yyyy', { locale: ru })
}

/** Short HH:mm time used inside message bubbles. */
export function formatMessageTime(value) {
  const d = parseDate(value)
  if (!d) return ''
  return format(d, 'HH:mm', { locale: ru })
}

export function formatVoiceDuration(seconds) {
  const total = Math.max(0, Math.round(seconds ?? 0))
  const m = Math.floor(total / 60)
  const s = total % 60
  return `${m}:${s.toString().padStart(2, '0')}`
}

export function formatFileSize(bytes) {
  if (!bytes && bytes !== 0) return ''
  if (bytes < 1024) return `${bytes} Б`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} КБ`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} МБ`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} ГБ`
}

const MEDIA_LABELS = {
  image: 'Фото',
  video: 'Видео',
  voice: 'Голосовое сообщение',
  file: 'Файл',
}

export function formatMessagePreview({
  content,
  type,
  isMine,
  senderName,
  isGroup,
  isDeleted,
}) {
  if (isDeleted) {
    return isMine ? 'Вы: сообщение удалено' : 'Сообщение удалено'
  }
  const body =
    type && type !== 'text'
      ? (MEDIA_LABELS[type] ?? '')
      : (content ?? '').trim()
  if (isMine) return `Вы: ${body}`
  if (isGroup && senderName) return `${senderName}: ${body}`
  return body
}

/** First letter for the avatar placeholder. */
export function avatarInitial(name) {
  if (!name) return '?'
  const trimmed = String(name).trim()
  if (!trimmed) return '?'
  return trimmed.charAt(0).toUpperCase()
}

/** Deterministic palette index 1..7 from any string. */
export function avatarColor(seed) {
  if (!seed) return 1
  let h = 0
  for (let i = 0; i < seed.length; i += 1) {
    h = (h * 31 + seed.charCodeAt(i)) >>> 0
  }
  return (h % 7) + 1
}
