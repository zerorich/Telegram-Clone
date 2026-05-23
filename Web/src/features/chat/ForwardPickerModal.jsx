import { useMemo, useRef, useState, useEffect } from 'react'
import { Search } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import {
  chatAvatarUrl,
  chatDisplayTitle,
  isSavedChat,
} from '../../lib/chat.js'
import styles from '../chats/NewChat.module.css'

/**
 * Picker for forwarding a message to another chat. Saved chat sticks to top.
 *
 * Calls `onPick(chat)` and lets the parent execute the API request +
 * toast / close handling, so we don't double-fire requests on a slow network.
 */
export function ForwardPickerModal({ open, onClose, onPick, excludeChatId }) {
  const user = useAuthStore((s) => s.user)
  const chats = useChatsStore((s) => s.chats)
  const inputRef = useRef(null)
  const [query, setQuery] = useState('')

  useEffect(() => {
    if (!open) {
      setQuery('')
      return
    }
    inputRef.current?.focus()
  }, [open])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    const items = chats.filter((c) => c.id !== excludeChatId)
    if (!q) return items
    return items.filter((c) =>
      chatDisplayTitle(c, user?.id).toLowerCase().includes(q),
    )
  }, [chats, excludeChatId, query, user?.id])

  return (
    <Modal open={open} onClose={onClose} title="Переслать" size="md">
      <div className={styles.searchBox}>
        <Search size={18} className={styles.searchIcon} />
        <input
          ref={inputRef}
          className={styles.searchInput}
          placeholder="Поиск чата"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          type="search"
        />
      </div>
      <div className={styles.results}>
        {!filtered.length ? (
          <div className={styles.center}>
            <p className={styles.hint}>Ничего не найдено</p>
          </div>
        ) : (
          filtered.map((c) => {
            const saved = isSavedChat(c)
            const title = chatDisplayTitle(c, user?.id)
            return (
              <button
                key={c.id}
                type="button"
                className={styles.row}
                onClick={() => onPick?.(c)}
              >
                <Avatar
                  src={saved ? '' : chatAvatarUrl(c, user?.id)}
                  name={title}
                  size={42}
                  saved={saved}
                />
                <div className={styles.rowBody}>
                  <div className={styles.rowName}>{title}</div>
                  <div className={styles.rowSub}>
                    {saved
                      ? 'Сохранённые сообщения'
                      : c.type === 'group'
                        ? 'Группа'
                        : 'Личный чат'}
                  </div>
                </div>
              </button>
            )
          })
        )}
      </div>
    </Modal>
  )
}
