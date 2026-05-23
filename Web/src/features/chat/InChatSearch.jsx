import { useEffect, useRef, useState } from 'react'
import { Search, X } from 'lucide-react'
import { messagesApi } from '../../api/messages.js'
import { Spinner } from '../../components/Spinner.jsx'
import { formatMessageTime, formatChatDateSeparator } from '../../lib/format.js'
import styles from './InChatSearch.module.css'

const TYPE_LABELS = {
  image: 'Фото',
  video: 'Видео',
  voice: 'Голосовое сообщение',
  file: 'Файл',
}

function snippetFor(message) {
  if (!message) return ''
  if (message.is_deleted) return 'Сообщение удалено'
  if (message.type === 'text') return (message.content ?? '').trim()
  const label = TYPE_LABELS[message.type] || ''
  const caption = (message.content ?? '').trim()
  return caption ? `${label}: ${caption}` : label
}

/**
 * Inline header search bar + result overlay for the currently open chat.
 *
 * - Debounces input by 300ms before hitting the server
 * - Renders up to 10 results visible at a time (overlay scrolls for more)
 * - Calling `onPick(message)` is the parent's job to scroll-to-message
 */
export function InChatSearch({ chatId, onClose, onPick }) {
  const inputRef = useRef(null)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const debounceRef = useRef(null)
  const requestIdRef = useRef(0)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  useEffect(() => {
    function onKey(e) {
      if (e.key === 'Escape') onClose?.()
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    const trimmed = query.trim()
    if (trimmed.length < 1) {
      setResults([])
      setLoading(false)
      setError(null)
      return undefined
    }
    setLoading(true)
    setError(null)
    debounceRef.current = setTimeout(async () => {
      const id = ++requestIdRef.current
      try {
        const messages = await messagesApi.search(chatId, {
          q: trimmed,
          limit: 50,
        })
        if (id !== requestIdRef.current) return
        setResults(messages)
      } catch (err) {
        if (id !== requestIdRef.current) return
        setError(err)
        setResults([])
      } finally {
        if (id === requestIdRef.current) setLoading(false)
      }
    }, 300)
    return () => clearTimeout(debounceRef.current)
  }, [query, chatId])

  return (
    <div className={styles.layer}>
      <div className={styles.bar}>
        <Search size={18} className={styles.icon} />
        <input
          ref={inputRef}
          className={styles.input}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Поиск по чату"
          type="search"
          aria-label="Поиск по чату"
        />
        <button
          type="button"
          className={styles.close}
          onClick={onClose}
          aria-label="Закрыть поиск"
        >
          <X size={18} />
        </button>
      </div>

      {query.trim() ? (
        <div className={styles.overlay} role="listbox">
          {loading ? (
            <div className={styles.center}>
              <Spinner size={20} />
            </div>
          ) : error ? (
            <div className={styles.center}>
              <span className={styles.muted}>Ошибка поиска</span>
            </div>
          ) : !results.length ? (
            <div className={styles.center}>
              <span className={styles.muted}>Ничего не найдено</span>
            </div>
          ) : (
            results.map((m) => (
              <button
                key={m.id}
                type="button"
                role="option"
                className={styles.row}
                onClick={() => onPick?.(m)}
              >
                <div className={styles.rowMain}>
                  <span className={styles.rowSnippet}>
                    {snippetFor(m) || '\u00A0'}
                  </span>
                </div>
                <div className={styles.rowMeta}>
                  <span>{formatChatDateSeparator(m.created_at)}</span>
                  <span className={styles.rowDot}>·</span>
                  <span>{formatMessageTime(m.created_at)}</span>
                </div>
              </button>
            ))
          )}
        </div>
      ) : null}
    </div>
  )
}
