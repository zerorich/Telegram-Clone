import { forwardRef } from 'react'
import { ArrowDown, Bookmark } from 'lucide-react'
import { Spinner } from '../../components/Spinner.jsx'
import { MessageBubble } from './MessageBubble.jsx'
import { DateSeparator } from './DateSeparator.jsx'
import { PinnedBanner } from './PinnedBanner.jsx'
import { formatChatDateSeparator } from '../../lib/format.js'
import { userDisplayName } from '../../lib/chat.js'
import { describeError } from '../../api/client.js'
import styles from './ChatStage.module.css'

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

export const ChatMessageList = forwardRef(function ChatMessageList(
  {
    chatId,
    messages,
    members,
    userId,
    isGroup,
    loading,
    loadingMore,
    scrollToTopRunning,
    showSavedEmpty,
    detailError,
    chat,
    showJumpDown,
    onScroll,
    onJumpDown,
    onPinnedJump,
    onUnpin,
    onRequestMenu,
    bottomAnchorRef,
  },
  scrollerRef,
) {
  return (
    <>
      <div className={styles.scroller} ref={scrollerRef} onScroll={onScroll}>
        {!showSavedEmpty ? (
          <PinnedBanner
            chatId={chatId}
            onJump={onPinnedJump}
            onUnpin={onUnpin}
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
                const isMine = m.sender_id === userId
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
                      onRequestMenu={(anchor) => onRequestMenu(m, anchor)}
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
          onClick={onJumpDown}
          aria-label="К новым сообщениям"
        >
          <ArrowDown size={20} />
        </button>
      ) : null}
    </>
  )
})
