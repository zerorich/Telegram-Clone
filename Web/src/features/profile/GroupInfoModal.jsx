import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { LogOut } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { ConfirmDialog } from '../../components/ConfirmDialog.jsx'
import { chatsApi } from '../../api/chats.js'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { describeError } from '../../api/client.js'
import { userDisplayName } from '../../lib/chat.js'
import { GroupInfoHeader } from './GroupInfoHeader.jsx'
import { GroupMembersSection } from './GroupMembersSection.jsx'
import { AddMembersDialog } from './AddMembersDialog.jsx'
import styles from './Profile.module.css'

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
  const [confirmRemoveMember, setConfirmRemoveMember] = useState(null)
  const [confirmLeave, setConfirmLeave] = useState(false)
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
    setConfirmRemoveMember(null)
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
    setConfirmLeave(false)
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
    <>
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
            <GroupInfoHeader
              chat={detail.chat}
              canManage={canManage}
              saving={saving}
              editingName={editingName}
              name={name}
              onNameChange={setName}
              onStartEdit={() => setEditingName(true)}
              onCancelEdit={() => {
                setName(detail.chat.name ?? '')
                setEditingName(false)
              }}
              onSaveName={saveName}
              onAvatarClick={() => canManage && fileRef.current?.click()}
              fileRef={fileRef}
              onAvatarChange={changeAvatar}
            />

            <GroupMembersSection
              members={detail.members}
              canManage={canManage}
              currentUserId={user?.id}
              onAdd={() => setAddOpen(true)}
              onRemove={(m) => setConfirmRemoveMember(m)}
            />

            <div className={styles.actions} style={{ marginTop: 16 }}>
              <Button variant="dangerGhost" onClick={() => setConfirmLeave(true)}>
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

      <ConfirmDialog
        open={!!confirmRemoveMember}
        onClose={() => setConfirmRemoveMember(null)}
        onConfirm={() => removeMember(confirmRemoveMember)}
        title="Удалить участника"
        message={
          confirmRemoveMember
            ? `Удалить ${userDisplayName(confirmRemoveMember.user)}?`
            : ''
        }
        confirmLabel="Удалить"
      />

      <ConfirmDialog
        open={confirmLeave}
        onClose={() => setConfirmLeave(false)}
        onConfirm={leave}
        title="Выйти из группы"
        message="Выйти из группы?"
        confirmLabel="Выйти"
      />
    </>
  )
}
