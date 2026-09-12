import { useEffect, useRef, useState } from 'react'
import { Check, Search, X } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { usersApi } from '../../api/users.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import chatStyles from '../chats/NewChat.module.css'

export function AddMembersDialog({ existingIds, onClose, onConfirm }) {
  const showToast = useUiStore((s) => s.showToast)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [selected, setSelected] = useState([])
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const debounceRef = useRef(null)

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      setResults([])
      return undefined
    }
    setLoading(true)
    debounceRef.current = setTimeout(async () => {
      try {
        const list = await usersApi.search(trimmed)
        setResults(list.filter((u) => !existingIds.includes(u.id)))
      } catch (err) {
        showToast(describeError(err), { kind: 'error' })
      } finally {
        setLoading(false)
      }
    }, 250)
    return () => debounceRef.current && clearTimeout(debounceRef.current)
  }, [query, existingIds, showToast])

  function toggle(u) {
    setSelected((cur) =>
      cur.some((x) => x.id === u.id)
        ? cur.filter((x) => x.id !== u.id)
        : [...cur, u],
    )
  }

  async function submit() {
    if (!selected.length) return
    setSubmitting(true)
    try {
      await onConfirm(selected.map((u) => u.id))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title="Добавить участников"
      size="md"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Отмена
          </Button>
          <Button onClick={submit} loading={submitting} disabled={!selected.length}>
            Добавить
          </Button>
        </>
      }
    >
      {selected.length ? (
        <div className={chatStyles.chips}>
          {selected.map((u) => (
            <span key={u.id} className={chatStyles.chip}>
              {userDisplayName(u)}
              <button
                type="button"
                onClick={() => toggle(u)}
                aria-label="Убрать"
              >
                <X size={14} />
              </button>
            </span>
          ))}
        </div>
      ) : null}
      <div className={chatStyles.searchBox}>
        <Search size={18} className={chatStyles.searchIcon} />
        <input
          type="search"
          className={chatStyles.searchInput}
          placeholder="Поиск пользователей"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          autoFocus
          aria-label="Поиск пользователей"
        />
      </div>
      <div className={chatStyles.results}>
        {loading ? (
          <div className={chatStyles.center}>
            <Spinner size={22} />
          </div>
        ) : !results.length ? (
          <div className={chatStyles.center}>
            <p className={chatStyles.hint}>
              {query.trim().length < 2
                ? 'Введите минимум 2 символа'
                : 'Ничего не найдено'}
            </p>
          </div>
        ) : (
          results.map((u) => {
            const picked = selected.some((x) => x.id === u.id)
            return (
              <button
                key={u.id}
                type="button"
                className={chatStyles.row}
                onClick={() => toggle(u)}
              >
                <Avatar
                  src={mediaUrl(u.avatar_url, { auth: true })}
                  name={userDisplayName(u)}
                  size={40}
                />
                <div className={chatStyles.rowBody}>
                  <div className={chatStyles.rowName}>
                    {userDisplayName(u)}
                  </div>
                  <div className={chatStyles.rowSub}>
                    {u.username ? `@${u.username}` : u.email || u.phone}
                  </div>
                </div>
                {picked ? (
                  <span className={chatStyles.check}>
                    <Check size={14} />
                  </span>
                ) : null}
              </button>
            )
          })
        )}
      </div>
    </Modal>
  )
}
