import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useOpenModal } from '../../hooks/useOpenModal.js'
import { Composer } from './Composer.jsx'
import { ChatStageHeader } from './ChatStageHeader.jsx'
import { ChatMessageList } from './ChatMessageList.jsx'
import { ChatStageModals } from './ChatStageModals.jsx'
import { useAuthStore } from '../../store/authStore.js'
import { useChatsStore } from '../../store/chatsStore.js'
import { useMessagesStore } from '../../store/messagesStore.js'
import { useUiStore } from '../../store/uiStore.js'
import { wsClient } from '../../ws/client.js'
import {
  chatAvatarUrl,
  chatDisplayTitle,
  isSavedChat,
  peerMember,
  userDisplayName,
} from '../../lib/chat.js'
import { chatsApi } from '../../api/chats.js'
import { describeError } from '../../api/client.js'
import { callManager } from '../../lib/callManager.js'
import { useIsDesktop } from '../../hooks/useMediaQuery.js'
import styles from './ChatStage.module.css'

const SCROLL_BOTTOM_THRESHOLD = 80
const LOAD_MORE_THRESHOLD = 120
const MAX_SCROLL_TO_TOP_BATCHES = 10

function scrollToMessage(chatId, messageId) {
  if (!chatId || !messageId) return false
  const node = document.getElementById(`msg-${messageId}`)
  if (!node) return false
  node.scrollIntoView({ behavior: 'smooth', block: 'center' })
  node.classList.add('msg-highlight')
  setTimeout(() => node.classList.remove('msg-highlight'), 1500)
  return true
}

function isAdminOrOwner(member) {
  const role = member?.role
  return role === 'admin' || role === 'owner'
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
  const [ctxMenu, setCtxMenu] = useState(null)
  const [headerMenuOpen, setHeaderMenuOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [callStartOpen, setCallStartOpen] = useState(false)
  const [forwardSource, setForwardSource] = useState(null)
  const [confirmClear, setConfirmClear] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [confirmDeleteMessage, setConfirmDeleteMessage] = useState(null)
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
    if (!message) return
    setConfirmDeleteMessage(null)
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

  function handleStartCall(media) {
    setCallStartOpen(false)
    if (!peer?.user_id) {
      showToast('Звонки доступны только в личных чатах', { kind: 'info' })
      return
    }
    const peerName = peer.user ? userDisplayName(peer.user) : title
    callManager.startCall(peer.user_id, peerName, media)
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
      <ChatStageHeader
        showBack={showBack}
        onBack={onBack}
        chat={chat}
        isSaved={isSaved}
        isGroup={isGroup}
        title={title}
        avatar={avatar}
        membersCount={members.length || chat?.members?.length || 0}
        peer={peer}
        peerOnline={peerOnline}
        someoneTyping={someoneTyping}
        typingMember={typingMember}
        headerMenuOpen={headerMenuOpen}
        onToggleHeaderMenu={(v) =>
          setHeaderMenuOpen(typeof v === 'boolean' ? v : (o) => !o)
        }
        onOpenProfile={() => {
          if (isSaved) return
          if (isGroup) openModal(`/group/${chatId}`)
          else if (peer) openModal(`/user/${peer.user_id}`)
        }}
        onToggleSearch={() => setSearchOpen(true)}
        onCall={() => setCallStartOpen(true)}
        onScrollToTop={doScrollToTop}
        onClearHistory={() => setConfirmClear(true)}
        onDeleteChat={() => setConfirmDelete(true)}
        onMute={doMute}
        onUnmute={doUnmute}
      />

      <ChatMessageList
        ref={scrollerRef}
        chatId={chatId}
        messages={messages}
        members={members}
        userId={user?.id}
        isGroup={isGroup}
        loading={loading}
        loadingMore={loadingMore}
        scrollToTopRunning={scrollToTopRunning}
        showSavedEmpty={showSavedEmpty}
        detailError={detailError}
        chat={chat}
        showJumpDown={showJumpDown}
        onScroll={onScroll}
        onJumpDown={() => scrollToBottom()}
        onPinnedJump={handlePinnedJump}
        onUnpin={(m) => doTogglePin(m)}
        onRequestMenu={(message, anchor) => setCtxMenu({ message, anchor })}
        bottomAnchorRef={bottomAnchorRef}
      />

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

      <ChatStageModals
        chatId={chatId}
        chat={chat}
        searchOpen={searchOpen}
        onCloseSearch={() => setSearchOpen(false)}
        onSearchPick={handleSearchPick}
        ctxMenu={ctxMenu}
        onCloseCtxMenu={() => setCtxMenu(null)}
        isMine={ctxMenu?.message?.sender_id === user?.id}
        canDelete={canDeleteMessage(ctxMenu?.message)}
        onReply={() => setReply(chatId, ctxMenu?.message)}
        onCopy={() => copyMessage(ctxMenu?.message)}
        onEdit={() => {
          setReply(chatId, null)
          setEdit(chatId, ctxMenu?.message)
        }}
        onDeleteRequest={() => setConfirmDeleteMessage(ctxMenu?.message)}
        onForward={() => setForwardSource(ctxMenu?.message)}
        onSaveToSaved={() => doSaveToSaved(ctxMenu?.message)}
        onTogglePin={() => doTogglePin(ctxMenu?.message)}
        forwardSource={forwardSource}
        onCloseForward={() => setForwardSource(null)}
        onPickForward={doPickForward}
        callStartOpen={callStartOpen}
        onCloseCallStart={() => setCallStartOpen(false)}
        onStartCall={handleStartCall}
        confirmClear={confirmClear}
        onCloseConfirmClear={() => setConfirmClear(false)}
        onConfirmClear={doClearHistory}
        confirmDelete={confirmDelete}
        onCloseConfirmDelete={() => setConfirmDelete(false)}
        onConfirmDeleteChat={doDeleteChat}
        confirmDeleteMessage={confirmDeleteMessage}
        onCloseConfirmDeleteMessage={() => setConfirmDeleteMessage(null)}
        onConfirmDeleteMessage={() => doDeleteMessage(confirmDeleteMessage)}
        busyAction={busyAction}
      />
    </div>
  )
}
