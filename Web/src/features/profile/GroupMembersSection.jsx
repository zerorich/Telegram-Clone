import { Trash2, UserPlus } from 'lucide-react'
import { Avatar } from '../../components/Avatar.jsx'
import { Button } from '../../components/Button.jsx'
import { mediaUrl } from '../../lib/env.js'
import { userDisplayName } from '../../lib/chat.js'
import styles from './Profile.module.css'

const ROLE_LABEL = {
  owner: 'Создатель',
  admin: 'Администратор',
  member: 'Участник',
}

export function GroupMembersSection({
  members,
  canManage,
  currentUserId,
  onAdd,
  onRemove,
}) {
  return (
    <div className={styles.section}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div className={styles.sectionTitle}>
          Участники: {members.length}
        </div>
        {canManage ? (
          <Button size="sm" variant="ghost" onClick={onAdd}>
            <UserPlus size={16} /> Добавить
          </Button>
        ) : null}
      </div>
      <div>
        {members.map((m) => (
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
            m.user_id !== currentUserId &&
            m.role !== 'owner' ? (
              <button
                type="button"
                onClick={() => onRemove(m)}
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
  )
}
