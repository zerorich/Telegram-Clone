import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Camera, Check, Search, X } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { chatsApi } from '../../api/chats.js'
import { usersApi } from '../../api/users.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './NewChat.module.css'

export function NewGroupModal() {
  const navigate = useNavigate()
  const upsertChat = useChatsStore((s) => s.upsertChat)
  const showToast = useUiStore((s) => s.showToast)
  const reloadChats = useChatsStore((s) => s.load)

  const [name, setName] = useState('')
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [selected, setSelected] = useState([])
  const [searching, setSearching] = useState(false)
  const [avatarFile, setAvatarFile] = useState(null)
  const [avatarPreview, setAvatarPreview] = useState(null)
  const [creating, setCreating] = useState(false)
  const fileRef = useRef(null)
  const debounceRef = useRef(null)

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      setResults([])
      setSearching(false)
      return undefined
    }
    setSearching(true)
    debounceRef.current = setTimeout(async () => {
      try {
        const list = await usersApi.search(trimmed)
        setResults(list)
      } catch (err) {
        showToast(describeError(err), { kind: 'error' })
      } finally {
        setSearching(false)
      }
    }, 250)
    return () => debounceRef.current && clearTimeout(debounceRef.current)
  }, [query, showToast])

  function pickAvatar() {
    fileRef.current?.click()
  }

  function onAvatarPicked(e) {
    const file = e.target.files?.[0]
    if (!file) return
    setAvatarFile(file)
    setAvatarPreview(URL.createObjectURL(file))
  }

  function toggle(user) {
    setSelected((cur) => {
      const exists = cur.some((u) => u.id === user.id)
      if (exists) return cur.filter((u) => u.id !== user.id)
      return [...cur, user]
    })
  }

  async function submit() {
    const trimmedName = name.trim()
    if (!trimmedName) {
      showToast('Введите название группы', { kind: 'error' })
      return
    }
    if (!selected.length) {
      showToast('Добавьте хотя бы одного участника', { kind: 'error' })
      return
    }
    setCreating(true)
    try {
      const chat = await chatsApi.createGroup({
        name: trimmedName,
        memberIds: selected.map((u) => u.id),
        avatar: avatarFile,
      })
      upsertChat(chat)
      reloadChats()
      navigate(`/chats/${chat.id}`, { replace: true })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setCreating(false)
    }
  }

  return (
    <Modal
      open
      onClose={() => navigate(-1)}
      title="Новая группа"
      size="md"
      footer={
        <>
          <Button variant="ghost" onClick={() => navigate(-1)}>
            Отмена
          </Button>
          <Button onClick={submit} loading={creating}>
            Создать
          </Button>
        </>
      }
    >
      <div className={styles.avatarRow}>
        <button
          type="button"
          className={styles.avatarBtn}
          onClick={pickAvatar}
          aria-label="Выбрать аватар"
        >
          {avatarPreview ? <img src={avatarPreview} alt="" /> : <Camera />}
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,image/png"
          hidden
          onChange={onAvatarPicked}
        />
        <div style={{ flex: 1 }}>
          <div className={styles.field}>
            <label className={styles.label} htmlFor="groupName">
              Название группы
            </label>
            <input
              id="groupName"
              className={styles.input}
              placeholder="Например, Семья"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
        </div>
      </div>

      {selected.length ? (
        <div className={styles.chips}>
          {selected.map((u) => (
            <span key={u.id} className={styles.chip}>
              {userDisplayName(u)}
              <button
                type="button"
                onClick={() => toggle(u)}
                aria-label="Удалить участника"
              >
                <X size={14} />
              </button>
            </span>
          ))}
        </div>
      ) : null}

      <div className={styles.searchBox}>
        <Search size={18} className={styles.searchIcon} />
        <input
          type="search"
          className={styles.searchInput}
          placeholder="Добавить участников"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      <div className={styles.results}>
        {searching ? (
          <div className={styles.center}>
            <Spinner size={22} />
          </div>
        ) : !results.length ? (
          <div className={styles.center}>
            <p className={styles.hint}>
              {query.trim().length < 2
                ? 'Введите минимум 2 символа'
                : 'Никого не найдено'}
            </p>
          </div>
        ) : (
          results.map((u) => {
            const isPicked = selected.some((x) => x.id === u.id)
            return (
              <button
                key={u.id}
                type="button"
                className={styles.row}
                onClick={() => toggle(u)}
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
                {isPicked ? (
                  <span className={styles.check} aria-hidden>
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
