import { useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Sidebar } from '../features/chats/Sidebar.jsx'
import { ChatStage } from '../features/chat/ChatStage.jsx'
import { useChatsStore } from '../store/chatsStore.js'
import { useIsDesktop } from '../hooks/useMediaQuery.js'
import { useVisualViewport } from '../hooks/useVisualViewport.js'
import styles from './AppLayout.module.css'

export function AppLayout() {
  useVisualViewport()
  const isDesktop = useIsDesktop()
  const params = useParams()
  const navigate = useNavigate()
  const setActiveChatId = useChatsStore((s) => s.setActiveChatId)
  const loadChats = useChatsStore((s) => s.load)
  const chats = useChatsStore((s) => s.chats)
  const chatsLoading = useChatsStore((s) => s.loading)

  const chatId = params.chatId ?? null
  const onChat = !!chatId

  useEffect(() => {
    setActiveChatId(chatId)
    return () => setActiveChatId(null)
  }, [chatId, setActiveChatId])

  useEffect(() => {
    loadChats()
  }, [loadChats])

  // If the active chat was deleted (via WS or otherwise) and we have a fresh
  // chats list, drop the route back to the chat list.
  useEffect(() => {
    if (!chatId || chatsLoading || !chats.length) return
    if (!chats.some((c) => c.id === chatId)) {
      navigate('/', { replace: true })
    }
  }, [chatId, chats, chatsLoading, navigate])

  return (
    <div
      className={styles.shell}
      data-mobile-pane={isDesktop ? 'split' : onChat ? 'chat' : 'list'}
    >
      <aside className={styles.sidebar}>
        <Sidebar />
      </aside>
      <main className={styles.main}>
        <ChatStage
          chatId={chatId}
          showBack={!isDesktop && onChat}
          onBack={() => navigate('/')}
        />
      </main>
    </div>
  )
}
