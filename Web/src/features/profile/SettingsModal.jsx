import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Bell, LogOut, Monitor, Moon, SunMedium } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import {
  notificationsEnabled,
  requestNotificationPermission,
  registerServiceWorker,
} from '../../lib/notifications.js'
import { notificationStorage } from '../../lib/storage.js'
import styles from '../chats/SideMenu.module.css'
import profileStyles from './Profile.module.css'

const THEMES = [
  { value: 'system', label: 'Система', Icon: Monitor },
  { value: 'light', label: 'Светлая', Icon: SunMedium },
  { value: 'dark', label: 'Тёмная', Icon: Moon },
]

export function SettingsModal() {
  const navigate = useNavigate()
  const themeSetting = useUiStore((s) => s.themeSetting)
  const setThemeSetting = useUiStore((s) => s.setThemeSetting)
  const showToast = useUiStore((s) => s.showToast)
  const logout = useAuthStore((s) => s.logout)

  const [notifyOn, setNotifyOn] = useState(notificationsEnabled())
  const [permission, setPermission] = useState(
    typeof Notification !== 'undefined' ? Notification.permission : 'unsupported',
  )

  useEffect(() => {
    registerServiceWorker()
  }, [])

  async function toggleNotifications() {
    if (!('Notification' in window)) {
      showToast('Уведомления не поддерживаются', { kind: 'error' })
      return
    }
    if (!notifyOn) {
      const result = await requestNotificationPermission()
      setPermission(result)
      if (result === 'granted') {
        setNotifyOn(true)
        showToast('Уведомления включены', { kind: 'success' })
      } else if (result === 'denied') {
        showToast('Разрешите уведомления в настройках браузера', { kind: 'error' })
      }
      return
    }
    notificationStorage.setEnabled(false)
    setNotifyOn(false)
    showToast('Уведомления отключены', { kind: 'info' })
  }

  return (
    <Modal open onClose={() => navigate(-1)} title="Настройки" size="sm">
      <div className={profileStyles.section} style={{ paddingTop: 0, borderTop: 'none' }}>
        <div className={profileStyles.sectionTitle}>Внешний вид</div>
        <div className={styles.themeRow} role="group" aria-label="Тема оформления">
          {THEMES.map(({ value, label, Icon }) => (
            <button
              key={value}
              type="button"
              className={`${styles.themeBtn} ${
                themeSetting === value ? styles.themeActive : ''
              }`}
              onClick={() => setThemeSetting(value)}
              aria-pressed={themeSetting === value}
            >
              <Icon size={18} />
              <span>{label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className={profileStyles.section}>
        <div className={profileStyles.sectionTitle}>Уведомления</div>
        <button
          type="button"
          className={styles.themeBtn}
          style={{ width: '100%', justifyContent: 'flex-start' }}
          onClick={toggleNotifications}
          aria-pressed={notifyOn}
        >
          <Bell size={18} />
          <span>
            {notifyOn ? 'Уведомления включены' : 'Включить уведомления'}
          </span>
        </button>
        {permission === 'denied' ? (
          <p style={{ margin: '8px 0 0', fontSize: 13, color: 'var(--text-muted)' }}>
            Доступ заблокирован в браузере. Разрешите уведомления для этого сайта.
          </p>
        ) : (
          <p style={{ margin: '8px 0 0', fontSize: 13, color: 'var(--text-muted)' }}>
            Показывать системные уведомления о новых сообщениях, когда вкладка скрыта.
          </p>
        )}
      </div>

      <div className={profileStyles.section}>
        <div className={profileStyles.sectionTitle}>Аккаунт</div>
        <Button
          variant="dangerGhost"
          onClick={async () => {
            await logout()
          }}
          style={{ width: '100%' }}
        >
          <LogOut size={16} /> Выйти из аккаунта
        </Button>
      </div>
    </Modal>
  )
}
