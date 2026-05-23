import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, ArrowDown, MoreVertical, Bookmark } from 'lucide-react'
import { useOpenModal } from '../../hooks/useOpenModal.js'
import { Avatar } from '../../components/Avatar.jsx'
import { Spinner } from '../../components/Spinner.jsx'
import { Modal } from '../../components/Modal.jsx'
import { Button } from '../../components/Button.jsx'
import { ComingSoonModal } from '../../components/ComingSoonModal.jsx'
import { Composer } from './Composer.jsx'
import { MessageBubble } from './MessageBubble.jsx'
import { DateSeparator } from './DateSeparator.jsx'
import { MessageContextMenu } from './MessageContextMenu.jsx'
import { ChatHeaderMenu } from './ChatHeaderMenu.jsx'
import { PinnedBanner } from './PinnedBanner.jsx'
import { InChatSearch } from './InChatSearch.jsx'
import { ForwardPickerModal } from './ForwardPickerModal.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useMessagesStore } from '../../store/messagesStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { wsClient } from '../../ws/client.js'
import {
  chatAvatarUrl,
  chatDisplayTitle,
  isSavedChat,
  memberCountLabel,
  peerMember,
  userDisplayName,
} from '../../lib/chat.js'
import { formatChatDateSeparator } from '../../lib/format.js'
import { chatsApi } from '../../api/chats.js'
import { describeError } from '../../api/client.js'
import { useIsDesktop } from '../../hooks/useMediaQuery.js'
import styles from './ChatStage.module.css'

const SCROLL_BOTTOM_THRESHOLD = 80
const LOAD_MORE_THRESHOLD = 120
const MAX_SCROLL_TO_TOP_BATCHES = 10

function sameDay(a, b) {
  if (!a || !b) return false
  const ad = new Date(a)
  const bd = new Date(b)
  return (
    ad.getFullYear() === bd.getFullYear() &&
    ad.getMonth() === bd.getMonth() &&
    ad.getDate() === bd.getDate()
  )
}

function isAdminOrOwner(member) {
  const role = member?.role
  return role === 'admin' || role === 'owner'
}

function scrollToMessage(chatId, messageId) {
  if (!chatId || !messageId) return false
  const node = document.getElementById(`msg-${messageId}`)
  if (!node) return false
  node.scrollIntoView({ behavior: 'smooth', block: 'center' })
  node.classList.add('msg-highlight')
  setTimeout(() => node.classList.remove('msg-highlight'), 1500)
  return true
}

