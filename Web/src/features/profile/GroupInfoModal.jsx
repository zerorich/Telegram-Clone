import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Camera,
  Check,
  LogOut,
  Pencil,
  Search,
  Trash2,
  UserPlus,
  X,
} from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Input } from '../../components/Input.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { chatsApi } from '../../api/chats.js'
import { usersApi } from '../../api/users.js'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './Profile.module.css'
import chatStyles from '../chats/NewChat.module.css'

const ROLE_LABEL = {
  owner: 'Создатель',
  admin: 'Администратор',
  member: 'Участник',
}

export function GroupInfoModal() {
  const navigate = useNavigate()
  const { chatId } = useParams()
  const user = useAuthStore((s) => s.user)
  const removeChat = useChatsStore((s) => s.removeChat)
  const upsertChat = useChatsStore((s) => s.upsertChat)
  const reloadChats = useChatsStore((s) => s.load)
  const showToast = useUiStore((s) => s.showToast)

  const [detail, setDetail] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [editingName, setEditingName] = useState(false)
  const [name, setName] = useState('')
  const [saving, setSaving] = useState(false)
  const [addOpen, setAddOpen] = useState(false)
  const fileRef = useRef(null)

  useEffect(() => {
    refresh()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chatId])

  async function refresh() {
    setLoading(true)
    setError(null)
    try {
      const data = await chatsApi.get(chatId)
      setDetail(data)
      setName(data.chat?.name ?? '')
    } catch (err) {
      setError(err)
    } finally {
      setLoading(false)
    }
  }

  const me = detail?.members?.find((m) => m.user_id === user?.id)
  const canManage = me?.role === 'owner' || me?.role === 'admin'

  async function saveName() {
    const value = name.trim()
    if (!value || value === detail.chat.name) {
      setEditingName(false)
      return
    }
    setSaving(true)
    try {
      const chat = await chatsApi.updateGroup(chatId, { name: value })
      setDetail((cur) => ({ ...cur, chat: { ...cur.chat, ...chat } }))
      upsertChat({ ...detail.chat, ...chat })
      setEditingName(false)
      showToast('Группа обновлена', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setSaving(false)
    }
  }

  async function changeAvatar(e) {
    const file = e.target.files?.[0]
    if (!file) return
    setSaving(true)
    try {
      const chat = await chatsApi.updateGroup(chatId, { avatar: file })
      setDetail((cur) => ({ ...cur, chat: { ...cur.chat, ...chat } }))
      upsertChat({ ...detail.chat, ...chat })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setSaving(false)
      e.target.value = ''
    }
  }

  async function removeMember(member) {
    if (!window.confirm(`Удалить ${userDisplayName(member.user)}?`)) return
    try {
      await chatsApi.removeMember(chatId, member.user_id)
      setDetail((cur) => ({
        ...cur,
        members: cur.members.filter((m) => m.user_id !== member.user_id),
      }))
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function leave() {
    if (!window.confirm('Выйти из группы?')) return
    try {
      await chatsApi.leave(chatId)
      removeChat(chatId)
      navigate('/', { replace: true })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function addMembers(userIds) {
    try {
      await chatsApi.addMembers(chatId, userIds)
      await refresh()
      reloadChats()
      setAddOpen(false)
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  return (
    <Modal open onClose={() => navigate(-1)} title="Информация о группе" size="md">
      {loading ? (
        <div className={styles.head}>
          <Spinner size={28} label="Загрузка" />
        </div>
      ) : error || !detail ? (
        <div className={styles.banner}>
          {error ? describeError(error) : 'Группа не найдена'}
        </div>
      ) : (
        <>
          <div className={styles.head}>
            <button
              type="button"
              className={styles.avatarBtn}
              onClick={() => canManage && fileRef.current?.click()}
              disabled={!canManage || saving}
              aria-label="Изменить аватар"
            >
              <Avatar
                src={mediaUrl(detail.chat.avatar_url, { auth: true })}
                name={detail.chat.name}
                size={112}
              />
              {canManage ? (
                <span className={styles.avatarOverlay} aria-hidden>
                  <Camera size={18} />
                </span>
              ) : null}
            </button>
            <input
              ref={fileRef}
              type="file"
              accept="image/jpeg,image/png"
              hidden
              onChange={changeAvatar}
            />
          </div>

          {editingName ? (
            <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
              <Input
                label="Название"
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoFocus
              />
              <Button onClick={saveName} loading={saving} size="sm">
                <Check size={16} />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setName(detail.chat.name ?? '')
                  setEditingName(false)
                }}
              >
                <X size={16} />
              </Button>
            </div>
          ) : (
            <div className={styles.row}>
              <div className={styles.rowLabel}>Название</div>
              <div className={styles.rowValue} style={{ display: 'flex', gap: 8 }}>
                <span style={{ flex: 1 }}>{detail.chat.name}</span>
                {canManage ? (
                  <button
                    type="button"
                    onClick={() => setEditingName(true)}
                    aria-label="Изменить название"
                    style={{ color: 'var(--text-muted)' }}
                  >
                    <Pencil size={16} />
                  </button>
                ) : null}
              </div>
            </div>
          )}

          <div className={styles.section}>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}
            >
              <div className={styles.sectionTitle}>
                Участники: {detail.members.length}
              </div>
              {canManage ? (
                <Button size="sm" variant="ghost" onClick={() => setAddOpen(true)}>
                  <UserPlus size={16} /> Добавить
                </Button>
              ) : null}
            </div>
            <div>
              {detail.members.map((m) => (
                <div key={m.user_id} className={styles.memberRow}>
                  <Avatar
                    src={mediaUrl(m.user?.avatar_url, { auth: true })}
                    name={userDisplayName(m.user)}
                    size={42}
                  />
                  <div className={styles.memberBody}>
                    <div className={styles.memberName}>
                      {userDisplayName(m.user)}
                    </div>
                    <div className={styles.memberRole}>
                      {ROLE_LABEL[m.role] ?? m.role}
                    </div>
                  </div>
                  {canManage &&
                  m.user_id !== user?.id &&
                  m.role !== 'owner' ? (
                    <button
                      type="button"
                      onClick={() => removeMember(m)}
                      aria-label="Удалить участника"
                      style={{ color: 'var(--danger)', padding: 6 }}
                    >
                      <Trash2 size={16} />
                    </button>
                  ) : null}
                </div>
              ))}
            </div>
          </div>

          <div className={styles.actions} style={{ marginTop: 16 }}>
            <Button variant="dangerGhost" onClick={leave}>
              <LogOut size={16} /> Выйти из группы
            </Button>
          </div>

          {addOpen ? (
            <AddMembersDialog
              existingIds={detail.members.map((m) => m.user_id)}
              onClose={() => setAddOpen(false)}
              onConfirm={addMembers}
            />
          ) : null}
        </>
      )}
    </Modal>
  )
}

function AddMembersDialog({ existingIds, onClose, onConfirm }) {
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
