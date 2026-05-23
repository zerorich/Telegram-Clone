import { useEffect } from 'react'
import { Settings, LogOut, UserCircle2, Moon, SunMedium, Monitor } from 'lucide-react'
import { useAuthStore } from '../../store/authStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { useOpenModal } from '../../hooks/useOpenModal.js'
import styles from './SideMenu.module.css'

const THEMES = [
  { value: 'system', label: 'Система', Icon: Monitor },
  { value: 'light', label: 'Светлая', Icon: SunMedium },
  { value: 'dark', label: 'Тёмная', Icon: Moon },
]

export function SideMenu({ open, onClose, header }) {
  const logout = useAuthStore((s) => s.logout)
  const themeSetting = useUiStore((s) => s.themeSetting)
  const setThemeSetting = useUiStore((s) => s.setThemeSetting)
  const openModal = useOpenModal()

  useEffect(() => {
    if (!open) return undefined
    const onKey = (e) => e.key === 'Escape' && onClose?.()
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null
  return (
    <div className={styles.backdrop} onMouseDown={onClose}>
      <aside
        className={styles.panel}
        onMouseDown={(e) => e.stopPropagation()}
        aria-label="Меню"
      >
        {header}
        <nav className={styles.nav}>
          <button
            type="button"
            className={styles.item}
            onClick={() => {
              onClose?.()
              openModal('/profile')
            }}
          >
            <UserCircle2 size={20} />
            <span>Профиль</span>
          </button>
          <button
            type="button"
            className={styles.item}
            onClick={() => {
              onClose?.()
              openModal('/settings')
            }}
          >
            <Settings size={20} />
            <span>Настройки</span>
          </button>
        </nav>
        <div className={styles.section}>
          <div className={styles.sectionTitle}>Тема</div>
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
        <button
          type="button"
          className={`${styles.item} ${styles.logout}`}
          onClick={async () => {
            onClose?.()
            await logout()
          }}
        >
          <LogOut size={20} />
          <span>Выйти</span>
        </button>
      </aside>
    </div>
  )
}