export function ChatStage({ chatId, showBack, onBack }) {
  const navigate = useNavigate()
  const isDesktop = useIsDesktop()
  const openModal = useOpenModal()
  const user = useAuthStore((s) => s.user)
  const chats = useChatsStore((s) => s.chats)
  const findSavedChat = useChatsStore((s) => s.findSavedChat)
  const applyMuted = useChatsStore((s) => s.applyMuted)
  const removeChat = useChatsStore((s) => s.removeChat)
  const typingUid = useChatsStore((s) => (chatId ? s.typing[chatId] : null))
  const onlineUsers = useChatsStore((s) => s.onlineUsers)

  const chatState = useMessagesStore((s) => (chatId ? s.byChat[chatId] : null))
  const replyTarget = useMessagesStore((s) =>
    chatId ? s.replyTargets[chatId] : null,
  )
  const editTarget = useMessagesStore((s) =>
    chatId ? s.editTargets[chatId] : null,
  )
  const setReply = useMessagesStore((s) => s.setReply)
  const setEdit = useMessagesStore((s) => s.setEdit)
  const loadInitial = useMessagesStore((s) => s.loadInitial)
  const loadMore = useMessagesStore((s) => s.loadMore)
  const sendText = useMessagesStore((s) => s.sendText)
  const sendMedia = useMessagesStore((s) => s.sendMedia)
  const editMessage = useMessagesStore((s) => s.editMessage)
  const deleteMessage = useMessagesStore((s) => s.deleteMessage)
  const markAllRead = useMessagesStore((s) => s.markAllRead)
  const pinMessage = useMessagesStore((s) => s.pinMessage)
  const unpinMessage = useMessagesStore((s) => s.unpinMessage)
  const forwardMessage = useMessagesStore((s) => s.forwardMessage)
  const clearHistory = useMessagesStore((s) => s.clearHistory)

  const showToast = useUiStore((s) => s.showToast)

  const [chatDetail, setChatDetail] = useState(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState(null)
  const [showJumpDown, setShowJumpDown] = useState(false)
  const [stickToBottom, setStickToBottom] = useState(true)
  const [ctxMenu, setCtxMenu] = useState(null) // { message, anchor }
  const [headerMenuOpen, setHeaderMenuOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [comingSoonOpen, setComingSoonOpen] = useState(false)
  const [forwardSource, setForwardSource] = useState(null) // message
  const [confirmClear, setConfirmClear] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [scrollToTopRunning, setScrollToTopRunning] = useState(false)
  const [busyAction, setBusyAction] = useState(false)

  const scrollerRef = useRef(null)
  const bottomAnchorRef = useRef(null)
  const typingTimerRef = useRef(null)
  const lastTypingStateRef = useRef(false)

  const listChat = useMemo(
    () => chats.find((c) => c.id === chatId) ?? null,
    [chats, chatId],
  )

  const chat = chatDetail?.chat ?? listChat
  const members = useMemo(
    () => chatDetail?.members ?? listChat?.members ?? [],
    [chatDetail, listChat],
  )
  const messages = chatState?.messages ?? []
  const loading = chatState?.loading
  const loadingMore = chatState?.loadingMore

  const isSaved = isSavedChat(chat)
  const title = chat ? chatDisplayTitle(chat, user?.id) : ''
  const avatar = chat ? chatAvatarUrl(chat, user?.id) : ''
  const isGroup = chat?.type === 'group'
  const peer = !isGroup && chat ? peerMember(chat, user?.id) : null
  const peerOnline = peer ? !!onlineUsers[peer.user_id] : false
  const someoneTyping =
    typingUid && (!user?.id || typingUid !== user.id) ? typingUid : null
  const typingMember = someoneTyping
    ? members.find((m) => m.user_id === someoneTyping)
    : null

  // Membership of the current user (for delete-permission checks in groups)
  const myMembership = useMemo(
    () => members.find((m) => m.user_id === user?.id) ?? null,
    [members, user?.id],
  )

  useEffect(() => {
    if (!chatId) return
    loadInitial(chatId)
  }, [chatId, loadInitial])

  const needsDetail = useMemo(() => {
    if (!chatId) return false
    if (!listChat) return true
    if (listChat.type === 'saved') return false
    if (listChat.type === 'group') {
      return !listChat.members || listChat.members.length === 0
    }
    return !peerMember(listChat, user?.id)?.user
  }, [chatId, listChat, user?.id])

  useEffect(() => {
    if (!chatId || !needsDetail) return undefined
    let cancelled = false
    setDetailLoading(true)
    setDetailError(null)
    chatsApi
      .get(chatId)
      .then((d) => {
        if (cancelled) return
        setChatDetail(d)
      })
      .catch((e) => {
        if (cancelled) return
        setDetailError(e)
      })
      .finally(() => {
        if (cancelled) return
        setDetailLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [chatId, needsDetail])

  useEffect(() => {
    setStickToBottom(true)
    setShowJumpDown(false)
    setHeaderMenuOpen(false)
    setSearchOpen(false)
    setCtxMenu(null)
    requestAnimationFrame(() => {
      const el = scrollerRef.current
      if (el) el.scrollTop = el.scrollHeight
    })
  }, [chatId])

  const lastMessage = messages[messages.length - 1]
  useEffect(() => {
    if (!chatId || !lastMessage) return
    if (stickToBottom) {
      const el = scrollerRef.current
      if (el) el.scrollTop = el.scrollHeight
      markAllRead(chatId)
    } else if (lastMessage.sender_id !== user?.id) {
      setShowJumpDown(true)
    }
  }, [chatId, lastMessage, stickToBottom, markAllRead, user?.id])

  const onScroll = useCallback(() => {
    const el = scrollerRef.current
    if (!el) return
    const distanceFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight
    const atBottom = distanceFromBottom < SCROLL_BOTTOM_THRESHOLD
    setStickToBottom(atBottom)
    if (atBottom) setShowJumpDown(false)
    if (el.scrollTop < LOAD_MORE_THRESHOLD && chatState?.nextCursor) {
      const prevHeight = el.scrollHeight
      loadMore(chatId).then(() => {
        const next = scrollerRef.current
        if (!next) return
        next.scrollTop = next.scrollHeight - prevHeight + next.scrollTop
      })
    }
  }, [chatId, chatState?.nextCursor, loadMore])

  function scrollToBottom(smooth = true) {
    const el = scrollerRef.current
    if (!el) return
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? 'smooth' : 'auto' })
    setStickToBottom(true)
    setShowJumpDown(false)
  }

  function emitTyping(isTyping) {
    if (!chatId) return
    if (isTyping) {
      if (!lastTypingStateRef.current) {
        wsClient.sendTyping(chatId, true)
        lastTypingStateRef.current = true
      }
      if (typingTimerRef.current) clearTimeout(typingTimerRef.current)
      typingTimerRef.current = setTimeout(() => {
        wsClient.sendTyping(chatId, false)
        lastTypingStateRef.current = false
      }, 2200)
    } else if (lastTypingStateRef.current) {
      wsClient.sendTyping(chatId, false)
      lastTypingStateRef.current = false
      if (typingTimerRef.current) {
        clearTimeout(typingTimerRef.current)
        typingTimerRef.current = null
      }
    }
  }

  useEffect(() => {
    return () => {
      if (typingTimerRef.current) clearTimeout(typingTimerRef.current)
      if (lastTypingStateRef.current && chatId) {
        wsClient.sendTyping(chatId, false)
      }
      lastTypingStateRef.current = false
    }
  }, [chatId])

  async function onSendText({ mode, content, replyToId }) {
    if (mode === 'edit' && editTarget) {
      await editMessage(chatId, editTarget.id, content)
      setEdit(chatId, null)
      return
    }
    await sendText(chatId, { content, replyToId })
    setReply(chatId, null)
    setStickToBottom(true)
    requestAnimationFrame(() => scrollToBottom(false))
  }

  async function onSendMedia(payload) {
    await sendMedia(chatId, payload)
    setReply(chatId, null)
    setStickToBottom(true)
    requestAnimationFrame(() => scrollToBottom(false))
  }

  function openMenuForMessage(message, anchor) {
    setCtxMenu({ message, anchor })
  }

  function canDeleteMessage(message) {
    if (!message || message.is_deleted) return false
    if (message.sender_id === user?.id) return true
    if (isGroup && isAdminOrOwner(myMembership)) return true
    return false
  }

  async function copyMessage(message) {
    try {
      await navigator.clipboard.writeText(message?.content ?? '')
      showToast('Скопировано', { kind: 'success' })
    } catch {
      showToast('Не удалось скопировать', { kind: 'error' })
    }
  }

  async function doDeleteMessage(message) {
    if (!window.confirm('Удалить сообщение?')) return
    try {
      await deleteMessage(chatId, message.id)
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function doTogglePin(message) {
    try {
      if (message.is_pinned) {
        await unpinMessage(chatId, message.id)
        showToast('Откреплено', { kind: 'success' })
      } else {
        await pinMessage(chatId, message.id)
        showToast('Закреплено', { kind: 'success' })
      }
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function doSaveToSaved(message) {
    let saved = findSavedChat()
    if (!saved) {
      try {
        saved = await chatsApi.getSavedChat()
        if (saved) useChatsStore.getState().upsertChat(saved)
      } catch (err) {
        showToast(describeError(err), { kind: 'error' })
        return
      }
    }
    if (!saved) {
      showToast('Не удалось открыть Избранное', { kind: 'error' })
      return
    }
    try {
      await forwardMessage(saved.id, chatId, message.id)
      showToast('Сохранено в Избранное', {
        kind: 'success',
        duration: 5000,
        action: { label: 'Открыть', onClick: () => navigate(`/chats/${saved.id}`) },
      })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function doPickForward(targetChat) {
    if (!forwardSource) {
      setForwardSource(null)
      return
    }
    const src = forwardSource
    setForwardSource(null)
    try {
      await forwardMessage(targetChat.id, chatId, src.id)
      showToast('Переслано', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function doScrollToTop() {
    if (scrollToTopRunning) return
    setScrollToTopRunning(true)
    try {
      for (let i = 0; i < MAX_SCROLL_TO_TOP_BATCHES; i += 1) {
        const slot = useMessagesStore.getState().byChat[chatId]
        if (!slot || !slot.nextCursor) break
        await loadMore(chatId)
      }
    } finally {
      setScrollToTopRunning(false)
      const el = scrollerRef.current
      if (el) el.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  async function doClearHistory() {
    setConfirmClear(false)
    if (!chatId) return
    setBusyAction(true)
    try {
      await clearHistory(chatId)
      showToast('История очищена', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setBusyAction(false)
    }
  }

  async function doDeleteChat() {
    setConfirmDelete(false)
    if (!chatId) return
    setBusyAction(true)
    try {
      await chatsApi.deleteChat(chatId)
      removeChat(chatId)
      navigate('/', { replace: true })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    } finally {
      setBusyAction(false)
    }
  }

  async function doMute(until) {
    if (!chatId) return
    try {
      await chatsApi.muteChat(chatId, until)
      applyMuted(chatId, until ?? null)
      showToast('Уведомления отключены', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  async function doUnmute() {
    if (!chatId) return
    try {
      await chatsApi.unmuteChat(chatId)
      // Mark as unmuted by removing the field locally
      const list = useChatsStore.getState().chats
      const idx = list.findIndex((c) => c.id === chatId)
      if (idx !== -1) {
        const next = [...list]
        const cur = { ...next[idx] }
        delete cur.muted_until
        delete cur.is_muted
        next[idx] = cur
        useChatsStore.setState({ chats: next })
      }
      showToast('Уведомления включены', { kind: 'success' })
    } catch (err) {
      showToast(describeError(err), { kind: 'error' })
    }
  }

  function handleSearchPick(message) {
    if (!message?.id) return
    const slot = useMessagesStore.getState().byChat[chatId]
    const inCache = slot?.messages?.some((m) => m.id === message.id)
    if (!inCache) {
      showToast('Сообщение не в кэше', { kind: 'info' })
      return
    }
    setSearchOpen(false)
    requestAnimationFrame(() => {
      scrollToMessage(chatId, message.id)
    })
  }

  function handlePinnedJump(pinned) {
    if (!pinned?.id) return
    requestAnimationFrame(() => {
      const ok = scrollToMessage(chatId, pinned.id)
      if (!ok) showToast('Сообщение не в кэше', { kind: 'info' })
    })
  }

  if (!chatId) {
    return (
      <div className={styles.empty}>
        <div className={styles.emptyIcon} aria-hidden>
          <svg viewBox="0 0 48 48" width="64" height="64">
            <circle cx="24" cy="24" r="22" fill="currentColor" opacity="0.12" />
            <path
              d="M14 19c0-2.2 1.8-4 4-4h12c2.2 0 4 1.8 4 4v8c0 2.2-1.8 4-4 4h-9l-5 5v-5h-2c-2.2 0-4-1.8-4-4v-8z"
              fill="currentColor"
            />
          </svg>
        </div>
        <p className={styles.emptyText}>
          {isDesktop
            ? 'Выберите чат, чтобы начать переписку'
            : 'У вас нет открытых чатов'}
        </p>
      </div>
    )
  }

  const showSavedEmpty = isSaved && !loading && messages.length === 0

  return (
    <div className={styles.stage}>
      <header className={styles.header}>
        {showBack ? (
          <button
            type="button"
            className={styles.iconBtn}
            aria-label="Назад"
            onClick={onBack}
          >
            <ArrowLeft size={22} />
          </button>
        ) : null}
        <button
          type="button"
          className={styles.titleLink}
          onClick={() => {
            if (isSaved) return
            if (isGroup) openModal(`/group/${chatId}`)
            else if (peer) openModal(`/user/${peer.user_id}`)
          }}
          disabled={!chat || isSaved}
        >
          <Avatar
            src={avatar}
            name={title}
            size={42}
            saved={isSaved}
          />
          <div className={styles.titleBody}>
            <div className={styles.titleText}>{title || 'Чат'}</div>
            <div className={styles.subtitle}>
              {isSaved ? (
                'личное пространство'
              ) : someoneTyping ? (
                <span className={styles.subtitleTyping}>
                  {typingMember?.user
                    ? `${userDisplayName(typingMember.user)} печатает…`
                    : 'печатает…'}
                </span>
              ) : isGroup ? (
                memberCountLabel(members.length || chat?.members?.length || 0)
              ) : peerOnline ? (
                <span className={styles.subtitleOnline}>в сети</span>
              ) : peer ? (
                'был(а) недавно'
              ) : (
                ''
              )}
            </div>
          </div>
        </button>

        <div className={styles.headerActions}>
          <button
            type="button"
            className={styles.iconBtn}
            aria-label="Меню чата"
            aria-expanded={headerMenuOpen}
            onClick={() => setHeaderMenuOpen((v) => !v)}
          >
            <MoreVertical size={22} />
          </button>
        </div>

        <ChatHeaderMenu
          open={headerMenuOpen}
          chat={chat}
          isSaved={isSaved}
          onClose={() => setHeaderMenuOpen(false)}
          onToggleSearch={() => setSearchOpen(true)}
          onCall={() => setComingSoonOpen(true)}
          onScrollToTop={doScrollToTop}
          onClearHistory={() => setConfirmClear(true)}
          onDeleteChat={() => setConfirmDelete(true)}
          onMute={(until) => doMute(until)}
          onUnmute={doUnmute}
        />
      </header>

      {searchOpen ? (
        <InChatSearch
          chatId={chatId}
          onClose={() => setSearchOpen(false)}
          onPick={handleSearchPick}
        />
      ) : null}

      <div className={styles.scroller} ref={scrollerRef} onScroll={onScroll}>
        {!showSavedEmpty ? (
          <PinnedBanner
            chatId={chatId}
            onJump={handlePinnedJump}
            onUnpin={(m) => doTogglePin(m)}
          />
        ) : null}

        {detailError && !chat ? (
          <div className={styles.center}>{describeError(detailError)}</div>
        ) : loading && !messages.length ? (
          <div className={styles.center}>
            <Spinner size={28} label="Загрузка" />
          </div>
        ) : showSavedEmpty ? (
          <div className={styles.savedEmpty}>
            <div className={styles.savedEmptyIcon} aria-hidden>
              <Bookmark size={48} />
            </div>
            <p className={styles.emptyText}>
              Сохраняйте важные сообщения здесь
            </p>
          </div>
        ) : (
          <div className={styles.thread}>
            {loadingMore || scrollToTopRunning ? (
              <div className={styles.loaderRow}>
                <Spinner size={20} />
              </div>
            ) : null}
            {messages.length === 0 ? (
              <div className={styles.center}>
                <p className={styles.emptyText}>
                  Нет сообщений. Напишите первым!
                </p>
              </div>
            ) : (
              messages.map((m, i) => {
                const prev = messages[i - 1]
                const next = messages[i + 1]
                const isMine = m.sender_id === user?.id
                const showDate =
                  !prev || !sameDay(prev.created_at, m.created_at)
                const showSenderName =
                  isGroup &&
                  !isMine &&
                  (!prev ||
                    prev.sender_id !== m.sender_id ||
                    !sameDay(prev.created_at, m.created_at))
                const showTail =
                  !next ||
                  next.sender_id !== m.sender_id ||
                  !sameDay(next.created_at, m.created_at)
                const replyTo = m.reply_to_id
                  ? (messages.find((x) => x.id === m.reply_to_id) ?? null)
                  : null
                const senderMember = members.find(
                  (mem) => mem.user_id === m.sender_id,
                )
                const senderName = senderMember?.user
                  ? userDisplayName(senderMember.user)
                  : null
                return (
                  <div key={m.id}>
                    {showDate ? (
                      <DateSeparator
                        label={formatChatDateSeparator(m.created_at)}
                      />
                    ) : null}
                    <MessageBubble
                      message={m}
                      isMine={isMine}
                      showSenderName={showSenderName}
                      senderName={senderName}
                      replyTo={replyTo}
                      showTail={showTail}
                      onRequestMenu={(anchor) => openMenuForMessage(m, anchor)}
                    />
                  </div>
                )
              })
            )}
            <div ref={bottomAnchorRef} />
          </div>
        )}
      </div>

      {showJumpDown ? (
        <button
          type="button"
          className={styles.jumpBtn}
          onClick={() => scrollToBottom()}
          aria-label="К новым сообщениям"
        >
          <ArrowDown size={20} />
        </button>
      ) : null}

      <Composer
        reply={replyTarget}
        onCancelReply={() => setReply(chatId, null)}
        edit={editTarget}
        onCancelEdit={() => setEdit(chatId, null)}
        onSendText={onSendText}
        onSendMedia={onSendMedia}
        onTyping={emitTyping}
        disabled={detailLoading && !chat}
      />

      <MessageContextMenu
        open={!!ctxMenu}
        anchor={ctxMenu?.anchor}
        message={ctxMenu?.message}
        isMine={ctxMenu?.message?.sender_id === user?.id}
        isDirect={chat?.type === 'direct'}
        canDelete={canDeleteMessage(ctxMenu?.message)}
        onClose={() => setCtxMenu(null)}
        onReply={() => setReply(chatId, ctxMenu?.message)}
        onCopy={() => copyMessage(ctxMenu?.message)}
        onEdit={() => {
          setReply(chatId, null)
          setEdit(chatId, ctxMenu?.message)
        }}
        onDelete={() => doDeleteMessage(ctxMenu?.message)}
        onForward={() => setForwardSource(ctxMenu?.message)}
        onSaveToSaved={() => doSaveToSaved(ctxMenu?.message)}
        onTogglePin={() => doTogglePin(ctxMenu?.message)}
      />

      <ForwardPickerModal
        open={!!forwardSource}
        excludeChatId={chatId}
        onClose={() => setForwardSource(null)}
        onPick={doPickForward}
      />

      <ComingSoonModal
        open={comingSoonOpen}
        onClose={() => setComingSoonOpen(false)}
      />

      <Modal
        open={confirmClear}
        onClose={() => setConfirmClear(false)}
        title="Очистить историю"
        size="sm"
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirmClear(false)}>
              Отмена
            </Button>
            <Button
              variant="danger"
              onClick={doClearHistory}
              loading={busyAction}
            >
              Очистить
            </Button>
          </>
        }
      >
        <p style={{ margin: 0 }}>
          Очистить всю историю сообщений? Это действие нельзя отменить.
        </p>
      </Modal>

      <Modal
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        title="Удалить чат"
        size="sm"
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirmDelete(false)}>
              Отмена
            </Button>
            <Button
              variant="danger"
              onClick={doDeleteChat}
              loading={busyAction}
            >
              Удалить
            </Button>
          </>
        }
      >
        <p style={{ margin: 0 }}>Удалить чат? Сообщения будут удалены.</p>
      </Modal>
    </div>
  )
}
