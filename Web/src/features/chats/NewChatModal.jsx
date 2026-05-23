import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { usersApi } from '../../api/users.js'
import { chatsApi } from '../../api/chats.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './NewChat.module.css'

export function NewChatModal() {
  const navigate = useNavigate()
  const showToast = useUiStore((s) => s.showToast)
  const upsertChat = useChatsStore((s) => s.upsertChat)

  const [query, setQuery] = useState('')
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(false)
  const [creating, setCreating] = useState(false)
  const debounceRef = useRef(null)
  const inputRef = useRef(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      setUsers([])
      setLoading(false)
      return undefined
    }
    setLoading(true)
    debounceRef.current = setTimeout(async () => {
      try {
        const result = await usersApi.search(trimmed)
        setUsers(result)
      } catch (err) {
        showToast(describeError(err), { kind: 'error' })
      } finally {
        setLoading(false)
      }
    }, 250)
    return () => debounceRef.current && clearTimeout(debounceRef.current)
  }, [query, showToast])

  async function open(userId) {
    setCreating(true)
    try {
      const chat = await chatsApi.createDirect(userId)
      upsertChat(chat)
      navigate(`/chats/${chat.id}`, { replace: true })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setCreating(false)
    }
  }

  return (
    <Modal open onClose={() => navigate(-1)} title="Новое сообщение" size="md">
      <div className={styles.searchBox}>
        <Search size={18} className={styles.searchIcon} />
        <input
          ref={inputRef}
          className={styles.searchInput}
          placeholder="Поиск по имени, email или телефону"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          type="search"
        />
      </div>
      <div className={styles.results}>
        {loading ? (
          <div className={styles.center}>
            <Spinner size={22} label="Поиск" />
          </div>
        ) : !users.length ? (
          <div className={styles.center}>
            <p className={styles.hint}>
              {query.trim().length < 2
                ? 'Введите минимум 2 символа'
                : 'Никого не найдено'}
            </p>
          </div>
        ) : (
          users.map((u) => (
            <button
              key={u.id}
              type="button"
              className={styles.row}
              disabled={creating}
              onClick={() => open(u.id)}
            >
              <Avatar
                src={mediaUrl(u.avatar_url, { auth: true })}
                name={userDisplayName(u)}
                size={42}
              />
              <div className={styles.rowBody}>
                <div className={styles.rowName}>{userDisplayName(u)}</div>
                <div className={styles.rowSub}>
                  {u.username ? `@${u.username}` : u.email || u.phone}
                </div>
              </div>
            </button>
          ))
        )}
      </div>
    </Modal>
  )
}
