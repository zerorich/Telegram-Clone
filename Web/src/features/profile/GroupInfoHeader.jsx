import { Camera, Check, Pencil, X } from 'lucide-react'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { Input } from '../../components/Input.jsx'
import { mediaUrl } from '../../lib/env.js'
import styles from './Profile.module.css'

export function GroupInfoHeader({
  chat,
  canManage,
  saving,
  editingName,
  name,
  onNameChange,
  onStartEdit,
  onCancelEdit,
  onSaveName,
  onAvatarClick,
  fileRef,
  onAvatarChange,
}) {
  return (
    <>
      <div className={styles.head}>
        <button
          type="button"
          className={styles.avatarBtn}
          onClick={onAvatarClick}
          disabled={!canManage || saving}
          aria-label="Изменить аватар"
        >
          <Avatar
            src={mediaUrl(chat.avatar_url, { auth: true })}
            name={chat.name}
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
          onChange={onAvatarChange}
        />
      </div>

      {editingName ? (
        <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
          <Input
            label="Название"
            value={name}
            onChange={(e) => onNameChange(e.target.value)}
            autoFocus
          />
          <Button onClick={onSaveName} loading={saving} size="sm">
            <Check size={16} />
          </Button>
          <Button variant="ghost" size="sm" onClick={onCancelEdit}>
            <X size={16} />
          </Button>
        </div>
      ) : (
        <div className={styles.row}>
          <div className={styles.rowLabel}>Название</div>
          <div className={styles.rowValue} style={{ display: 'flex', gap: 8 }}>
            <span style={{ flex: 1 }}>{chat.name}</span>
            {canManage ? (
              <button
                type="button"
                onClick={onStartEdit}
                aria-label="Изменить название"
                style={{ color: 'var(--text-muted)' }}
              >
                <Pencil size={16} />
              </button>
            ) : null}
          </div>
        </div>
      )}
    </>
  )
}
