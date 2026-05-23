import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Camera, Pencil } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Input } from '../../components/Input.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { usersApi } from '../../api/users.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './Profile.module.css'

export function ProfileModal() {
  const navigate = useNavigate()
  const user = useAuthStore((s) => s.user)
  const setUser = useAuthStore((s) => s.setUser)
  const showToast = useUiStore((s) => s.showToast)

  const [editing, setEditing] = useState(false)
  const [name, setName] = useState(user?.name ?? '')
  const [surname, setSurname] = useState(user?.surname ?? '')
  const [username, setUsername] = useState(user?.username ?? '')
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState(false)
  const fileRef = useRef(null)

  useEffect(() => {
    if (!editing && user) {
      setName(user.name ?? '')
      setSurname(user.surname ?? '')
      setUsername(user.username ?? '')
    }
  }, [user, editing])

  async function save() {
    if (!name.trim()) {
      showToast('Введите имя', { kind: 'error' })
      return
    }
    setSaving(true)
    try {
      const updated = await usersApi.updateMe({
        name: name.trim(),
        surname: surname.trim() || undefined,
        username: username.trim() || undefined,
      })
      setUser(updated)
      setEditing(false)
      showToast('Профиль обновлён', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setSaving(false)
    }
  }

  async function changeAvatar(e) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const updated = await usersApi.uploadAvatar(file)
      setUser(updated)
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setUploading(false)
      e.target.value = ''
    }
  }

  if (!user) return null

  return (
    <Modal
      open
      onClose={() => navigate(-1)}
      title="Профиль"
      size="md"
      footer={
        editing ? (
          <>
            <Button variant="ghost" onClick={() => setEditing(false)}>
              Отмена
            </Button>
            <Button onClick={save} loading={saving}>
              Сохранить
            </Button>
          </>
        ) : (
          <Button variant="ghost" onClick={() => setEditing(true)}>
            <Pencil size={16} /> Изменить
          </Button>
        )
      }
    >
      <div className={styles.head}>
        <button
          type="button"
          className={styles.avatarBtn}
          onClick={() => fileRef.current?.click()}
          disabled={uploading}
          aria-label="Изменить аватар"
        >
          <Avatar
            src={mediaUrl(user.avatar_url, { auth: true })}
            name={userDisplayName(user)}
            size={112}
          />
          <span className={styles.avatarOverlay} aria-hidden>
            <Camera size={18} />
          </span>
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,image/png"
          hidden
          onChange={changeAvatar}
        />
      </div>

      {editing ? (
        <div className={styles.form}>
          <Input
            label="Имя"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
          />
          <Input
            label="Фамилия"
            value={surname}
            onChange={(e) => setSurname(e.target.value)}
          />
          <Input
            label="Имя пользователя"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="username"
            hint="Никнейм для поиска по @"
          />
        </div>
      ) : (
        <div className={styles.info}>
          <Row label="Имя" value={userDisplayName(user)} />
          {user.username ? (
            <Row label="Имя пользователя" value={`@${user.username}`} />
          ) : null}
          {user.email ? <Row label="Email" value={user.email} /> : null}
          {user.phone ? <Row label="Телефон" value={user.phone} /> : null}
        </div>
      )}
    </Modal>
  )
}

function Row({ label, value }) {
  return (
    <div className={styles.row}>
      <div className={styles.rowLabel}>{label}</div>
      <div className={styles.rowValue}>{value}</div>
    </div>
  )
}
