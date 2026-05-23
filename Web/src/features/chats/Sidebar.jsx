import { useEffect, useMemo, useState } from 'react'
import { Menu, Search, MessageSquarePlus, UsersRound, X } from 'lucide-react'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { ChatListItem } from './ChatListItem.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { Avatar } from '../../components/Avatar.jsx'
import { userDisplayName, chatDisplayTitle } from '../../lib/chat.js'
import { mediaUrl } from '../../lib/env.js'
import { describeError } from '../../api/client.js'
import { useOpenModal } from '../../hooks/useOpenModal.js'
import { SideMenu } from './SideMenu.jsx'
import styles from './Sidebar.module.css'

export function Sidebar() {
  const openModal = useOpenModal()
  const user = useAuthStore((s) => s.user)
  const chats = useChatsStore((s) => s.chats)
  const loading = useChatsStore((s) => s.loading)
  const error = useChatsStore((s) => s.error)
  const reload = useChatsStore((s) => s.load)

  const [query, setQuery] = useState('')
  const [menuOpen, setMenuOpen] = useState(false)
  const [composeOpen, setComposeOpen] = useState(false)

  useEffect(() => {
    function onDoc(e) {
      if (e.target.closest('[data-compose-menu]')) return
      setComposeOpen(false)
    }
    if (composeOpen) document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [composeOpen])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return chats
    return chats.filter((c) =>
      chatDisplayTitle(c, user?.id).toLowerCase().includes(q),
    )
  }, [chats, query, user?.id])

  return (
    <div className={styles.wrap}>
      <header className={styles.header}>
        <button
          type="button"
          className={styles.iconBtn}
          aria-label="Меню"
          onClick={() => setMenuOpen(true)}
        >
          <Menu size={22} />
        </button>
        <div className={styles.searchWrap}>
          <Search size={18} className={styles.searchIcon} />
          <input
            className={styles.search}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Поиск"
            type="search"
            aria-label="Поиск чатов"
          />
          {query ? (
            <button
              type="button"
              className={styles.clear}
              onClick={() => setQuery('')}
              aria-label="Очистить поиск"
            >
              <X size={16} />
            </button>
          ) : null}
        </div>
      </header>

      <div className={styles.list} role="list" aria-label="Список чатов">
        {loading && !chats.length ? (
          <div className={styles.center}>
            <Spinner size={28} label="Загрузка" />
          </div>
        ) : error ? (
          <div className={styles.center}>
            <p className={styles.muted}>{describeError(error)}</p>
            <button
              type="button"
              className={styles.retry}
              onClick={() => reload()}
            >
              Повторить
            </button>
          </div>
        ) : !filtered.length ? (
          <div className={styles.center}>
            <p className={styles.muted}>
              {query
                ? 'Ничего не найдено'
                : 'У вас пока нет чатов. Начните новую переписку!'}
            </p>
          </div>
        ) : (
          filtered.map((c) => (
            <ChatListItem key={c.id} chat={c} currentUserId={user?.id} />
          ))
        )}
      </div>

      <div className={styles.fabWrap}>
        <div data-compose-menu className={styles.fabHolder}>
          {composeOpen ? (
            <div className={styles.composeMenu} role="menu">
              <button
                type="button"
                role="menuitem"
                onClick={() => {
                  setComposeOpen(false)
                  openModal('/new-chat')
                }}
              >
                <MessageSquarePlus size={18} />
                Новое сообщение
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => {
                  setComposeOpen(false)
                  openModal('/new-group')
                }}
              >
                <UsersRound size={18} />
                Новая группа
              </button>
            </div>
          ) : null}
          <button
            type="button"
            className={styles.fab}
            aria-label="Новое сообщение"
            onClick={() => setComposeOpen((v) => !v)}
          >
            <MessageSquarePlus size={24} />
          </button>
        </div>
      </div>

      <SideMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        header={
          <button
            type="button"
            className={styles.profileLink}
            onClick={() => {
              setMenuOpen(false)
              openModal('/profile')
            }}
          >
            <Avatar
              src={mediaUrl(user?.avatar_url, { auth: true })}
              name={userDisplayName(user)}
              size={56}
            />
            <div className={styles.profileText}>
              <div className={styles.profileName}>{userDisplayName(user)}</div>
              <div className={styles.profileSub}>{user?.email}</div>
            </div>
          </button>
        }
      />
    </div>
  )
}
