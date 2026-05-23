import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { MessageSquarePlus } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { usersApi } from '../../api/users.js'
import { chatsApi } from '../../api/chats.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './Profile.module.css'

export function UserProfileModal() {
  const navigate = useNavigate()
  const { userId } = useParams()
  const upsertChat = useChatsStore((s) => s.upsertChat)
  const showToast = useUiStore((s) => s.showToast)

  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [creating, setCreating] = useState(false)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    usersApi
      .get(userId)
      .then((u) => {
        if (cancelled) return
        setUser(u)
      })
      .catch((e) => {
        if (cancelled) return
        setError(e)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [userId])

  async function startChat() {
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
    <Modal open onClose={() => navigate(-1)} title="Профиль" size="sm">
      {loading ? (
        <div className={styles.head}>
          <Spinner size={28} label="Загрузка" />
        </div>
      ) : error || !user ? (
        <div className={styles.banner}>
          {error ? describeError(error) : 'Пользователь не найден'}
        </div>
      ) : (
        <>
          <div className={styles.head}>
            <Avatar
              src={mediaUrl(user.avatar_url, { auth: true })}
              name={userDisplayName(user)}
              size={112}
            />
          </div>
          <div className={styles.info}>
            <div className={styles.row}>
              <div className={styles.rowLabel}>Имя</div>
              <div className={styles.rowValue}>{userDisplayName(user)}</div>
            </div>
            {user.username ? (
              <div className={styles.row}>
                <div className={styles.rowLabel}>Имя пользователя</div>
                <div className={styles.rowValue}>@{user.username}</div>
              </div>
            ) : null}
            {user.email ? (
              <div className={styles.row}>
                <div className={styles.rowLabel}>Email</div>
                <div className={styles.rowValue}>{user.email}</div>
              </div>
            ) : null}
            {user.phone ? (
              <div className={styles.row}>
                <div className={styles.rowLabel}>Телефон</div>
                <div className={styles.rowValue}>{user.phone}</div>
              </div>
            ) : null}
          </div>
          <div className={styles.startBtn}>
            <Button onClick={startChat} loading={creating} style={{ width: '100%' }}>
              <MessageSquarePlus size={18} /> Написать
            </Button>
          </div>
        </>
      )}
    </Modal>
  )
}
