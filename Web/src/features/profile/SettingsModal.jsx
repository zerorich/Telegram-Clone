import { useNavigate } from 'react-router-dom'
import { LogOut, Monitor, Moon, SunMedium } from 'lucide-react'
import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
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
  const logout = useAuthStore((s) => s.logout)

  return (
    <Modal open onClose={() => navigate(-1)} title="Настройки" size="sm">
      <div className={profileStyles.section} style={{ paddingTop: 0, borderTop: 'none' }}>
        <div className={profileStyles.sectionTitle}>Внешний вид</div>
        <div className={styles.themeRow}>
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
